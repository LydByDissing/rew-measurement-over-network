#!/bin/bash
set -e

echo "🎵 Starting REW Audio Receiver..."

# Configure audio device (default to hw:0,0 if not specified)
export AUDIO_DEVICE="${AUDIO_DEVICE:-hw:0,0}"
echo "🔧 Audio device: $AUDIO_DEVICE"

# Check if we're running in Docker
if [ -f /.dockerenv ]; then
    echo "🐳 Running in Docker container"
    # Use full paths in Docker
    CAMILLADSP_BIN="camilladsp"
    CONFIG_DIR="/app/config"
else
    echo "🏠 Running natively"
    # Use local paths for native execution
    CAMILLADSP_BIN="./camilladsp"
    CONFIG_DIR="."
fi

# Generate CamillaDSP configuration from template if template exists
TEMPLATE_FILE="$CONFIG_DIR/camilladsp.yml.template"
CONFIG_FILE="$CONFIG_DIR/camilladsp.yml"

if [ -f "$TEMPLATE_FILE" ]; then
    echo "🎚️  Generating CamillaDSP configuration for audio device: $AUDIO_DEVICE"
    envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"
elif [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  No CamillaDSP configuration found"
    exit 1
fi

# Start CamillaDSP
echo "🎚️  Starting CamillaDSP..."
$CAMILLADSP_BIN -p 1234 "$CONFIG_FILE" &
CAMILLADSP_PID=$!

# Give it a moment to start
sleep 2
if kill -0 $CAMILLADSP_PID 2>/dev/null; then
    echo "✅ CamillaDSP started successfully"
else
    echo "❌ CamillaDSP failed to start"
    exit 1
fi

echo "✅ REW Audio Receiver ready!"
echo "📊 Access Points:"
echo "   • CamillaDSP API: http://localhost:1234"
echo ""
echo "🎯 Audio Bridges:"
echo "   • Start RTP bridge: ./rtp-to-alsa.sh --port 8000"
echo "   • Start UDP bridge: ./udp-to-alsa.sh --port 8000"

# Function to handle shutdown
shutdown() {
    echo "🛑 Shutting down CamillaDSP..."
    kill $CAMILLADSP_PID 2>/dev/null || true
    wait $CAMILLADSP_PID 2>/dev/null || true
    exit 0
}

# Handle signals
trap shutdown TERM INT

# Wait for CamillaDSP
wait $CAMILLADSP_PID
