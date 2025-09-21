#!/bin/bash

# Quick test to verify S32_LE format works with Merus amplifier
echo "🎵 Testing Merus Amplifier with S32_LE format"
echo "Device: usbstream:CARD=sndrpimerusamp"
echo "Format: S32_LE (32-bit signed little-endian)"
echo ""

echo "🔍 Checking if device supports S32_LE format..."
if aplay -D "usbstream:CARD=sndrpimerusamp" --dump-hw-params /dev/zero 2>/dev/null | grep -q "S32_LE"; then
    echo "✅ Device supports S32_LE format"
else
    echo "⚠️  Device format support check failed (this might be normal)"
fi

echo ""
echo "🔊 Testing with S32_LE format..."
echo "You should hear a clear 1000Hz tone for 3 seconds..."
echo ""

# Test with S32_LE format
if speaker-test -D "usbstream:CARD=sndrpimerusamp" -c 2 -r 48000 -F S32_LE -t sine -f 1000 -l 1 -p 3000; then
    echo ""
    echo "✅ S32_LE format test completed!"
    echo ""
    echo "If you heard clear audio, the configuration is correct."
    echo "You can now run: ./test-merus-amp.sh"
else
    echo ""
    echo "❌ S32_LE format test failed"
    echo ""
    echo "Let's try some alternatives..."
    
    # Try S16_LE as fallback
    echo "🔄 Trying S16_LE format as fallback..."
    if speaker-test -D "usbstream:CARD=sndrpimerusamp" -c 2 -r 48000 -F S16_LE -t sine -f 1000 -l 1 -p 2000; then
        echo "✅ S16_LE format works as fallback"
        echo "⚠️  You may need to update the CamillaDSP template to use S16_LE instead"
    else
        echo "❌ Both S32_LE and S16_LE formats failed"
        echo "Please check device connection and ALSA configuration"
    fi
fi

echo ""
echo "💡 Next steps:"
echo "1. If S32_LE worked: ./test-merus-amp.sh"
echo "2. If only S16_LE worked: Update camilladsp.yml.template format to S16LE"
echo "3. Check CamillaDSP config: ./configure-audio-device.sh -d \"usbstream:CARD=sndrpimerusamp\""
