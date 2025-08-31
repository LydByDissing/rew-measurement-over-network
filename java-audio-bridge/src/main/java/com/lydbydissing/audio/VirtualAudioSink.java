package com.lydbydissing.audio;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sound.sampled.*;
import java.io.IOException;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/**
 * Virtual audio sink that creates a system-level audio device for REW to output to.
 * 
 * <p>This class creates a virtual audio sink using PulseAudio's module-null-sink.
 * REW and other audio applications can then select this as an output device.
 * The sink captures all audio sent to it and forwards it to the RTP streamer.</p>
 * 
 * <p>On Linux systems with PulseAudio, this creates a "REW Network Bridge" audio device
 * that appears in all audio applications and system settings.</p>
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class VirtualAudioSink {
    
    private static final Logger logger = LoggerFactory.getLogger(VirtualAudioSink.class);
    
    /** Name of the virtual audio sink */
    public static final String SINK_NAME = "rew_network_bridge";
    
    /** Human-readable description of the sink */
    public static final String SINK_DESCRIPTION = "REW Network Bridge";
    
    /** Default audio format for the virtual sink */
    public static final AudioFormat DEFAULT_FORMAT = new AudioFormat(
        AudioFormat.Encoding.PCM_SIGNED,
        48000.0f,  // 48kHz sample rate
        16,        // 16-bit
        2,         // Stereo
        4,         // Frame size
        48000.0f,  // Frame rate
        false      // Little endian
    );
    
    private final AtomicBoolean isActive = new AtomicBoolean(false);
    private Process pulseAudioProcess;
    private Consumer<byte[]> audioDataConsumer;
    private AudioCaptureMonitor captureMonitor;
    private String sinkModuleId;
    
    /**
     * Creates a new virtual audio sink.
     */
    public VirtualAudioSink() {
        logger.info("Created virtual audio sink: {}", SINK_DESCRIPTION);
    }
    
    /**
     * Creates and starts the virtual audio sink.
     * This makes the device available to REW and other audio applications.
     * 
     * @throws IOException if the sink cannot be created
     * @throws IllegalStateException if the sink is already active
     */
    public void start() throws IOException {
        if (isActive.get()) {
            throw new IllegalStateException("Virtual audio sink is already active");
        }
        
        logger.info("Starting virtual audio sink");
        
        try {
            // Create PulseAudio null sink
            createPulseAudioSink();
            
            // Start monitoring the sink for audio data
            startAudioCapture();
            
            isActive.set(true);
            logger.info("Virtual audio sink '{}' created and active", SINK_DESCRIPTION);
            
        } catch (Exception e) {
            logger.error("Failed to start virtual audio sink", e);
            cleanup();
            throw new IOException("Failed to create virtual audio sink", e);
        }
    }
    
    /**
     * Stops the virtual audio sink and removes it from the system.
     */
    public void stop() {
        if (!isActive.get()) {
            logger.warn("Virtual audio sink is not active");
            return;
        }
        
        logger.info("Stopping virtual audio sink");
        
        isActive.set(false);
        
        try {
            // Stop audio capture
            if (captureMonitor != null) {
                captureMonitor.stop();
                captureMonitor = null;
            }
            
            // Remove PulseAudio sink
            removePulseAudioSink();
            
        } catch (Exception e) {
            logger.error("Error stopping virtual audio sink", e);
        } finally {
            cleanup();
        }
        
        logger.info("Virtual audio sink stopped");
    }
    
    /**
     * Checks if the virtual audio sink is currently active.
     * 
     * @return true if the sink is active, false otherwise
     */
    public boolean isActive() {
        return isActive.get();
    }
    
    /**
     * Sets the consumer for audio data captured from the virtual sink.
     * 
     * @param consumer Consumer that will receive audio data
     */
    public void setAudioDataConsumer(Consumer<byte[]> consumer) {
        this.audioDataConsumer = consumer;
        if (captureMonitor != null) {
            captureMonitor.setAudioDataConsumer(consumer);
        }
        logger.debug("Audio data consumer set for virtual sink");
    }
    
    /**
     * Gets the name of the virtual audio sink as it appears in the system.
     * 
     * @return The sink name
     */
    public String getSinkName() {
        return SINK_NAME;
    }
    
    /**
     * Gets the description of the virtual audio sink.
     * 
     * @return The sink description
     */
    public String getSinkDescription() {
        return SINK_DESCRIPTION;
    }
    
    /**
     * Creates a PulseAudio null sink using pactl command.
     * 
     * @throws IOException if the sink cannot be created
     */
    private void createPulseAudioSink() throws IOException {
        logger.debug("Creating PulseAudio null sink");
        
        // First check if PulseAudio is available
        if (!isPulseAudioAvailable()) {
            throw new IOException("PulseAudio is not available on this system");
        }
        
        // Create the null sink
        ProcessBuilder pb = new ProcessBuilder(
            "pactl", "load-module", "module-null-sink",
            "sink_name=" + SINK_NAME,
            "sink_properties=device.description=\"" + SINK_DESCRIPTION + "\"",
            "format=s16le",
            "rate=48000",
            "channels=2"
        );
        
        Process process = pb.start();
        try {
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                throw new IOException("Failed to create PulseAudio sink (exit code: " + exitCode + ")");
            }
            
            // Read the module ID from stdout
            byte[] output = process.getInputStream().readAllBytes();
            sinkModuleId = new String(output).trim();
            
            logger.info("Created PulseAudio sink with module ID: {}", sinkModuleId);
            
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Interrupted while creating PulseAudio sink", e);
        }
    }
    
    /**
     * Removes the PulseAudio null sink.
     */
    private void removePulseAudioSink() {
        if (sinkModuleId == null || sinkModuleId.isEmpty()) {
            logger.warn("No module ID available for sink removal");
            return;
        }
        
        logger.debug("Removing PulseAudio sink with module ID: {}", sinkModuleId);
        
        try {
            ProcessBuilder pb = new ProcessBuilder("pactl", "unload-module", sinkModuleId);
            Process process = pb.start();
            int exitCode = process.waitFor();
            
            if (exitCode == 0) {
                logger.info("Successfully removed PulseAudio sink");
            } else {
                logger.warn("Failed to remove PulseAudio sink (exit code: {})", exitCode);
            }
            
        } catch (Exception e) {
            logger.error("Error removing PulseAudio sink", e);
        } finally {
            sinkModuleId = null;
        }
    }
    
    /**
     * Starts capturing audio from the virtual sink monitor.
     * 
     * @throws IOException if audio capture cannot be started
     */
    private void startAudioCapture() throws IOException {
        logger.debug("Starting audio capture from virtual sink");
        
        captureMonitor = new AudioCaptureMonitor(SINK_NAME + ".monitor", DEFAULT_FORMAT);
        if (audioDataConsumer != null) {
            captureMonitor.setAudioDataConsumer(audioDataConsumer);
        }
        
        try {
            captureMonitor.start();
            logger.debug("Audio capture started for virtual sink");
        } catch (LineUnavailableException e) {
            logger.error("Failed to start audio capture monitor", e);
            throw new IOException("Failed to start audio capture from virtual sink", e);
        }
    }
    
    /**
     * Checks if PulseAudio is available on the system.
     * 
     * @return true if PulseAudio is available, false otherwise
     */
    private boolean isPulseAudioAvailable() {
        try {
            ProcessBuilder pb = new ProcessBuilder("pactl", "info");
            Process process = pb.start();
            int exitCode = process.waitFor();
            return exitCode == 0;
        } catch (Exception e) {
            logger.debug("PulseAudio not available: {}", e.getMessage());
            return false;
        }
    }
    
    /**
     * Cleans up resources.
     */
    private void cleanup() {
        if (pulseAudioProcess != null && pulseAudioProcess.isAlive()) {
            pulseAudioProcess.destroyForcibly();
            pulseAudioProcess = null;
        }
        
        sinkModuleId = null;
    }
}