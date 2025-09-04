package com.lydbydissing.audio;

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.DataLine;
import javax.sound.sampled.Line;
import javax.sound.sampled.Mixer;
import javax.sound.sampled.SourceDataLine;
import javax.sound.sampled.TargetDataLine;

/**
 * Utility class to discover available audio devices and mixers.
 * This helps understand what audio interfaces Java can see.
 */
public final class AudioDeviceDiscovery {
    
    /**
     * Private constructor to prevent instantiation of this utility class.
     */
    private AudioDeviceDiscovery() {
        // Utility class - no instantiation allowed
    }
    
    /**
     * Main entry point for audio device discovery.
     * 
     * @param args command line arguments
     */
    public static void main(String[] args) {
        System.out.println("=== Java Audio Device Discovery ===");
        System.out.println();
        
        // List all available mixers
        Mixer.Info[] mixerInfos = AudioSystem.getMixerInfo();
        System.out.println("Available Audio Mixers (" + mixerInfos.length + "):");
        System.out.println("----------------------------------------");
        
        for (int i = 0; i < mixerInfos.length; i++) {
            Mixer.Info info = mixerInfos[i];
            System.out.printf("%d. %s\n", i + 1, info.getName());
            System.out.printf("   Description: %s\n", info.getDescription());
            System.out.printf("   Vendor: %s\n", info.getVendor());
            System.out.printf("   Version: %s\n", info.getVersion());
            
            try {
                Mixer mixer = AudioSystem.getMixer(info);
                
                // Check supported target lines (input/recording)
                Line.Info[] targetLines = mixer.getTargetLineInfo();
                if (targetLines.length > 0) {
                    System.out.println("   Target Lines (Input/Recording):");
                    for (Line.Info lineInfo : targetLines) {
                        System.out.println("     - " + lineInfo.toString());
                    }
                }
                
                // Check supported source lines (output/playback)
                Line.Info[] sourceLines = mixer.getSourceLineInfo();
                if (sourceLines.length > 0) {
                    System.out.println("   Source Lines (Output/Playback):");
                    for (Line.Info lineInfo : sourceLines) {
                        System.out.println("     - " + lineInfo.toString());
                    }
                }
                
            } catch (Exception e) {
                System.out.println("   Error accessing mixer: " + e.getMessage());
            }
            
            System.out.println();
        }
        
        // Test default audio formats
        System.out.println("=== Default Audio Line Support ===");
        testAudioFormats();
    }
    
    private static void testAudioFormats() {
        AudioFormat[] testFormats = {
            new AudioFormat(44100, 16, 2, true, false),
            new AudioFormat(48000, 16, 2, true, false),
            new AudioFormat(96000, 16, 2, true, false),
            new AudioFormat(44100, 24, 2, true, false),
        };
        
        for (AudioFormat format : testFormats) {
            System.out.printf("Testing format: %.0f Hz, %d-bit, %d channels\n", 
                format.getSampleRate(), format.getSampleSizeInBits(), format.getChannels());
            
            // Test TargetDataLine (recording/input)
            DataLine.Info targetInfo = new DataLine.Info(TargetDataLine.class, format);
            boolean targetSupported = AudioSystem.isLineSupported(targetInfo);
            System.out.printf("  TargetDataLine (input): %s\n", targetSupported ? "SUPPORTED" : "NOT SUPPORTED");
            
            // Test SourceDataLine (playback/output)  
            DataLine.Info sourceInfo = new DataLine.Info(SourceDataLine.class, format);
            boolean sourceSupported = AudioSystem.isLineSupported(sourceInfo);
            System.out.printf("  SourceDataLine (output): %s\n", sourceSupported ? "SUPPORTED" : "NOT SUPPORTED");
            
            System.out.println();
        }
    }
}