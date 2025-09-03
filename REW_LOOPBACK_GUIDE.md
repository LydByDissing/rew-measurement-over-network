# REW Loopback Device Manager Guide

The `rew-loopback` script is a comprehensive tool for managing PulseAudio virtual devices specifically designed for REW (Room EQ Wizard) integration. It creates a virtual audio sink that allows REW to output audio while simultaneously providing access to that audio stream for network streaming or recording.

## 🎯 Purpose

REW requires an audio output device to generate measurement signals. The `rew-loopback` script creates a virtual audio device that:
- Appears as `REW Network Audio Bridge` in audio applications
- Routes audio to your speakers so you can hear REW output
- Provides a monitor source for capturing/streaming REW audio
- Prevents conflicts with multiple virtual devices

## 🚀 Features

### ✅ **Enhanced Device Creation**
- Creates properly named devices (not generic "null sink")
- Sets descriptive names: `REW Network Audio Bridge`
- Automatic verification of device creation
- Robust error handling and cleanup

### ✅ **Smart Duplicate Detection**
- Prevents creation of duplicate devices
- Detects existing REW devices by name and configuration
- Interactive prompts when conflicts are found
- Safe handling of orphaned device cleanup

### ✅ **Comprehensive Testing**
- 27 automated test cases covering all functionality
- Regression prevention for future changes
- Automated setup and cleanup during testing
- Detailed test reporting and failure analysis

## 📋 Command Reference

### Basic Commands

```bash
# Create REW virtual audio device
./rew-loopback create

# Check device status
./rew-loopback status

# Remove device
./rew-loopback remove

# List all audio devices
./rew-loopback list

# Show help
./rew-loopback help
```

### Advanced Commands

```bash
# Restart device (remove + create)
./rew-loopback restart

# Comprehensive cleanup of all REW devices
./rew-loopback cleanup

# Fix PulseAudio connection issues
./rew-loopback fix
```

## 🛠️ Installation and Setup

### Prerequisites
- **PulseAudio** - Required for virtual device creation
- **pactl/pacmd** - PulseAudio control utilities (usually included)
- **Bash** - Script requires bash shell environment

### Setup Process

1. **Make script executable:**
   ```bash
   chmod +x rew-loopback
   ```

2. **Create virtual device:**
   ```bash
   ./rew-loopback create
   ```

3. **Verify creation:**
   ```bash
   ./rew-loopback status
   ```

4. **Configure REW:**
   - Open REW (Room EQ Wizard)
   - Go to **Preferences** → **Soundcard**
   - Set **Output Device** to: `REW Network Audio Bridge`

## 📊 Device Details

When created, the virtual device provides:

### Audio Sink
- **Name**: `REW_Network_Audio_Bridge`
- **Description**: `REW Network Audio Bridge`
- **Format**: 16-bit, 2-channel, 44.1 kHz (configurable)
- **Purpose**: REW outputs audio to this device

### Monitor Source  
- **Name**: `REW_Network_Audio_Bridge.monitor`
- **Purpose**: Captures audio sent to the sink
- **Usage**: Audio streaming, recording, analysis

### Speaker Loopback
- **Purpose**: Routes audio to default speakers
- **Latency**: 20ms (optimized for real-time use)
- **Function**: Allows user to hear REW output

## 🧪 Testing

### Automated Test Suite

Run the comprehensive test suite:
```bash
./test-rew-loopback.sh
```

**Test Coverage:**
- ✅ Device creation with proper naming
- ✅ Duplicate detection and prevention  
- ✅ Device removal and cleanup
- ✅ Status reporting accuracy
- ✅ Error condition handling
- ✅ Configuration file management
- ✅ PulseAudio integration

**Test Results:**
```
Tests Run: 9 test scenarios
Individual Checks: 27 verification points
Expected Result: All tests pass ✨
```

### Manual Testing

**Verify device creation:**
```bash
# Check device appears in PulseAudio
pactl list short sinks | grep REW

# Check device description
pactl list sinks | grep -A 15 "REW_Network_Audio_Bridge"

# Test audio routing (play test sound)
speaker-test -D REW_Network_Audio_Bridge -c 2 -t sine -f 1000 -l 1
```

## 🔧 Troubleshooting

### Common Issues

**Issue: Device creation fails**
```bash
# Check PulseAudio status
pulseaudio --check && echo "Running" || echo "Not running"

# Restart PulseAudio if needed
./rew-loopback fix
```

**Issue: Duplicate device warnings**
```bash
# Clean up all REW devices
./rew-loopback cleanup

# Create fresh device
./rew-loopback create
```

**Issue: No audio through speakers**
```bash
# Check default sink
pactl info | grep "Default Sink"

# Verify loopback module
pactl list short modules | grep loopback
```

### Advanced Debugging

**Check device modules:**
```bash
# List all loaded modules
pactl list short modules | grep -E "(null-sink|loopback)"

# Check configuration
cat ~/.rew-loopback
```

**Monitor audio flow:**
```bash
# Monitor sink activity  
pactl subscribe | grep -E "(sink|source)"

# Check audio levels
pavucontrol  # GUI volume control
```

## 🏗️ Technical Architecture

### Component Interaction

```
┌─────────────────┐    Audio Output    ┌──────────────────────┐
│      REW        │ ──────────────────► │  Virtual Sink        │
│ (Room EQ Wizard)│                     │ REW_Network_Audio_   │
└─────────────────┘                     │ Bridge               │
                                        └──────┬───────────────┘
                                               │
                                    ┌──────────▼──────────────┐
                                    │    Monitor Source       │
                                    │ REW_Network_Audio_      │
                                    │ Bridge.monitor          │
                                    └──────┬──────────────────┘
                                           │
                          ┌────────────────┼────────────────┐
                          │                │                │
                          ▼                ▼                ▼
                 ┌─────────────────┐ ┌─────────────┐ ┌──────────────┐
                 │   Speakers      │ │  Recording  │ │   Network    │
                 │  (Loopback)     │ │             │ │  Streaming   │
                 └─────────────────┘ └─────────────┘ └──────────────┘
```

### Module Configuration

The script creates these PulseAudio modules:

1. **module-null-sink** - Creates the virtual audio device
2. **module-loopback** - Routes audio to speakers  

Configuration is stored in `~/.rew-loopback`:
```bash
# REW Loopback Device Configuration
SINK_MODULE_ID="123"
LOOPBACK_MODULE_ID="124"
```

## 📈 Performance Characteristics

- **Latency**: ~20ms total (suitable for REW measurements)
- **CPU Usage**: Minimal (<1% on modern systems)
- **Memory**: <10MB for virtual device management
- **Audio Quality**: Bit-perfect passthrough (no processing)

## 🔄 Integration with Audio Bridge

The REW loopback device integrates seamlessly with the Java Audio Bridge:

```bash
# 1. Create virtual device
./rew-loopback create

# 2. Configure REW to use the device
# (Set output to "REW Network Audio Bridge")

# 3. Start audio bridge to stream to Pi
java -jar audio-bridge-0.1.0-SNAPSHOT.jar --headless --target 192.168.1.100

# 4. REW audio now streams to Pi while playing locally
```

This setup enables:
- **Local monitoring** - Hear REW output through speakers
- **Remote streaming** - Send audio to Pi for processing
- **Measurement capability** - REW can perform acoustic measurements
- **Recording/analysis** - Capture audio stream for further processing

## 🤝 Contributing

When modifying the `rew-loopback` script:

1. **Run tests first:** `./test-rew-loopback.sh`
2. **Make changes** to the script
3. **Run tests again** to ensure no regressions
4. **Add new tests** for new functionality
5. **Update documentation** as needed

The test suite is designed to catch common issues:
- Device naming problems
- Duplicate device conflicts  
- Cleanup failures
- PulseAudio integration issues

---

*The REW Loopback Device Manager provides a robust foundation for REW audio integration with comprehensive testing and error handling.*