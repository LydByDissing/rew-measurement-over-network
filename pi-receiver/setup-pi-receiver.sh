#!/bin/bash

# REW Pi Receiver Setup Script with Python 3.12 and venv
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[PI-SETUP]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

fail() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "🥧 REW Pi Receiver Setup - Python 3.12 + venv"
echo "==============================================="

# Check if we're on a Pi or compatible system
if command -v raspi-config &> /dev/null; then
    log "Running on Raspberry Pi"
    PI_DETECTED=true
else
    warn "Not running on Raspberry Pi, will set up for compatible Linux system"
    PI_DETECTED=false
fi

# Check for Python 3.12
log "Checking Python 3.12 availability..."
if command -v python3.12 &> /dev/null; then
    PYTHON_CMD="python3.12"
    success "Python 3.12 found: $(python3.12 --version)"
elif command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | grep -o "3\.[0-9][0-9]*")
    if [[ "$PYTHON_VERSION" == "3.12" ]]; then
        PYTHON_CMD="python3"
        success "Python 3.12 found as python3: $(python3 --version)"
    else
        warn "Python 3.12 not found, using Python $PYTHON_VERSION"
        PYTHON_CMD="python3"
    fi
else
    fail "No Python 3 installation found"
fi

# Create virtual environment
VENV_DIR="$HOME/.rew-pi-venv"
log "Setting up Python virtual environment at $VENV_DIR"

if [ -d "$VENV_DIR" ]; then
    warn "Virtual environment already exists, removing old one..."
    rm -rf "$VENV_DIR"
fi

$PYTHON_CMD -m venv "$VENV_DIR"
success "Virtual environment created"

# Activate virtual environment
source "$VENV_DIR/bin/activate"
log "Virtual environment activated"

# Upgrade pip
log "Upgrading pip..."
pip install --upgrade pip

# Install system dependencies (if we have sudo access)
if command -v apt-get &> /dev/null && [ "$EUID" -eq 0 ]; then
    log "Installing system dependencies..."
    apt-get update
    apt-get install -y libasound2-dev portaudio19-dev python3-dev gcc
elif command -v apt-get &> /dev/null; then
    warn "Not running as root, you may need to install system dependencies manually:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y libasound2-dev portaudio19-dev python3-dev gcc"
fi

# Install Python dependencies with better error handling
log "Installing Python dependencies..."

# Install core dependencies one by one for better error reporting
DEPS=("wheel" "setuptools" "zeroconf>=0.39.0" "pyalsaaudio>=0.10.0")

for dep in "${DEPS[@]}"; do
    log "Installing $dep..."
    if pip install "$dep"; then
        success "$dep installed successfully"
    else
        warn "Failed to install $dep, trying alternative approach..."
        # Try with --user flag as fallback
        pip install --user "$dep" || warn "Failed to install $dep even with --user"
    fi
done

# Verify installations
log "Verifying installations..."
python -c "import zeroconf; print('✓ zeroconf version:', zeroconf.__version__)" || warn "zeroconf import failed"
python -c "import alsaaudio; print('✓ pyalsaaudio version:', alsaaudio.__version__)" || warn "pyalsaaudio import failed"

# Create activation script
ACTIVATE_SCRIPT="$HOME/.rew-pi-activate"
cat > "$ACTIVATE_SCRIPT" << 'EOF'
#!/bin/bash
# REW Pi Receiver Environment Activation Script
source "$HOME/.rew-pi-venv/bin/activate"
echo "🥧 REW Pi Receiver environment activated"
echo "Python: $(python --version)"
echo "Location: $(which python)"
EOF

chmod +x "$ACTIVATE_SCRIPT"
success "Activation script created at $ACTIVATE_SCRIPT"

# Create startup script
STARTUP_SCRIPT="$HOME/.rew-pi-start"
cat > "$STARTUP_SCRIPT" << 'EOF'
#!/bin/bash
# REW Pi Receiver Startup Script
set -e

# Activate virtual environment
source "$HOME/.rew-pi-venv/bin/activate"

# Change to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_SCRIPT="$SCRIPT_DIR/rew_audio_receiver.py"

if [ ! -f "$PI_SCRIPT" ]; then
    # Try to find the script
    if [ -f "$(dirname "$0")/rew_audio_receiver.py" ]; then
        PI_SCRIPT="$(dirname "$0")/rew_audio_receiver.py"
    elif [ -f "rew_audio_receiver.py" ]; then
        PI_SCRIPT="rew_audio_receiver.py"
    else
        echo "❌ Could not find rew_audio_receiver.py"
        exit 1
    fi
fi

echo "🚀 Starting REW Pi Audio Receiver..."
echo "Script: $PI_SCRIPT"
echo "Python: $(python --version)"

# Start with default arguments or passed arguments
python "$PI_SCRIPT" "${@:---verbose}"
EOF

chmod +x "$STARTUP_SCRIPT"
success "Startup script created at $STARTUP_SCRIPT"

# Create systemd service file (if we have systemd and permissions)
if command -v systemctl &> /dev/null && [ "$EUID" -eq 0 ]; then
    log "Creating systemd service..."
    
    SERVICE_FILE="/etc/systemd/system/rew-pi-receiver.service"
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=REW Pi Audio Receiver
After=network.target sound.target
Wants=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$(pwd)
Environment=HOME=$HOME
ExecStart=$STARTUP_SCRIPT --verbose
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    success "Systemd service created: rew-pi-receiver.service"
    echo "  Enable with: sudo systemctl enable rew-pi-receiver"
    echo "  Start with:  sudo systemctl start rew-pi-receiver"
    echo "  Status with: sudo systemctl status rew-pi-receiver"
fi

echo
echo "==============================================="
echo "REW Pi Receiver Setup Complete!"
echo "==============================================="
echo
echo "✅ Virtual environment: $VENV_DIR"
echo "✅ Activation script: $ACTIVATE_SCRIPT"
echo "✅ Startup script: $STARTUP_SCRIPT"
echo
echo "Quick Start Commands:"
echo "1. Activate environment:  source $ACTIVATE_SCRIPT"
echo "2. Start receiver:        $STARTUP_SCRIPT"
echo "3. Start with options:    $STARTUP_SCRIPT --device hw:1,0 --verbose"
echo
echo "Manual Usage:"
echo "  source $VENV_DIR/bin/activate"
echo "  python rew_audio_receiver.py --help"
echo
echo "The receiver will:"
echo "• Listen for RTP audio on port 5004"
echo "• Provide HTTP status on port 8080"  
echo "• Advertise via mDNS as 'REW-Pi-[hostname]'"
echo "• Output audio to ALSA default device"
echo "==============================================="