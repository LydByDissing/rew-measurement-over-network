package com.lydbydissing.gui;

import com.lydbydissing.audio.JavaAudioLoopback;
import com.lydbydissing.audio.PulseAudioLoopback;
import com.lydbydissing.network.PiDiscoveryService;
import com.lydbydissing.network.RTPAudioStreamer;
import javafx.application.Platform;

import javax.sound.sampled.AudioFormat;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.fxml.FXML;
import javafx.fxml.Initializable;
import javafx.geometry.Insets;
import javafx.scene.control.*;
import javafx.scene.control.cell.PropertyValueFactory;
import javafx.scene.layout.GridPane;
import javafx.scene.layout.Priority;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.net.URL;
import java.util.ResourceBundle;

/**
 * Main controller for the REW Network Audio Bridge GUI.
 * 
 * <p>Handles user interactions for Pi device discovery, connection management,
 * and audio streaming status display. This controller manages the primary
 * user interface components including device list, connection controls,
 * and status indicators.</p>
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class MainController implements Initializable {
    
    private static final Logger logger = LoggerFactory.getLogger(MainController.class);
    
    // FXML Components - Device Discovery
    @FXML
    private TableView<PiDevice> deviceTable;
    @FXML
    private TableColumn<PiDevice, String> nameColumn;
    @FXML
    private TableColumn<PiDevice, String> ipAddressColumn;
    @FXML
    private TableColumn<PiDevice, String> statusColumn;
    
    // FXML Components - Connection Controls
    @FXML
    private Button connectButton;
    @FXML
    private Button disconnectButton;
    @FXML
    private Button refreshButton;
    @FXML
    private Button addDeviceButton;
    
    // FXML Components - Status Display
    @FXML
    private Label connectionStatusLabel;
    @FXML
    private Label audioStatusLabel;
    @FXML
    private ProgressBar audioLevelIndicator;
    @FXML
    private TextArea logTextArea;
    
    // Data
    private final ObservableList<PiDevice> discoveredDevices = FXCollections.observableArrayList();
    private final PiDiscoveryService discoveryService = new PiDiscoveryService();
    
    // Audio components
    private JavaAudioLoopback audioLoopback;
    private PulseAudioLoopback pulseLoopback;
    private RTPAudioStreamer activeStreamer;
    
    // Auto-connect configuration
    private String autoConnectIp;
    private int autoConnectPort;
    
    /**
     * Initializes the controller after FXML loading.
     * Sets up table columns, button states, and starts device discovery.
     * 
     * @param location  The location used to resolve relative paths for the root object
     * @param resources The resources used to localize the root object
     */
    @Override
    public void initialize(URL location, ResourceBundle resources) {
        logger.info("Initializing main controller");
        
        setupDeviceTable();
        setupButtonStates();
        setupStatusDisplay();
        
        // Start device discovery
        startDeviceDiscovery();
        
        // Initialize audio loopback system
        initializeAudioSystem();
        
        // Perform auto-connect if configured
        if (autoConnectIp != null) {
            performAutoConnect();
        }
        
        logger.info("Main controller initialized successfully");
    }
    
    /**
     * Sets up the device table columns and data binding.
     */
    private void setupDeviceTable() {
        nameColumn.setCellValueFactory(new PropertyValueFactory<>("name"));
        ipAddressColumn.setCellValueFactory(new PropertyValueFactory<>("ipAddress"));
        statusColumn.setCellValueFactory(new PropertyValueFactory<>("status"));
        
        deviceTable.setItems(discoveredDevices);
        
        // Enable row selection
        deviceTable.getSelectionModel().selectedItemProperty().addListener(
            (observable, oldValue, newValue) -> updateButtonStates(newValue)
        );
        
        logger.debug("Device table configured");
    }
    
    /**
     * Sets up initial button states.
     */
    private void setupButtonStates() {
        connectButton.setDisable(true);
        disconnectButton.setDisable(true);
        refreshButton.setDisable(false);
        
        logger.debug("Button states initialized");
    }
    
    /**
     * Sets up initial status display.
     */
    private void setupStatusDisplay() {
        connectionStatusLabel.setText("Not connected");
        audioStatusLabel.setText("No audio");
        audioLevelIndicator.setProgress(0.0);
        
        logger.debug("Status display initialized");
    }
    
    /**
     * Updates button states based on device selection and connection status.
     * 
     * @param selectedDevice The currently selected Pi device, or null if none selected
     */
    private void updateButtonStates(PiDevice selectedDevice) {
        boolean deviceSelected = selectedDevice != null;
        boolean deviceAvailable = deviceSelected && "Available".equals(selectedDevice.getStatus());
        
        connectButton.setDisable(!deviceAvailable);
        // TODO: Update disconnect button based on actual connection state
        
        logger.debug("Button states updated for device: {}", 
                    selectedDevice != null ? selectedDevice.getName() : "none");
    }
    
    /**
     * Starts the Pi device discovery process using mDNS.
     */
    private void startDeviceDiscovery() {
        logger.info("Starting device discovery");
        
        try {
            // Set up listeners for device discovery
            discoveryService.addDeviceAddedListener(device -> {
                Platform.runLater(() -> {
                    discoveredDevices.add(device);
                    logMessage("Device discovered: " + device.getName() + " (" + device.getIpAddress() + ")");
                });
            });
            
            discoveryService.addDeviceRemovedListener(device -> {
                Platform.runLater(() -> {
                    discoveredDevices.remove(device);
                    logMessage("Device lost: " + device.getName());
                });
            });
            
            // Start the actual mDNS discovery
            discoveryService.startDiscovery();
            logMessage("Device discovery started - scanning for Pi devices...");
            
        } catch (IOException e) {
            logger.error("Failed to start device discovery", e);
            logMessage("ERROR: Failed to start device discovery - " + e.getMessage());
        }
    }
    
    /**
     * Initializes the audio system with PulseAudio loopback and fallback.
     */
    private void initializeAudioSystem() {
        logger.info("Initializing audio system");
        
        try {
            // Try PulseAudio loopback first
            pulseLoopback = new PulseAudioLoopback();
            
            // Set up audio data consumer to forward to RTP streamer
            pulseLoopback.setAudioDataConsumer(audioData -> {
                if (activeStreamer != null && activeStreamer.isStreaming()) {
                    try {
                        activeStreamer.streamAudioData(audioData);
                    } catch (IOException e) {
                        logger.error("Error streaming audio data", e);
                        Platform.runLater(() -> logMessage("ERROR: Audio streaming failed - " + e.getMessage()));
                    }
                }
            });
            
            // Start the PulseAudio loopback
            pulseLoopback.start();
            
            Platform.runLater(() -> {
                audioStatusLabel.setText("Virtual device: " + pulseLoopback.getDeviceDescription());
                logMessage("✅ PulseAudio loopback created: " + pulseLoopback.getDeviceDescription());
                logMessage("");
                logMessage("🎯 REW SETUP INSTRUCTIONS:");
                logMessage("1. In REW, go to Preferences > Soundcard");
                logMessage("2. Set Output Device to: '" + pulseLoopback.getDeviceName() + "'");
                logMessage("3. Audio from REW will be automatically:");
                logMessage("   • Played through your speakers");
                logMessage("   • Streamed to connected Pi devices");
                logMessage("");
                logMessage("✅ Setup complete - ready for measurements!");
            });
            
        } catch (Exception e) {
            logger.warn("PulseAudio loopback failed, using fallback: {}", e.getMessage());
            Platform.runLater(() -> {
                logMessage("⚠️  PulseAudio loopback failed: " + e.getMessage());
                logMessage("🔄 Switching to fallback mode...");
                initializeFallbackAudioLoopback();
            });
        }
    }
    
    /**
     * Fallback to Java audio loopback if PulseAudio is not available.
     */
    private void initializeFallbackAudioLoopback() {
        logger.info("Initializing fallback Java audio loopback");
        
        try {
            audioLoopback = new JavaAudioLoopback();
            
            // Set up audio data consumer to forward to RTP streamer
            audioLoopback.setAudioDataConsumer(audioData -> {
                if (activeStreamer != null && activeStreamer.isStreaming()) {
                    try {
                        activeStreamer.streamAudioData(audioData);
                    } catch (IOException e) {
                        logger.error("Error streaming audio data", e);
                        Platform.runLater(() -> logMessage("ERROR: Audio streaming failed - " + e.getMessage()));
                    }
                }
            });
            
            // Set up audio level monitoring
            audioLoopback.setAudioLevelConsumer(level -> {
                Platform.runLater(() -> audioLevelIndicator.setProgress(level));
            });
            
            // Start the audio loopback
            audioLoopback.start();
            
            Platform.runLater(() -> {
                audioStatusLabel.setText("Fallback mode: " + audioLoopback.getInterfaceDescription());
                logMessage("Java audio loopback created: " + audioLoopback.getInterfaceDescription());
                logMessage("FALLBACK MODE: REW must use default system audio output");
                logMessage("Audio will be captured from system microphone");
            });
            
        } catch (Exception e2) {
            logger.error("Failed to initialize fallback audio loopback", e2);
            Platform.runLater(() -> {
                audioStatusLabel.setText("Audio initialization failed");
                logMessage("ERROR: All audio initialization methods failed");
                logMessage("Please check your audio system configuration");
            });
        }
    }
    
    /**
     * Handles the connect button click event.
     * Initiates connection to the selected Pi device.
     */
    @FXML
    private void handleConnect() {
        PiDevice selectedDevice = deviceTable.getSelectionModel().getSelectedItem();
        if (selectedDevice == null) {
            logMessage("ERROR: No device selected for connection");
            return;
        }
        
        logger.info("Connecting to device: {}", selectedDevice.getName());
        logMessage("Connecting to " + selectedDevice.getName() + " (" + selectedDevice.getIpAddress() + ")");
        
        try {
            // Create RTP streamer for the selected device
            AudioFormat streamFormat = JavaAudioLoopback.DEFAULT_FORMAT;
                
            activeStreamer = new RTPAudioStreamer(
                java.net.InetAddress.getByName(selectedDevice.getIpAddress()),
                RTPAudioStreamer.DEFAULT_RTP_PORT,
                streamFormat
            );
            
            // Start streaming
            activeStreamer.startStreaming();
            
            Platform.runLater(() -> {
                connectionStatusLabel.setText("Connected to " + selectedDevice.getName());
                connectButton.setDisable(true);
                disconnectButton.setDisable(false);
                logMessage("RTP audio streaming started to " + selectedDevice.getIpAddress() + ":" + RTPAudioStreamer.DEFAULT_RTP_PORT);
            });
            
        } catch (Exception e) {
            logger.error("Failed to connect to device", e);
            Platform.runLater(() -> {
                logMessage("ERROR: Failed to connect to " + selectedDevice.getName() + " - " + e.getMessage());
            });
        }
    }
    
    /**
     * Handles the disconnect button click event.
     * Disconnects from the currently connected Pi device.
     */
    @FXML
    private void handleDisconnect() {
        logger.info("Disconnecting from current device");
        logMessage("Disconnecting from device");
        
        // Stop active audio streamer
        if (activeStreamer != null) {
            activeStreamer.close();
            activeStreamer = null;
        }
        
        Platform.runLater(() -> {
            connectionStatusLabel.setText("Not connected");
            
            if (pulseLoopback != null && pulseLoopback.isActive()) {
                audioStatusLabel.setText("Virtual device: " + pulseLoopback.getDeviceDescription());
            } else if (audioLoopback != null && audioLoopback.isActive()) {
                audioStatusLabel.setText("Fallback mode: " + audioLoopback.getInterfaceDescription());
            } else {
                audioStatusLabel.setText("No audio");
            }
            audioLevelIndicator.setProgress(0.0);
            connectButton.setDisable(false);
            disconnectButton.setDisable(true);
            logMessage("Disconnected - RTP streaming stopped");
        });
    }
    
    /**
     * Handles the refresh button click event.
     * Refreshes the Pi device discovery.
     */
    @FXML
    private void handleRefresh() {
        logger.info("Refreshing device discovery");
        logMessage("Refreshing device discovery...");
        
        // Clear existing devices and refresh discovery
        discoveredDevices.clear();
        
        if (discoveryService.isRunning()) {
            discoveryService.refreshDiscovery();
        } else {
            startDeviceDiscovery();
        }
    }
    
    /**
     * Handles the add device button click event.
     * Opens a dialog to manually add a Pi device by IP address.
     */
    @FXML
    private void handleAddDevice() {
        logger.info("Opening add device dialog");
        
        // Create custom dialog
        Dialog<PiDevice> dialog = new Dialog<>();
        dialog.setTitle("Add Pi Device");
        dialog.setHeaderText("Manually add a Raspberry Pi audio receiver");
        
        // Set button types
        ButtonType addButtonType = new ButtonType("Add Device", ButtonBar.ButtonData.OK_DONE);
        dialog.getDialogPane().getButtonTypes().addAll(addButtonType, ButtonType.CANCEL);
        
        // Create form fields
        GridPane grid = new GridPane();
        grid.setHgap(10);
        grid.setVgap(10);
        grid.setPadding(new Insets(20, 150, 10, 10));
        
        TextField nameField = new TextField();
        nameField.setPromptText("Device name (e.g., REW-Pi-Manual)");
        nameField.setPrefWidth(200);
        
        TextField ipField = new TextField();
        ipField.setPromptText("IP address (e.g., 192.168.1.100)");
        ipField.setPrefWidth(200);
        
        TextField portField = new TextField("5004");
        portField.setPromptText("RTP port (default: 5004)");
        portField.setPrefWidth(200);
        
        grid.add(new Label("Device Name:"), 0, 0);
        grid.add(nameField, 1, 0);
        grid.add(new Label("IP Address:"), 0, 1);
        grid.add(ipField, 1, 1);
        grid.add(new Label("RTP Port:"), 0, 2);
        grid.add(portField, 1, 2);
        
        // Enable/disable add button based on input
        Button addButton = (Button) dialog.getDialogPane().lookupButton(addButtonType);
        addButton.setDisable(true);
        
        // Validation listener
        Runnable validateInput = () -> {
            boolean nameValid = !nameField.getText().trim().isEmpty();
            boolean ipValid = isValidIPAddress(ipField.getText().trim());
            boolean portValid = isValidPort(portField.getText().trim());
            addButton.setDisable(!(nameValid && ipValid && portValid));
        };
        
        nameField.textProperty().addListener((observable, oldValue, newValue) -> validateInput.run());
        ipField.textProperty().addListener((observable, oldValue, newValue) -> validateInput.run());
        portField.textProperty().addListener((observable, oldValue, newValue) -> validateInput.run());
        
        dialog.getDialogPane().setContent(grid);
        
        // Request focus on name field
        Platform.runLater(nameField::requestFocus);
        
        // Convert result when add button is clicked
        dialog.setResultConverter(dialogButton -> {
            if (dialogButton == addButtonType) {
                return new PiDevice(
                    nameField.getText().trim(),
                    ipField.getText().trim(),
                    "Manual"
                );
            }
            return null;
        });
        
        // Show dialog and handle result
        dialog.showAndWait().ifPresent(device -> {
            // Add device to list
            discoveredDevices.add(device);
            logMessage("Manually added device: " + device.getName() + " (" + device.getIpAddress() + ")");
            logger.info("Added manual device: {} at {}", device.getName(), device.getIpAddress());
            
            // Select the newly added device
            deviceTable.getSelectionModel().select(device);
        });
    }
    
    /**
     * Adds a log message to the log text area with timestamp.
     * 
     * @param message The message to log
     */
    private void logMessage(String message) {
        Platform.runLater(() -> {
            String timestamp = java.time.LocalTime.now().toString().substring(0, 8);
            String logEntry = "[" + timestamp + "] " + message + "\n";
            logTextArea.appendText(logEntry);
        });
    }
    
    /**
     * Updates the audio level indicator.
     * Called by the audio streaming service to show current audio levels.
     * 
     * @param level Audio level between 0.0 and 1.0
     */
    public void updateAudioLevel(double level) {
        Platform.runLater(() -> {
            audioLevelIndicator.setProgress(level);
            if (level > 0.01) {
                audioStatusLabel.setText("Audio streaming");
            } else {
                audioStatusLabel.setText("Connected - no audio");
            }
        });
    }
    
    /**
     * Updates the connection status display.
     * Called by the connection service to update status.
     * 
     * @param status The current connection status message
     * @param isConnected Whether currently connected to a device
     */
    public void updateConnectionStatus(String status, boolean isConnected) {
        Platform.runLater(() -> {
            connectionStatusLabel.setText(status);
            connectButton.setDisable(isConnected);
            disconnectButton.setDisable(!isConnected);
            logMessage("Connection status: " + status);
        });
    }
    
    /**
     * Validates if a string is a valid IPv4 address.
     * 
     * @param ip The IP address string to validate
     * @return true if valid IPv4 address, false otherwise
     */
    private boolean isValidIPAddress(String ip) {
        if (ip == null || ip.isEmpty()) {
            return false;
        }
        
        String[] parts = ip.split("\\.");
        if (parts.length != 4) {
            return false;
        }
        
        try {
            for (String part : parts) {
                int num = Integer.parseInt(part);
                if (num < 0 || num > 255) {
                    return false;
                }
            }
            return true;
        } catch (NumberFormatException e) {
            return false;
        }
    }
    
    /**
     * Validates if a string is a valid port number.
     * 
     * @param port The port string to validate
     * @return true if valid port (1-65535), false otherwise
     */
    private boolean isValidPort(String port) {
        if (port == null || port.isEmpty()) {
            return false;
        }
        
        try {
            int portNum = Integer.parseInt(port);
            return portNum >= 1 && portNum <= 65535;
        } catch (NumberFormatException e) {
            return false;
        }
    }
    
    /**
     * Cleanup method to be called when the application shuts down.
     * Stops the discovery service and releases resources.
     */
    public void cleanup() {
        logger.info("Cleaning up main controller resources");
        
        // Stop PulseAudio loopback
        if (pulseLoopback != null && pulseLoopback.isActive()) {
            pulseLoopback.stop();
        }
        
        // Stop Java audio loopback (fallback)
        if (audioLoopback != null && audioLoopback.isActive()) {
            audioLoopback.stop();
        }
        
        // Stop active audio streamer
        if (activeStreamer != null) {
            activeStreamer.close();
        }
        
        // Stop discovery service
        if (discoveryService.isRunning()) {
            discoveryService.stopDiscovery();
        }
        
        logger.info("Main controller cleanup complete");
    }
    
    /**
     * Sets the auto-connect target for CLI-specified Pi device.
     * 
     * @param ip The IP address to auto-connect to
     * @param port The port to use for the connection
     */
    public void setAutoConnectTarget(String ip, int port) {
        this.autoConnectIp = ip;
        this.autoConnectPort = port;
        logger.info("Auto-connect target set: {}:{}", ip, port);
    }
    
    /**
     * Performs automatic connection to the CLI-specified device.
     */
    private void performAutoConnect() {
        logger.info("Performing auto-connect to {}:{}", autoConnectIp, autoConnectPort);
        
        Platform.runLater(() -> {
            logMessage("Auto-connecting to " + autoConnectIp + ":" + autoConnectPort + " (from CLI arguments)");
            
            // Add the device manually to the table
            PiDevice autoDevice = new PiDevice("CLI-Target", autoConnectIp, "Available");
            discoveredDevices.add(autoDevice);
            
            // Select and connect to the device
            deviceTable.getSelectionModel().select(autoDevice);
            
            // Wait a moment for GUI to update, then connect
            javafx.concurrent.Task<Void> connectTask = new javafx.concurrent.Task<Void>() {
                @Override
                protected Void call() throws Exception {
                    Thread.sleep(500); // Brief delay for GUI update
                    return null;
                }
                
                @Override
                protected void succeeded() {
                    connectToDevice(autoDevice, autoConnectPort);
                }
            };
            
            new Thread(connectTask).start();
        });
    }
    
    /**
     * Connects to a specific Pi device with a custom port.
     * 
     * @param device The Pi device to connect to
     * @param port The port to use for RTP streaming
     */
    private void connectToDevice(PiDevice device, int port) {
        logger.info("Connecting to device: {} at {}:{}", device.getName(), device.getIpAddress(), port);
        logMessage("Connecting to " + device.getName() + " (" + device.getIpAddress() + ":" + port + ")");
        
        try {
            // Create RTP streamer for the device
            AudioFormat streamFormat = JavaAudioLoopback.DEFAULT_FORMAT;
                
            activeStreamer = new RTPAudioStreamer(
                java.net.InetAddress.getByName(device.getIpAddress()),
                port,
                streamFormat
            );
            
            // Start streaming
            activeStreamer.startStreaming();
            
            Platform.runLater(() -> {
                connectionStatusLabel.setText("Connected to " + device.getName());
                connectButton.setDisable(true);
                disconnectButton.setDisable(false);
                logMessage("RTP audio streaming started to " + device.getIpAddress() + ":" + port);
                logMessage("Connection successful - ready for REW measurements");
            });
            
        } catch (Exception e) {
            logger.error("Failed to connect to device", e);
            Platform.runLater(() -> {
                logMessage("ERROR: Failed to connect to " + device.getName() + " - " + e.getMessage());
            });
        }
    }
}