#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INSTALL]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

TARGET_DIR="/home/pi/rew-receiver"
CURRENT_DIR="$(pwd)"

log "🎵 Installing REW MediaMTX Audio Receiver..."

# Create target directory
sudo mkdir -p "$TARGET_DIR"
sudo chown pi:pi "$TARGET_DIR"

# Copy files
log "Installing binaries and configurations..."
cp mediamtx camilladsp mediamtx.yml camilladsp.yml "$TARGET_DIR/"
chmod +x "$TARGET_DIR/mediamtx" "$TARGET_DIR/camilladsp"

# Install systemd services
log "Installing systemd services..."
sudo cp mediamtx.service camilladsp.service /etc/systemd/system/
sudo systemctl daemon-reload

# Setup ALSA loopback
log "Configuring ALSA loopback device..."
sudo modprobe snd-aloop || true
echo "snd-aloop" | sudo tee -a /etc/modules-load.d/modules.conf > /dev/null || true

# Create log directories
sudo mkdir -p /var/log/mediamtx
sudo chown pi:pi /var/log/mediamtx

# Stop any existing services
sudo systemctl stop mediamtx camilladsp 2>/dev/null || true

# Enable and start services
log "Starting services..."
sudo systemctl enable mediamtx camilladsp
sudo systemctl start mediamtx
sleep 2
sudo systemctl start camilladsp

# Check status
if systemctl is-active --quiet mediamtx && systemctl is-active --quiet camilladsp; then
    success "🎉 REW MediaMTX Audio Receiver installed successfully!"
    echo
    echo "📊 Service Status:"
    sudo systemctl status mediamtx --no-pager -l
    sudo systemctl status camilladsp --no-pager -l
    echo
    echo "🔗 Access Points:"
    echo "• MediaMTX API: http://$(hostname -I | awk '{print $1}'):9997"
    echo "• CamillaDSP API: http://$(hostname -I | awk '{print $1}'):1234"
    echo "• RTSP Stream: rtsp://$(hostname -I | awk '{print $1}'):8554/rew_audio"
    echo "• RTP Input: rtp://$(hostname -I | awk '{print $1}'):5004"
    echo
    echo "🔧 Commands:"
    echo "• View logs: sudo journalctl -u mediamtx -u camilladsp -f"
    echo "• Restart: sudo systemctl restart mediamtx camilladsp"
    echo "• Stop: sudo systemctl stop mediamtx camilladsp"
else
    error "❌ Service installation failed"
    echo "Check logs: sudo journalctl -u mediamtx -u camilladsp"
    exit 1
fi
