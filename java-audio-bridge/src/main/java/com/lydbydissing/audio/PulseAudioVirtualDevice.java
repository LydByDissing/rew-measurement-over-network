package com.lydbydissing.audio;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.LineUnavailableException;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/**
 * Creates a PulseAudio virtual sink that appears as a system audio device.
 * 
 * <p>This class creates a PulseAudio null-sink that REW and other applications
 * can output audio to. The Java application then monitors this sink and captures
 * the audio for streaming to Pi devices.</p>
 * 
 * <p>This approach creates a real system-level audio device that appears in:</p>
 * <ul>
 *   <li>REW's audio device selection</li>
 *   <li>System sound settings (pavucontrol, etc.)</li>
 *   <li>All audio applications on the system</li>
 * </ul>
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class PulseAudioVirtualDevice {
    
    private static final Logger LOGGER = LoggerFactory.getLogger(PulseAudioVirtualDevice.class);
    
    /** Name of the virtual audio device. */
    public static final String DEVICE_NAME = "REW_Network_Bridge";
    
    /** Human-readable description. */
    public static final String DEVICE_DESCRIPTION = "REW Network Audio Bridge";
    
    /** Audio format for the virtual device. */
    public static final AudioFormat DEVICE_FORMAT = new AudioFormat(
        AudioFormat.Encoding.PCM_SIGNED,
        48000.0f,  // 48kHz sample rate
        16,        // 16-bit
        2,         // Stereo
        4,         // Frame size
        48000.0f,  // Frame rate
        false      // Little endian
    );
    
    private final AtomicBoolean isActive = new AtomicBoolean(false);
    private String sinkModuleId;
    private String loopbackModuleId;
    private AudioCaptureMonitor monitor;
    private Consumer<byte[]> audioDataConsumer;
    
    /**
     * Creates and starts the PulseAudio virtual device.
     * 
     * @throws IOException if the device cannot be created
     * @throws IllegalStateException if already active
     */
    public void start() throws IOException {
        if (isActive.get()) {
            throw new IllegalStateException("PulseAudio virtual device is already active");
        }
        
        LOGGER.info("Creating PulseAudio virtual audio device: {}", DEVICE_DESCRIPTION);
        
        if (!isPulseAudioAvailable()) {
            throw new IOException("PulseAudio is not available - cannot create virtual audio device");
        }
        
        try {
            // Clean up any existing REW devices first
            cleanupExistingDevices();
            
            // Create the null sink (this is what REW will output to)
            createNullSink();
            
            // Create a loopback from the sink to our monitoring
            createLoopback();
            
            // Start monitoring the loopback for audio capture
            startAudioMonitoring();
            
            isActive.set(true);
            LOGGER.info("PulseAudio virtual device '{}' created successfully", DEVICE_DESCRIPTION);
            
        } catch (Exception e) {
            LOGGER.error("Failed to create PulseAudio virtual device", e);
            cleanup();
            throw new IOException("Failed to create virtual audio device: " + e.getMessage(), e);
        }
    }
    
    /**
     * Stops and removes the PulseAudio virtual device.
     */
    public void stop() {
        if (!isActive.get()) {
            LOGGER.warn("PulseAudio virtual device is not active");
            return;
        }
        
        LOGGER.info("Stopping PulseAudio virtual device");
        
        isActive.set(false);
        
        try {
            // Stop audio monitoring
            if (monitor != null) {
                monitor.stop();
                monitor = null;
            }
            
            // Remove PulseAudio modules
            removeLoopback();
            removeNullSink();
            
        } catch (Exception e) {
            LOGGER.error("Error stopping PulseAudio virtual device", e);
        } finally {
            cleanup();
        }
        
        LOGGER.info("PulseAudio virtual device stopped");
    }
    
    /**
     * Checks if the virtual device is currently active.
     * 
     * @return true if active, false otherwise
     */
    public boolean isActive() {
        return isActive.get();
    }
    
    /**
     * Sets the consumer for audio data captured from the virtual device.
     * 
     * @param consumer Consumer that will receive audio data
     */
    public void setAudioDataConsumer(Consumer<byte[]> consumer) {
        this.audioDataConsumer = consumer;
        if (monitor != null) {
            monitor.setAudioDataConsumer(consumer);
        }
        LOGGER.debug("Audio data consumer set for virtual device");
    }
    
    /**
     * Gets the system name of the virtual audio device.
     * 
     * @return The device name as it appears in the system
     */
    public String getDeviceName() {
        return DEVICE_NAME;
    }
    
    /**
     * Gets the description of the virtual audio device.
     * 
     * @return The device description
     */
    public String getDeviceDescription() {
        return DEVICE_DESCRIPTION;
    }
    
    /**
     * Creates the PulseAudio null sink.
     * 
     * @throws IOException if creation fails
     */
    private void createNullSink() throws IOException {
        LOGGER.debug("Creating PulseAudio null sink");
        
        String[] command = {
            "pactl", "load-module", "module-null-sink",
            "sink_name=" + DEVICE_NAME
        };
        
        ProcessResult result = runCommand(command);
        if (result.exitCode != 0) {
            throw new IOException("Failed to create null sink: " + result.stderr);
        }
        
        sinkModuleId = result.stdout.trim();
        LOGGER.info("Created null sink with module ID: {}", sinkModuleId);
    }
    
    /**
     * Creates a loopback from the null sink for monitoring.
     * 
     * @throws IOException if creation fails
     */
    private void createLoopback() throws IOException {
        LOGGER.debug("Creating loopback for audio monitoring");
        
        String[] command = {
            "pactl", "load-module", "module-loopback",
            "source=" + DEVICE_NAME + ".monitor",
            "sink=@DEFAULT_SINK@",
            "latency_msec=1"
        };
        
        ProcessResult result = runCommand(command);
        if (result.exitCode != 0) {
            throw new IOException("Failed to create loopback: " + result.stderr);
        }
        
        loopbackModuleId = result.stdout.trim();
        LOGGER.debug("Created loopback with module ID: {}", loopbackModuleId);
    }
    
    /**
     * Starts monitoring the audio from the virtual device.
     * 
     * @throws IOException if monitoring cannot be started
     */
    private void startAudioMonitoring() throws IOException {
        LOGGER.debug("Starting audio monitoring");
        
        String monitorSource = DEVICE_NAME + ".monitor";
        monitor = new AudioCaptureMonitor(monitorSource, DEVICE_FORMAT);
        
        if (audioDataConsumer != null) {
            monitor.setAudioDataConsumer(audioDataConsumer);
        }
        
        try {
            monitor.start();
            LOGGER.debug("Audio monitoring started for virtual device");
        } catch (LineUnavailableException e) {
            throw new IOException("Failed to start audio monitoring", e);
        }
    }
    
    /**
     * Removes the null sink.
     */
    private void removeNullSink() {
        if (sinkModuleId == null) {
            return;
        }
        
        LOGGER.debug("Removing null sink with module ID: {}", sinkModuleId);
        
        try {
            String[] command = {"pactl", "unload-module", sinkModuleId};
            ProcessResult result = runCommand(command);
            
            if (result.exitCode == 0) {
                LOGGER.debug("Successfully removed null sink");
            } else {
                LOGGER.warn("Failed to remove null sink: {}", result.stderr);
            }
        } catch (IOException e) {
            LOGGER.error("Error removing null sink", e);
        }
        
        sinkModuleId = null;
    }
    
    /**
     * Removes the loopback.
     */
    private void removeLoopback() {
        if (loopbackModuleId == null) {
            return;
        }
        
        LOGGER.debug("Removing loopback with module ID: {}", loopbackModuleId);
        
        try {
            String[] command = {"pactl", "unload-module", loopbackModuleId};
            ProcessResult result = runCommand(command);
            
            if (result.exitCode == 0) {
                LOGGER.debug("Successfully removed loopback");
            } else {
                LOGGER.warn("Failed to remove loopback: {}", result.stderr);
            }
        } catch (IOException e) {
            LOGGER.error("Error removing loopback", e);
        }
        
        loopbackModuleId = null;
    }
    
    /**
     * Checks if PulseAudio is available on the system.
     * 
     * @return true if available, false otherwise
     */
    private boolean isPulseAudioAvailable() {
        try {
            ProcessResult result = runCommand(new String[]{"pactl", "info"});
            return result.exitCode == 0;
        } catch (IOException e) {
            LOGGER.debug("PulseAudio not available: {}", e.getMessage());
            return false;
        }
    }
    
    /**
     * Cleans up any existing REW devices to prevent conflicts.
     */
    private void cleanupExistingDevices() {
        LOGGER.debug("Cleaning up existing REW audio devices");
        
        try {
            // Get list of modules that contain REW
            String[] listCommand = {"pactl", "list", "short", "modules"};
            ProcessResult listResult = runCommand(listCommand);
            
            if (listResult.exitCode == 0) {
                String[] lines = listResult.stdout.split("\\n");
                
                for (String line : lines) {
                    // Look for modules that contain REW in the name
                    if (line.contains("REW") && (line.contains("null-sink") || line.contains("loopback"))) {
                        String[] parts = line.split("\\t");
                        if (parts.length > 0) {
                            String moduleId = parts[0];
                            
                            try {
                                String[] unloadCommand = {"pactl", "unload-module", moduleId};
                                ProcessResult unloadResult = runCommand(unloadCommand);
                                
                                if (unloadResult.exitCode == 0) {
                                    LOGGER.debug("Cleaned up existing REW module: {}", moduleId);
                                } else {
                                    LOGGER.debug("Could not unload module {} (may be already gone): {}", 
                                               moduleId, unloadResult.stderr);
                                }
                                
                            } catch (Exception e) {
                                // Continue with other modules if one fails
                                LOGGER.debug("Failed to unload module {}: {}", moduleId, e.getMessage());
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            // Don't fail the whole operation if cleanup fails
            LOGGER.debug("Error during device cleanup (non-critical): {}", e.getMessage());
        }
    }

    /**
     * Runs a system command and returns the result.
     * 
     * @param command The command to run
     * @return Process result with exit code and output
     * @throws IOException if command execution fails
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
     * Result of running a system command.
     */
    private static class ProcessResult {
        private final int exitCode;
        private final String stdout;
        private final String stderr;
        
        /**
         * Gets the exit code of the process.
         * 
         * @return the exit code
         */
        public int getExitCode() {
            return exitCode;
        }
        
        /**
         * Gets the standard output of the process.
         * 
         * @return the stdout as a string
         */
        public String getStdout() {
            return stdout;
        }
        
        /**
         * Gets the standard error of the process.
         * 
         * @return the stderr as a string
         */
        public String getStderr() {
            return stderr;
        }
        
        ProcessResult(int exitCode, String stdout, String stderr) {
            this.exitCode = exitCode;
            this.stdout = stdout;
            this.stderr = stderr;
        }
    }
}