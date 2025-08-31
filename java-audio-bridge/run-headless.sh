#!/bin/bash

# REW Network Audio Bridge - Headless Mode Runner
# Usage: ./run-headless.sh <PI_IP_ADDRESS> [PORT]

set -e

if [ $# -eq 0 ]; then
    echo "REW Network Audio Bridge - Headless Mode"
    echo "Usage: $0 <PI_IP_ADDRESS> [PORT]"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100"
    echo "  $0 10.0.0.50 5005"
    echo ""
    echo "This will start the audio bridge in headless mode and connect"
    echo "directly to the specified Pi device for audio streaming."
    exit 1
fi

PI_IP="$1"
PI_PORT="${2:-5004}"

echo "Starting REW Network Audio Bridge in headless mode..."
echo "Target Pi: $PI_IP:$PI_PORT"
echo ""

# Build the application if needed
if [ ! -f target/classes/com/lydbydissing/AudioBridgeMain.class ]; then
    echo "Building application..."
    mvn compile -q
fi

# Run in headless mode
exec mvn exec:java -Dexec.mainClass="com.lydbydissing.AudioBridgeMain" \
                   -Dexec.args="--headless --target $PI_IP --port $PI_PORT" \
                   -q