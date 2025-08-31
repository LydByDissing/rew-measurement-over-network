# Contributing to REW Measurements over Network

Thank you for your interest in contributing to this project! This guide will help you get started.

## 🎯 Project Vision

We're building an automated, network-based audio measurement system that bridges the gap between manual REW measurements and professional automated testing solutions.

## 🚀 Getting Started

### Prerequisites
- Python 3.8+
- REW (Room EQ Wizard) - latest version with API support
- Basic understanding of audio measurements and DSP concepts

### Development Setup
*Coming soon as the project structure develops*

## 🤝 How to Contribute

### Areas Where Help is Needed

1. **Core Development**
   - Python API clients for REW integration
   - Raspberry Pi service implementation
   - Network communication protocols

2. **Hardware Integration**
   - CamillaDSP configuration management
   - Audio interface optimization for RPi Zero W
   - Hardware-specific adaptations

3. **Documentation**
   - Setup and installation guides
   - Usage examples and tutorials
   - API documentation

4. **Testing**
   - Hardware compatibility testing
   - Network latency and reliability testing
   - Cross-platform validation

### Contribution Process

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

## 📋 Development Guidelines

### Code Quality Standards

#### Testing Requirements
- **Test-First Development**: Always create tests for new features before implementation
- **Regression Protection**: Ensure comprehensive tests are in place before modifying existing functionality
- **Test Coverage**: Aim for >80% code coverage on core components
- **Hardware Testing**: Test on actual RPi Zero W and various audio interfaces when possible
- **Cross-Platform Testing**: Validate on Windows, macOS, and Linux

#### Java Development Standards
- **Build System**: Use Maven for all Java components
- **Documentation**: Use Javadoc for all public classes, methods, and interfaces
- **Code Style**: Follow Google Java Style Guide or Oracle Java conventions
- **Dependencies**: Minimize external dependencies, prefer standard library when possible
- **Testing Framework**: Use JUnit 5 for unit tests, TestFX for GUI testing

#### Python Development Standards (RPi Components)
- **Code Style**: Follow PEP 8 for Python code
- **Documentation**: Use docstrings for all public functions and classes
- **Type Hints**: Add type annotations for function parameters and return values
- **Testing Framework**: Use pytest for unit tests

### Project Structure Standards

#### Java Components (Maven Layout)
```
java-audio-bridge/
├── pom.xml
├── src/
│   ├── main/java/com/lydbydissing/
│   │   ├── audio/          # Audio streaming components
│   │   ├── network/        # Network communication
│   │   ├── gui/           # User interface
│   │   └── util/          # Utilities and helpers
│   ├── main/resources/    # Configuration files, assets
│   └── test/java/         # Unit and integration tests
└── target/                # Maven build output
```

#### Maven Build Requirements
- **Java Version**: Target Java 21 LTS (current LTS as of 2025)
- **Artifact Naming**: Group ID: `com.lydbydissing`, Artifact ID: `audio-bridge`
- **Executable JAR**: Use maven-shade-plugin for single JAR distribution
- **Quality Plugins**: Include SpotBugs, Checkstyle, and JaCoCo for code quality

### Documentation Standards

#### Javadoc Requirements
```java
/**
 * Establishes RTP audio stream connection to Raspberry Pi device.
 * 
 * @param piDevice The target Pi device discovered via mDNS
 * @param audioFormat The audio format for streaming (sample rate, bit depth)
 * @param bufferSize Buffer size in milliseconds for network streaming
 * @return Connection object for managing the audio stream
 * @throws NetworkException if connection cannot be established
 * @throws AudioException if audio format is not supported
 * @since 1.0
 */
public AudioConnection connectToPi(PiDevice piDevice, 
                                   AudioFormat audioFormat, 
                                   int bufferSize) throws NetworkException, AudioException {
    // Implementation
}
```

#### Code Comments
- **When to Comment**: Complex algorithms, business logic, workarounds
- **What to Avoid**: Obvious operations, redundant descriptions
- **Focus on Why**: Explain reasoning behind implementation decisions

### Testing Standards

#### Unit Testing Requirements
```java
@Test
@DisplayName("Should establish RTP connection with valid Pi device")
void shouldConnectToPiWithValidDevice() {
    // Given
    PiDevice mockPi = createMockPiDevice("192.168.1.100");
    AudioFormat format = new AudioFormat(48000, 16, 2, true, false);
    
    // When
    AudioConnection connection = audioService.connectToPi(mockPi, format, 100);
    
    // Then
    assertThat(connection.isConnected()).isTrue();
    assertThat(connection.getLatency()).isLessThan(50);
}
```

#### Integration Testing
- **Network Testing**: Mock network conditions (latency, packet loss)
- **Audio Testing**: Validate audio stream integrity and timing
- **Hardware Testing**: Automated tests with actual RPi Zero W devices
- **Cross-Platform Testing**: CI/CD pipeline testing on multiple OS

### Build and Deployment Standards

#### Maven Configuration
```xml
<properties>
    <maven.compiler.source>11</maven.compiler.source>
    <maven.compiler.target>11</maven.compiler.target>
    <junit.version>5.9.2</junit.version>
    <jacoco.version>0.8.8</jacoco.version>
</properties>
```

#### Quality Gates
- **Build Success**: All tests must pass
- **Code Coverage**: Minimum 80% line coverage
- **Static Analysis**: Zero critical SpotBugs violations
- **Documentation**: All public APIs must have Javadoc
- **Style Compliance**: Checkstyle violations block build

### Commit and PR Standards

#### Commit Messages
```
feat(audio): add RTP streaming with automatic Pi discovery

- Implement mDNS service discovery for Pi devices
- Add RTP packet encoding with configurable quality
- Include connection retry logic with exponential backoff
- Add comprehensive unit tests for network components

Closes #15, Closes #18
```

#### Pull Request Requirements
- **Description**: Clear description of changes and rationale
- **Testing Evidence**: Screenshots, test results, hardware validation
- **Documentation Updates**: Update relevant docs and Javadoc
- **Breaking Changes**: Clearly marked and documented
- **Review Requirements**: At least one approving review required

## 🐛 Reporting Issues

When reporting issues, please include:
- Operating system and version
- Python version
- REW version
- Hardware configuration (if applicable)
- Steps to reproduce
- Expected vs actual behavior
- Relevant log output

## 💡 Suggesting Features

We welcome feature suggestions! Please:
- Check existing issues first
- Clearly describe the use case
- Explain how it fits the project goals
- Consider implementation complexity

## 📚 Resources

- [REW Documentation](https://www.roomeqwizard.com/help/)
- [CamillaDSP GitHub](https://github.com/HEnquist/camilladsp)
- [Project Specification](specification.md)

## 🔧 Development Roadmap

### Phase 1: Foundation
- [ ] Basic network communication
- [ ] REW API client
- [ ] CamillaDSP integration

### Phase 2: Automation
- [ ] Measurement sequences
- [ ] Configuration management
- [ ] Error handling

### Phase 3: Enhancement
- [ ] Web interface
- [ ] Advanced features
- [ ] Performance optimization

## 📞 Communication

- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: GitHub Discussions for general questions and ideas
- **Security**: Email maintainers directly for security concerns

## 🙏 Recognition

All contributors will be acknowledged in the project documentation and release notes.

---

*This project is in early development. Guidelines may evolve as the project matures.*