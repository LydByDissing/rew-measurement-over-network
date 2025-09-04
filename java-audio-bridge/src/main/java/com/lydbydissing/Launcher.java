package com.lydbydissing;

/**
 * Non-JavaFX launcher class that starts the JavaFX application.
 * This approach bypasses JavaFX module system checks when using shaded JARs.
 * 
 * @author REW Network Project Contributors
 * @version 0.1.0
 * @since 1.0
 */
public final class Launcher {
    
    /**
     * Private constructor to prevent instantiation of this utility class.
     */
    private Launcher() {
        // Utility class - no instantiation allowed
    }
    
    /**
     * Main entry point that launches the JavaFX application.
     * 
     * @param args command line arguments passed to JavaFX application
     */
    public static void main(String[] args) {
        AudioBridgeMain.main(args);
    }
}