# REW Measurements over Network

## Project Overview

The goal of this project is to create an automated, network-based audio measurement system that makes taking precise acoustic measurements with Room EQ Wizard (REW) both easy and repeatable. This system enables remote control and measurement of audio systems without requiring physical access to the measurement hardware.

## System Components

### Primary Audio Device
- **Hardware**: Raspberry Pi Zero W (1st generation)
- **DSP Software**: CamillaDSP for real-time audio processing and speaker tuning
- **Role**: Acts as the remote measurement target and signal processing unit
- **Connectivity**: Wi-Fi network connection for remote control and data transfer

### Measurement System
- **Software**: Room EQ Wizard (REW) for acoustic analysis
- **API Integration**: Leveraging REW's API for automated measurement sequences
- **Input Device**: Calibrated miniDSP UMIK-1 or similar USB measurement microphone
- **Platform**: Runs on developer/control machine

### Control Infrastructure
- **Management Device**: Developer workstation or laptop
- **Network**: Local network connection between all components
- **Protocol**: Network-based communication for remote control and data synchronization

## Use Cases

1. **Remote Speaker Tuning**: Adjust CamillaDSP parameters and immediately measure the acoustic response
2. **Batch Measurements**: Automate multiple measurement sequences with different configurations
3. **A/B Testing**: Compare different DSP settings or hardware configurations remotely
4. **Documentation**: Automatically generate measurement reports and store results
5. **Iterative Optimization**: Continuous measurement-adjustment cycles without manual intervention

## Benefits

- **Repeatability**: Consistent measurement conditions and procedures
- **Efficiency**: No physical access required to measurement location
- **Automation**: Scripted measurement sequences reduce human error
- **Documentation**: Automatic logging and result storage
- **Scalability**: Multiple measurement setups can be managed from one location

## System Design

### Architecture Overview

The system follows a distributed architecture optimized for measurement accuracy and practical setup:

```
[Developer Machine]                    [Raspberry Pi Zero W + Speaker]
     (REW + Mic)  ←→ [Network] ←→        (CamillaDSP + Audio Out)
                                              ↓
                        [Audible Timing Reference]
                                              ↓
                            [Room Acoustics]
                                              ↓
                              [Microphone Input]
```

**Key Principle**: REW runs locally with direct microphone connection, while the RPi serves as a remote DSP-controlled audio source. Timing synchronization uses REW's audible timing reference to eliminate network latency issues.

### Network Communication Layer

#### Control Protocol
- **Transport**: TCP/IP over Wi-Fi
- **Message Format**: JSON-based command and response structure
- **Security**: Optional TLS encryption for sensitive environments
- **Discovery**: mDNS/Bonjour for automatic device discovery on local network

#### API Endpoints
- `/api/camilladsp/config` - Upload/download DSP configurations
- `/api/camilladsp/status` - Query current DSP state and audio output status
- `/api/camilladsp/reload` - Hot-reload configuration without audio interruption
- `/api/audio/play` - Control audio playback (start/stop/volume)
- `/api/measurement/prepare` - Prepare system for measurement (optimize settings)
- `/api/system/health` - System status, audio interface, and network diagnostics

### Raspberry Pi Zero Implementation

#### Software Stack
- **OS**: Raspberry Pi OS Lite (headless)
- **Audio**: ALSA with low-latency kernel patches
- **DSP**: CamillaDSP daemon with REST API interface
- **Control Service**: Python-based web service for remote management
- **Dependencies**: 
  - Flask or FastAPI for web framework
  - PyAudio for audio interface management
  - systemd for service management

#### Hardware Interface
- **Audio Output**: I2S DAC or USB audio interface
- **Network**: Built-in Wi-Fi adapter
- **Storage**: microSD card (Class 10 or better for low latency)
- **Power**: 5V micro-USB (stable power supply critical for audio quality)

### Developer Machine Components

#### REW Integration (Local)
- **REW Instance**: Full REW installation with direct USB microphone connection
- **REW API Client**: Python wrapper for REW's built-in automation API
- **Measurement Automation**: Scripts coordinating REW measurements with remote DSP changes
- **Data Processing**: Post-measurement analysis and report generation
- **Configuration Management**: Version control for DSP configurations with measurement metadata

#### Hardware Setup
- **USB Microphone**: Calibrated measurement mic (miniDSP UMIK-1) connected directly
- **Audio Interface**: Local audio output for REW's timing reference (optional)
- **Network Interface**: Wi-Fi or Ethernet connection to Raspberry Pi

#### Control Interface Options
1. **Command Line Interface**: For scripted automation and batch measurements
2. **Python API**: Direct integration with measurement scripts
3. **Web Dashboard**: Browser-based control panel for interactive use

### Data Flow Architecture

#### Measurement Sequence (Revised)
1. **Pre-measurement Setup**: 
   - Verify network connectivity to Raspberry Pi
   - Confirm microphone and audio interfaces are ready
   - Check CamillaDSP status and audio output levels
2. **Configuration Push**: Send new DSP parameters to Raspberry Pi via API
3. **System Settling**: Wait for DSP reconfiguration and audio stabilization
4. **REW Measurement**: 
   - REW generates test signal and timing reference locally
   - Raspberry Pi plays audio through speaker system
   - Local microphone captures acoustic response
   - REW uses audible timing reference for precise synchronization
5. **Data Processing**: REW processes measurement data locally
6. **Result Storage**: Save measurements with associated DSP configuration metadata
7. **Analysis & Reports**: Generate comparison reports and optimization suggestions

#### File Management
- **Configuration Storage**: Git-based versioning of DSP configs
- **Measurement Archive**: Timestamped results with metadata
- **Report Generation**: Automated PDF/HTML report creation
- **Backup Strategy**: Automatic backup of critical configurations

### Performance Considerations

#### Latency and Timing Considerations
- **Network Latency**: Not critical for measurement accuracy (only affects control responsiveness)
- **Audio Timing**: REW's audible timing reference eliminates network timing dependencies
- **Configuration Update**: < 2 seconds for DSP parameter changes and settling
- **Measurement Accuracy**: Timing precision maintained through acoustic coupling, not network synchronization
- **System Response**: < 1 second feedback for configuration changes and system status

#### Reliability Features
- **Health Monitoring**: Continuous system health checks
- **Auto Recovery**: Automatic restart of failed services
- **Error Handling**: Graceful degradation and error reporting
- **Logging**: Comprehensive logging for troubleshooting

### Security Model

#### Network Security
- **Firewall**: Restrict access to measurement network only
- **Authentication**: Optional API key authentication
- **Encryption**: TLS for sensitive data transmission
- **Access Control**: Role-based permissions for different users

#### System Integrity
- **Configuration Validation**: Verify DSP configs before deployment
- **Backup Verification**: Regular backup integrity checks
- **Update Management**: Secure update mechanism for system components

## Minimum Requirements

### Software Requirements

#### REW (Room EQ Wizard)
- **Minimum Version**: V5.40 beta 99 (August 30, 2025) or later
- **Rationale**: API support introduced in V5.40 beta series
- **Required Features**:
  - REST API server (default port 4735)
  - API blocking mode support
  - Audible timing reference capability
  - Multi-input capture support (Pro upgrade recommended)
  - CamillaDSP YAML export functionality
- **Platform**: Windows, macOS, or Linux
- **API Access**: HTTP REST API at localhost:4735 with OpenAPI documentation

#### CamillaDSP
- **Minimum Version**: v3.0.1 (March 2025) or later
- **Rationale**: Latest bugfixes and websocket API stability
- **Required Features**:
  - Websocket server for remote control
  - JSON command interface
  - Configuration hot-reload capability
  - YAML configuration format
  - REW filter import compatibility
- **Platform**: Linux (Raspberry Pi ARM builds available)
- **API Access**: Websocket server with configurable port and binding

### Hardware Requirements

#### Developer Machine
- **OS**: Windows 10/11, macOS 10.15+, or Linux (Ubuntu 20.04+)
- **RAM**: 4GB minimum, 8GB recommended (for REW processing)
- **Storage**: 1GB free space for software and measurement data
- **Network**: Wi-Fi or Ethernet connectivity
- **USB**: Available USB port for measurement microphone
- **Audio**: Audio output capable of timing reference playback (optional)

#### Raspberry Pi Zero W (1st Generation)
- **Hardware**: Raspberry Pi Zero W with 512MB RAM
- **OS**: Raspberry Pi OS Lite (Bullseye or newer)
- **Storage**: Class 10 microSD card, 8GB minimum
- **Audio Interface**: 
  - I2S DAC HAT (recommended for quality)
  - USB audio interface (alternative)
  - 3.5mm audio jack (basic functionality)
- **Network**: Built-in 802.11n Wi-Fi
- **Power**: 5V 2A micro-USB supply (stable power critical)

#### Audio Hardware
- **Measurement Microphone**: 
  - Calibrated USB measurement microphone
  - Recommended: miniDSP UMIK-1, UMIK-2, or equivalent
  - Frequency response: 20Hz-20kHz minimum
- **Speaker System**: Full-range or component speakers connected to RPi audio output
- **Cables**: Quality audio cables appropriate for setup

### Network Requirements

#### Network Infrastructure
- **Bandwidth**: 100 Mbps minimum for configuration transfer
- **Latency**: < 100ms for responsive control (measurement timing independent)
- **Protocols**: TCP/IP, Websocket support
- **Discovery**: mDNS/Bonjour support recommended
- **Security**: WPA2/WPA3 Wi-Fi encryption

#### Network Configuration
- **Connectivity**: RPi Zero W and developer machine on same network
- **Firewall**: Allow communication on CamillaDSP websocket port (default 1234)
- **DNS**: Static IP or mDNS resolution for RPi Zero W
- **Remote Access**: SSH access to RPi for maintenance (optional)

### Development Environment

#### Programming Languages
- **Java**: 21 LTS (current LTS as of 2025) for audio bridge application
- **Python**: 3.8+ (Raspberry Pi components)
- **Java Dependencies**:
  - JavaFX 21.0.2 for GUI
  - JmDNS 3.5.8 for service discovery
  - Jackson 2.14.2 for JSON processing
  - SLF4J + Logback for logging
- **Python Dependencies**:
  - `pyalsaaudio` for ALSA audio output
  - `zeroconf` for mDNS service advertisement
  - `pytest` for testing

#### Development Tools
- **Build System**: Maven 3.8+ for Java components
- **Version Control**: Git 2.20+
- **Documentation**: Javadoc for Java, docstrings for Python
- **Testing**: JUnit 5 for Java, pytest for Python
- **Quality Tools**: SpotBugs, Checkstyle, JaCoCo for code quality

### Performance Targets

#### Measurement Accuracy
- **Frequency Response**: ±0.1dB accuracy at measurement microphone
- **Timing Precision**: REW audible timing reference (network-independent)
- **Dynamic Range**: Limited by hardware (typically >90dB for quality DACs)
- **Phase Accuracy**: ±1° at frequencies below 10kHz

#### System Responsiveness
- **Configuration Updates**: < 3 seconds end-to-end
- **System Status Queries**: < 500ms response time
- **Measurement Preparation**: < 5 seconds for system ready state
- **Error Recovery**: Automatic retry with graceful degradation

