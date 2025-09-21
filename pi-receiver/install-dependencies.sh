#!/bin/bash
set -e

# Install dependencies for REW MediaMTX Audio Receiver
# This script installs packages needed for audio testing and RTP streaming

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[DEPS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

log "🔧 Installing dependencies for REW MediaMTX Audio Receiver..."

# Update package lists
log "Updating package lists..."
sudo apt-get update

# Install essential audio and media tools
log "Installing audio and media tools..."
PACKAGES=(
    "ffmpeg"                # For RTP stream generation and testing
    "alsa-utils"           # ALSA audio utilities (aplay, speaker-test, etc.)
    "curl"                 # For API testing and downloads
    "wget"                 # For downloads
    "netcat-openbsd"       # For network testing (nc command)
    "pulseaudio-utils"     # PulseAudio utilities
    "gettext-base"         # For envsubst command (template processing)
    "jq"                   # JSON processing for API testing
)

# Install packages with error handling
for package in "${PACKAGES[@]}"; do
    log "Installing $package..."
    if sudo apt-get install -y "$package"; then
        success "✅ $package installed successfully"
    else
        warning "⚠️  Failed to install $package (might already be installed)"
    fi
done

# Verify critical installations
log "Verifying installations..."

# Check ffmpeg
if command -v ffmpeg >/dev/null 2>&1; then
    success "✅ ffmpeg is available"
    ffmpeg_version=$(ffmpeg -version 2>/dev/null | head -1)
    log "   $ffmpeg_version"
else
    error "❌ ffmpeg not found"
fi

# Check ALSA tools
if command -v aplay >/dev/null 2>&1 && command -v speaker-test >/dev/null 2>&1; then
    success "✅ ALSA utilities are available"
else
    error "❌ ALSA utilities not found"
fi

# Check envsubst
if command -v envsubst >/dev/null 2>&1; then
    success "✅ envsubst is available"
else
    error "❌ envsubst not found (needed for configuration templates)"
fi

# Check curl
if command -v curl >/dev/null 2>&1; then
    success "✅ curl is available"
else
    error "❌ curl not found"
fi

# Check netcat
if command -v nc >/dev/null 2>&1; then
    success "✅ netcat is available"
else
    warning "⚠️  netcat not found (network testing may be limited)"
fi

# Check jq
if command -v jq >/dev/null 2>&1; then
    success "✅ jq is available"
else
    warning "⚠️  jq not found (JSON processing may be limited)"
fi

echo ""
log "🎵 Dependency installation completed!"
echo ""
log "Available tools for testing:"
log "• ffmpeg - RTP stream generation and media processing"
log "• speaker-test - Direct audio device testing"
log "• aplay - Audio playback testing"
log "• curl - API endpoint testing"
log "• envsubst - Configuration template processing"
echo ""
log "Next steps:"
log "1. Test audio device: speaker-test -D \"hw:CARD=sndrpimerusamp\" -c 2 -r 48000 -F S32_LE -t sine -f 1000 -l 1"
log "2. Test Merus amp: ./test-merus-amp.sh"
log "3. Test full pipeline: ./test-full-pipeline.sh"
log "4. Test RTP streaming: ./test-rtp-stream.sh"
