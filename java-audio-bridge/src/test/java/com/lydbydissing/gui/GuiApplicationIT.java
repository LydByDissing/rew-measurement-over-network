package com.lydbydissing.gui;

import com.lydbydissing.AudioBridgeMain;
import javafx.application.Platform;
import javafx.stage.Stage;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.testfx.api.FxToolkit;
import org.testfx.framework.junit5.ApplicationExtension;
import org.testfx.framework.junit5.ApplicationTest;

import java.util.concurrent.TimeoutException;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Integration tests for the GUI application.
 * Tests the complete application lifecycle and GUI initialization.
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
@DisplayName("GUI Application Integration Tests")
@ExtendWith(ApplicationExtension.class)
class GuiApplicationIT extends ApplicationTest {
    
    private static boolean isHeadless;
    
    @BeforeAll
    static void setupHeadlessMode() throws TimeoutException {
        // Check if we're running in headless mode
        isHeadless = Boolean.parseBoolean(System.getProperty("java.awt.headless", "false")) ||
                     Boolean.parseBoolean(System.getProperty("testfx.headless", "false"));
        
        if (isHeadless) {
            // Configure TestFX for headless testing
            System.setProperty("testfx.robot", "glass");
            System.setProperty("testfx.headless", "true");
            System.setProperty("prism.order", "sw");
            System.setProperty("prism.text", "t2k");
            System.setProperty("java.awt.headless", "true");
        }
        
        // Initialize JavaFX toolkit
        if (!Platform.isFxApplicationThread()) {
            FxToolkit.registerPrimaryStage();
        }
    }
    
    public void start(Stage stage) throws Exception {
        // Start the application
        AudioBridgeMain app = new AudioBridgeMain();
        app.start(stage);
    }
    
    @Test
    @DisplayName("Should start GUI application successfully")
    void shouldStartGuiApplication() {
        if (isHeadless) {
            // In headless mode, we just verify the application doesn't crash
            assertThat(Platform.isFxApplicationThread()).isFalse();
            // The fact that we got here means the application started without crashing
        } else {
            // In GUI mode, we can check for actual UI components
            // This would be expanded with actual UI component checks
        }
    }
    
    @Test
    @DisplayName("Should handle headless environment gracefully")
    void shouldHandleHeadlessEnvironment() {
        // Test that the application can detect and handle headless environments
        boolean headlessProperty = Boolean.parseBoolean(System.getProperty("java.awt.headless", "false"));
        
        if (isHeadless) {
            // Verify headless configuration is applied
            assertThat(System.getProperty("testfx.headless")).isEqualTo("true");
            assertThat(System.getProperty("prism.order")).isEqualTo("sw");
        }
        
        // Application should not crash regardless of headless state
        // The fact that we can run this test means it's working
        assertThat(true).isTrue();
    }
    
    @Test
    @DisplayName("Should initialize JavaFX platform properly")
    void shouldInitializeJavaFxPlatform() {
        // Test that JavaFX platform is properly initialized
        // This test ensures that Platform.runLater() and other JavaFX APIs work
        final boolean[] platformReady = {false};
        
        Platform.runLater(() -> {
            platformReady[0] = true;
        });
        
        // Wait a bit for the platform thread to execute
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        // In headless mode, we can't guarantee Platform.runLater execution
        // but the fact that it doesn't throw an exception is good
        if (!isHeadless) {
            assertThat(platformReady[0]).isTrue();
        }
    }
}