package com.lydbydissing.service;

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
 * Shared service layer for audio bridge functionality.
 * This service is used by both GUI and headless modes to ensure consistent behavior.
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class AudioBridgeService {
    
    private static final Logger LOGGER = LoggerFactory.getLogger(AudioBridgeService.class);
    
    // Audio components
    private PulseAudioVirtualDevice virtualDevice;
    private JavaAudioLoopback audioLoopback;
    private RTPAudioStreamer activeStreamer;
    
    // State management
    private final AtomicBoolean isInitialized = new AtomicBoolean(false);
    private final AtomicBoolean isConnected = new AtomicBoolean(false);
    
    // Statistics
    private final AtomicLong audioPacketsReceived = new AtomicLong(0);
    private final AtomicLong audioPacketsStreamed = new AtomicLong(0);
    private volatile double currentAudioLevel = 0.0;
    
    // Callbacks for status updates
    private volatile Runnable onAudioSystemInitialized;
    private volatile Runnable onConnectionEstablished;
    private volatile Runnable onConnectionLost;
    
    /**
     * Initializes the audio system using the same logic as HeadlessRunner.
     * 
     * @return true if initialization was successful
     */
    public boolean initializeAudioSystem() {
        if (isInitialized.get()) {
            LOGGER.warn("Audio system is already initialized");
            return true;
        }
        
        LOGGER.info("Initializing audio system");
        
        try {
            // Try to create virtual audio device first (same as headless)
            virtualDevice = new PulseAudioVirtualDevice();
            
            // Set up audio data consumer
            virtualDevice.setAudioDataConsumer(audioData -> {
                audioPacketsReceived.incrementAndGet();
                
                if (activeStreamer != null && activeStreamer.isStreaming()) {
                    try {
                        activeStreamer.streamAudioData(audioData);
                        audioPacketsStreamed.incrementAndGet();
                    } catch (IOException e) {
                        LOGGER.error("Error streaming audio data", e);
                    }
                }
            });
            
            // Start the virtual device
            virtualDevice.start();
            LOGGER.info("Virtual audio device started successfully");
            
            isInitialized.set(true);
            
            // Notify callback
            if (onAudioSystemInitialized != null) {
                onAudioSystemInitialized.run();
            }
            
            return true;
            
        } catch (Exception e) {
            LOGGER.warn("Failed to create virtual audio device, falling back to loopback: {}", e.getMessage());
            
            // Fallback to Java audio loopback
            try {
                audioLoopback = new JavaAudioLoopback();
                
                // Set up audio data consumer
                audioLoopback.setAudioDataConsumer(audioData -> {
                    audioPacketsReceived.incrementAndGet();
                    
                    if (activeStreamer != null && activeStreamer.isStreaming()) {
                        try {
                            activeStreamer.streamAudioData(audioData);
                            audioPacketsStreamed.incrementAndGet();
                        } catch (IOException e2) {
                            LOGGER.error("Error streaming audio data", e2);
                        }
                    }
                });
                
                // Set up level monitoring
                audioLoopback.setAudioLevelConsumer(level -> {
                    currentAudioLevel = level;
                });
                
                // Start the loopback
                audioLoopback.start();
                LOGGER.info("Audio loopback (fallback) started successfully");
                
                isInitialized.set(true);
                
                // Notify callback
                if (onAudioSystemInitialized != null) {
                    onAudioSystemInitialized.run();
                }
                
                return true;
                
            } catch (Exception e2) {
                LOGGER.error("Failed to initialize both virtual device and fallback loopback", e2);
                return false;
            }
        }
    }
    
    /**
     * Connects to a Pi device at the specified address and port.
     * 
     * @param ipAddress The IP address of the Pi device
     * @param port The port to connect to
     * @return true if connection was successful
     */
    public boolean connectToDevice(String ipAddress, int port) {
        if (!isInitialized.get()) {
            LOGGER.error("Audio system must be initialized before connecting");
            return false;
        }
        
        if (isConnected.get()) {
            LOGGER.warn("Already connected to a device. Disconnect first.");
            return false;
        }
        
        try {
            LOGGER.info("Connecting to device: {}:{}", ipAddress, port);
            
            InetAddress targetAddress = InetAddress.getByName(ipAddress);
            
            AudioFormat streamFormat = virtualDevice != null ? 
                PulseAudioVirtualDevice.DEVICE_FORMAT : 
                JavaAudioLoopback.DEFAULT_FORMAT;
                
            activeStreamer = new RTPAudioStreamer(
                targetAddress,
                port,
                streamFormat
            );
            
            // Start streaming
            activeStreamer.startStreaming();
            
            isConnected.set(true);
            LOGGER.info("Successfully connected to {}:{}", ipAddress, port);
            
            // Notify callback
            if (onConnectionEstablished != null) {
                onConnectionEstablished.run();
            }
            
            return true;
            
        } catch (Exception e) {
            LOGGER.error("Failed to connect to device {}:{}", ipAddress, port, e);
            return false;
        }
    }
    
    /**
     * Disconnects from the current device.
     */
    public void disconnect() {
        if (!isConnected.get()) {
            LOGGER.debug("Not connected to any device");
            return;
        }
        
        LOGGER.info("Disconnecting from device");
        
        if (activeStreamer != null) {
            activeStreamer.stopStreaming();
            activeStreamer = null;
        }
        
        isConnected.set(false);
        LOGGER.info("Disconnected successfully");
        
        // Notify callback
        if (onConnectionLost != null) {
            onConnectionLost.run();
        }
    }
    
    /**
     * Shuts down the audio bridge service.
     */
    public void shutdown() {
        LOGGER.info("Shutting down audio bridge service");
        
        // Disconnect first
        disconnect();
        
        // Stop audio system
        if (virtualDevice != null && virtualDevice.isActive()) {
            virtualDevice.stop();
            virtualDevice = null;
        }
        
        if (audioLoopback != null && audioLoopback.isActive()) {
            audioLoopback.stop();
            audioLoopback = null;
        }
        
        isInitialized.set(false);
        LOGGER.info("Audio bridge service stopped");
    }
    
    // Getters for status and statistics
    
    public boolean isInitialized() {
        return isInitialized.get();
    }
    
    public boolean isConnected() {
        return isConnected.get();
    }
    
    public long getAudioPacketsReceived() {
        return audioPacketsReceived.get();
    }
    
    public long getAudioPacketsStreamed() {
        return audioPacketsStreamed.get();
    }
    
    public double getCurrentAudioLevel() {
        return currentAudioLevel;
    }
    
    public String getAudioSystemDescription() {
        if (virtualDevice != null && virtualDevice.isActive()) {
            return virtualDevice.getDeviceDescription();
        } else if (audioLoopback != null && audioLoopback.isActive()) {
            return audioLoopback.getInterfaceDescription() + " (fallback mode)";
        } else {
            return "No audio system";
        }
    }
    
    public String getVirtualDeviceName() {
        if (virtualDevice != null && virtualDevice.isActive()) {
            return virtualDevice.getDeviceName();
        } else {
            return "Default system audio";
        }
    }
    
    // Callback setters
    
    public void setOnAudioSystemInitialized(Runnable callback) {
        this.onAudioSystemInitialized = callback;
    }
    
    public void setOnConnectionEstablished(Runnable callback) {
        this.onConnectionEstablished = callback;
    }
    
    public void setOnConnectionLost(Runnable callback) {
        this.onConnectionLost = callback;
    }
}