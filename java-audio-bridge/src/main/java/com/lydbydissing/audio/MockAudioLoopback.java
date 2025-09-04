package com.lydbydissing.audio;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sound.sampled.AudioFormat;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/**
 * Mock audio loopback implementation for testing and containerized environments.
 * 
 * <p>This implementation generates synthetic audio data instead of capturing from
 * real audio devices, making it suitable for CI/CD pipelines and Docker containers
 * where audio hardware may not be available.</p>
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class MockAudioLoopback {
    
    private static final Logger LOGGER = LoggerFactory.getLogger(MockAudioLoopback.class);
    
    private final AudioFormat audioFormat;
    private final AtomicBoolean isActive = new AtomicBoolean(false);
    
    private Consumer<byte[]> audioDataConsumer;
    private Consumer<Double> audioLevelConsumer;
    
    private Thread audioThread;
    
    /**
     * Creates a mock audio loopback with the specified audio format.
     * 
     * @param audioFormat The audio format for the mock loopback
     */
    public MockAudioLoopback(AudioFormat audioFormat) {
        this.audioFormat = audioFormat;
        LOGGER.info("Created mock audio loopback with format: {}", formatToString(audioFormat));
    }
    
    public void setAudioDataConsumer(Consumer<byte[]> consumer) {
        this.audioDataConsumer = consumer;
        LOGGER.debug("Audio data consumer set for mock audio loopback");
    }
    
    public void setAudioLevelConsumer(Consumer<Double> consumer) {
        this.audioLevelConsumer = consumer;
        LOGGER.debug("Audio level consumer set for mock audio loopback");
    }
    
    public void start() throws Exception {
        if (isActive.get()) {
            throw new IllegalStateException("Mock audio loopback is already active");
        }
        
        LOGGER.info("Starting mock audio loopback");
        
        isActive.set(true);
        
        // Start mock audio generation thread
        audioThread = new Thread(this::generateMockAudio, "MockAudio-Generator");
        audioThread.start();
        
        LOGGER.info("Mock audio loopback started successfully");
        LOGGER.info("Generating synthetic audio data for testing");
    }
    
    /**
     * Generates synthetic audio data at regular intervals.
     */
    private void generateMockAudio() {
        int sampleRate = (int) audioFormat.getSampleRate();
        int channels = audioFormat.getChannels();
        int bytesPerFrame = audioFormat.getFrameSize();
        
        // Generate 20ms worth of audio per iteration (typical packet size)
        int framesPerPacket = sampleRate / 50; // 20ms
        int bytesPerPacket = framesPerPacket * bytesPerFrame;
        
        byte[] audioData = new byte[bytesPerPacket];
        long frameCount = 0;
        
        LOGGER.debug("Generating mock audio: {}Hz, {} channels, {} bytes per packet", 
                    sampleRate, channels, bytesPerPacket);
        
        while (isActive.get() && !Thread.currentThread().isInterrupted()) {
            try {
                // Generate simple sine wave test pattern
                generateSineWave(audioData, frameCount, sampleRate, channels);
                
                // Send to audio data consumer if available
                if (audioDataConsumer != null) {
                    audioDataConsumer.accept(audioData);
                }
                
                // Calculate and send audio level (simulate moderate level)
                if (audioLevelConsumer != null) {
                    double level = 0.3 + 0.2 * Math.sin(frameCount * 0.001); // Vary between 0.1 and 0.5
                    audioLevelConsumer.accept(level);
                }
                
                frameCount += framesPerPacket;
                
                // Wait 20ms before next packet
                Thread.sleep(20);
                
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            } catch (Exception e) {
                LOGGER.error("Error in mock audio generation", e);
            }
        }
        
        LOGGER.debug("Mock audio generation stopped");
    }
    
    /**
     * Generates a simple sine wave pattern for testing.
     * 
     * @param buffer The buffer to fill with audio data
     * @param startFrame The starting frame number for timing
     * @param sampleRate The audio sample rate in Hz
     * @param channels The number of audio channels
     */
    private void generateSineWave(byte[] buffer, long startFrame, int sampleRate, int channels) {
        int framesInBuffer = buffer.length / (channels * 2); // 16-bit = 2 bytes per sample
        double frequency = 440.0; // A4 note
        
        for (int frame = 0; frame < framesInBuffer; frame++) {
            long globalFrame = startFrame + frame;
            double time = (double) globalFrame / sampleRate;
            
            // Generate sine wave (-1.0 to 1.0)
            double amplitude = 0.1; // Keep it quiet
            double sample = amplitude * Math.sin(2 * Math.PI * frequency * time);
            
            // Convert to 16-bit signed integer
            short sampleValue = (short) (sample * Short.MAX_VALUE);
            
            // Write to buffer for all channels
            for (int channel = 0; channel < channels; channel++) {
                int offset = (frame * channels + channel) * 2;
                if (offset + 1 < buffer.length) {
                    buffer[offset] = (byte) (sampleValue & 0xFF);        // Low byte
                    buffer[offset + 1] = (byte) ((sampleValue >> 8) & 0xFF); // High byte
                }
            }
        }
    }
    
    public void stop() {
        if (!isActive.get()) {
            return;
        }
        
        LOGGER.info("Stopping mock audio loopback");
        isActive.set(false);
        
        if (audioThread != null) {
            audioThread.interrupt();
            try {
                audioThread.join(1000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            audioThread = null;
        }
        
        LOGGER.info("Mock audio loopback stopped");
    }
    
    public boolean isActive() {
        return isActive.get();
    }
    
    public AudioFormat getAudioFormat() {
        return audioFormat;
    }
    
    /**
     * Converts an AudioFormat to a human-readable string.
     * 
     * @param format The AudioFormat to convert
     * @return A human-readable string representation
     */
    private String formatToString(AudioFormat format) {
        return String.format("%.1f kHz, %d-bit, %d channels",
                           format.getSampleRate() / 1000.0,
                           format.getSampleSizeInBits(),
                           format.getChannels());
    }
}