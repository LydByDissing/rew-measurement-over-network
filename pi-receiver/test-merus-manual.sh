#!/bin/bash

# Quick manual test for the corrected Merus amplifier device name
# Based on the aplay -L output showing: usbstream:CARD=sndrpimerusamp

echo "🎵 Testing Merus Amplifier with correct device name"
echo "Device: hw:CARD=sndrpimerusamp"
echo ""

echo "🔍 First, let's see what ALSA devices are available:"
echo "Running: aplay -L | grep -i merus"
aplay -L | grep -i merus || echo "No Merus device found in aplay -L"
echo ""

echo "📋 All available devices:"
aplay -L | head -10
echo ""

echo "🔊 Testing speaker output with correct device name..."
echo "Using S32_LE format (required for Merus amplifier)..."
echo "You should hear a 1000Hz tone for 3 seconds..."
echo ""

# Test the corrected device name with S32_LE format
speaker-test -D "hw:CARD=sndrpimerusamp" -c 2 -r 48000 -F S32_LE -t sine -f 1000 -l 1 -p 3000

echo ""
echo "Did you hear the test tone? If yes, the device name is correct!"
echo "If not, let's try some alternatives..."
echo ""

# Try some common alternatives based on the aplay -L output pattern
echo "🔄 Trying alternative device names..."
for device in "hw:CARD=sndrpimerusamp" "plughw:CARD=sndrpimerusamp" "default:CARD=sndrpimerusamp"; do
    echo "Testing: $device"
    if speaker-test -D "$device" -c 2 -r 48000 -F S32_LE -t sine -f 1000 -l 1 -p 1000 2>/dev/null; then
        echo "✅ Success with: $device"
        echo "Use this device name: $device"
        break
    else
        echo "❌ Failed with: $device"
    fi
done

echo ""
echo "💡 To use the working device name with the configuration scripts:"
echo "   ./configure-audio-device.sh -d \"WORKING_DEVICE_NAME\""
echo "   ./validate-audio-device.sh -d \"WORKING_DEVICE_NAME\""
