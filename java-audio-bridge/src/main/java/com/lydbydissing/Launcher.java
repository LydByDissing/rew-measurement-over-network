package com.lydbydissing;

/**
 * Non-JavaFX launcher class that starts the JavaFX application.
 * This approach bypasses JavaFX module system checks when using shaded JARs.
 * 
 * @author REW Network Project Contributors
 * @version 0.1.0
 * @since 1.0
 */
public class Launcher {
    
    /**
     * Main entry point that launches the JavaFX application.
     * 
     * @param args command line arguments passed to JavaFX application
     */
    public static void main(String[] args) {
        AudioBridgeMain.main(args);
    }
}