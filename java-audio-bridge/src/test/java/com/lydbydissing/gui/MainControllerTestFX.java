package com.lydbydissing.gui;

import com.lydbydissing.gui.PiDevice;
import javafx.application.Platform;
import javafx.fxml.FXMLLoader;
import javafx.scene.Parent;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.control.Label;
import javafx.scene.control.TableView;
import javafx.stage.Stage;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.testfx.api.FxRobot;
import org.testfx.framework.junit5.ApplicationExtension;
import org.testfx.framework.junit5.Start;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;
import static org.testfx.assertions.api.Assertions.assertThat;

/**
 * TestFX integration tests for MainController GUI functionality.
 * Tests the actual user interface interactions including device management,
 * connection handling, and audio system integration.
 */
@ExtendWith(ApplicationExtension.class)
class MainControllerTestFX {

    private MainController controller;
    private TableView<PiDevice> deviceTable;
    private Button connectButton;
    private Button disconnectButton;
    private Button addDeviceButton;
    private Label audioStatusLabel;
    private Label connectionStatusLabel;

    @Start
    private void start(Stage stage) throws Exception {
        // Load the FXML file
        FXMLLoader loader = new FXMLLoader(getClass().getResource("/main.fxml"));
        Parent root = loader.load();
        controller = loader.getController();

        // Create scene and show stage
        Scene scene = new Scene(root, 800, 600);
        stage.setScene(scene);
        stage.show();

        // Wait for initialization to complete
        CountDownLatch latch = new CountDownLatch(1);
        Platform.runLater(() -> {
            try {
                // Give time for all initialization to complete
                Thread.sleep(2000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            latch.countDown();
        });
        assertTrue(latch.await(5, TimeUnit.SECONDS), "Controller initialization timed out");
    }

    @BeforeEach
    void setUp(FxRobot robot) {
        // Get references to UI components for testing
        deviceTable = robot.lookup("#deviceTable").query();
        connectButton = robot.lookup("#connectButton").query();
        disconnectButton = robot.lookup("#disconnectButton").query();
        addDeviceButton = robot.lookup("#addDeviceButton").query();
        audioStatusLabel = robot.lookup("#audioStatusLabel").query();
        connectionStatusLabel = robot.lookup("#connectionStatusLabel").query();

        assertNotNull(controller, "Controller should be initialized");
        assertNotNull(deviceTable, "Device table should be present");
        assertNotNull(connectButton, "Connect button should be present");
        assertNotNull(addDeviceButton, "Add device button should be present");
    }

    @Test
    void testInitialGUIState() {
        // Test initial state of the GUI
        assertThat(connectButton).isDisabled();
        assertThat(disconnectButton).isDisabled();
        assertThat(addDeviceButton).isEnabled();

        // Check initial labels
        assertThat(audioStatusLabel).hasText("Virtual device: REW Network Audio Bridge");
        assertThat(connectionStatusLabel).hasText("Not connected");

        // Device table should be empty initially
        assertEquals(0, deviceTable.getItems().size(), "Device table should be empty initially");
    }

    @Test
    void testManualDeviceAddition() throws InterruptedException {
        // Test programmatic device addition (simulates user adding device manually)
        CountDownLatch deviceAddedLatch = new CountDownLatch(1);
        
        Platform.runLater(() -> {
            boolean success = controller.addManualDevice("Test-Pi-Device", "192.168.1.100");
            assertTrue(success, "Device addition should succeed");
            deviceAddedLatch.countDown();
        });

        // Wait for device to be added
        assertTrue(deviceAddedLatch.await(3, TimeUnit.SECONDS), "Device addition timed out");

        // Verify device appears in table
        assertEquals(1, deviceTable.getItems().size(), "Device table should contain one device");
        
        PiDevice addedDevice = deviceTable.getItems().get(0);
        assertEquals("Test-Pi-Device", addedDevice.getName());
        assertEquals("192.168.1.100", addedDevice.getIpAddress());
        assertEquals(5004, addedDevice.getPort());

        // Connect button should now be enabled since a device is selected
        assertThat(connectButton).isEnabled();
    }

    @Test
    void testAutoConnectTarget() throws InterruptedException {
        // Test setting auto-connect target
        CountDownLatch autoConnectLatch = new CountDownLatch(1);
        
        Platform.runLater(() -> {
            controller.setAutoConnectTarget("192.168.1.200", 5004);
            autoConnectLatch.countDown();
        });

        assertTrue(autoConnectLatch.await(2, TimeUnit.SECONDS), "Auto-connect setup timed out");

        // Verify that auto-connect target is set (this would normally trigger connection)
        // In a real test, we'd mock the RTP streamer to avoid actual network calls
        // For now, we just verify the method doesn't throw exceptions
    }

    @Test
    void testDeviceTableSelection() throws InterruptedException {
        // Add a device first
        CountDownLatch setupLatch = new CountDownLatch(1);
        Platform.runLater(() -> {
            controller.addManualDevice("Selection-Test-Pi", "192.168.1.150");
            setupLatch.countDown();
        });
        assertTrue(setupLatch.await(3, TimeUnit.SECONDS));

        // Test device selection
        CountDownLatch selectionLatch = new CountDownLatch(1);
        Platform.runLater(() -> {
            deviceTable.getSelectionModel().select(0);
            selectionLatch.countDown();
        });
        assertTrue(selectionLatch.await(2, TimeUnit.SECONDS));

        // Verify selection affects button states
        PiDevice selectedDevice = deviceTable.getSelectionModel().getSelectedItem();
        assertNotNull(selectedDevice, "A device should be selected");
        assertEquals("Selection-Test-Pi", selectedDevice.getName());
        
        // Connect button should be enabled when device is selected
        assertThat(connectButton).isEnabled();
    }

    @Test
    void testMultipleDeviceAddition() throws InterruptedException {
        // Test adding multiple devices
        CountDownLatch multiDeviceLatch = new CountDownLatch(3);
        
        Platform.runLater(() -> {
            controller.addManualDevice("Pi-Device-1", "192.168.1.101");
            multiDeviceLatch.countDown();
        });
        
        Platform.runLater(() -> {
            controller.addManualDevice("Pi-Device-2", "192.168.1.102");
            multiDeviceLatch.countDown();
        });
        
        Platform.runLater(() -> {
            controller.addManualDevice("Pi-Device-3", "192.168.1.103");
            multiDeviceLatch.countDown();
        });

        assertTrue(multiDeviceLatch.await(5, TimeUnit.SECONDS), "Multiple device addition timed out");

        // Verify all devices are present
        assertEquals(3, deviceTable.getItems().size(), "Should have 3 devices in table");
        
        // Check device names
        assertEquals("Pi-Device-1", deviceTable.getItems().get(0).getName());
        assertEquals("Pi-Device-2", deviceTable.getItems().get(1).getName());
        assertEquals("Pi-Device-3", deviceTable.getItems().get(2).getName());
    }

    @Test
    void testAudioSystemInitialization() {
        // Test that audio system initializes correctly
        // The audio status should show virtual device is created
        assertThat(audioStatusLabel).hasText("Virtual device: REW Network Audio Bridge");
        
        // This test verifies the GUI reflects the audio system state correctly
        // In a real deployment, this would show the actual PulseAudio device
    }

    @Test
    void testButtonInteractions() {
        // Test basic button interactions
        assertThat(addDeviceButton).isEnabled();
        assertThat(connectButton).isDisabled(); // No device selected
        assertThat(disconnectButton).isDisabled(); // Not connected
        
        // Click add device button (this would open dialog in real GUI)
        // For testing, we just verify the button is clickable
        assertThat(addDeviceButton).isVisible();
    }

}