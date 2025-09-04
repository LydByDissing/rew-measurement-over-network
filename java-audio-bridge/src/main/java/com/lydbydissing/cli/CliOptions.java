package com.lydbydissing.cli;

/**
 * Command line options for the REW Network Audio Bridge.
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class CliOptions {
    
    private boolean headless = false;
    private String targetIp = null;
    private int targetPort = 5004;
    private boolean showHelp = false;
    private boolean showVersion = false;
    private boolean testMode = false;
    
    /**
     * Parses command line arguments into options.
     * 
     * @param args Command line arguments
     * @return Parsed CLI options
     * @throws IllegalArgumentException if invalid arguments provided
     */
    public static CliOptions parse(String[] args) {
        CliOptions options = new CliOptions();
        
        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            
            switch (arg) {
                case "--headless":
                case "-h":
                    options.headless = true;
                    break;
                    
                case "--target":
                case "-t":
                    if (i + 1 >= args.length) {
                        throw new IllegalArgumentException("--target requires an IP address");
                    }
                    options.targetIp = args[++i];
                    if (!isValidIpAddress(options.targetIp)) {
                        throw new IllegalArgumentException("Invalid IP address: " + options.targetIp);
                    }
                    break;
                    
                case "--port":
                case "-p":
                    if (i + 1 >= args.length) {
                        throw new IllegalArgumentException("--port requires a port number");
                    }
                    try {
                        options.targetPort = Integer.parseInt(args[++i]);
                        if (options.targetPort < 1 || options.targetPort > 65535) {
                            throw new IllegalArgumentException("Port must be between 1 and 65535");
                        }
                    } catch (NumberFormatException e) {
                        throw new IllegalArgumentException("Invalid port number: " + args[i]);
                    }
                    break;
                    
                case "--help":
                    options.showHelp = true;
                    break;
                    
                case "--version":
                    options.showVersion = true;
                    break;
                    
                case "--test-mode":
                    options.testMode = true;
                    break;
                    
                default:
                    throw new IllegalArgumentException("Unknown argument: " + arg);
            }
        }
        
        // Validation
        if (options.headless && options.targetIp == null) {
            throw new IllegalArgumentException("--headless mode requires --target IP address");
        }
        
        return options;
    }
    
    /**
     * Validates if a string is a valid IP address.
     * 
     * @param ip The IP address string to validate
     * @return true if valid, false otherwise
     */
    private static boolean isValidIpAddress(String ip) {
        if (ip == null || ip.isEmpty()) {
            return false;
        }
        
        String[] parts = ip.split("\\.");
        if (parts.length != 4) {
            return false;
        }
        
        try {
            for (String part : parts) {
                int num = Integer.parseInt(part);
                if (num < 0 || num > 255) {
                    return false;
                }
            }
            return true;
        } catch (NumberFormatException e) {
            return false;
        }
    }
    
    /**
     * Prints usage information.
     */
    public static void printUsage() {
        System.out.println("REW Network Audio Bridge - Usage:");
        System.out.println();
        System.out.println("GUI Mode (default):");
        System.out.println("  java -jar rew-audio-bridge.jar");
        System.out.println();
        System.out.println("Headless Mode:");
        System.out.println("  java -jar rew-audio-bridge.jar --headless --target <IP>");
        System.out.println();
        System.out.println("Options:");
        System.out.println("  -h, --headless              Run without GUI, connect automatically");
        System.out.println("  -t, --target <IP>           Target Pi device IP address (required for headless)");
        System.out.println("  -p, --port <PORT>           Target RTP port (default: 5004)");
        System.out.println("      --test-mode             Enable test mode (mock audio for containers)");
        System.out.println("      --help                  Show this help message");
        System.out.println("      --version               Show version information");
        System.out.println();
        System.out.println("Examples:");
        System.out.println("  java -jar rew-audio-bridge.jar --headless --target 192.168.1.100");
        System.out.println("  java -jar rew-audio-bridge.jar --headless -t 10.0.0.50 -p 5005");
        System.out.println("  java -jar rew-audio-bridge.jar --headless --target 192.168.1.100 --test-mode");
        System.out.println();
        System.out.println("In headless mode, the application will:");
        System.out.println("  - Start the Java audio loopback automatically");
        System.out.println("  - Connect to the specified Pi device immediately");
        System.out.println("  - Begin streaming audio from microphone to Pi");
        System.out.println("  - Run until Ctrl+C is pressed");
    }
    
    /**
     * Prints version information.
     */
    public static void printVersion() {
        System.out.println("REW Network Audio Bridge v0.1.0-SNAPSHOT");
        System.out.println("Pure Java audio streaming solution for REW measurements");
        System.out.println("https://github.com/your-repo/rew-network-bridge");
    }
    
    // Getters
    public boolean isHeadless() {
        return headless;
    }
    
    public String getTargetIp() {
        return targetIp;
    }
    
    public int getTargetPort() {
        return targetPort;
    }
    
    public boolean isShowHelp() {
        return showHelp;
    }
    
    public boolean isShowVersion() {
        return showVersion;
    }
    
    public boolean isTestMode() {
        return testMode;
    }
    
    @Override
    public String toString() {
        return String.format("CliOptions{headless=%s, targetIp='%s', targetPort=%d, showHelp=%s, "
                           + "showVersion=%s, testMode=%s}",
                           headless, targetIp, targetPort, showHelp, showVersion, testMode);
    }
}