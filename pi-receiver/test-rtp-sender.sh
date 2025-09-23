#!/bin/bash

# Test RTP Sender - Properly configured to match SDP file
# This eliminates "guessing" warnings on the receiver

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[RTP-SENDER]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Configuration
PI_IP="${1:-192.168.1.254}"
RTP_PORT="${2:-5004}"
DURATION="${3:-5}"
FREQUENCY="${4:-1000}"

log "🎵 Testing RTP Audio Stream to Pi"
log "Target: $PI_IP:$RTP_PORT"
log "Duration: ${DURATION}s"
log "Frequency: ${FREQUENCY}Hz"
echo ""

# This FFmpeg command is precisely configured to match the SDP file
# Payload type 10 = L16/48000/2 (16-bit linear PCM, 48kHz, 2 channels)
FFMPEG_CMD="ffmpeg -f lavfi -i \"sine=frequency=$FREQUENCY:duration=$DURATION\" \
-ar 48000 -ac 2 -acodec pcm_s16le \
-f rtp -payload_type 10 -pkt_size 1200 \
rtp://$PI_IP:$RTP_PORT"

log "Command: $FFMPEG_CMD"
echo ""

success "Starting RTP stream..."
eval $FFMPEG_CMD

echo ""
success "✅ RTP stream completed!"
log "Check Pi receiver logs for 'Guessing' warnings - they should be gone!"
