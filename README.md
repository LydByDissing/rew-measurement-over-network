# REW Network Audio Bridge

A complete audio streaming and measurement system that enables remote REW (Room EQ Wizard) measurements over a network connection. Stream audio from REW to remote Raspberry Pi devices running audio processing systems.

## 🎯 Project Goals

- **Network Audio Streaming**: Stream REW output to remote devices via RTP/UDP
- **Virtual Audio Devices**: Create seamless audio loopback for REW integration
- **Remote Measurements**: Perform acoustic measurements without physical access to the target system
- **Container Deployment**: Easy deployment using Docker containers
- **Automated Testing**: Comprehensive testing for reliability and consistency

## 🏗️ System Architecture

```
┌─────────────────────┐    RTP/UDP Audio Stream    ┌──────────────────────────┐
│  Developer Machine  │◄─────────────────────────►│    Raspberry Pi Zero W   │
│                     │                            │                          │
│ ┌─────────────────┐ │                            │ ┌──────────────────────┐ │
│ │ REW (Room EQ    │ │                            │ │  Audio Receiver      │ │
│ │ Wizard)         │ │                            │ │  + CamillaDSP        │ │
│ └─────────────────┘ │                            │ └──────────────────────┘ │
│          │          │                            │                          │
│ ┌─────────────────┐ │                            │ ┌──────────────────────┐ │
│ │ Java Audio      │ │                            │ │ ALSA Audio Output    │ │
│ │ Bridge          │ │                            │ │                      │ │
│ │ • Virtual Device│ │                            │ │ ┌──────────────────┐ │ │
│ │ • RTP Streaming │ │                            │ │ │    Speakers      │ │ │
│ └─────────────────┘ │                            │ │ └──────────────────┘ │ │
└─────────────────────┘                            └──────────────────────────┘
```

## 🧩 Components

### Hardware
- **Developer Machine** - Linux/Windows system running REW and Java Audio Bridge
- **Raspberry Pi Zero W** - Remote audio target with containerized receiver
- **Network Connection** - WiFi or Ethernet for RTP audio streaming
- **Audio Output** - Speakers, amplifier, or audio interface on Pi

### Software Stack

#### Java Audio Bridge (Developer Machine)
- **PulseAudio Virtual Device** - Creates `REW Network Audio Bridge` sink
- **RTP Audio Streaming** - Real-time audio transport over UDP
- **JavaFX GUI** - Device discovery and connection management  
- **Headless Mode** - CLI operation for automation and scripts

#### Pi Audio Receiver (Raspberry Pi)
- **Python RTP Receiver** - Receives and processes audio stream
- **ALSA Integration** - Direct audio output to Pi speakers/DAC
- **Docker Container** - Simplified deployment and management
- **Connection Detection** - Status monitoring and logging

#### Development Tools
- **REW Loopback Manager** - `rew-loopback` script for virtual audio devices
- **Comprehensive Testing** - Automated test suites for quality assurance
- **Docker Deployment** - Container orchestration and deployment scripts

## 🚀 Key Features

### Audio Streaming
- **Low-latency RTP streaming** - Real-time audio transport optimized for measurements
- **Automatic format detection** - Supports various sample rates and bit depths
- **Connection monitoring** - Health checks and status reporting
- **Fallback audio support** - Multiple audio backend support (PulseAudio, ALSA)

### Device Management  
- **GUI and CLI modes** - Flexible operation for different use cases
- **Device discovery** - Automatic Pi device detection on network
- **Manual device addition** - Support for static IP configurations
- **Connection status** - Real-time monitoring of streaming status

### Development & Testing
- **Unified architecture** - Shared business logic between GUI and headless modes
- **Comprehensive test suite** - 27+ automated tests for reliability
- **Container deployment** - Docker support for Pi and development environments
- **CI/CD ready** - Automated testing and quality assurance

## 📋 Use Cases

1. **Remote REW Measurements** - Stream REW output to remote Pi devices for acoustic measurement
2. **Multi-room Audio Testing** - Test speakers in different rooms from a central control station  
3. **Headless Audio Streaming** - Automated streaming for CI/CD and testing environments
4. **Development Testing** - Validate audio processing pipelines and DSP configurations
5. **Educational Setups** - Demonstrate acoustic measurement concepts remotely

## 🛠️ Installation

### Prerequisites
- **Java 21+** - Required for Audio Bridge application
- **Maven 3.8+** - For building the Java application  
- **PulseAudio** - Required for virtual audio device creation (Linux)
- **Docker** (optional) - For containerized Pi receiver deployment

### Quick Start

#### 1. Clone Repository
```bash
git clone <repository-url>
cd rew-measurement-over-network
```

#### 2. Build Java Audio Bridge
```bash
cd java-audio-bridge
mvn clean package
```

#### 3. Set Up Virtual Audio Device
```bash
# Create REW virtual audio device
./rew-loopback create

# Verify device creation
./rew-loopback status
```

#### 4. Deploy Pi Receiver (Docker)
```bash
cd pi-receiver
# Deploy to Pi at 192.168.1.100
./deploy-to-pi.sh deploy pi@192.168.1.100
```

#### 5. Run Audio Bridge

**GUI Mode:**
```bash
cd java-audio-bridge  
java -jar target/audio-bridge-0.1.0-SNAPSHOT.jar
```

**Headless Mode:**
```bash
# Connect to Pi at 192.168.1.100
java -jar target/audio-bridge-0.1.0-SNAPSHOT.jar --headless --target 192.168.1.100
```

### REW Configuration
1. Open REW (Room EQ Wizard)
2. Go to **Preferences** → **Soundcard**  
3. Set **Output Device** to: `REW Network Audio Bridge`
4. Audio will now stream to connected Pi devices

## 📖 Documentation

- **[System Architecture](specification.md)** - Detailed technical specifications
- **[Pi Receiver Setup](pi-receiver/README.md)** - Pi deployment and configuration  
- **[SSH Deployment Guide](pi-receiver/SSH_DEPLOYMENT_GUIDE.md)** - Advanced deployment options
- **[Testing Documentation](TESTING_SUMMARY.md)** - Test coverage and procedures

## 🧪 Development & Testing

### Running Tests
```bash
# Test Java Audio Bridge
cd java-audio-bridge
mvn test

# Test REW loopback functionality  
./test-rew-loopback.sh

# Test Docker integration
./test-docker-setup.sh

# Test core functionality
./test-core-functionality.sh
```

### Development Tools
```bash
# REW loopback device management
./rew-loopback create|remove|status|list|cleanup

# Pi receiver deployment 
./pi-receiver/deploy-to-pi.sh [build|deploy|status] [target]

# Docker container management
docker-compose -f pi-receiver/docker-compose.simple.yaml up -d
```

## 🤝 Contributing

This project welcomes contributions! Please ensure:
- All tests pass: `mvn test && ./test-rew-loopback.sh`
- Code follows existing patterns and conventions
- New features include appropriate test coverage
- Documentation is updated for user-facing changes

## 📄 License

*License to be determined*

## 🙋‍♂️ Project Status

**Active Development** - Core functionality implemented with:
- ✅ **Java Audio Bridge** - GUI and headless modes working
- ✅ **Pi Audio Receiver** - Docker containerization complete  
- ✅ **Virtual Audio Devices** - REW loopback integration working
- ✅ **Comprehensive Testing** - 27+ automated tests passing
- ✅ **Docker Deployment** - Simplified Pi setup and deployment
- 🚧 **CI/CD Pipeline** - GitHub Actions integration in progress

### Recent Improvements
- **Unified Architecture**: Shared business logic between GUI and headless modes
- **Enhanced Device Management**: Proper naming and duplicate detection for virtual audio devices
- **Test Coverage**: Comprehensive test suite with 27 test cases covering all major functionality
- **Container Support**: Complete Docker infrastructure for easy Pi deployment

## 🏢 Organization

This project is developed and maintained by [LydByDissing](https://github.com/LydByDissing).

---

*Bridging the gap between REW measurements and remote audio systems through reliable network audio streaming.*