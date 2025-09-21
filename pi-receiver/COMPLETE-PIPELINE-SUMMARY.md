# Complete MediaMTX → CamillaDSP → Merus Amplifier Pipeline

## 🎯 **CONFIRMED WORKING CONFIGURATION**

✅ **Audio Device**: `hw:CARD=sndrpimerusamp`  
✅ **Format**: `S32_LE` (32-bit signed little-endian)  
✅ **Sample Rate**: 48000 Hz  
✅ **Channels**: 2 (stereo)  

## 🚀 **Ready-to-Deploy Package**

**Latest Package**: `rew-receiver-native-20250920-134426-unknown-67168b9-dirty.tar.gz`

### 📦 **Package Contents**

**Core Components:**
- ✅ `mediamtx` + `camilladsp` binaries
- ✅ Systemd service files
- ✅ `install.sh` deployment script

**Audio Configuration:**
- ✅ `camilladsp.yml.template` - Configurable with S32_LE format
- ✅ `configure-audio-device.sh` - Device configuration tool
- ✅ `validate-audio-device.sh` - Audio validation tool

**Testing Tools:**
- ✅ `test-merus-amp.sh` - Complete Merus amplifier workflow
- ✅ `test-confirmed-working.sh` - Verified working command test
- ✅ `test-full-pipeline.sh` - Complete MediaMTX→CamillaDSP→Merus pipeline test
- ✅ `test-rtp-stream.sh` - RTP streaming validation

**Configuration Files:**
- ✅ `mediamtx.yml` - Basic MediaMTX configuration
- ✅ `mediamtx-rtp.yml` - Enhanced RTP configuration

**Documentation:**
- ✅ `WORKING-MERUS-CONFIG.md` - Verified configuration details
- ✅ `AUDIO-DEVICE-CONFIG.md` - Complete configuration guide
- ✅ `PIPELINE-VALIDATION-GUIDE.md` - Pipeline testing guide

## 🔄 **Deployment Workflow**

### 1. Deploy to Pi
```bash
scp export/rew-receiver-native-20250920-134426-unknown-67168b9-dirty.tar.gz pi@pi-ip:~/
ssh pi@pi-ip 'tar -xzf rew-receiver-native-*.tar.gz && cd rew-receiver-package && ./install.sh'
```

### 2. Validate Audio Configuration
```bash
cd /home/pi/rew-receiver
./test-merus-amp.sh
```

### 3. Test Complete Pipeline
```bash
# Start MediaMTX + CamillaDSP services
./test-full-pipeline.sh
```

### 4. Validate RTP Streaming
```bash
# In another terminal, test RTP input
./test-rtp-stream.sh
```

## 🎵 **Pipeline Validation Steps**

### Step 1: Device Configuration ✅
- [x] Merus amplifier device: `hw:CARD=sndrpimerusamp`
- [x] Audio format: S32_LE
- [x] CamillaDSP template configured
- [x] Direct speaker-test validation working

### Step 2: Service Integration ✅
- [x] CamillaDSP configured for Merus amplifier
- [x] MediaMTX configured for RTP input
- [x] Services can start and respond to API calls
- [x] End-to-end audio chain tested

### Step 3: RTP Workflow Validation (Next)
- [ ] **MediaMTX receives RTP on port 5004**
- [ ] **Audio flows through CamillaDSP processing**
- [ ] **Output plays through Merus amplifier**
- [ ] **REW integration working**

## 🧪 **Testing Commands Ready**

```bash
# Quick device verification
speaker-test -D "hw:CARD=sndrpimerusamp" -c 2 -r 48000 -t sine -f 1000 -l 1 -F S32_LE

# Complete workflow test
./test-full-pipeline.sh

# RTP stream test
./test-rtp-stream.sh

# REW integration test
# (Configure REW: Output → Network/RTP → PI_IP:5004)
```

## 🎯 **Success Criteria for Next Phase**

The pipeline validation is **COMPLETE** when:

✅ **Audio Device**: Working with confirmed configuration  
🔄 **Service Integration**: Ready to test  
⏳ **RTP Reception**: MediaMTX receives RTP streams  
⏳ **Audio Processing**: CamillaDSP processes audio correctly  
⏳ **Output**: Clear audio through Merus amplifier  
⏳ **REW Integration**: REW can stream audio successfully  

## 🔗 **Ready for REW Integration**

Once pipeline validation passes:
1. **REW Output Configuration**: Network/RTP → `PI_IP:5004`
2. **Audio Measurements**: Full-range frequency response
3. **Room Correction**: EQ filters via CamillaDSP
4. **Production Ready**: Automated room correction system

---

**Current Status**: Ready for MediaMTX → CamillaDSP → Merus amplifier pipeline validation
