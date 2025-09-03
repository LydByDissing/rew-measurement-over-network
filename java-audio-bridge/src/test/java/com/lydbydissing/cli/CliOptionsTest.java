package com.lydbydissing.cli;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for CLI options parsing and handling.
 * These tests validate command line argument processing without GUI dependencies.
 * 
 * @author LydByDissing  
 * @version 0.1.0
 * @since 1.0
 */
@DisplayName("CLI Options Tests")
class CliOptionsTest {
    
    @Test
    @DisplayName("Should create CliOptions instance")
    void shouldCreateCliOptionsInstance() {
        CliOptions options = new CliOptions();
        assertThat(options).isNotNull();
    }
    
    @Test
    @DisplayName("Should have default values")
    void shouldHaveDefaultValues() {
        CliOptions options = CliOptions.parse(new String[]{});
        
        // Test default values (based on actual implementation)
        assertThat(options.isHeadless()).isFalse(); // Default should be GUI mode
        assertThat(options.getTargetIp()).isNull();   // No default target
        assertThat(options.getTargetPort()).isEqualTo(5004); // Default RTP port from code
    }
    
    @Test
    @DisplayName("Should parse headless flag with target")
    void shouldParseHeadlessFlag() {
        String[] args = {"--headless", "--target", "192.168.1.100"};
        CliOptions options = CliOptions.parse(args);
        
        assertThat(options.isHeadless()).isTrue();
        assertThat(options.getTargetIp()).isEqualTo("192.168.1.100");
    }
    
    @Test
    @DisplayName("Should parse target argument")
    void shouldParseTargetArgument() {
        String[] args = {"--headless", "--target", "192.168.1.100"};
        CliOptions options = CliOptions.parse(args);
        
        assertThat(options.getTargetIp()).isEqualTo("192.168.1.100");
    }
    
    @Test
    @DisplayName("Should parse port argument")
    void shouldParsePortArgument() {
        String[] args = {"--headless", "--target", "192.168.1.100", "--port", "6000"};
        CliOptions options = CliOptions.parse(args);
        
        assertThat(options.getTargetPort()).isEqualTo(6000);
    }
    
    @Test
    @DisplayName("Should parse combined arguments")
    void shouldParseCombinedArguments() {
        String[] args = {"--headless", "--target", "192.168.1.50", "--port", "5005"};
        CliOptions options = CliOptions.parse(args);
        
        assertThat(options.isHeadless()).isTrue();
        assertThat(options.getTargetIp()).isEqualTo("192.168.1.50");
        assertThat(options.getTargetPort()).isEqualTo(5005);
    }
    
    @Test
    @DisplayName("Should handle empty arguments")
    void shouldHandleEmptyArguments() {
        String[] args = {};
        CliOptions options = CliOptions.parse(args);
        
        assertThat(options).isNotNull();
        assertThat(options.isHeadless()).isFalse(); // Default to GUI mode
    }
    
    @Test
    @DisplayName("Should validate required CLI functionality")
    void shouldValidateRequiredCliFunctionality() {
        // Ensure CLI parsing doesn't require JavaFX
        assertThat(CliOptions.class).isNotNull();
        
        // Test that we can parse basic arguments without graphics
        String[] testArgs = {"--headless", "--target", "127.0.0.1", "--port", "8080"};
        CliOptions result = CliOptions.parse(testArgs);
        
        assertThat(result).isNotNull();
        assertThat(result.isHeadless()).isTrue();
        assertThat(result.getTargetIp()).isEqualTo("127.0.0.1");
        assertThat(result.getTargetPort()).isEqualTo(8080);
    }
}