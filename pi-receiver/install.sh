#!/bin/bash
#
# REW Pi Audio Receiver - One-click installer
# Downloads and installs the Pi receiver service without building from source
#
# Usage: curl -sSL https://raw.githubusercontent.com/LydByDissing/rew-measurement-over-network/main/pi-receiver/install.sh | bash
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}REW Pi Audio Receiver Installer${NC}"
echo "================================="

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo -e "${YELLOW}Warning: This doesn't appear to be a Raspberry Pi${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
echo "Python version: $PYTHON_VERSION"

if ! python3 -c 'import sys; exit(0 if sys.version_info >= (3, 7) else 1)' 2>/dev/null; then
    echo -e "${RED}Error: Python 3.7+ required. Found Python $PYTHON_VERSION${NC}"
    exit 1
fi

# Install system dependencies (using pre-built packages only)
echo "Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y python3-alsaaudio python3-zeroconf python3-setuptools

echo "All dependencies installed from system packages - no compilation needed!"

# Create installation directory
INSTALL_DIR="$HOME/rew-audio-receiver"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download receiver script
echo "Downloading REW audio receiver..."
curl -sSL -o rew_audio_receiver.py https://raw.githubusercontent.com/LydByDissing/rew-measurement-over-network/main/pi-receiver/rew_audio_receiver.py

# Create systemd service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/rew-audio-receiver.service > /dev/null <<EOF
[Unit]
Description=REW Audio Receiver Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/rew_audio_receiver.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable rew-audio-receiver
sudo systemctl start rew-audio-receiver

# Check service status
if systemctl is-active --quiet rew-audio-receiver; then
    echo -e "${GREEN}✓ REW Audio Receiver installed and running successfully!${NC}"
    echo
    echo "Service status:"
    systemctl status rew-audio-receiver --no-pager -l
    echo
    echo "The Pi is now advertising as a REW audio receiver on the network."
    echo "You can check logs with: journalctl -u rew-audio-receiver -f"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "Check logs with: journalctl -u rew-audio-receiver -f"
    exit 1
fi