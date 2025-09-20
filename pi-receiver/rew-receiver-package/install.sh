#!/bin/bash
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

log "🎵 Installing REW MediaMTX Audio Receiver..."

# Create target directory
sudo mkdir -p "$TARGET_DIR"
sudo chown pi:pi "$TARGET_DIR"

# Stop any existing services first to free up binaries
log "Stopping existing services..."
sudo systemctl stop mediamtx camilladsp 2>/dev/null || true
sleep 2

# Copy files
log "Installing binaries and configurations..."
if ! cp mediamtx camilladsp mediamtx.yml camilladsp.yml "$TARGET_DIR/" 2>/dev/null; then
    error "Failed to copy binaries. Trying to force stop services and kill processes..."
    sudo systemctl stop mediamtx camilladsp 2>/dev/null || true
    sudo pkill -f mediamtx 2>/dev/null || true
    sudo pkill -f camilladsp 2>/dev/null || true
    sleep 3

    log "Retrying file copy..."
    cp mediamtx camilladsp mediamtx.yml camilladsp.yml "$TARGET_DIR/"
fi
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

# Check ALSA device configuration and select appropriate config
log "Checking ALSA device configuration..."

# Check if loopback device is available
if grep -q "Loopback" /proc/asound/cards 2>/dev/null; then
    success "ALSA Loopback device detected"

    # Check if any processes are using audio devices
    if pgrep -f "pulseaudio\|jackd" >/dev/null 2>&1; then
        warning "Audio processes detected, stopping them..."
        sudo pkill pulseaudio 2>/dev/null || true
        sudo pkill jackd 2>/dev/null || true
        sleep 1
    fi
else
    warning "ALSA Loopback device not found, using fallback configuration"
    if [ -f "$TARGET_DIR/camilladsp-fallback.yml" ]; then
        log "Switching to fallback configuration..."
        cp "$TARGET_DIR/camilladsp-fallback.yml" "$TARGET_DIR/camilladsp.yml"
    fi
fi

# Enable and start services
log "Starting services..."
sudo systemctl enable mediamtx
sudo systemctl start mediamtx
sleep 3

# Disable CamillaDSP temporarily due to ALSA enumeration issues
warning "Disabling CamillaDSP due to persistent ALSA enumeration issues"
warning "CamillaDSP service will be installed but not started automatically"
warning "MediaMTX will handle audio streaming without DSP processing for now"

# Install but don't enable CamillaDSP service
sudo systemctl disable camilladsp 2>/dev/null || true
sudo systemctl stop camilladsp 2>/dev/null || true

log "CamillaDSP is available but disabled. To troubleshoot later:"
log "• Check ALSA devices: cat /proc/asound/cards"
log "• Try manual start: sudo systemctl start camilladsp"
log "• View logs: sudo journalctl -u camilladsp -f"

# Check final status
MEDIAMTX_ACTIVE=$(systemctl is-active --quiet mediamtx && echo "true" || echo "false")
CAMILLADSP_ENABLED=$(systemctl is-enabled camilladsp 2>/dev/null | grep -q "enabled" && echo "true" || echo "false")

if [ "$MEDIAMTX_ACTIVE" = "true" ]; then
    success "🎉 REW MediaMTX Audio Receiver installed successfully!"
    warning "⚠️ CamillaDSP is installed but disabled due to ALSA issues"
    warning "Audio streaming works via MediaMTX without DSP processing"

    echo
    echo "📊 Service Status:"
    sudo systemctl status mediamtx --no-pager -l

    echo
    echo "🔗 Access Points:"
    echo "• MediaMTX API: http://$(hostname -I | awk '{print $1}'):9997"
    echo "• RTSP Stream: rtsp://$(hostname -I | awk '{print $1}'):8554/stream-name"
    echo "• Publish to: MediaMTX via RTSP/RTMP/WebRTC"
    echo
    echo "🔧 Commands:"
    echo "• View MediaMTX logs: sudo journalctl -u mediamtx -f"
    echo "• Restart MediaMTX: sudo systemctl restart mediamtx"
    echo "• Stop MediaMTX: sudo systemctl stop mediamtx"
    echo
    warning "🔧 CamillaDSP Troubleshooting (when ready):"
    warning "• Check ALSA devices: cat /proc/asound/cards"
    warning "• Check CamillaDSP logs: sudo journalctl -u camilladsp -f"
    warning "• Try manual start: sudo systemctl start camilladsp"
    warning "• Check config: cat $TARGET_DIR/camilladsp.yml"
else
    error "❌ MediaMTX installation failed"
    echo "Check logs: sudo journalctl -u mediamtx"
    exit 1
fi
