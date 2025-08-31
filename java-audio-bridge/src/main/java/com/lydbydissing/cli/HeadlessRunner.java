package com.lydbydissing.cli;

import com.lydbydissing.audio.JavaAudioLoopback;
import com.lydbydissing.audio.PulseAudioVirtualDevice;
import com.lydbydissing.network.RTPAudioStreamer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sound.sampled.AudioFormat;
import java.io.IOException;
import java.net.InetAddress;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

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
    
    private JavaAudioLoopback audioLoopback;
    private PulseAudioVirtualDevice virtualDevice;
    private RTPAudioStreamer streamer;
    private Thread statusThread;
    
    // Statistics
    private final AtomicLong audioPacketsReceived = new AtomicLong(0);
    private final AtomicLong audioPacketsStreamed = new AtomicLong(0);
    private volatile double currentAudioLevel = 0.0;
    
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
            // Initialize virtual audio device (with fallback)
            initializeAudioInterface();
            
            // Initialize RTP streamer
            initializeRTPStreamer();
            
            // Start status monitoring
            startStatusMonitoring();
            
            System.out.println("\n=== REW Network Audio Bridge - Headless Mode ===");
            System.out.println("Connected to Pi: " + options.getTargetIp() + ":" + options.getTargetPort());
            
            if (virtualDevice != null && virtualDevice.isActive()) {
                System.out.println("Audio Interface: " + virtualDevice.getDeviceDescription());
                System.out.println("REW Setup: Select '" + virtualDevice.getDeviceName() + "' as output device");
            } else if (audioLoopback != null && audioLoopback.isActive()) {
                System.out.println("Audio Interface: " + audioLoopback.getInterfaceDescription() + " (fallback mode)");
                System.out.println("REW Setup: Use default system audio output");
            }
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
     * Initializes the audio interface (virtual device with fallback).
     */
    private void initializeAudioInterface() throws Exception {
        logger.info("Initializing audio interface");
        
        try {
            // Try to create virtual audio device first
            virtualDevice = new PulseAudioVirtualDevice();
            
            // Set up audio data consumer
            virtualDevice.setAudioDataConsumer(audioData -> {
                audioPacketsReceived.incrementAndGet();
                
                if (streamer != null && streamer.isStreaming()) {
                    try {
                        streamer.streamAudioData(audioData);
                        audioPacketsStreamed.incrementAndGet();
                    } catch (IOException e) {
                        logger.error("Error streaming audio data", e);
                    }
                }
            });
            
            // Start the virtual device
            virtualDevice.start();
            logger.info("Virtual audio device started successfully");
            
        } catch (Exception e) {
            logger.warn("Failed to create virtual audio device, falling back to loopback: {}", e.getMessage());
            
            // Fallback to Java audio loopback
            audioLoopback = new JavaAudioLoopback();
            
            // Set up audio data consumer
            audioLoopback.setAudioDataConsumer(audioData -> {
                audioPacketsReceived.incrementAndGet();
                
                if (streamer != null && streamer.isStreaming()) {
                    try {
                        streamer.streamAudioData(audioData);
                        audioPacketsStreamed.incrementAndGet();
                    } catch (IOException e2) {
                        logger.error("Error streaming audio data", e2);
                    }
                }
            });
            
            // Set up level monitoring
            audioLoopback.setAudioLevelConsumer(level -> {
                currentAudioLevel = level;
            });
            
            // Start the loopback
            audioLoopback.start();
            logger.info("Audio loopback (fallback) started successfully");
        }
    }
    
    /**
     * Initializes the RTP streamer.
     */
    private void initializeRTPStreamer() throws Exception {
        logger.info("Initializing RTP streamer");
        
        InetAddress targetAddress = InetAddress.getByName(options.getTargetIp());
        
        AudioFormat streamFormat = virtualDevice != null ? 
            PulseAudioVirtualDevice.DEVICE_FORMAT : 
            JavaAudioLoopback.DEFAULT_FORMAT;
            
        streamer = new RTPAudioStreamer(
            targetAddress,
            options.getTargetPort(),
            streamFormat
        );
        
        // Start streaming
        streamer.startStreaming();
        logger.info("RTP streaming started to {}:{}", options.getTargetIp(), options.getTargetPort());
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
                
                long currentAudioPackets = audioPacketsReceived.get();
                long currentStreamPackets = audioPacketsStreamed.get();
                
                long audioRate = currentAudioPackets - lastAudioPackets;
                long streamRate = currentStreamPackets - lastStreamPackets;
                
                // Print status update
                System.out.printf("[%s] Audio: %d pkts/10s (level: %.3f) | Stream: %d pkts/10s | Total: %d audio, %d streamed%n",
                                java.time.LocalTime.now().toString().substring(0, 8),
                                audioRate,
                                currentAudioLevel,
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
        
        // Stop RTP streamer
        if (streamer != null) {
            streamer.close();
            logger.info("RTP streamer stopped");
        }
        
        // Stop virtual audio device
        if (virtualDevice != null) {
            virtualDevice.stop();
            logger.info("Virtual audio device stopped");
        }
        
        // Stop audio loopback (fallback)
        if (audioLoopback != null) {
            audioLoopback.stop();
            logger.info("Audio loopback stopped");
        }
        
        // Print final statistics
        System.out.println("\nFinal Statistics:");
        System.out.println("  Audio packets received: " + audioPacketsReceived.get());
        System.out.println("  Audio packets streamed: " + audioPacketsStreamed.get());
        
        if (streamer != null) {
            RTPAudioStreamer.StreamingStats stats = streamer.getStatistics();
            System.out.println("  RTP packets sent: " + stats.getPacketsSent());
            System.out.println("  RTP bytes sent: " + stats.getBytesSent());
            System.out.println("  Average bitrate: " + String.format("%.1f bps", stats.getAverageBitrate()));
        }
        
        System.out.println("REW Network Audio Bridge stopped.");
        logger.info("Headless runner shutdown complete");
    }
}