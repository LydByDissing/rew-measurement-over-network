package com.lydbydissing.audio;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.DataLine;
import javax.sound.sampled.LineUnavailableException;
import javax.sound.sampled.TargetDataLine;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/**
 * Virtual audio device that captures audio from the system and streams it to a Pi device.
 * 
 * <p>This class creates a virtual audio sink that REW can output to. It uses Java Sound API
 * to capture audio data and forwards it to registered audio data consumers (typically the
 * RTP streaming service). The device runs in a separate thread to avoid blocking the main
 * application.</p>
 * 
 * <p>The virtual device supports standard audio formats (16/24-bit, 44.1/48/96 kHz) and
 * provides real-time audio level monitoring for the GUI.</p>
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class VirtualAudioDevice {
    
    private static final Logger LOGGER = LoggerFactory.getLogger(VirtualAudioDevice.class);
    
    /** Default audio format: 48kHz, 16-bit, stereo. */
    public static final AudioFormat DEFAULT_FORMAT = new AudioFormat(
        AudioFormat.Encoding.PCM_SIGNED,
        48000.0f,  // Sample rate
        16,        // Bits per sample
        2,         // Channels (stereo)
        4,         // Frame size (2 channels * 2 bytes)
        48000.0f,  // Frame rate
        false      // Little endian
    );
    
    /** Buffer size for audio capture in bytes. */
    private static final int BUFFER_SIZE = 4096;
    
    /** Queue size for audio data buffering. */
    private static final int QUEUE_SIZE = 100;
    
    private TargetDataLine targetLine;
    private AudioFormat audioFormat;
    private Thread captureThread;
    private final AtomicBoolean isRunning = new AtomicBoolean(false);
    private final AtomicBoolean isCapturing = new AtomicBoolean(false);
    
    // Audio data processing
    private final BlockingQueue<byte[]> audioDataQueue = new LinkedBlockingQueue<>(QUEUE_SIZE);
    private Consumer<byte[]> audioDataConsumer;
    private Consumer<Double> audioLevelConsumer;
    
    // Audio level calculation
    private double currentAudioLevel = 0.0;
    private long lastLevelUpdate = 0;
    private static final long LEVEL_UPDATE_INTERVAL = 50; // ms
    
    /**
     * Creates a virtual audio device with default audio format.
     */
    public VirtualAudioDevice() {
        this(DEFAULT_FORMAT);
    }
    
    /**
     * Creates a virtual audio device with the specified audio format.
     * 
     * @param audioFormat The audio format to use for capture
     */
    public VirtualAudioDevice(AudioFormat audioFormat) {
        this.audioFormat = audioFormat;
        LOGGER.info("Created virtual audio device with format: {}", formatToString(audioFormat));
    }
    
    /**
     * Starts the virtual audio device.
     * Initializes the audio capture line and begins capturing audio data.
     * 
     * @throws LineUnavailableException if the audio line cannot be opened
     * @throws IllegalStateException if the device is already running
     */
    public void start() throws LineUnavailableException {
        if (isRunning.get()) {
            throw new IllegalStateException("Virtual audio device is already running");
        }
        
        LOGGER.info("Starting virtual audio device");
        
        try {
            // Get and open the target data line
            DataLine.Info lineInfo = new DataLine.Info(TargetDataLine.class, audioFormat);
            
            if (!AudioSystem.isLineSupported(lineInfo)) {
                throw new LineUnavailableException("Audio format not supported: " + formatToString(audioFormat));
            }
            
            targetLine = (TargetDataLine) AudioSystem.getLine(lineInfo);
            targetLine.open(audioFormat, BUFFER_SIZE);
            
            // Start the capture thread
            captureThread = new Thread(this::captureLoop, "AudioCapture");
            isRunning.set(true);
            captureThread.start();
            
            // Start the target line
            targetLine.start();
            isCapturing.set(true);
            
            LOGGER.info("Virtual audio device started successfully");
            
        } catch (LineUnavailableException e) {
            LOGGER.error("Failed to start virtual audio device", e);
            cleanup();
            throw e;
        }
    }
    
    /**
     * Stops the virtual audio device.
     * Stops audio capture and releases all resources.
     */
    public void stop() {
        if (!isRunning.get()) {
            LOGGER.warn("Virtual audio device is not running");
            return;
        }
        
        LOGGER.info("Stopping virtual audio device");
        
        isCapturing.set(false);
        isRunning.set(false);
        
        // Stop and close the target line
        if (targetLine != null) {
            targetLine.stop();
            targetLine.close();
        }
        
        // Wait for capture thread to finish
        if (captureThread != null) {
            try {
                captureThread.interrupt();
                captureThread.join(1000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                LOGGER.warn("Interrupted while stopping capture thread");
            }
        }
        
        cleanup();
        LOGGER.info("Virtual audio device stopped");
    }
    
    /**
     * Checks if the virtual audio device is currently running.
     * 
     * @return true if the device is running, false otherwise
     */
    public boolean isRunning() {
        return isRunning.get();
    }
    
    /**
     * Checks if audio is currently being captured.
     * 
     * @return true if audio is being captured, false otherwise
     */
    public boolean isCapturing() {
        return isCapturing.get();
    }
    
    /**
     * Gets the current audio format being used.
     * 
     * @return The current audio format
     */
    public AudioFormat getAudioFormat() {
        return audioFormat;
    }
    
    /**
     * Gets the current audio level (0.0 to 1.0).
     * 
     * @return The current audio level
     */
    public double getCurrentAudioLevel() {
        return currentAudioLevel;
    }
    
    /**
     * Sets the consumer for audio data.
     * The consumer will receive byte arrays containing audio data.
     * 
     * @param consumer Consumer that will receive audio data
     */
    public void setAudioDataConsumer(Consumer<byte[]> consumer) {
        this.audioDataConsumer = consumer;
        LOGGER.debug("Audio data consumer set");
    }
    
    /**
     * Sets the consumer for audio level updates.
     * The consumer will receive audio level values between 0.0 and 1.0.
     * 
     * @param consumer Consumer that will receive audio level updates
     */
    public void setAudioLevelConsumer(Consumer<Double> consumer) {
        this.audioLevelConsumer = consumer;
        LOGGER.debug("Audio level consumer set");
    }
    
    /**
     * Main audio capture loop running in a separate thread.
     */
    private void captureLoop() {
        LOGGER.debug("Audio capture loop started");
        byte[] buffer = new byte[BUFFER_SIZE];
        
        while (isRunning.get()) {
            try {
                if (targetLine != null && isCapturing.get()) {
                    int bytesRead = targetLine.read(buffer, 0, buffer.length);
                    
                    if (bytesRead > 0) {
                        // Create a copy of the data for processing
                        byte[] audioData = new byte[bytesRead];
                        System.arraycopy(buffer, 0, audioData, 0, bytesRead);
                        
                        // Calculate audio level
                        updateAudioLevel(audioData);
                        
                        // Queue audio data for consumption
                        if (audioDataConsumer != null) {
                            if (!audioDataQueue.offer(audioData)) {
                                LOGGER.warn("Audio data queue is full, dropping data");
                            }
                        }
                        
                        // Process queued audio data
                        processQueuedAudioData();
                    }
                    
                } else {
                    // Sleep briefly if not capturing
                    Thread.sleep(10);
                }
                
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            } catch (Exception e) {
                LOGGER.error("Error in audio capture loop", e);
                break;
            }
        }
        
        LOGGER.debug("Audio capture loop ended");
    }
    
    /**
     * Processes queued audio data by sending it to the consumer.
     */
    private void processQueuedAudioData() {
        if (audioDataConsumer == null) {
            return;
        }
        
        byte[] audioData;
        while ((audioData = audioDataQueue.poll()) != null) {
            try {
                audioDataConsumer.accept(audioData);
            } catch (Exception e) {
                LOGGER.error("Error processing audio data", e);
                break;
            }
        }
    }
    
    /**
     * Updates the current audio level and notifies the level consumer.
     * 
     * @param audioData The audio data to analyze
     */
    private void updateAudioLevel(byte[] audioData) {
        long currentTime = System.currentTimeMillis();
        if (currentTime - lastLevelUpdate < LEVEL_UPDATE_INTERVAL) {
            return;
        }
        
        // Calculate RMS level for 16-bit stereo audio
        long sum = 0;
        int samples = audioData.length / 2; // 16-bit = 2 bytes per sample
        
        for (int i = 0; i < audioData.length - 1; i += 2) {
            // Convert bytes to 16-bit signed integer
            int sample = (audioData[i + 1] << 8) | (audioData[i] & 0xFF);
            sum += sample * sample;
        }
        
        // Calculate RMS and normalize to 0.0-1.0 range
        double rms = Math.sqrt((double) sum / samples);
        currentAudioLevel = Math.min(rms / 32768.0, 1.0); // 32768 = max 16-bit value
        
        // Notify level consumer
        if (audioLevelConsumer != null) {
            try {
                audioLevelConsumer.accept(currentAudioLevel);
            } catch (Exception e) {
                LOGGER.error("Error notifying audio level consumer", e);
            }
        }
        
        lastLevelUpdate = currentTime;
    }
    
    /**
     * Cleans up resources.
     */
    private void cleanup() {
        audioDataQueue.clear();
        targetLine = null;
        captureThread = null;
        currentAudioLevel = 0.0;
    }
    
    /**
     * Converts an AudioFormat to a readable string.
     * 
     * @param format The audio format to convert
     * @return A string representation of the format
     */
    private String formatToString(AudioFormat format) {
        return String.format("%.1f kHz, %d-bit, %d channels", 
                           format.getSampleRate() / 1000.0,
                           format.getSampleSizeInBits(),
                           format.getChannels());
    }
}