package com.lydbydissing.gui;

import javafx.beans.property.SimpleStringProperty;
import javafx.beans.property.StringProperty;

/**
 * Represents a discovered Raspberry Pi device available for audio streaming.
 * 
 * <p>This class encapsulates the properties of a Pi device discovered via mDNS,
 * including its name, IP address, and current status. The properties are implemented
 * as JavaFX properties to support data binding in the user interface.</p>
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class PiDevice {
    
    private final StringProperty name;
    private final StringProperty ipAddress;
    private final StringProperty status;
    private final int port;
    
    /**
     * Creates a new Pi device with the specified properties.
     * 
     * @param name      The display name of the Pi device (e.g., "REW-Pi-01")
     * @param ipAddress The IP address of the Pi device (e.g., "192.168.1.100")
     * @param status    The current status of the device (e.g., "Available", "Busy", "Offline")
     */
    public PiDevice(String name, String ipAddress, String status) {
        this(name, ipAddress, status, 5004);
    }
    
    /**
     * Creates a new Pi device with the specified properties including port.
     * 
     * @param name      The display name of the Pi device (e.g., "REW-Pi-01")
     * @param ipAddress The IP address of the Pi device (e.g., "192.168.1.100")
     * @param status    The current status of the device (e.g., "Available", "Busy", "Offline")
     * @param port      The port number for RTP communication (default: 5004)
     */
    public PiDevice(String name, String ipAddress, String status, int port) {
        this.name = new SimpleStringProperty(name);
        this.ipAddress = new SimpleStringProperty(ipAddress);
        this.status = new SimpleStringProperty(status);
        this.port = port;
    }
    
    /**
     * Gets the name property of the device.
     * 
     * @return The name property for data binding
     */
    public StringProperty nameProperty() {
        return name;
    }
    
    /**
     * Gets the name of the device.
     * 
     * @return The device name
     */
    public String getName() {
        return name.get();
    }
    
    /**
     * Sets the name of the device.
     * 
     * @param name The new device name
     */
    public void setName(String name) {
        this.name.set(name);
    }
    
    /**
     * Gets the IP address property of the device.
     * 
     * @return The IP address property for data binding
     */
    public StringProperty ipAddressProperty() {
        return ipAddress;
    }
    
    /**
     * Gets the IP address of the device.
     * 
     * @return The device IP address
     */
    public String getIpAddress() {
        return ipAddress.get();
    }
    
    /**
     * Sets the IP address of the device.
     * 
     * @param ipAddress The new IP address
     */
    public void setIpAddress(String ipAddress) {
        this.ipAddress.set(ipAddress);
    }
    
    /**
     * Gets the status property of the device.
     * 
     * @return The status property for data binding
     */
    public StringProperty statusProperty() {
        return status;
    }
    
    /**
     * Gets the current status of the device.
     * 
     * @return The device status
     */
    public String getStatus() {
        return status.get();
    }
    
    /**
     * Sets the current status of the device.
     * 
     * @param status The new device status
     */
    public void setStatus(String status) {
        this.status.set(status);
    }
    
    /**
     * Gets the port number for RTP communication.
     * 
     * @return The port number
     */
    public int getPort() {
        return port;
    }
    
    /**
     * Creates a manual Pi device with default settings.
     * This is a convenience factory method for manually added devices.
     * 
     * @param name      The display name of the Pi device
     * @param ipAddress The IP address of the Pi device
     * @return A new PiDevice configured for manual use
     */
    public static PiDevice createManualDevice(String name, String ipAddress) {
        return new PiDevice(name, ipAddress, "Manual", 5004);
    }
    
    /**
     * Returns a string representation of the device.
     * 
     * @return A string containing the device name and IP address
     */
    @Override
    public String toString() {
        return String.format("PiDevice{name='%s', ipAddress='%s', status='%s'}", 
                           getName(), getIpAddress(), getStatus());
    }
    
    /**
     * Checks if this device equals another object.
     * Two devices are considered equal if they have the same IP address.
     * 
     * @param obj The object to compare with
     * @return true if the objects are equal, false otherwise
     */
    @Override
    public boolean equals(Object obj) {
        if (this == obj) return true;
        if (obj == null || getClass() != obj.getClass()) return false;
        
        PiDevice piDevice = (PiDevice) obj;
        return ipAddress.get().equals(piDevice.ipAddress.get());
    }
    
    /**
     * Returns the hash code for this device.
     * Based on the IP address for consistency with equals().
     * 
     * @return The hash code
     */
    @Override
    public int hashCode() {
        return ipAddress.get().hashCode();
    }
}