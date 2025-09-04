package com.lydbydissing.audio;

/**
 * Simple test to verify the JavaAudioLoopback works correctly.
 */
public final class AudioLoopbackTest {
    
    /**
     * Private constructor to prevent instantiation.
     */
    private AudioLoopbackTest() {
        // Utility class
    }
    
    public static void main(String[] args) {
        System.out.println("=== Java Audio Loopback Test ===");
        System.out.println();
        
        try {
            System.out.println("Creating audio loopback...");
            JavaAudioLoopback loopback = new JavaAudioLoopback();
            
            // Set up a simple consumer to count audio data
            final int[] dataCount = {0};
            loopback.setAudioDataConsumer(audioData -> {
                dataCount[0]++;
                if (dataCount[0] % 100 == 0) {
                    System.out.println("Received " + dataCount[0] + " audio data packets");
                }
            });
            
            // Set up level monitoring
            loopback.setAudioLevelConsumer(level -> {
                if (level > 0.01) { // Only show when there's actual audio
                    System.out.printf("Audio level: %.3f\n", level);
                }
            });
            
            System.out.println("Starting audio loopback...");
            loopback.start();
            
            System.out.println("Audio loopback started successfully!");
            System.out.println("Interface: " + loopback.getInterfaceDescription());
            System.out.println();
            System.out.println("This is a pure Java audio interface - REW can use the system's default audio device.");
            System.out.println("The audio will be captured from the system's default input and can be streamed.");
            System.out.println();
            System.out.println("Press Ctrl+C to stop or wait 10 seconds...");
            
            // Run for 10 seconds
            Thread.sleep(10000);
            
            System.out.println("\nStopping audio loopback...");
            loopback.stop();
            
            System.out.println("Audio loopback stopped successfully!");
            System.out.println("Total audio data packets received: " + dataCount[0]);
            
        } catch (Exception e) {
            System.err.println("Error testing audio loopback: " + e.getMessage());
            e.printStackTrace();
        }
    }
}