#!/bin/bash
#
# REW Network Audio Bridge Startup Script
# This script handles JavaFX module path setup for running the audio bridge
#
# Usage: ./run.sh

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JAR_FILE="$SCRIPT_DIR/target/audio-bridge-0.1.0-SNAPSHOT.jar"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}REW Network Audio Bridge${NC}"
echo "========================"

# Check if JAR file exists
if [ ! -f "$JAR_FILE" ]; then
    echo -e "${RED}Error: JAR file not found at $JAR_FILE${NC}"
    echo "Please run 'mvn clean package' first."
    exit 1
fi

# Check Java version
JAVA_VERSION_OUTPUT=$(java -version 2>&1 | head -n 1)
JAVA_VERSION=$(echo "$JAVA_VERSION_OUTPUT" | grep -oP '(?<=version ")[^"]*' | cut -d'.' -f1)

# For Java 9+, the version format changed
if [[ "$JAVA_VERSION_OUTPUT" == *"1.8"* ]]; then
    JAVA_VERSION=8
fi

if [ "$JAVA_VERSION" -lt 21 ]; then
    echo -e "${RED}Error: Java 21 LTS or later is required. Found Java $JAVA_VERSION${NC}"
    echo "Please install Java 21 LTS from:"
    echo "  - OpenJDK: https://jdk.java.net/21/"
    echo "  - Eclipse Temurin: https://adoptium.net/temurin/releases/?version=21"
    exit 1
fi

echo "Java version: $JAVA_VERSION"

echo -e "${GREEN}Starting application...${NC}"

# Check if we're on a headless system
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    echo "Display detected: $DISPLAY$WAYLAND_DISPLAY"
else
    echo -e "${YELLOW}Warning: No display detected. GUI may not work.${NC}"
fi

# Run the application with JavaFX software rendering fallback
# This avoids OpenGL/graphics driver issues on some Linux systems
java \
    -Djava.awt.headless=false \
    -Dprism.order=sw \
    -Dprism.verbose=false \
    -jar "$JAR_FILE" "$@"