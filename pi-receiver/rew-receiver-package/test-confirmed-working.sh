#!/bin/bash

# Test script using the confirmed working combination
# Based on user-verified command: speaker-test -D "hw:CARD=sndrpimerusamp" -c 2 -r 48000 -t sine -f 1000 -l 1 -F S32_LE

echo "🎵 Testing Merus Amplifier with CONFIRMED WORKING configuration"
echo "Device: hw:CARD=sndrpimerusamp"
echo "Format: S32_LE"
echo "Command: speaker-test -D \"hw:CARD=sndrpimerusamp\" -c 2 -r 48000 -t sine -f 1000 -l 1 -F S32_LE"
echo ""

echo "🔊 Running confirmed working test..."
echo "You should hear a clear 1000Hz tone for about 1 second..."
echo ""

# Execute the exact working command
speaker-test -D "hw:CARD=sndrpimerusamp" -c 2 -r 48000 -t sine -f 1000 -l 1 -F S32_LE

echo ""
if [ $? -eq 0 ]; then
    echo "✅ SUCCESS! The confirmed configuration works."
    echo ""
    echo "🎯 Ready to configure CamillaDSP:"
    echo "   ./configure-audio-device.sh -d \"hw:CARD=sndrpimerusamp\""
    echo ""
    echo "🎯 Ready to run full test:"
    echo "   ./test-merus-amp.sh"
else
    echo "❌ Test failed. Please check:"
    echo "1. Merus amplifier is connected"
    echo "2. ALSA device is available: aplay -l"
    echo "3. Audio permissions are correct"
fi

echo ""
echo "Configuration summary:"
echo "• Device: hw:CARD=sndrpimerusamp"
echo "• Sample rate: 48000 Hz"
echo "• Channels: 2 (stereo)"
echo "• Format: S32_LE"
echo "• Test frequency: 1000 Hz"
