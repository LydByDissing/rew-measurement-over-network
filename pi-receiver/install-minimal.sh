#!/bin/bash
#
# REW Pi Audio Receiver - Zero Compilation Installer
# Uses only Python standard library + aplay (no pip packages, no compilation)
#
# Usage: curl -sSL https://path-to-minimal-install.sh | bash
#

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}REW Pi Audio Receiver - Zero Compilation Installer${NC}"
echo "===================================================="

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

# Check if aplay is available
if ! command -v aplay &> /dev/null; then
    echo -e "${RED}Error: aplay command not found${NC}"
    echo "Installing ALSA utilities..."
    sudo apt-get update -qq
    sudo apt-get install -y alsa-utils
else
    echo "aplay found: $(which aplay)"
fi

echo -e "${GREEN}✓ No compilation needed - using Python standard library only!${NC}"

# Create installation directory
INSTALL_DIR="$HOME/rew-audio-receiver"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Copy minimal receiver script (for local testing)
echo "Copying REW audio receiver (minimal version)..."
if [ -f "$(dirname "$0")/rew_audio_receiver_minimal.py" ]; then
    cp "$(dirname "$0")/rew_audio_receiver_minimal.py" rew_audio_receiver.py
    echo "✓ Copied local file"
else
    echo "Downloading from GitHub..."
    curl -sSL -o rew_audio_receiver.py https://raw.githubusercontent.com/LydByDissing/rew-measurement-over-network/main/pi-receiver/rew_audio_receiver_minimal.py
fi

# Test the script
echo "Testing receiver script..."
if python3 rew_audio_receiver.py --help > /tmp/test_output.log 2>&1; then
    echo -e "${GREEN}✓ Receiver script working${NC}"
else
    echo -e "${RED}✗ Receiver script test failed${NC}"
    echo "Error details:"
    cat /tmp/test_output.log
    echo "Attempting syntax check..."
    python3 -m py_compile rew_audio_receiver.py
    exit 1
fi

# Create systemd service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/rew-audio-receiver.service > /dev/null <<EOF
[Unit]
Description=REW Audio Receiver Service (Minimal)
After=network.target sound.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/rew_audio_receiver.py --verbose
Restart=always
RestartSec=10
Environment=HOME=$HOME

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable rew-audio-receiver
sudo systemctl start rew-audio-receiver

# Wait a moment for service to start
sleep 2

# Check service status
if systemctl is-active --quiet rew-audio-receiver; then
    echo -e "${GREEN}✓ REW Audio Receiver installed and running successfully!${NC}"
    echo
    echo "Service status:"
    systemctl status rew-audio-receiver --no-pager -l
    echo
    echo -e "${GREEN}Installation Summary:${NC}"
    echo "• No compilation or pip packages needed"
    echo "• Uses Python standard library + aplay"
    echo "• Audio receiver listening on port 5004 (RTP)"
    echo "• Status API available on port 8080 (HTTP)"
    echo "• Service will auto-start on boot"
    echo
    echo -e "${YELLOW}Note: No mDNS discovery (requires manual configuration)${NC}"
    echo "Configure your Java client to connect to:"
    echo "  Hostname: $(hostname)"
    echo "  IP: $(hostname -I | awk '{print $1}')"
    echo "  Port: 5004"
    echo
    echo "Check logs with: journalctl -u rew-audio-receiver -f"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "Check logs with: journalctl -u rew-audio-receiver -f"
    exit 1
fi