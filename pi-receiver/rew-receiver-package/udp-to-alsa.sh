#!/bin/bash

# UDP to ALSA Bridge (simpler alternative to RTP)
# Sometimes more reliable than RTP for local audio streaming

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[UDP-BRIDGE]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Configuration
UDP_PORT="${UDP_PORT:-8000}"
ALSA_DEVICE="${ALSA_DEVICE:-plughw:CARD=Loopback,DEV=0}"
SAMPLE_RATE="${SAMPLE_RATE:-48000}"
CHANNELS="${CHANNELS:-2}"

log "🎵 Starting UDP to ALSA bridge..."
log "UDP Port: $UDP_PORT"
log "ALSA Device: $ALSA_DEVICE"
log "Sample Rate: $SAMPLE_RATE Hz"
log "Channels: $CHANNELS"

# Start UDP audio receiver with proper buffering and format
FFMPEG_CMD="ffmpeg -y -f s16le -ar $SAMPLE_RATE -ac $CHANNELS -i udp://0.0.0.0:$UDP_PORT?fifo_size=1000000&overrun_nonfatal=1 -f alsa -acodec pcm_s16le -ar $SAMPLE_RATE -ac $CHANNELS $ALSA_DEVICE"

log "Command: $FFMPEG_CMD"
echo ""

exec $FFMPEG_CMD
