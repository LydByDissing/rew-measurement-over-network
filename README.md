# REW Measurements over Network

An automated, network-based audio measurement system that makes taking precise acoustic measurements with Room EQ Wizard (REW) both easy and repeatable.

## 🎯 Project Goals

- **Remote Control**: Manage audio measurements without physical access to the measurement setup
- **Automation**: Script measurement sequences to reduce human error and increase repeatability  
- **Integration**: Seamless workflow between CamillaDSP configuration and REW measurements
- **Scalability**: Manage multiple measurement setups from one control station

## 🏗️ System Architecture

```
[Developer Machine] ←→ [Network] ←→ [Raspberry Pi Zero W + Speaker System]
     (REW + Control)                      (CamillaDSP + API)
```

## 🧩 Components

### Hardware
- **Raspberry Pi Zero W** - Remote measurement target with CamillaDSP
- **Calibrated USB Microphone** - miniDSP UMIK-1 or similar
- **Developer Machine** - Control station running REW

### Software Stack
- **CamillaDSP** - Real-time audio processing on Raspberry Pi
- **REW (Room EQ Wizard)** - Acoustic measurement and analysis
- **Python Control Layer** - Network communication and automation
- **REST API** - Remote configuration and control interface

## 🚀 Key Features

- **Automated Measurement Sequences** - Script multiple measurements with different configurations
- **Real-time DSP Control** - Push configuration changes to CamillaDSP instantly
- **REW API Integration** - Leverage REW's built-in API for measurement automation
- **Configuration Versioning** - Git-based tracking of DSP configurations
- **Health Monitoring** - Continuous system status and diagnostics
- **Multi-format Export** - Generate reports in various formats

## 📋 Use Cases

1. **Remote Speaker Tuning** - Adjust and measure speaker response remotely
2. **Batch Testing** - Automated measurement of multiple configurations
3. **A/B Comparisons** - Compare different DSP settings objectively
4. **Iterative Optimization** - Continuous measurement-adjustment cycles
5. **Documentation** - Automatic measurement logging and report generation

## 🛠️ Installation

*Coming soon - this project is in active development*

## 📖 Documentation

See [specification.md](specification.md) for detailed system design and architecture.

## 🤝 Contributing

This project is in early development. Contributions, ideas, and feedback are welcome!

## 📄 License

*License to be determined*

## 🙋‍♂️ Project Status

**Early Development** - Core architecture and specifications are being defined.

## 🏢 Organization

This project is developed and maintained by [LydByDissing](https://github.com/LydByDissing).

---

*This project aims to bridge the gap between manual REW measurements and automated, network-controlled audio analysis systems.*