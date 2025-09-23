#!/bin/bash
#
# Clean REW Audio Receiver Installation Script
# Installs CamillaDSP and RTP/UDP to ALSA bridges
#

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${BLUE}[INSTALL]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

TARGET_DIR="/home/pi/rew-receiver"
CURRENT_DIR="$(pwd)"

log "🎵 Installing REW Audio Receiver..."

# Create target directory
sudo mkdir -p "$TARGET_DIR"
sudo chown pi:pi "$TARGET_DIR"

# Stop any existing services first
log "Stopping existing services..."
sudo systemctl stop camilladsp 2>/dev/null || true
sleep 2

# Copy files
log "Installing binaries and configurations..."
if ! cp camilladsp camilladsp.yml "$TARGET_DIR/" 2>/dev/null; then
    error "Failed to copy binaries. Trying to force stop services..."
    sudo systemctl stop camilladsp 2>/dev/null || true
    sudo pkill -f camilladsp 2>/dev/null || true
    sleep 3

    log "Retrying file copy..."
    cp camilladsp camilladsp.yml "$TARGET_DIR/"
fi

# Copy bridge scripts
log "Installing audio bridge scripts..."
cp rtp-to-alsa.sh udp-to-alsa.sh "$TARGET_DIR/"

# Copy test and configuration tools
log "Installing configuration tools..."
cp test-audio.sh "$TARGET_DIR/" 2>/dev/null || true
cp validate-audio-device.sh "$TARGET_DIR/" 2>/dev/null || true
cp test-merus-amp.sh "$TARGET_DIR/" 2>/dev/null || true

# Set permissions
log "Setting permissions..."
chmod +x "$TARGET_DIR/camilladsp" "$TARGET_DIR"/*.sh 2>/dev/null || true

# Install systemd services
log "Installing systemd services..."
sudo cp camilladsp.service /etc/systemd/system/
sudo cp udp-bridge.service /etc/systemd/system/ 2>/dev/null || true
sudo cp rtp-bridge.service /etc/systemd/system/ 2>/dev/null || true

# Create log directories
log "Creating log directories..."
sudo mkdir -p /var/log/camilladsp
sudo chown pi:pi /var/log/camilladsp

# Reload systemd and enable services
log "Configuring services..."
sudo systemctl daemon-reload

# Enable and start CamillaDSP
log "Starting CamillaDSP service..."
sudo systemctl enable camilladsp
sudo systemctl start camilladsp

# Check service status
CAMILLADSP_ACTIVE=$(systemctl is-active --quiet camilladsp && echo "true" || echo "false")

if [ "$CAMILLADSP_ACTIVE" = "true" ]; then
    success "🎉 REW Audio Receiver installed successfully!"
    log ""
    log "Core Components:"
    log "• CamillaDSP: Running for audio processing"
    log "• RTP Bridge: $TARGET_DIR/rtp-to-alsa.sh"  
    log "• UDP Bridge: $TARGET_DIR/udp-to-alsa.sh"
    log ""
    log "Status:"
    sudo systemctl status camilladsp --no-pager -l
    log ""
    log "API Access:"
    log "• CamillaDSP API: http://$(hostname -I | awk '{print $1}'):1234"
    log ""
    log "Audio Streaming:"
    log "• Use bridge scripts to receive RTP/UDP audio streams"
    log "• Configure in CamillaDSP for processing and output"
    log ""
    log "Management Commands:"
    log "• View CamillaDSP logs: sudo journalctl -u camilladsp -f"
    log "• Restart CamillaDSP: sudo systemctl restart camilladsp"
    log "• Stop CamillaDSP: sudo systemctl stop camilladsp"
    log ""
    log "Audio Bridge Usage:"
    log "• RTP Bridge: $TARGET_DIR/rtp-to-alsa.sh --port 8000"
    log "• UDP Bridge: $TARGET_DIR/udp-to-alsa.sh --port 8000"
    log ""
    log "Bridge Services (optional - alternative to manual scripts):"
    log "• Start UDP bridge service: sudo systemctl start udp-bridge"
    log "• Start RTP bridge service: sudo systemctl start rtp-bridge"
    log "• Enable on boot: sudo systemctl enable udp-bridge rtp-bridge"
    log "• Check status: sudo systemctl status udp-bridge rtp-bridge"
    log "• View logs: sudo journalctl -u udp-bridge -u rtp-bridge -f"
else
    error "❌ CamillaDSP installation failed"
    echo "Check logs: sudo journalctl -u camilladsp"
    exit 1
fi
