package com.lydbydissing.cli;

import com.lydbydissing.service.AudioBridgeService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Headless runner for the REW Network Audio Bridge.
 * Runs without GUI and connects directly to a specified Pi device.
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class HeadlessRunner {
    
    private static final Logger logger = LoggerFactory.getLogger(HeadlessRunner.class);
    
    private final CliOptions options;
    private final AtomicBoolean running = new AtomicBoolean(false);
    
    private final AudioBridgeService audioBridgeService = new AudioBridgeService();
    private Thread statusThread;
    
    public HeadlessRunner(CliOptions options) {
        this.options = options;
    }
    
    /**
     * Runs the headless audio bridge.
     * 
     * @throws Exception if startup fails
     */
    public void run() throws Exception {
        logger.info("Starting REW Network Audio Bridge in headless mode");
        logger.info("Target: {}:{}", options.getTargetIp(), options.getTargetPort());
        
        running.set(true);
        
        // Setup shutdown hook
        Runtime.getRuntime().addShutdownHook(new Thread(this::shutdown));
        
        try {
            // Initialize audio system
            if (!audioBridgeService.initializeAudioSystem()) {
                throw new Exception("Failed to initialize audio system");
            }
            
            // Connect to target device
            if (!audioBridgeService.connectToDevice(options.getTargetIp(), options.getTargetPort())) {
                throw new Exception("Failed to connect to target device");
            }
            
            // Start status monitoring
            startStatusMonitoring();
            
            System.out.println("\n=== REW Network Audio Bridge - Headless Mode ===");
            System.out.println("Connected to Pi: " + options.getTargetIp() + ":" + options.getTargetPort());
            System.out.println("Audio Interface: " + audioBridgeService.getAudioSystemDescription());
            System.out.println("REW Setup: Select '" + audioBridgeService.getVirtualDeviceName() + "' as output device");
            System.out.println();
            System.out.println("Status: ACTIVE - Audio streaming to Pi device");
            System.out.println("Press Ctrl+C to stop");
            System.out.println("==========================================");
            
            // Keep running until interrupted
            while (running.get()) {
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
            
        } catch (Exception e) {
            logger.error("Error in headless runner", e);
            throw e;
        } finally {
            shutdown();
        }
    }
    
    /**
     * Starts status monitoring in a separate thread.
     */
    private void startStatusMonitoring() {
        statusThread = new Thread(this::statusMonitoringLoop, "StatusMonitor");
        statusThread.setDaemon(true);
        statusThread.start();
    }
    
    /**
     * Status monitoring loop that prints periodic updates.
     */
    private void statusMonitoringLoop() {
        long lastAudioPackets = 0;
        long lastStreamPackets = 0;
        
        while (running.get() && !Thread.currentThread().isInterrupted()) {
            try {
                Thread.sleep(10000); // Update every 10 seconds
                
                if (!running.get()) break;
                
                long currentAudioPackets = audioBridgeService.getAudioPacketsReceived();
                long currentStreamPackets = audioBridgeService.getAudioPacketsStreamed();
                
                long audioRate = currentAudioPackets - lastAudioPackets;
                long streamRate = currentStreamPackets - lastStreamPackets;
                
                // Print status update
                System.out.printf("[%s] Audio: %d pkts/10s (level: %.3f) | Stream: %d pkts/10s | Total: %d audio, %d streamed%n",
                                java.time.LocalTime.now().toString().substring(0, 8),
                                audioRate,
                                audioBridgeService.getCurrentAudioLevel(),
                                streamRate,
                                currentAudioPackets,
                                currentStreamPackets);
                
                lastAudioPackets = currentAudioPackets;
                lastStreamPackets = currentStreamPackets;
                
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    }
    
    /**
     * Shuts down the headless runner and cleans up resources.
     */
    public void shutdown() {
        if (!running.getAndSet(false)) {
            return; // Already shut down
        }
        
        logger.info("Shutting down headless runner");
        System.out.println("\nShutting down...");
        
        // Stop status monitoring
        if (statusThread != null) {
            statusThread.interrupt();
        }
        
        // Use shared service to shutdown everything
        audioBridgeService.shutdown();
        
        // Print final statistics
        System.out.println("\nFinal Statistics:");
        System.out.println("  Audio packets received: " + audioBridgeService.getAudioPacketsReceived());
        System.out.println("  Audio packets streamed: " + audioBridgeService.getAudioPacketsStreamed());
        
        System.out.println("REW Network Audio Bridge stopped.");
        logger.info("Headless runner shutdown complete");
    }
}