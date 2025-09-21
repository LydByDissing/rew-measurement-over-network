#!/bin/bash

# Quick test to see what files are being copied during installation

echo "🔍 Testing file installation process..."
echo ""

echo "Files in current directory (rew-receiver-package):"
ls -la | grep -E "(test-|\.sh|\.md)"

echo ""
echo "Simulating install process - files that would be copied:"

TARGET_DIR="/tmp/test-install"
mkdir -p "$TARGET_DIR"

# Copy audio configuration scripts and tools
echo "Basic scripts:"
cp configure-audio-device.sh validate-audio-device.sh test-merus-amp.sh "$TARGET_DIR/" 2>/dev/null && echo "  ✅ Basic scripts copied" || echo "  ❌ Basic scripts failed"

# Copy additional test scripts
echo "Additional test scripts:"
[ -f "test-full-pipeline.sh" ] && cp test-full-pipeline.sh "$TARGET_DIR/" 2>/dev/null && echo "  ✅ test-full-pipeline.sh" || echo "  ❌ test-full-pipeline.sh missing"
[ -f "test-rtp-stream.sh" ] && cp test-rtp-stream.sh "$TARGET_DIR/" 2>/dev/null && echo "  ✅ test-rtp-stream.sh" || echo "  ❌ test-rtp-stream.sh missing"
[ -f "test-confirmed-working.sh" ] && cp test-confirmed-working.sh "$TARGET_DIR/" 2>/dev/null && echo "  ✅ test-confirmed-working.sh" || echo "  ❌ test-confirmed-working.sh missing"

# Copy documentation and configuration files
echo "Documentation:"
[ -f "AUDIO-DEVICE-CONFIG.md" ] && cp AUDIO-DEVICE-CONFIG.md "$TARGET_DIR/" 2>/dev/null && echo "  ✅ AUDIO-DEVICE-CONFIG.md" || echo "  ❌ AUDIO-DEVICE-CONFIG.md missing"
[ -f "WORKING-MERUS-CONFIG.md" ] && cp WORKING-MERUS-CONFIG.md "$TARGET_DIR/" 2>/dev/null && echo "  ✅ WORKING-MERUS-CONFIG.md" || echo "  ❌ WORKING-MERUS-CONFIG.md missing"
[ -f "PIPELINE-VALIDATION-GUIDE.md" ] && cp PIPELINE-VALIDATION-GUIDE.md "$TARGET_DIR/" 2>/dev/null && echo "  ✅ PIPELINE-VALIDATION-GUIDE.md" || echo "  ❌ PIPELINE-VALIDATION-GUIDE.md missing"
[ -f "mediamtx-rtp.yml" ] && cp mediamtx-rtp.yml "$TARGET_DIR/" 2>/dev/null && echo "  ✅ mediamtx-rtp.yml" || echo "  ❌ mediamtx-rtp.yml missing"

echo ""
echo "Files that would be in target directory:"
ls -la "$TARGET_DIR/" | grep -E "(test-|\.sh|\.md|\.yml)"

echo ""
echo "Summary:"
SCRIPT_COUNT=$(find "$TARGET_DIR" -name "test-*.sh" | wc -l)
echo "Test scripts found: $SCRIPT_COUNT"
DOC_COUNT=$(find "$TARGET_DIR" -name "*.md" | wc -l)  
echo "Documentation files found: $DOC_COUNT"

# Cleanup
rm -rf "$TARGET_DIR"
