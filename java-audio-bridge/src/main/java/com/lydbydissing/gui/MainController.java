package com.lydbydissing.gui;

import com.lydbydissing.network.PiDiscoveryService;
import com.lydbydissing.service.AudioBridgeService;
import javafx.application.Platform;

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
import java.util.Timer;
import java.util.TimerTask;

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
    
    // Audio bridge service
    private final AudioBridgeService audioBridgeService = new AudioBridgeService();
    
    // Connection monitoring
    private Timer connectionMonitorTimer;
    private int connectionQualityTicks = 0;
    
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
        
        // Initialize audio system
        initializeAudioSystem();
        
        // Set up audio level monitoring
        Timer audioLevelTimer = new Timer(true);
        audioLevelTimer.scheduleAtFixedRate(new TimerTask() {
            @Override
            public void run() {
                double level = audioBridgeService.getCurrentAudioLevel();
                Platform.runLater(() -> audioLevelIndicator.setProgress(level));
            }
        }, 0, 100); // Update every 100ms
        
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
     * Initializes the audio system using shared AudioBridgeService.
     */
    private void initializeAudioSystem() {
        logger.info("Initializing audio system");
        
        // Set up callbacks for status updates
        audioBridgeService.setOnAudioSystemInitialized(() -> {
            Platform.runLater(() -> {
                audioStatusLabel.setText(audioBridgeService.getAudioSystemDescription());
                logMessage("✅ Audio system initialized: " + audioBridgeService.getAudioSystemDescription());
                logMessage("");
                logMessage("🎯 REW SETUP INSTRUCTIONS:");
                logMessage("1. In REW, go to Preferences > Soundcard");
                logMessage("2. Set Output Device to: '" + audioBridgeService.getVirtualDeviceName() + "'");
                logMessage("3. Audio from REW will be automatically:");
                logMessage("   • Played through your speakers");
                logMessage("   • Streamed to connected Pi devices");
                logMessage("");
                logMessage("✅ Setup complete - ready for measurements!");
            });
        });
        
        // Initialize the audio system
        if (!audioBridgeService.initializeAudioSystem()) {
            Platform.runLater(() -> {
                audioStatusLabel.setText("Audio initialization failed");
                logMessage("ERROR: Audio system initialization failed");
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
        
        // Set up callbacks for connection events
        audioBridgeService.setOnConnectionEstablished(() -> {
            Platform.runLater(() -> {
                connectionStatusLabel.setText("Connected to " + selectedDevice.getName());
                connectButton.setDisable(true);
                disconnectButton.setDisable(false);
                logMessage("Connected to " + selectedDevice.getIpAddress() + ":" + selectedDevice.getPort());
                
                // Start connection quality monitoring
                startConnectionMonitoring();
            });
        });
        
        // Connect using shared service
        if (!audioBridgeService.connectToDevice(selectedDevice.getIpAddress(), selectedDevice.getPort())) {
            Platform.runLater(() -> {
                logMessage("ERROR: Failed to connect to " + selectedDevice.getName());
            });
            return;
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
        
        // Set up callback for disconnection
        audioBridgeService.setOnConnectionLost(() -> {
            Platform.runLater(() -> {
                connectionStatusLabel.setText("Not connected");
                audioStatusLabel.setText(audioBridgeService.getAudioSystemDescription());
                audioLevelIndicator.setProgress(0.0);
                connectButton.setDisable(false);
                disconnectButton.setDisable(true);
                logMessage("Disconnected - RTP streaming stopped");
            });
        });
        
        // Disconnect using shared service
        audioBridgeService.disconnect();
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
        
        // Shutdown audio bridge service
        audioBridgeService.shutdown();
        
        // Stop discovery service
        if (discoveryService.isRunning()) {
            discoveryService.stopDiscovery();
        }
        
        // Stop connection monitoring
        stopConnectionMonitoring();
        
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
     * Triggers auto-connect if a target is configured.
     * This method can be called after the GUI is fully initialized.
     */
    public void triggerAutoConnect() {
        if (autoConnectIp != null) {
            logger.info("Triggering auto-connect to {}:{}", autoConnectIp, autoConnectPort);
            performAutoConnect();
        } else {
            logger.debug("No auto-connect target configured");
        }
    }
    
    /**
     * Programmatically adds a manual device for testing purposes.
     * 
     * @param name The device name
     * @param ip The device IP address
     * @return true if device was added successfully
     */
    public boolean addManualDevice(String name, String ip) {
        try {
            logger.info("Adding manual device programmatically: {} at {}", name, ip);
            
            // Create a manual Pi device
            PiDevice device = PiDevice.createManualDevice(name, ip);
            
            // Add to the discovered devices list
            Platform.runLater(() -> {
                discoveredDevices.add(device);
                logger.info("Added manual device: {} at {}", device.getName(), device.getIpAddress());
                
                // Select the newly added device
                deviceTable.getSelectionModel().select(device);
            });
            
            return true;
            
        } catch (Exception e) {
            logger.error("Failed to add manual device: {} at {}", name, ip, e);
            return false;
        }
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
        
        // Set up callbacks for connection events
        audioBridgeService.setOnConnectionEstablished(() -> {
            Platform.runLater(() -> {
                connectionStatusLabel.setText("Connected to " + device.getName());
                connectButton.setDisable(true);
                disconnectButton.setDisable(false);
                logMessage("RTP audio streaming started to " + device.getIpAddress() + ":" + port);
                logMessage("Connection successful - ready for REW measurements");
                
                // Start connection quality monitoring
                startConnectionMonitoring();
            });
        });
        
        // Connect using shared service
        if (!audioBridgeService.connectToDevice(device.getIpAddress(), port)) {
            Platform.runLater(() -> {
                logMessage("ERROR: Failed to connect to " + device.getName());
            });
        }
    }
    
    /**
     * Starts connection quality monitoring with periodic health checks.
     * This method creates a timer that runs every 5 seconds to check connection health.
     */
    private void startConnectionMonitoring() {
        if (connectionMonitorTimer != null) {
            connectionMonitorTimer.cancel();
        }
        
        connectionMonitorTimer = new Timer("ConnectionMonitor", true);
        connectionQualityTicks = 0;
        
        System.out.println("🔍 Starting connection quality monitoring...");
        logger.info("Starting connection quality monitoring");
        
        TimerTask monitoringTask = new TimerTask() {
            @Override
            public void run() {
                connectionQualityTicks++;
                
                try {
                    // Check connection health using shared service
                    if (audioBridgeService.isConnected()) {
                        // Check audio flow status
                        checkAudioFlowStatus();
                        
                        // Every 12 ticks (1 minute), print basic status
                        if (connectionQualityTicks % 12 == 0) {
                            Platform.runLater(() -> {
                                String statusMessage = String.format(
                                    "📊 1-min Status: %d audio packets received, %d streamed",
                                    audioBridgeService.getAudioPacketsReceived(),
                                    audioBridgeService.getAudioPacketsStreamed()
                                );
                                System.out.println(statusMessage);
                                logMessage(statusMessage);
                            });
                        }
                    }
                } catch (Exception e) {
                    logger.error("Error in connection monitoring", e);
                }
            }
        };
        
        // Run every 5 seconds
        connectionMonitorTimer.scheduleAtFixedRate(monitoringTask, 5000, 5000);
    }
    
    /**
     * Checks the status of audio flow through the REW bridge.
     */
    private void checkAudioFlowStatus() {
        // Check if we have an initialized audio system and can monitor audio
        if (audioBridgeService.isInitialized()) {
            // Check if the device is receiving data by monitoring packet counts
            
            if (connectionQualityTicks % 6 == 0) { // Every 30 seconds
                System.out.println("🎵 REW Bridge Status: Audio system active, monitoring for audio...");
                logger.debug("REW audio bridge is active, device: {}", audioBridgeService.getVirtualDeviceName());
            }
        } else {
            if (connectionQualityTicks % 12 == 0) { // Every minute
                System.out.println("⚠️  REW Bridge: No active audio device found");
                logger.warn("No active audio loopback device");
            }
        }
    }
    
    /**
     * Stops connection quality monitoring.
     */
    private void stopConnectionMonitoring() {
        if (connectionMonitorTimer != null) {
            System.out.println("🔍 Stopping connection quality monitoring");
            connectionMonitorTimer.cancel();
            connectionMonitorTimer = null;
            logger.info("Connection quality monitoring stopped");
        }
    }
    
}