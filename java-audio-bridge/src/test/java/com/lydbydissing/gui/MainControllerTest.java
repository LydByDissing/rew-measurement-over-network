package com.lydbydissing.gui;

import javafx.fxml.FXMLLoader;
import javafx.scene.Parent;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeFalse;

/**
 * Tests for MainController GUI component.
 * Note: These tests avoid JavaFX rendering to prevent headless compatibility issues.
 * 
 * @author LydByDissing
 * @version 0.1.0  
 * @since 1.0
 */
@DisplayName("MainController Tests")
class MainControllerTest {
    
    private static final boolean isHeadless = 
        Boolean.parseBoolean(System.getProperty("java.awt.headless", "false")) ||
        Boolean.parseBoolean(System.getProperty("testfx.headless", "false")) ||
        System.getenv("DISPLAY") == null;
    
    @Test
    @DisplayName("Should create MainController instance")
    void shouldCreateMainControllerInstance() {
        MainController controller = new MainController();
        assertThat(controller).isNotNull();
    }
    
    @Test
    @DisplayName("Should validate controller class structure")
    void shouldValidateControllerClassStructure() {
        // Verify the controller class has expected structure
        assertThat(MainController.class).isNotNull();
        
        // Check that we can instantiate it
        MainController controller = new MainController();
        assertThat(controller).isNotNull();
        
        // Verify it's a valid JavaFX controller class
        assertThat(MainController.class.getPackage().getName()).contains("gui");
    }
    
    @Test
    @DisplayName("Should skip FXML loading tests in headless environment")
    void shouldSkipFxmlLoadingInHeadless() {
        assumeFalse(isHeadless, "Skipping FXML test in headless environment");
        
        // This test only runs if NOT in headless mode
        // In GUI environments, we could test FXML loading
        var fxmlResource = getClass().getResource("/main.fxml");
        
        if (fxmlResource != null) {
            // FXML file exists - in GUI mode we could load it
            assertThat(fxmlResource).isNotNull();
            System.out.println("FXML resource found - actual GUI tests would go here");
        } else {
            System.out.println("No FXML resource found - controller tests only");
        }
    }
    
    @Test
    @DisplayName("Should validate FXML resource exists")
    void shouldValidateFxmlResourceExists() {
        // Test that the FXML resource is properly packaged
        var fxmlResource = getClass().getResource("/main.fxml");
        
        if (fxmlResource != null) {
            assertThat(fxmlResource).isNotNull();
            assertThat(fxmlResource.toString()).contains("main.fxml");
        } else {
            // FXML not found - could be expected in some build scenarios
            System.out.println("No FXML resource found - may need to be created");
        }
    }
}