package com.lydbydissing.network;

import com.lydbydissing.gui.PiDevice;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.jmdns.JmDNS;
import javax.jmdns.ServiceEvent;
import javax.jmdns.ServiceListener;
import java.io.IOException;
import java.net.InetAddress;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

/**
 * Service for discovering Raspberry Pi devices on the local network using mDNS.
 * 
 * <p>This service uses JmDNS (Java implementation of multicast DNS) to discover
 * Pi devices advertising the REW audio receiver service. It maintains a list of
 * discovered devices and notifies listeners when devices are found or lost.</p>
 * 
 * <p>The service type used for discovery is "_rew-audio._tcp.local." which should
 * be advertised by the Python receiver service running on the Pi.</p>
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class PiDiscoveryService {
    
    private static final Logger LOGGER = LoggerFactory.getLogger(PiDiscoveryService.class);
    
    /** The mDNS service type to discover. */
    private static final String SERVICE_TYPE = "_rew-audio._tcp.local.";
    
    /** Timeout for mDNS operations in milliseconds. */
    private static final int MDNS_TIMEOUT = 5000;
    
    private JmDNS jmdns;
    private boolean isRunning = false;
    
    // Thread-safe collections for discovered devices and listeners
    private final ConcurrentHashMap<String, PiDevice> discoveredDevices = new ConcurrentHashMap<>();
    private final CopyOnWriteArrayList<Consumer<PiDevice>> deviceAddedListeners = new CopyOnWriteArrayList<>();
    private final CopyOnWriteArrayList<Consumer<PiDevice>> deviceRemovedListeners = new CopyOnWriteArrayList<>();
    
    /**
     * Starts the Pi discovery service.
     * Initializes JmDNS and begins listening for Pi devices on the network.
     * 
     * @throws IOException if the mDNS service cannot be started
     */
    public void startDiscovery() throws IOException {
        if (isRunning) {
            LOGGER.warn("Discovery service is already running");
            return;
        }
        
        LOGGER.info("Starting Pi discovery service");
        
        try {
            // Initialize JmDNS
            jmdns = JmDNS.create(InetAddress.getLocalHost());
            
            // Add service listener
            jmdns.addServiceListener(SERVICE_TYPE, new REWServiceListener());
            
            isRunning = true;
            LOGGER.info("Pi discovery service started successfully");
            
        } catch (IOException e) {
            LOGGER.error("Failed to start Pi discovery service", e);
            throw e;
        }
    }
    
    /**
     * Stops the Pi discovery service.
     * Closes the JmDNS service and cleans up resources.
     */
    public void stopDiscovery() {
        if (!isRunning) {
            LOGGER.warn("Discovery service is not running");
            return;
        }
        
        LOGGER.info("Stopping Pi discovery service");
        
        try {
            if (jmdns != null) {
                jmdns.removeServiceListener(SERVICE_TYPE, new REWServiceListener());
                jmdns.close();
                jmdns = null;
            }
            
            discoveredDevices.clear();
            isRunning = false;
            
            LOGGER.info("Pi discovery service stopped");
            
        } catch (IOException e) {
            LOGGER.error("Error stopping Pi discovery service", e);
        }
    }
    
    /**
     * Checks if the discovery service is currently running.
     * 
     * @return true if the service is running, false otherwise
     */
    public boolean isRunning() {
        return isRunning;
    }
    
    /**
     * Gets all currently discovered Pi devices.
     * 
     * @return An array of discovered PiDevice objects
     */
    public PiDevice[] getDiscoveredDevices() {
        return discoveredDevices.values().toArray(new PiDevice[0]);
    }
    
    /**
     * Adds a listener for device added events.
     * 
     * @param listener Consumer that will be called when a device is discovered
     */
    public void addDeviceAddedListener(Consumer<PiDevice> listener) {
        deviceAddedListeners.add(listener);
        LOGGER.debug("Added device added listener");
    }
    
    /**
     * Removes a device added listener.
     * 
     * @param listener The listener to remove
     */
    public void removeDeviceAddedListener(Consumer<PiDevice> listener) {
        deviceAddedListeners.remove(listener);
        LOGGER.debug("Removed device added listener");
    }
    
    /**
     * Adds a listener for device removed events.
     * 
     * @param listener Consumer that will be called when a device is lost
     */
    public void addDeviceRemovedListener(Consumer<PiDevice> listener) {
        deviceRemovedListeners.add(listener);
        LOGGER.debug("Added device removed listener");
    }
    
    /**
     * Removes a device removed listener.
     * 
     * @param listener The listener to remove
     */
    public void removeDeviceRemovedListener(Consumer<PiDevice> listener) {
        deviceRemovedListeners.remove(listener);
        LOGGER.debug("Removed device removed listener");
    }
    
    /**
     * Forces a refresh of the device discovery.
     * Requests updated information for all known services.
     */
    public void refreshDiscovery() {
        if (!isRunning) {
            LOGGER.warn("Cannot refresh - discovery service is not running");
            return;
        }
        
        LOGGER.info("Refreshing Pi device discovery");
        
        try {
            // Request service info for all known services
            jmdns.requestServiceInfo(SERVICE_TYPE, null, MDNS_TIMEOUT);
            
        } catch (Exception e) {
            LOGGER.error("Error refreshing discovery", e);
        }
    }
    
    /**
     * Notifies all device added listeners about a new device.
     * 
     * @param device The newly discovered device
     */
    private void notifyDeviceAdded(PiDevice device) {
        for (Consumer<PiDevice> listener : deviceAddedListeners) {
            try {
                listener.accept(device);
            } catch (Exception e) {
                LOGGER.error("Error notifying device added listener", e);
            }
        }
    }
    
    /**
     * Notifies all device removed listeners about a lost device.
     * 
     * @param device The device that was lost
     */
    private void notifyDeviceRemoved(PiDevice device) {
        for (Consumer<PiDevice> listener : deviceRemovedListeners) {
            try {
                listener.accept(device);
            } catch (Exception e) {
                LOGGER.error("Error notifying device removed listener", e);
            }
        }
    }
    
    /**
     * JmDNS service listener implementation for REW audio services.
     */
    private class REWServiceListener implements ServiceListener {
        
        @Override
        public void serviceAdded(ServiceEvent event) {
            LOGGER.debug("Service added: {}", event.getName());
            // Request detailed service info
            jmdns.requestServiceInfo(event.getType(), event.getName(), MDNS_TIMEOUT);
        }
        
        @Override
        public void serviceRemoved(ServiceEvent event) {
            String serviceName = event.getName();
            LOGGER.info("Service removed: {}", serviceName);
            
            PiDevice removedDevice = discoveredDevices.remove(serviceName);
            if (removedDevice != null) {
                notifyDeviceRemoved(removedDevice);
            }
        }
        
        @Override
        public void serviceResolved(ServiceEvent event) {
            String serviceName = event.getName();
            String hostAddress = null;
            
            // Get IP address from service info
            InetAddress[] addresses = event.getInfo().getInetAddresses();
            if (addresses.length > 0) {
                hostAddress = addresses[0].getHostAddress();
            }
            
            if (hostAddress != null) {
                LOGGER.info("Service resolved: {} at {}", serviceName, hostAddress);
                
                PiDevice device = new PiDevice(serviceName, hostAddress, "Available");
                discoveredDevices.put(serviceName, device);
                notifyDeviceAdded(device);
                
            } else {
                LOGGER.warn("Service resolved but no IP address found: {}", serviceName);
            }
        }
    }
}