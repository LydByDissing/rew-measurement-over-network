package com.lydbydissing.audio;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

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
    
    private static final Logger LOGGER = LoggerFactory.getLogger(PulseAudioLoopback.class);
    
    /** Name of the virtual output device. */
    public static final String SINK_NAME = "REW_Network_Bridge";
    
    /** Description that appears in audio applications. */
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
        
        LOGGER.info("Creating PulseAudio loopback: {}", SINK_DESCRIPTION);
        
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
            LOGGER.info("PulseAudio loopback '{}' created successfully", SINK_DESCRIPTION);
            
        } catch (Exception e) {
            LOGGER.error("Failed to create PulseAudio loopback", e);
            cleanup();
            throw new IOException("Failed to create PulseAudio loopback: " + e.getMessage(), e);
        }
    }
    
    /**
     * Stops the PulseAudio loopback and cleans up.
     */
    public void stop() {
        if (!isActive.get()) {
            LOGGER.warn("PulseAudio loopback is not active");
            return;
        }
        
        LOGGER.info("Stopping PulseAudio loopback");
        
        isActive.set(false);
        
        // Stop Java monitoring
        if (monitor != null) {
            monitor.stop();
            monitor = null;
        }
        
        // Remove PulseAudio modules
        removePulseAudioModules();
        
        cleanup();
        LOGGER.info("PulseAudio loopback stopped");
    }
    
    /**
     * Checks if the loopback is active.
     * 
     * @return true if the loopback is active, false otherwise
     */
    public boolean isActive() {
        return isActive.get();
    }
    
    /**
     * Sets the consumer for captured audio data.
     * 
     * @param consumer the consumer to set for captured audio data
     */
    public void setAudioDataConsumer(Consumer<byte[]> consumer) {
        this.audioDataConsumer = consumer;
        if (monitor != null) {
            monitor.setAudioDataConsumer(consumer);
        }
        LOGGER.debug("Audio data consumer set");
    }
    
    /**
     * Gets the device name that appears in audio applications.
     * 
     * @return the device name
     */
    public String getDeviceName() {
        return SINK_NAME;
    }
    
    /**
     * Gets the device description.
     * 
     * @return the device description
     */
    public String getDeviceDescription() {
        return SINK_DESCRIPTION;
    }
    
    /**
     * Creates the null-sink that REW will output to.
     * 
     * @throws IOException if the null-sink creation fails
     */
    private void createNullSink() throws IOException {
        LOGGER.debug("Creating null-sink");
        
        ProcessResult result = runCommand(new String[]{
            "pactl", "load-module", "module-null-sink",
            "sink_name=" + SINK_NAME
        });
        
        if (result.getExitCode() != 0) {
            throw new IOException("Failed to create null-sink: " + result.getStderr());
        }
        
        sinkModuleId = result.getStdout().trim();
        LOGGER.info("Created null-sink '{}' with module ID: {}", SINK_NAME, sinkModuleId);
    }
    
    /**
     * Creates loopback from our null-sink to speakers so user hears audio.
     * 
     * @throws IOException if the speaker loopback creation fails
     */
    private void createSpeakerLoopback() throws IOException {
        LOGGER.debug("Creating speaker loopback");
        
        ProcessResult result = runCommand(new String[]{
            "pactl", "load-module", "module-loopback",
            "source=" + SINK_NAME + ".monitor",
            "sink=@DEFAULT_SINK@",
            "latency_msec=20"
        });
        
        if (result.getExitCode() != 0) {
            throw new IOException("Failed to create speaker loopback: " + result.getStderr());
        }
        
        loopbackModuleId = result.getStdout().trim();
        LOGGER.debug("Created speaker loopback with module ID: {}", loopbackModuleId);
    }
    
    /**
     * Starts monitoring the null-sink for Java audio capture.
     * 
     * @throws IOException if monitoring cannot be started
     */
    private void startMonitoring() throws IOException {
        LOGGER.debug("Starting Java audio monitoring");
        
        String monitorSource = SINK_NAME + ".monitor";
        monitor = new AudioCaptureMonitor(monitorSource, PulseAudioVirtualDevice.DEVICE_FORMAT);
        
        if (audioDataConsumer != null) {
            monitor.setAudioDataConsumer(audioDataConsumer);
        }
        
        try {
            monitor.start();
            LOGGER.debug("Audio monitoring started");
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
            LOGGER.debug("Removing loopback module: {}", loopbackModuleId);
            try {
                ProcessResult result = runCommand(new String[]{"pactl", "unload-module", loopbackModuleId});
                if (result.getExitCode() == 0) {
                    LOGGER.debug("Loopback module removed");
                } else {
                    LOGGER.warn("Failed to remove loopback: {}", result.getStderr());
                }
            } catch (IOException e) {
                LOGGER.error("Error removing loopback", e);
            }
        }
        
        // Remove null-sink
        if (sinkModuleId != null) {
            LOGGER.debug("Removing null-sink module: {}", sinkModuleId);
            try {
                ProcessResult result = runCommand(new String[]{"pactl", "unload-module", sinkModuleId});
                if (result.getExitCode() == 0) {
                    LOGGER.debug("Null-sink module removed");
                } else {
                    LOGGER.warn("Failed to remove null-sink: {}", result.getStderr());
                }
            } catch (IOException e) {
                LOGGER.error("Error removing null-sink", e);
            }
        }
    }
    
    /**
     * Checks if PulseAudio is available.
     * 
     * @return true if PulseAudio is available, false otherwise
     */
    private boolean isPulseAudioAvailable() {
        try {
            ProcessResult result = runCommand(new String[]{"pactl", "info"});
            return result.getExitCode() == 0;
        } catch (IOException e) {
            LOGGER.debug("PulseAudio not available: {}", e.getMessage());
            return false;
        }
    }
    
    /**
     * Runs a command and returns the result.
     * 
     * @param command the command to run
     * @return the result of the command execution
     * @throws IOException if the command execution fails
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
        private final int exitCode;
        private final String stdout;
        private final String stderr;
        
        ProcessResult(int exitCode, String stdout, String stderr) {
            this.exitCode = exitCode;
            this.stdout = stdout;
            this.stderr = stderr;
        }
        
        /**
         * Gets the exit code.
         * 
         * @return the exit code
         */
        public int getExitCode() {
            return exitCode;
        }
        
        /**
         * Gets the standard output.
         * 
         * @return the standard output
         */
        public String getStdout() {
            return stdout;
        }
        
         /**
          * Gets the standard error.
          * 
          * @return the standard error
          */
         public String getStderr() {
             return stderr;
         }
    }
}