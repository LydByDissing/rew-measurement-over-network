#!/bin/bash

# Manual RTP to ALSA Bridge for REW Measurements
# Start this manually before running REW measurements

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${BLUE}[RTP-MANUAL]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
RTP_PORT="${RTP_PORT:-5004}"
ALSA_DEVICE="${ALSA_DEVICE:-plughw:CARD=Loopback,DEV=0}"
SAMPLE_RATE="${SAMPLE_RATE:-48000}"
CHANNELS="${CHANNELS:-2}"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT       RTP port to listen on (default: 5004)"
    echo "  -d, --device DEVICE   ALSA device (default: plughw:CARD=Loopback,DEV=0)"
    echo "  -r, --rate RATE       Sample rate (default: 48000)"
    echo "  -c, --channels CHANS  Audio channels (default: 2)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --port 5004       # Listen on port 5004"
    echo ""
    echo "This bridge waits indefinitely for RTP streams. Perfect for REW measurements."
    echo "Press Ctrl+C to stop."
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

# Cleanup function
cleanup() {
    log "Shutting down RTP bridge..."
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

log "🎵 Starting Manual RTP to ALSA bridge for REW..."
log "RTP Port: $RTP_PORT"
log "ALSA Device: $ALSA_DEVICE"
log "Sample Rate: $SAMPLE_RATE Hz"
log "Channels: $CHANNELS"
echo ""

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

log "🎯 Starting FFmpeg RTP receiver..."
log "Waiting indefinitely for RTP streams on port $RTP_PORT"
log "This is perfect for REW measurements - start your test when ready!"
log "Press Ctrl+C to stop"
echo ""

# Check for SDP file to eliminate RTP header guessing
SCRIPT_DIR="$(dirname "$0")"
SDP_FILE="$SCRIPT_DIR/audio.sdp"

if [ -f "$SDP_FILE" ]; then
    log "Using SDP configuration for precise RTP payload handling"
    # Add timeout tolerance and restart capability for finite REW streams
    FFMPEG_CMD="ffmpeg -y -protocol_whitelist file,rtp,udp -analyzeduration 2000000 -probesize 65536 -fflags +genpts -avoid_negative_ts make_zero -i $SDP_FILE -f alsa -acodec pcm_s16le -ac $CHANNELS -ar $SAMPLE_RATE $ALSA_DEVICE"
else
    warning "SDP file not found, using direct RTP (may show 'guessing' warnings)"  
    FFMPEG_CMD="ffmpeg -y -f rtp -analyzeduration 2000000 -probesize 65536 -i rtp://0.0.0.0:$RTP_PORT -f alsa -acodec pcm_s16le -ac $CHANNELS -ar $SAMPLE_RATE $ALSA_DEVICE"
fi

log "Command: $FFMPEG_CMD"
echo ""

# Execute FFmpeg
exec $FFMPEG_CMD
