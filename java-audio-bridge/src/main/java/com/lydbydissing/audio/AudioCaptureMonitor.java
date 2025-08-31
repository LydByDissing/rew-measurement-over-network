package com.lydbydissing.audio;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sound.sampled.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/**
 * Monitors a PulseAudio source (typically a monitor) and captures audio data.
 * 
 * <p>This class captures audio from a specific PulseAudio source using the Java Sound API.
 * It's designed to work with monitor sources that provide audio data from sinks.</p>
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class AudioCaptureMonitor {
    
    private static final Logger logger = LoggerFactory.getLogger(AudioCaptureMonitor.class);
    
    /** Buffer size for audio capture */
    private static final int BUFFER_SIZE = 4096;
    
    private final String sourceName;
    private final AudioFormat audioFormat;
    private final AtomicBoolean isRunning = new AtomicBoolean(false);
    
    private TargetDataLine targetLine;
    private Thread captureThread;
    private Consumer<byte[]> audioDataConsumer;
    
    /**
     * Creates an audio capture monitor for the specified source.
     * 
     * @param sourceName  The name of the PulseAudio source to monitor
     * @param audioFormat The audio format to capture
     */
    public AudioCaptureMonitor(String sourceName, AudioFormat audioFormat) {
        this.sourceName = sourceName;
        this.audioFormat = audioFormat;
        logger.debug("Created audio capture monitor for source: {}", sourceName);
    }
    
    /**
     * Starts capturing audio from the source.
     * 
     * @throws LineUnavailableException if the audio line cannot be opened
     * @throws IllegalStateException if already running
     */
    public void start() throws LineUnavailableException {
        if (isRunning.get()) {
            throw new IllegalStateException("Audio capture monitor is already running");
        }
        
        logger.info("Starting audio capture from source: {}", sourceName);
        
        try {
            // Try to get a specific mixer for the PulseAudio source
            Mixer mixer = findPulseAudioMixer(sourceName);
            
            DataLine.Info lineInfo = new DataLine.Info(TargetDataLine.class, audioFormat);
            
            if (mixer != null) {
                targetLine = (TargetDataLine) mixer.getLine(lineInfo);
                logger.debug("Using specific mixer for source: {}", sourceName);
            } else {
                // Fall back to default line
                targetLine = (TargetDataLine) AudioSystem.getLine(lineInfo);
                logger.debug("Using default audio line (PulseAudio source not found)");
            }
            
            targetLine.open(audioFormat, BUFFER_SIZE);
            targetLine.start();
            
            // Start capture thread
            captureThread = new Thread(this::captureLoop, "AudioCaptureMonitor-" + sourceName);
            isRunning.set(true);
            captureThread.start();
            
            logger.info("Audio capture started for source: {}", sourceName);
            
        } catch (LineUnavailableException e) {
            logger.error("Failed to start audio capture for source: {}", sourceName, e);
            cleanup();
            throw e;
        }
    }
    
    /**
     * Stops audio capture.
     */
    public void stop() {
        if (!isRunning.get()) {
            logger.debug("Audio capture monitor is not running");
            return;
        }
        
        logger.info("Stopping audio capture for source: {}", sourceName);
        
        isRunning.set(false);
        
        if (targetLine != null) {
            targetLine.stop();
            targetLine.close();
        }
        
        if (captureThread != null) {
            try {
                captureThread.interrupt();
                captureThread.join(1000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                logger.warn("Interrupted while stopping capture thread");
            }
        }
        
        cleanup();
        logger.info("Audio capture stopped for source: {}", sourceName);
    }
    
    /**
     * Sets the consumer for captured audio data.
     * 
     * @param consumer Consumer that will receive audio data
     */
    public void setAudioDataConsumer(Consumer<byte[]> consumer) {
        this.audioDataConsumer = consumer;
        logger.debug("Audio data consumer set for monitor");
    }
    
    /**
     * Checks if the monitor is currently running.
     * 
     * @return true if running, false otherwise
     */
    public boolean isRunning() {
        return isRunning.get();
    }
    
    /**
     * Main capture loop running in a separate thread.
     */
    private void captureLoop() {
        logger.debug("Audio capture loop started for source: {}", sourceName);
        byte[] buffer = new byte[BUFFER_SIZE];
        
        while (isRunning.get() && !Thread.currentThread().isInterrupted()) {
            try {
                if (targetLine != null && targetLine.isOpen()) {
                    int bytesRead = targetLine.read(buffer, 0, buffer.length);
                    
                    if (bytesRead > 0 && audioDataConsumer != null) {
                        // Create a copy of the data
                        byte[] audioData = new byte[bytesRead];
                        System.arraycopy(buffer, 0, audioData, 0, bytesRead);
                        
                        // Send to consumer
                        audioDataConsumer.accept(audioData);
                    }
                } else {
                    Thread.sleep(10);
                }
                
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            } catch (Exception e) {
                logger.error("Error in audio capture loop for source: {}", sourceName, e);
                break;
            }
        }
        
        logger.debug("Audio capture loop ended for source: {}", sourceName);
    }
    
    /**
     * Attempts to find a PulseAudio mixer for the specified source name.
     * 
     * @param sourceName The source name to look for
     * @return The mixer if found, null otherwise
     */
    private Mixer findPulseAudioMixer(String sourceName) {
        Mixer.Info[] mixerInfos = AudioSystem.getMixerInfo();
        
        for (Mixer.Info mixerInfo : mixerInfos) {
            logger.debug("Checking mixer: {} - {}", mixerInfo.getName(), mixerInfo.getDescription());
            
            // Look for PulseAudio mixers that might match our source
            if (mixerInfo.getName().toLowerCase().contains("pulse") ||
                mixerInfo.getDescription().toLowerCase().contains("pulse")) {
                
                try {
                    Mixer mixer = AudioSystem.getMixer(mixerInfo);
                    
                    // Check if this mixer supports target data lines
                    DataLine.Info lineInfo = new DataLine.Info(TargetDataLine.class, audioFormat);
                    if (mixer.isLineSupported(lineInfo)) {
                        logger.debug("Found compatible PulseAudio mixer: {}", mixerInfo.getName());
                        return mixer;
                    }
                    
                } catch (Exception e) {
                    logger.debug("Error checking mixer {}: {}", mixerInfo.getName(), e.getMessage());
                }
            }
        }
        
        logger.debug("No specific PulseAudio mixer found for source: {}", sourceName);
        return null;
    }
    
    /**
     * Cleans up resources.
     */
    private void cleanup() {
        targetLine = null;
        captureThread = null;
    }
}