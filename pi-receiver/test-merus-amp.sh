#!/bin/bash
set -e

# Quick test script for snd_rpi_merus_amp device configuration
# This script demonstrates the workflow for configuring and testing the Merus amplifier

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[MERUS-TEST]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log "🎵 Testing snd_rpi_merus_amp Audio Device Configuration"
echo ""

# Step 1: Configure CamillaDSP for Merus amplifier
log "Step 1: Configuring CamillaDSP for Merus amplifier..."
log "Using working device: hw:CARD=sndrpimerusamp"
if [ -f "configure-audio-device.sh" ]; then
    ./configure-audio-device.sh -d "hw:CARD=sndrpimerusamp"
    if [ $? -eq 0 ]; then
        success "✅ CamillaDSP configured for Merus amplifier"
    else
        error "❌ Failed to configure CamillaDSP"
        exit 1
    fi
else
    error "configure-audio-device.sh not found"
    exit 1
fi

echo ""

# Step 2: Validate the audio device
log "Step 2: Validating Merus amplifier device..."
if [ -f "validate-audio-device.sh" ]; then
    ./validate-audio-device.sh -d "hw:CARD=sndrpimerusamp" -f 1000 -t 3
    echo ""
    
    # Prompt for manual validation
    warning "Did you hear the test tone through the Merus amplifier? (y/n): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        success "✅ Audio validation successful!"
        AUDIO_OK=true
    else
        error "❌ Audio validation failed"
        AUDIO_OK=false
    fi
else
    error "validate-audio-device.sh not found"
    exit 1
fi

echo ""

# Step 3: Show next steps
if [ "$AUDIO_OK" = true ]; then
    log "🎉 Merus Amplifier Configuration Complete!"
    echo ""
    log "Your system is now configured to use the hw:CARD=sndrpimerusamp device."
    log "The CamillaDSP configuration has been updated in camilladsp.yml"
    echo ""
    log "Next steps for MediaMTX integration:"
    log "1. Start CamillaDSP: camilladsp -p 1234 camilladsp.yml"
    log "2. Start MediaMTX: mediamtx mediamtx.yml"
    log "3. Test the complete audio pipeline"
    echo ""
    log "Configuration details:"
    log "• Audio device: hw:CARD=sndrpimerusamp"
    log "• Sample rate: 48000 Hz"
    log "• Channels: 2 (stereo)"
    log "• Format: S32LE (required for Merus amplifier)"
    echo ""
    
    # Show the relevant configuration
    if [ -f "camilladsp.yml" ]; then
        log "Current playback configuration:"
        grep -A 4 "playback:" camilladsp.yml | sed 's/^/  /'
    fi
else
    warning "⚠️  Audio validation failed. Troubleshooting steps:"
    log "1. Check if the Merus amplifier is properly connected"
    log "2. Verify the device is available: cat /proc/asound/cards"
    log "3. Try alternative device names like 'hw:1,0' or 'hw:0,0'"
    log "4. Check ALSA configuration and kernel modules"
    echo ""
    log "Alternative device test:"
    log "./validate-audio-device.sh -d hw:1,0"
    log "./validate-audio-device.sh -d hw:0,0"
    echo ""
    exit 1
fi
