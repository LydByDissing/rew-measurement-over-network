#!/bin/bash

# RTP to ALSA Bridge
# Receives RTP audio streams and forwards to ALSA loopback device
# This bridges RTP input to CamillaDSP via ALSA loopback

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[RTP-BRIDGE]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configuration
RTP_PORT="${RTP_PORT:-5004}"
ALSA_DEVICE="${ALSA_DEVICE:-plughw:CARD=Loopback,DEV=0}"
SAMPLE_RATE="${SAMPLE_RATE:-48000}"
CHANNELS="${CHANNELS:-2}"

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Bridge RTP audio streams to ALSA loopback device"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT       RTP port to listen on (default: 5004)"
    echo "  -d, --device DEVICE   ALSA device to output to (default: plughw:CARD=Loopback,DEV=0)"
    echo "  -r, --rate RATE       Sample rate (default: 48000)"
    echo "  -c, --channels N      Number of channels (default: 2)"
    echo "  -h, --help           Show this help"
    echo ""
    echo "Environment variables:"
    echo "  RTP_PORT, ALSA_DEVICE, SAMPLE_RATE, CHANNELS"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            RTP_PORT="$2"
            shift 2
            ;;
        -d|--device)
            ALSA_DEVICE="$2"
            shift 2
            ;;
        -r|--rate)
            SAMPLE_RATE="$2"
            shift 2
            ;;
        -c|--channels)
            CHANNELS="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

log "🎵 Starting RTP to ALSA bridge..."
log "RTP Port: $RTP_PORT"
log "ALSA Device: $ALSA_DEVICE"
log "Sample Rate: $SAMPLE_RATE Hz"
log "Channels: $CHANNELS"

# Check if FFmpeg is available
if ! command -v ffmpeg >/dev/null 2>&1; then
    error "FFmpeg is not installed or not in PATH"
    error "Please install FFmpeg: sudo apt-get install ffmpeg"
    exit 1
fi

# Check if ALSA device is available
if ! aplay -l 2>/dev/null | grep -q "Loopback"; then
    warning "ALSA Loopback device not found in 'aplay -l'"
    warning "Make sure snd-aloop module is loaded: sudo modprobe snd-aloop"
fi

# Start the RTP to ALSA bridge
log "🎯 Starting FFmpeg RTP receiver..."
log "Listening for RTP streams on port $RTP_PORT"
log "Press Ctrl+C to stop"

# Check if SDP file exists for better RTP payload handling
SDP_FILE="${SCRIPT_DIR:-$(dirname "$0")}/audio.sdp"
if [ -f "$SDP_FILE" ]; then
    # Use SDP file for precise RTP payload type handling (eliminates "guessing" warnings)
    FFMPEG_CMD="ffmpeg -y -protocol_whitelist file,rtp,udp -analyzeduration 2000000 -probesize 65536 -fflags +genpts -avoid_negative_ts make_zero -i $SDP_FILE -f alsa -acodec pcm_s16le -ac $CHANNELS -ar $SAMPLE_RATE $ALSA_DEVICE"
else
    # Fallback to direct RTP with improved reliability
    FFMPEG_CMD="ffmpeg -y -f rtp -analyzeduration 2000000 -probesize 65536 -fflags +genpts -avoid_negative_ts make_zero -i rtp://0.0.0.0:$RTP_PORT -f alsa -acodec pcm_s16le -ac $CHANNELS -ar $SAMPLE_RATE $ALSA_DEVICE"
fi

log "Command: $FFMPEG_CMD"
echo ""

# Execute FFmpeg with proper error handling
exec $FFMPEG_CMD
