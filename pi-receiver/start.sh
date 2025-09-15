#!/bin/sh
set -e

echo "🎵 Starting REW MediaMTX Audio Receiver..."

# Start MediaMTX in background
echo "📡 Starting MediaMTX..."
mediamtx /app/config/mediamtx.yml &
MEDIAMTX_PID=$!

# Give MediaMTX time to start
sleep 3

# Start CamillaDSP (optional - may fail on some platforms)
echo "🎚️  Starting CamillaDSP..."
camilladsp -p 1234 /app/config/camilladsp.yml &
CAMILLADSP_PID=$!
# Give it a moment to potentially crash
sleep 1
if kill -0 $CAMILLADSP_PID 2>/dev/null; then
    echo "✅ CamillaDSP started successfully"
else
    echo "⚠️  CamillaDSP failed to start (continuing without audio processing)"
    CAMILLADSP_PID=""
fi

echo "✅ MediaMTX started successfully!"
echo "📊 Access Points:"
echo "   • MediaMTX API: http://localhost:9997"  
echo "   • CamillaDSP API: http://localhost:1234"
echo "   • RTSP Stream: rtsp://localhost:8554/"
echo "   • RTP Input: Send to port 5004"

# Function to handle shutdown
shutdown() {
    echo "🛑 Shutting down services..."
    kill $MEDIAMTX_PID 2>/dev/null || true
    [ -n "$CAMILLADSP_PID" ] && kill $CAMILLADSP_PID 2>/dev/null || true
    wait
    exit 0
}

# Handle signals
trap shutdown TERM INT

# Wait for both services (MediaMTX is primary)
wait $MEDIAMTX_PID