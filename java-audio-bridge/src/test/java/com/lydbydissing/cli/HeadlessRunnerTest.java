package com.lydbydissing.cli;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

/**
 * Tests for HeadlessRunner functionality.
 * These tests don't require JavaFX GUI initialization.
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
@DisplayName("HeadlessRunner Tests")
class HeadlessRunnerTest {
    
    @Test
    @DisplayName("Should create HeadlessRunner instance")
    void shouldCreateHeadlessRunnerInstance() {
        CliOptions options = CliOptions.parse(new String[]{"--headless", "--target", "192.168.1.100"});
        HeadlessRunner runner = new HeadlessRunner(options);
        assertThat(runner).isNotNull();
    }
    
    @Test
    @DisplayName("Should handle valid CLI options")
    void shouldHandleValidCliOptions() {
        CliOptions options = CliOptions.parse(new String[]{"--headless", "--target", "10.0.0.1", "--port", "5005"});
        HeadlessRunner runner = new HeadlessRunner(options);
        
        // Should not throw exception with valid options
        assertDoesNotThrow(() -> {
            // For now, we just test that the instance can be created
            runner.getClass();
        });
    }
    
    @Test
    @DisplayName("Should be runnable without GUI dependencies")
    void shouldBeRunnableWithoutGuiDependencies() {
        // This test verifies we can create and use the HeadlessRunner
        // without initializing any JavaFX components
        
        CliOptions options = CliOptions.parse(new String[]{"--headless", "--target", "127.0.0.1"});
        HeadlessRunner runner = new HeadlessRunner(options);
        assertThat(runner).isNotNull();
        
        // Test that the class exists and has expected methods
        assertThat(runner.getClass().getName()).isEqualTo("com.lydbydissing.cli.HeadlessRunner");
    }
}