#!/bin/sh
echo "🔍 MediaMTX Container Architecture Test"
echo "======================================"
echo "Architecture: $(uname -m)"
echo ""

echo "📡 Testing MediaMTX binary..."
if mediamtx --help >/dev/null 2>&1; then
    echo "✅ MediaMTX binary is ARM-compatible"
    mediamtx --version
else
    echo "❌ MediaMTX binary failed"
    exit 1
fi

echo ""
echo "🎚️  Testing CamillaDSP binary..."
if camilladsp --help >/dev/null 2>&1; then
    echo "✅ CamillaDSP binary is ARM-compatible"
    camilladsp --version 2>/dev/null || echo "CamillaDSP version check completed"
else
    echo "❌ CamillaDSP binary failed"
    exit 1
fi

echo ""
echo "🔊 Testing ALSA setup..."
if [ -d /proc/asound ]; then
    echo "✅ ALSA proc filesystem available"
else
    echo "⚠️  ALSA proc filesystem not available (expected in test)"
fi
