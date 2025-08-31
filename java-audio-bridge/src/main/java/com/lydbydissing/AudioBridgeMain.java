package com.lydbydissing;

import javafx.application.Application;
import javafx.stage.Stage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Main entry point for the REW Network Audio Bridge application.
 * 
 * <p>This application provides a bridge between REW (Room EQ Wizard) running on a 
 * developer machine and CamillaDSP running on a remote Raspberry Pi Zero W. It handles
 * audio streaming via RTP/UDP and provides a GUI for device discovery and connection
 * management.</p>
 * 
 * <p>Usage: java -jar rew-network-bridge.jar</p>
 * 
 * @author REW Network Project Contributors
 * @version 0.1.0
 * @since 1.0
 */
public class AudioBridgeMain extends Application {
    
    private static final Logger logger = LoggerFactory.getLogger(AudioBridgeMain.class);
    
    /**
     * Application entry point.
     * 
     * @param args command line arguments (currently unused)
     */
    public static void main(String[] args) {
        logger.info("Starting REW Network Audio Bridge v{}", getVersion());
        launch(args);
    }
    
    /**
     * JavaFX application start method.
     * Initializes the GUI and starts the audio bridge services.
     * 
     * @param primaryStage the primary stage for this application
     * @throws Exception if application startup fails
     */
    @Override
    public void start(Stage primaryStage) throws Exception {
        logger.info("Initializing JavaFX application");
        
        // TODO: Initialize GUI components
        // TODO: Start Pi discovery service
        // TODO: Initialize audio system
        
        primaryStage.setTitle("REW Network Audio Bridge");
        primaryStage.show();
        
        logger.info("Application started successfully");
    }
    
    /**
     * JavaFX application stop method.
     * Performs cleanup when the application is closed.
     * 
     * @throws Exception if shutdown fails
     */
    @Override
    public void stop() throws Exception {
        logger.info("Shutting down REW Network Audio Bridge");
        
        // TODO: Cleanup network connections
        // TODO: Stop audio streaming
        // TODO: Release audio resources
        
        super.stop();
        logger.info("Application shutdown complete");
    }
    
    /**
     * Gets the application version from the manifest or properties.
     * 
     * @return application version string
     */
    private static String getVersion() {
        // TODO: Read version from manifest or properties file
        return "0.1.0-SNAPSHOT";
    }
}