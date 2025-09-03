package com.lydbydissing;

import com.lydbydissing.cli.CliOptions;
import com.lydbydissing.cli.HeadlessRunner;
import com.lydbydissing.gui.MainController;
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
 * <p>Usage:</p>
 * <ul>
 *   <li>GUI Mode: java -jar rew-network-bridge.jar</li>
 *   <li>Headless: java -jar rew-network-bridge.jar --headless --target 192.168.1.100</li>
 * </ul>
 * 
 * @author REW Network Project Contributors
 * @version 0.1.0
 * @since 1.0
 */
public class AudioBridgeMain extends Application {
    
    private static final Logger logger = LoggerFactory.getLogger(AudioBridgeMain.class);
    private static CliOptions cliOptions;
    private MainController mainController;
    
    /**
     * Application entry point.
     * 
     * @param args command line arguments
     */
    public static void main(String[] args) {
        // Force software rendering to avoid GPU shader issues
        System.setProperty("prism.order", "sw");
        System.setProperty("prism.text", "t2k");
        System.setProperty("java2d.opengl", "false");
        
        logger.info("Starting REW Network Audio Bridge v{}", getVersion());
        
        try {
            // Parse CLI arguments
            cliOptions = CliOptions.parse(args);
            logger.debug("CLI options: {}", cliOptions);
            
            // Handle special options first
            if (cliOptions.isShowHelp()) {
                CliOptions.printUsage();
                return;
            }
            
            if (cliOptions.isShowVersion()) {
                CliOptions.printVersion();
                return;
            }
            
            // Run in headless mode if requested
            if (cliOptions.isHeadless()) {
                runHeadless();
                return;
            }
            
            // Otherwise run GUI mode
            launch(args);
            
        } catch (IllegalArgumentException e) {
            System.err.println("Error: " + e.getMessage());
            System.err.println();
            CliOptions.printUsage();
            System.exit(1);
        } catch (Exception e) {
            logger.error("Fatal error during startup", e);
            System.err.println("Fatal error: " + e.getMessage());
            System.exit(1);
        }
    }
    
    /**
     * Runs the application in headless mode.
     */
    private static void runHeadless() {
        try {
            HeadlessRunner runner = new HeadlessRunner(cliOptions);
            runner.run();
        } catch (Exception e) {
            logger.error("Error in headless mode", e);
            System.err.println("Headless mode error: " + e.getMessage());
            System.exit(1);
        }
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
        
        try {
            // Load FXML
            javafx.fxml.FXMLLoader loader = new javafx.fxml.FXMLLoader(
                getClass().getResource("/main.fxml")
            );
            javafx.scene.Parent root = loader.load();
            
            // Get the controller for cleanup purposes
            mainController = loader.getController();
            
            // Create scene
            javafx.scene.Scene scene = new javafx.scene.Scene(root, 800, 600);
            
            // Setup stage
            primaryStage.setTitle("REW Network Audio Bridge - LydByDissing");
            primaryStage.setScene(scene);
            primaryStage.setMinWidth(600);
            primaryStage.setMinHeight(400);
            
            // Show stage first
            primaryStage.show();
            
            // Handle CLI options after stage is shown
            if (cliOptions != null) {
                // Handle auto-connect
                if (cliOptions.getTargetIp() != null) {
                    mainController.setAutoConnectTarget(cliOptions.getTargetIp(), cliOptions.getTargetPort());
                    
                    // Trigger auto-connect after a small delay to ensure GUI is fully initialized
                    javafx.application.Platform.runLater(() -> {
                        try {
                            Thread.sleep(1000); // Give GUI time to initialize
                            mainController.triggerAutoConnect();
                        } catch (InterruptedException e) {
                            Thread.currentThread().interrupt();
                        }
                    });
                }
                
            }
            
            logger.info("Application started successfully");
            
        } catch (Exception e) {
            logger.error("Failed to start application", e);
            throw e;
        }
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
        
        // Cleanup controller resources (including discovery service)
        if (mainController != null) {
            mainController.cleanup();
        }
        
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