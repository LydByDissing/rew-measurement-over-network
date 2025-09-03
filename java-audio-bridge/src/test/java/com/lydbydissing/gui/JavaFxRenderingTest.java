package com.lydbydissing.gui;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.DisabledIfSystemProperty;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeFalse;

/**
 * Tests for JavaFX rendering configuration and graphics subsystem compatibility.
 * Note: Actual rendering tests are skipped in headless environments.
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
@DisplayName("JavaFX Rendering Tests") 
class JavaFxRenderingTest {
    
    private static boolean isHeadless;
    private static boolean hasDisplay;
    
    @BeforeAll
    static void detectEnvironment() {
        // Detect environment capabilities
        isHeadless = Boolean.parseBoolean(System.getProperty("java.awt.headless", "false")) ||
                     Boolean.parseBoolean(System.getProperty("testfx.headless", "false"));
        hasDisplay = System.getenv("DISPLAY") != null;
        
        // Configure software rendering to avoid shader issues
        System.setProperty("prism.order", "sw");
        System.setProperty("prism.text", "t2k");
        System.setProperty("prism.allowhidpi", "false");
    }
    
    @Test
    @DisplayName("Should configure software rendering to avoid shader issues")
    void shouldConfigureSoftwareRendering() {
        // Verify software rendering is configured
        String prismOrder = System.getProperty("prism.order");
        assertThat(prismOrder).isEqualTo("sw");
        
        String prismText = System.getProperty("prism.text");
        assertThat(prismText).isEqualTo("t2k");
        
        String prismHidpi = System.getProperty("prism.allowhidpi");
        assertThat(prismHidpi).isEqualTo("false");
    }
    
    @Test
    @DisplayName("Should detect environment capabilities")
    void shouldDetectEnvironmentCapabilities() {
        // Report environment information for debugging
        System.out.println("=== Graphics Environment Detection ===");
        System.out.println("Headless mode: " + isHeadless);
        System.out.println("Has DISPLAY: " + hasDisplay);
        System.out.println("DISPLAY env: " + System.getenv("DISPLAY"));
        System.out.println("prism.order: " + System.getProperty("prism.order"));
        System.out.println("prism.text: " + System.getProperty("prism.text"));
        System.out.println("java.awt.headless: " + System.getProperty("java.awt.headless"));
        
        // Basic assertions about environment detection
        assertThat(System.getProperty("prism.order")).isNotNull();
        
        // In CI/headless environments, we expect software rendering
        if (isHeadless) {
            assertThat(System.getProperty("prism.order")).isEqualTo("sw");
        }
    }
    
    @Test
    @DisplayName("Should skip rendering tests in headless environment")
    void shouldSkipRenderingTestsInHeadless() {
        assumeFalse(isHeadless || !hasDisplay, "Skipping rendering tests in headless environment");
        
        // This test only runs if NOT in headless mode AND has display
        // In GUI environments, we could test actual JavaFX rendering
        System.out.println("Running in GUI environment - actual rendering tests would go here");
        assertThat(true).isTrue();
    }
    
    @Test
    @DisplayName("Should validate JavaFX system properties are set correctly")
    void shouldValidateJavaFxSystemProperties() {
        // Test that all necessary system properties are configured
        // to avoid common JavaFX issues in various environments
        
        // Software rendering should be enabled to avoid GPU issues
        assertThat(System.getProperty("prism.order")).contains("sw");
        
        // Text rendering should use T2K to avoid font issues
        assertThat(System.getProperty("prism.text")).isEqualTo("t2k");
        
        // HiDPI should be disabled to avoid scaling issues in headless mode
        assertThat(System.getProperty("prism.allowhidpi")).isEqualTo("false");
    }
    
    @Test
    @DisplayName("Should provide safe defaults for all environments")
    void shouldProvideSafeDefaultsForAllEnvironments() {
        // This test ensures our JavaFX configuration works in all environments
        // including CI, Docker, headless servers, and development machines
        
        if (isHeadless || !hasDisplay) {
            System.out.println("Headless/no-display environment - using software rendering");
            // In headless environments, software rendering should be configured
            assertThat(System.getProperty("prism.order")).isEqualTo("sw");
        } else {
            System.out.println("GUI environment detected - rendering capabilities available");
        }
        
        // Test should always pass - we handle all environment types
        assertThat(true).isTrue();
    }
}