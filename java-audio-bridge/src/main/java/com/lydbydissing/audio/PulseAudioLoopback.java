package com.lydbydissing.audio;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sound.sampled.LineUnavailableException;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/**
 * Simple PulseAudio loopback that creates a virtual output device for REW.
 * 
 * <p>This creates a much simpler setup than the previous attempt:</p>
 * <ol>
 *   <li>Create a null-sink that REW can output to</li>
 *   <li>Create a loopback from null-sink.monitor to speakers (so user hears audio)</li>
 *   <li>Java captures audio from null-sink.monitor for streaming to Pi</li>
 * </ol>
 * 
 * <p>This approach is much more reliable and creates a proper virtual audio device.</p>
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class PulseAudioLoopback {
    
    private static final Logger logger = LoggerFactory.getLogger(PulseAudioLoopback.class);
    
    /** Name of the virtual output device */
    public static final String SINK_NAME = "REW_Network_Bridge";
    
    /** Description that appears in audio applications */
    public static final String SINK_DESCRIPTION = "REW Network Audio Bridge";
    
    private final AtomicBoolean isActive = new AtomicBoolean(false);
    private String sinkModuleId;
    private String loopbackModuleId;
    private AudioCaptureMonitor monitor;
    private Consumer<byte[]> audioDataConsumer;
    
    /**
     * Creates and starts the PulseAudio loopback.
     * 
     * @throws IOException if the setup fails
     * @throws IllegalStateException if already active
     */
    public void start() throws IOException {
        if (isActive.get()) {
            throw new IllegalStateException("PulseAudio loopback is already active");
        }
        
        logger.info("Creating PulseAudio loopback: {}", SINK_DESCRIPTION);
        
        if (!isPulseAudioAvailable()) {
            throw new IOException("PulseAudio is not available");
        }
        
        try {
            // Step 1: Create null-sink (this is what REW outputs to)
            createNullSink();
            
            // Step 2: Create loopback so user hears the audio
            createSpeakerLoopback();
            
            // Step 3: Start monitoring for our Java capture
            startMonitoring();
            
            isActive.set(true);
            logger.info("PulseAudio loopback '{}' created successfully", SINK_DESCRIPTION);
            
        } catch (Exception e) {
            logger.error("Failed to create PulseAudio loopback", e);
            cleanup();
            throw new IOException("Failed to create PulseAudio loopback: " + e.getMessage(), e);
        }
    }
    
    /**
     * Stops the PulseAudio loopback and cleans up.
     */
    public void stop() {
        if (!isActive.get()) {
            logger.warn("PulseAudio loopback is not active");
            return;
        }
        
        logger.info("Stopping PulseAudio loopback");
        
        isActive.set(false);
        
        // Stop Java monitoring
        if (monitor != null) {
            monitor.stop();
            monitor = null;
        }
        
        // Remove PulseAudio modules
        removePulseAudioModules();
        
        cleanup();
        logger.info("PulseAudio loopback stopped");
    }
    
    /**
     * Checks if the loopback is active.
     */
    public boolean isActive() {
        return isActive.get();
    }
    
    /**
     * Sets the consumer for captured audio data.
     */
    public void setAudioDataConsumer(Consumer<byte[]> consumer) {
        this.audioDataConsumer = consumer;
        if (monitor != null) {
            monitor.setAudioDataConsumer(consumer);
        }
        logger.debug("Audio data consumer set");
    }
    
    /**
     * Gets the device name that appears in audio applications.
     */
    public String getDeviceName() {
        return SINK_NAME;
    }
    
    /**
     * Gets the device description.
     */
    public String getDeviceDescription() {
        return SINK_DESCRIPTION;
    }
    
    /**
     * Creates the null-sink that REW will output to.
     */
    private void createNullSink() throws IOException {
        logger.debug("Creating null-sink");
        
        ProcessResult result = runCommand(new String[]{
            "pactl", "load-module", "module-null-sink",
            "sink_name=" + SINK_NAME
        });
        
        if (result.exitCode != 0) {
            throw new IOException("Failed to create null-sink: " + result.stderr);
        }
        
        sinkModuleId = result.stdout.trim();
        logger.info("Created null-sink '{}' with module ID: {}", SINK_NAME, sinkModuleId);
    }
    
    /**
     * Creates loopback from our null-sink to speakers so user hears audio.
     */
    private void createSpeakerLoopback() throws IOException {
        logger.debug("Creating speaker loopback");
        
        ProcessResult result = runCommand(new String[]{
            "pactl", "load-module", "module-loopback",
            "source=" + SINK_NAME + ".monitor",
            "sink=@DEFAULT_SINK@",
            "latency_msec=20"
        });
        
        if (result.exitCode != 0) {
            throw new IOException("Failed to create speaker loopback: " + result.stderr);
        }
        
        loopbackModuleId = result.stdout.trim();
        logger.debug("Created speaker loopback with module ID: {}", loopbackModuleId);
    }
    
    /**
     * Starts monitoring the null-sink for Java audio capture.
     */
    private void startMonitoring() throws IOException {
        logger.debug("Starting Java audio monitoring");
        
        String monitorSource = SINK_NAME + ".monitor";
        monitor = new AudioCaptureMonitor(monitorSource, PulseAudioVirtualDevice.DEVICE_FORMAT);
        
        if (audioDataConsumer != null) {
            monitor.setAudioDataConsumer(audioDataConsumer);
        }
        
        try {
            monitor.start();
            logger.debug("Audio monitoring started");
        } catch (Exception e) {
            throw new IOException("Failed to start audio monitoring", e);
        }
    }
    
    /**
     * Removes all PulseAudio modules we created.
     */
    private void removePulseAudioModules() {
        // Remove loopback first
        if (loopbackModuleId != null) {
            logger.debug("Removing loopback module: {}", loopbackModuleId);
            try {
                ProcessResult result = runCommand(new String[]{"pactl", "unload-module", loopbackModuleId});
                if (result.exitCode == 0) {
                    logger.debug("Loopback module removed");
                } else {
                    logger.warn("Failed to remove loopback: {}", result.stderr);
                }
            } catch (IOException e) {
                logger.error("Error removing loopback", e);
            }
        }
        
        // Remove null-sink
        if (sinkModuleId != null) {
            logger.debug("Removing null-sink module: {}", sinkModuleId);
            try {
                ProcessResult result = runCommand(new String[]{"pactl", "unload-module", sinkModuleId});
                if (result.exitCode == 0) {
                    logger.debug("Null-sink module removed");
                } else {
                    logger.warn("Failed to remove null-sink: {}", result.stderr);
                }
            } catch (IOException e) {
                logger.error("Error removing null-sink", e);
            }
        }
    }
    
    /**
     * Checks if PulseAudio is available.
     */
    private boolean isPulseAudioAvailable() {
        try {
            ProcessResult result = runCommand(new String[]{"pactl", "info"});
            return result.exitCode == 0;
        } catch (IOException e) {
            logger.debug("PulseAudio not available: {}", e.getMessage());
            return false;
        }
    }
    
    /**
     * Runs a command and returns the result.
     */
    private ProcessResult runCommand(String[] command) throws IOException {
        ProcessBuilder pb = new ProcessBuilder(command);
        Process process = pb.start();
        
        StringBuilder stdout = new StringBuilder();
        StringBuilder stderr = new StringBuilder();
        
        try (BufferedReader stdoutReader = new BufferedReader(new InputStreamReader(process.getInputStream()));
             BufferedReader stderrReader = new BufferedReader(new InputStreamReader(process.getErrorStream()))) {
            
            String line;
            while ((line = stdoutReader.readLine()) != null) {
                stdout.append(line).append("\n");
            }
            
            while ((line = stderrReader.readLine()) != null) {
                stderr.append(line).append("\n");
            }
        }
        
        try {
            int exitCode = process.waitFor();
            return new ProcessResult(exitCode, stdout.toString(), stderr.toString());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Command interrupted", e);
        }
    }
    
    /**
     * Cleans up resources.
     */
    private void cleanup() {
        monitor = null;
        sinkModuleId = null;
        loopbackModuleId = null;
    }
    
    /**
     * Result of a command execution.
     */
    private static class ProcessResult {
        final int exitCode;
        final String stdout;
        final String stderr;
        
        ProcessResult(int exitCode, String stdout, String stderr) {
            this.exitCode = exitCode;
            this.stdout = stdout;
            this.stderr = stderr;
        }
    }
}