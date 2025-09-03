# Contributing to REW Network Audio Bridge

Welcome! This guide will help you contribute effectively to the REW Network Audio Bridge project.

## 🚀 Quick Start

1. **Fork and clone the repository**
2. **Install dependencies** (see [Development Setup](#development-setup))  
3. **Run tests** to ensure everything works: `./test-rew-loopback.sh`
4. **Make your changes**
5. **Run tests again** to prevent regressions
6. **Submit a pull request**

## 🛠️ Development Setup

### Prerequisites

**System Requirements:**
- **Java 21** (OpenJDK recommended)
- **Maven 3.6+** for Java builds
- **PulseAudio** for virtual audio device testing
- **Docker** (optional, for Pi receiver development)

**For Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk maven pulseaudio pulseaudio-utils docker.io
```

### Project Structure

```
rew-measurement-over-network/
├── java-audio-bridge/          # Main Java application
│   ├── src/main/java/          # Java source code
│   ├── src/test/java/          # Unit tests
│   └── pom.xml                 # Maven configuration
├── pi-receiver/                # Raspberry Pi receiver
│   ├── Dockerfile.simple       # Docker container
│   └── deploy-to-pi.sh         # Deployment script
├── rew-loopback                # Virtual audio device manager
├── test-*.sh                   # Test scripts
└── .github/workflows/          # CI/CD pipelines
```

### Local Development

1. **Clone and setup:**
   ```bash
   git clone https://github.com/your-fork/rew-measurement-over-network.git
   cd rew-measurement-over-network
   chmod +x rew-loopback test-*.sh
   ```

2. **Run REW loopback tests:**
   ```bash
   ./test-rew-loopback.sh
   ```

3. **Build Java application:**
   ```bash
   cd java-audio-bridge
   mvn clean compile
   mvn test
   mvn package
   ```

4. **Test Docker setup:**
   ```bash
   ./test-docker-setup.sh
   ```

## 🧪 Testing

### Test Philosophy

We maintain comprehensive test coverage to ensure reliability:

- **Unit tests** for individual components
- **Integration tests** for component interaction
- **System tests** for end-to-end functionality
- **Regression tests** to prevent breaking changes

### Running Tests

**All tests:**
```bash
# REW loopback functionality (27 test cases)
./test-rew-loopback.sh

# Core Java functionality
cd java-audio-bridge && mvn test

# Docker containers
./test-docker-setup.sh

# Integration tests
./test-integration.sh
```

**Specific test categories:**
```bash
# Only Java unit tests
cd java-audio-bridge && mvn test -Dtest="*Test"

# Only integration tests
cd java-audio-bridge && mvn test -Dtest="*IT"

# REW loopback with verbose output
VERBOSE=1 ./test-rew-loopback.sh
```

### Test Requirements

- **All tests must pass** before submitting PRs
- **New features require tests** (aim for >80% coverage)
- **Bug fixes should include regression tests**
- **Tests should be fast** (< 30 seconds per test suite)

## 📝 Code Style and Standards

### Java Code Style

We use **Google Java Style** with minor modifications:

```bash
# Run Checkstyle validation
cd java-audio-bridge && mvn checkstyle:check

# Generate coverage reports
mvn clean test jacoco:report
```

**Key conventions:**
- **4-space indentation** (no tabs)
- **120-character line limit**
- **Descriptive variable names**
- **JavaDoc for public methods**
- **No commented-out code**

### Shell Script Style

For bash scripts (rew-loopback, test scripts):

- **4-space indentation**
- **Descriptive function names**
- **Proper error handling** with `set -euo pipefail`
- **Colored output** for user feedback
- **Comprehensive comments** for complex logic

### Git Commit Style

We follow **Conventional Commits**:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Examples:**
```
feat(audio): add headless mode support
fix(loopback): resolve duplicate device creation
docs(readme): update installation instructions
test(ci): add Docker integration tests
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test additions/modifications
- `refactor`: Code refactoring
- `style`: Formatting changes
- `ci`: CI/CD changes

## 🏗️ Architecture Guidelines

### Component Design

**Java Audio Bridge:**
- **MVC pattern** for GUI components
- **Service layer** for business logic
- **Repository pattern** for configuration
- **Dependency injection** where appropriate

**Audio Processing:**
- **Minimal latency** design (<50ms total)
- **Robust error handling** for audio device failures
- **Graceful degradation** when devices unavailable
- **Resource cleanup** on shutdown

### Performance Requirements

- **Startup time**: <5 seconds
- **Audio latency**: <50ms end-to-end
- **Memory usage**: <100MB under normal operation
- **CPU usage**: <10% on modern systems

## 🔄 Pull Request Process

### Before Submitting

1. **Run full test suite:**
   ```bash
   ./test-rew-loopback.sh
   cd java-audio-bridge && mvn clean verify
   ./test-integration.sh
   ```

2. **Check code quality:**
   ```bash
   cd java-audio-bridge && mvn checkstyle:check
   ```

3. **Update documentation** if needed
4. **Test manually** with real audio devices

### PR Description Template

```markdown
## Summary
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality) 
- [ ] Breaking change (fix or feature causing existing functionality to break)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] REW loopback tests pass (27/27)

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added for new functionality
```

### Review Process

1. **Automated checks** run via GitHub Actions
2. **Code review** by maintainers
3. **Testing verification** on multiple environments
4. **Documentation review** for completeness
5. **Merge** after approval

## 🐛 Bug Reports

### Reporting Issues

**Use the issue template:**
1. **Environment details** (OS, Java version, PulseAudio version)
2. **Steps to reproduce** the issue
3. **Expected vs actual behavior**
4. **Logs and error messages**
5. **Audio device configuration**

**Helpful information:**
```bash
# System information
java -version
mvn -version
pactl info

# Audio device status
./rew-loopback status
pactl list short sinks

# Application logs
java -jar audio-bridge-*.jar --headless --verbose
```

### Bug Fix Process

1. **Reproduce the issue** locally
2. **Write a failing test** that demonstrates the bug
3. **Fix the issue** with minimal code changes
4. **Verify the test passes**
5. **Run full test suite** to prevent regressions

## 💡 Feature Requests

### Proposing Features

Before implementing new features:

1. **Open an issue** describing the feature
2. **Discuss the approach** with maintainers
3. **Consider backwards compatibility**
4. **Plan the testing strategy**
5. **Update documentation plans**

### Feature Development

1. **Create feature branch** from `main`
2. **Implement incrementally** with tests
3. **Update documentation** throughout development
4. **Test thoroughly** including edge cases
5. **Submit PR** with comprehensive description

## 🏷️ Release Process

### Version Numbering

We use **Semantic Versioning** (semver):
- **Major**: Breaking changes
- **Minor**: New features (backwards compatible)  
- **Patch**: Bug fixes (backwards compatible)

### Release Workflow

1. **Version bump** in `pom.xml`
2. **Update CHANGELOG.md** with release notes
3. **Tag release** with `git tag v1.x.x`
4. **GitHub Actions** builds release artifacts
5. **Manual validation** of release bundle
6. **Publish release** with artifacts and documentation

## 🤝 Community

### Getting Help

- **GitHub Issues**: Bug reports and feature requests
- **Discussions**: General questions and ideas
- **Email**: For security issues or private concerns

### Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/):

- **Be respectful** and inclusive
- **Provide constructive feedback**
- **Focus on collaboration**
- **Help newcomers** get started

## 📚 Additional Resources

### Documentation

- **README.md**: Project overview and quick start
- **REW_LOOPBACK_GUIDE.md**: Detailed REW loopback usage
- **specification.md**: Technical requirements and architecture

### External References

- **Room EQ Wizard (REW)**: [roomeqwizard.com](https://roomeqwizard.com)
- **PulseAudio Documentation**: [freedesktop.org/wiki/Software/PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/)
- **JavaFX Documentation**: [openjfx.io](https://openjfx.io)
- **Maven Guide**: [maven.apache.org/guides](https://maven.apache.org/guides/)

---

Thank you for contributing to REW Network Audio Bridge! Your improvements help make acoustic measurement more accessible and reliable for everyone. 🎵