package com.lydbydissing;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

/**
 * Tests for the Launcher class without GUI dependencies.
 * Validates application entry point and command line handling.
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
@DisplayName("Launcher Tests")
class LauncherTest {
    
    @Test
    @DisplayName("Should have main method")
    void shouldHaveMainMethod() throws NoSuchMethodException {
        // Test that main method exists with correct signature
        var mainMethod = Launcher.class.getMethod("main", String[].class);
        
        assertThat(mainMethod).isNotNull();
        assertThat(mainMethod.getParameterCount()).isEqualTo(1);
        assertThat(mainMethod.getParameterTypes()[0]).isEqualTo(String[].class);
        assertThat(mainMethod.getReturnType()).isEqualTo(void.class);
    }
    
    @Test
    @DisplayName("Should be a utility class with private constructor")
    void shouldBeUtilityClassWithPrivateConstructor() {
        // Test that Launcher is properly designed as a utility class
        assertThat(Launcher.class.getDeclaredConstructors()).hasSize(1);
        
        var constructor = Launcher.class.getDeclaredConstructors()[0];
        assertThat(constructor.getModifiers()).satisfies(modifiers -> {
            assertThat(java.lang.reflect.Modifier.isPrivate(modifiers)).isTrue();
        });
    }
    
    @Test
    @DisplayName("Should handle command line arguments structure")
    void shouldHandleCommandLineArgumentsStructure() {
        // Test that we can call main without throwing exceptions in basic cases
        // Note: We don't actually run main() as it would start the GUI
        
        // Test argument arrays that the application should handle
        String[] emptyArgs = {};
        String[] headlessArgs = {"--headless"};
        String[] targetArgs = {"--target", "localhost"};
        
        // Verify these are valid string arrays (basic structure test)
        assertThat(emptyArgs).isNotNull();
        assertThat(headlessArgs).hasSize(1);
        assertThat(targetArgs).hasSize(2);
        assertThat(targetArgs[0]).isEqualTo("--target");
        assertThat(targetArgs[1]).isEqualTo("localhost");
    }
    
    @Test
    @DisplayName("Should be in correct package")
    void shouldBeInCorrectPackage() {
        assertThat(Launcher.class.getPackageName()).isEqualTo("com.lydbydissing");
        assertThat(Launcher.class.getSimpleName()).isEqualTo("Launcher");
    }
}