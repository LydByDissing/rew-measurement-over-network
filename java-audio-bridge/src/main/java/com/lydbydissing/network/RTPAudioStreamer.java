package com.lydbydissing.network;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.sound.sampled.AudioFormat;
import java.io.IOException;
import java.net.*;
import java.nio.ByteBuffer;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/**
 * RTP audio streamer for sending audio data to Raspberry Pi devices.
 * 
 * <p>This class implements a basic RTP (Real-time Transport Protocol) streamer
 * for sending audio data over UDP to Pi devices. It handles RTP packet formatting,
 * sequence numbering, and timestamp management according to RFC 3550.</p>
 * 
 * <p>The streamer supports standard audio formats and provides statistics for
 * monitoring stream quality and performance.</p>
 * 
 * @author LydByDissing
 * @version 0.1.0
 * @since 1.0
 */
public class RTPAudioStreamer {
    
    private static final Logger logger = LoggerFactory.getLogger(RTPAudioStreamer.class);
    
    /** RTP version (always 2) */
    private static final int RTP_VERSION = 2;
    
    /** Default RTP port for audio streaming */
    public static final int DEFAULT_RTP_PORT = 5004;
    
    /** Maximum RTP packet size (excluding headers) */
    private static final int MAX_PACKET_SIZE = 1200;
    
    /** RTP header size in bytes */
    private static final int RTP_HEADER_SIZE = 12;
    
    /** Maximum payload size per packet */
    private static final int MAX_PAYLOAD_SIZE = MAX_PACKET_SIZE - RTP_HEADER_SIZE;
    
    private DatagramSocket socket;
    private InetAddress targetAddress;
    private int targetPort;
    private AudioFormat audioFormat;
    
    private final AtomicBoolean isStreaming = new AtomicBoolean(false);
    private final AtomicLong sequenceNumber = new AtomicLong(0);
    private final AtomicLong timestamp = new AtomicLong(0);
    
    // Stream statistics
    private final AtomicLong packetsSent = new AtomicLong(0);
    private final AtomicLong bytesSent = new AtomicLong(0);
    private long streamStartTime = 0;
    
    // RTP session parameters
    private final int ssrc; // Synchronization source identifier
    private final int payloadType; // Payload type for audio format
    
    /**
     * Creates an RTP audio streamer with default parameters.
     * 
     * @param targetAddress The IP address of the target Pi device
     * @param targetPort    The target port for RTP streaming
     * @param audioFormat   The audio format for the stream
     * @throws SocketException if the UDP socket cannot be created
     */
    public RTPAudioStreamer(InetAddress targetAddress, int targetPort, AudioFormat audioFormat) 
            throws SocketException {
        this.targetAddress = targetAddress;
        this.targetPort = targetPort;
        this.audioFormat = audioFormat;
        
        // Generate random SSRC
        this.ssrc = (int) (Math.random() * Integer.MAX_VALUE);
        
        // Determine payload type based on audio format
        this.payloadType = determinePayloadType(audioFormat);
        
        // Create UDP socket
        this.socket = new DatagramSocket();
        
        logger.info("Created RTP streamer for {}:{} with format: {}", 
                   targetAddress.getHostAddress(), targetPort, formatToString(audioFormat));
    }
    
    /**
     * Starts the RTP streaming session.
     * 
     * @throws IllegalStateException if already streaming
     */
    public void startStreaming() {
        if (isStreaming.get()) {
            throw new IllegalStateException("RTP streamer is already running");
        }
        
        logger.info("Starting RTP audio streaming");
        
        isStreaming.set(true);
        streamStartTime = System.currentTimeMillis();
        sequenceNumber.set(0);
        timestamp.set(0);
        packetsSent.set(0);
        bytesSent.set(0);
        
        logger.info("RTP audio streaming started");
    }
    
    /**
     * Stops the RTP streaming session.
     */
    public void stopStreaming() {
        if (!isStreaming.get()) {
            logger.warn("RTP streamer is not running");
            return;
        }
        
        logger.info("Stopping RTP audio streaming");
        
        isStreaming.set(false);
        
        // Log final statistics
        long duration = System.currentTimeMillis() - streamStartTime;
        logger.info("RTP streaming stopped. Duration: {}ms, Packets: {}, Bytes: {}", 
                   duration, packetsSent.get(), bytesSent.get());
    }
    
    /**
     * Closes the RTP streamer and releases resources.
     */
    public void close() {
        stopStreaming();
        
        if (socket != null && !socket.isClosed()) {
            socket.close();
            logger.debug("RTP socket closed");
        }
    }
    
    /**
     * Checks if the streamer is currently active.
     * 
     * @return true if streaming is active, false otherwise
     */
    public boolean isStreaming() {
        return isStreaming.get();
    }
    
    /**
     * Streams audio data to the target device.
     * Splits large audio data into RTP packets and sends them.
     * 
     * @param audioData The audio data to stream
     * @throws IOException if there's an error sending data
     * @throws IllegalStateException if not currently streaming
     */
    public void streamAudioData(byte[] audioData) throws IOException {
        if (!isStreaming.get()) {
            throw new IllegalStateException("RTP streamer is not active");
        }
        
        if (audioData == null || audioData.length == 0) {
            return;
        }
        
        // Split audio data into packets
        int offset = 0;
        while (offset < audioData.length) {
            int payloadSize = Math.min(MAX_PAYLOAD_SIZE, audioData.length - offset);
            
            // Create RTP packet
            byte[] rtpPacket = createRTPPacket(audioData, offset, payloadSize);
            
            // Send packet
            DatagramPacket packet = new DatagramPacket(
                rtpPacket, rtpPacket.length, targetAddress, targetPort);
            
            socket.send(packet);
            
            // Update statistics
            packetsSent.incrementAndGet();
            bytesSent.addAndGet(rtpPacket.length);
            
            // Update sequence number and timestamp
            sequenceNumber.incrementAndGet();
            
            offset += payloadSize;
        }
        
        // Update timestamp based on audio data size
        updateTimestamp(audioData.length);
    }
    
    /**
     * Creates an RTP packet with header and audio payload.
     * 
     * @param audioData   The source audio data
     * @param offset      Offset in the audio data
     * @param payloadSize Size of the payload for this packet
     * @return Complete RTP packet as byte array
     */
    private byte[] createRTPPacket(byte[] audioData, int offset, int payloadSize) {
        byte[] packet = new byte[RTP_HEADER_SIZE + payloadSize];
        ByteBuffer buffer = ByteBuffer.wrap(packet);
        
        // RTP Header (12 bytes)
        // Byte 0: V(2) + P(1) + X(1) + CC(4)
        buffer.put((byte) ((RTP_VERSION << 6) | 0)); // V=2, P=0, X=0, CC=0
        
        // Byte 1: M(1) + PT(7)
        buffer.put((byte) (0 | payloadType)); // M=0, PT=payload type
        
        // Bytes 2-3: Sequence number
        buffer.putShort((short) (sequenceNumber.get() & 0xFFFF));
        
        // Bytes 4-7: Timestamp
        buffer.putInt((int) (timestamp.get() & 0xFFFFFFFFL));
        
        // Bytes 8-11: SSRC
        buffer.putInt(ssrc);
        
        // Payload
        buffer.put(audioData, offset, payloadSize);
        
        return packet;
    }
    
    /**
     * Updates the RTP timestamp based on audio data size.
     * 
     * @param audioDataSize Size of audio data in bytes
     */
    private void updateTimestamp(int audioDataSize) {
        // Calculate samples based on audio format
        int bytesPerSample = audioFormat.getSampleSizeInBits() / 8 * audioFormat.getChannels();
        int samples = audioDataSize / bytesPerSample;
        
        timestamp.addAndGet(samples);
    }
    
    /**
     * Determines the RTP payload type based on audio format.
     * 
     * @param format The audio format
     * @return RTP payload type number
     */
    private int determinePayloadType(AudioFormat format) {
        // Use dynamic payload types (96-127) for custom audio formats
        // In a full implementation, this would be negotiated
        return 96; // Dynamic payload type for PCM audio
    }
    
    /**
     * Gets current streaming statistics.
     * 
     * @return StreamingStats object with current statistics
     */
    public StreamingStats getStatistics() {
        long duration = isStreaming.get() ? 
            System.currentTimeMillis() - streamStartTime : 0;
        
        return new StreamingStats(
            packetsSent.get(),
            bytesSent.get(),
            duration,
            isStreaming.get()
        );
    }
    
    /**
     * Converts an AudioFormat to a readable string.
     * 
     * @param format The audio format to convert
     * @return A string representation of the format
     */
    private String formatToString(AudioFormat format) {
        return String.format("%.1f kHz, %d-bit, %d channels", 
                           format.getSampleRate() / 1000.0,
                           format.getSampleSizeInBits(),
                           format.getChannels());
    }
    
    /**
     * Statistics class for RTP streaming metrics.
     */
    public static class StreamingStats {
        private final long packetsSent;
        private final long bytesSent;
        private final long durationMs;
        private final boolean isActive;
        
        /**
         * Creates streaming statistics.
         * 
         * @param packetsSent Number of packets sent
         * @param bytesSent   Total bytes sent
         * @param durationMs  Duration in milliseconds
         * @param isActive    Whether streaming is currently active
         */
        public StreamingStats(long packetsSent, long bytesSent, long durationMs, boolean isActive) {
            this.packetsSent = packetsSent;
            this.bytesSent = bytesSent;
            this.durationMs = durationMs;
            this.isActive = isActive;
        }
        
        /**
         * Gets the number of packets sent.
         * 
         * @return Number of packets sent
         */
        public long getPacketsSent() {
            return packetsSent;
        }
        
        /**
         * Gets the total bytes sent.
         * 
         * @return Total bytes sent
         */
        public long getBytesSent() {
            return bytesSent;
        }
        
        /**
         * Gets the streaming duration in milliseconds.
         * 
         * @return Duration in milliseconds
         */
        public long getDurationMs() {
            return durationMs;
        }
        
        /**
         * Checks if streaming is currently active.
         * 
         * @return true if streaming is active, false otherwise
         */
        public boolean isActive() {
            return isActive;
        }
        
        /**
         * Calculates the average bitrate in bits per second.
         * 
         * @return Average bitrate in bps, or 0 if duration is 0
         */
        public double getAverageBitrate() {
            return durationMs > 0 ? (bytesSent * 8.0 * 1000.0) / durationMs : 0.0;
        }
        
        /**
         * Returns a string representation of the statistics.
         * 
         * @return Statistics as a formatted string
         */
        @Override
        public String toString() {
            return String.format("StreamingStats{packets=%d, bytes=%d, duration=%dms, active=%s, bitrate=%.1f bps}",
                               packetsSent, bytesSent, durationMs, isActive, getAverageBitrate());
        }
    }
}