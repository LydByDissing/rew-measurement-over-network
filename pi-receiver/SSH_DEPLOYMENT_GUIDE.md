# REW Pi Audio Receiver - SSH Deployment Guide

## SSH Key Authentication Issues Fixed

The deployment script has been enhanced to properly handle SSH key authentication for seamless Pi deployment.

## What Was Fixed

### 🔧 **SSH Key Detection and Usage**
- **Automatic key detection**: Looks for `id_rsa` or `id_ed25519` keys
- **Explicit key specification**: Uses `-i` flag to specify key file
- **SSH options**: Includes connection timeout and keep-alive settings
- **StrictHostKeyChecking=no**: Avoids host key verification prompts

### 🛠 **Connection Testing**
- **Pre-deployment test**: Verifies SSH connectivity before file transfer
- **Clear error messages**: Provides troubleshooting steps if connection fails
- **Authentication verification**: Tests both key-based and agent authentication

### 🚀 **New SSH Setup Command**
- **`setup-ssh`**: New command to automatically configure SSH keys
- **Key generation**: Creates ED25519 keys if none exist
- **Key copying**: Uses `ssh-copy-id` to install public key on Pi
- **Connection testing**: Verifies passwordless authentication works

## Usage Instructions

### 1. First-Time Setup (Recommended)

```bash
# Setup SSH keys for passwordless access
cd pi-receiver
./deploy-to-pi.sh setup-ssh pi@192.168.1.100
```

This command will:
1. ✅ Generate SSH keys if they don't exist (`~/.ssh/id_ed25519`)
2. ✅ Copy your public key to the Pi (you'll enter password once)
3. ✅ Test passwordless authentication
4. ✅ Confirm setup is working

### 2. Deploy to Pi (Now Passwordless)

```bash
# Deploy containerized receiver to Pi
./deploy-to-pi.sh deploy-remote pi@192.168.1.100
```

This will now work without password prompts!

## SSH Key Improvements

### **Enhanced SSH Options**
```bash
# Connection options now include:
-o ConnectTimeout=10          # Don't wait forever
-o ServerAliveInterval=60     # Keep connection alive  
-o ServerAliveCountMax=3      # Retry if connection drops
-o StrictHostKeyChecking=no   # Skip host key verification
```

### **Smart Key Detection**
```bash
# Script automatically finds and uses:
~/.ssh/id_ed25519     # Preferred (modern, secure)
~/.ssh/id_rsa         # Fallback (traditional)
# SSH agent keys      # If no files found
```

### **Connection Verification**
```bash
# Before deployment, script tests:
ssh $opts $key $target "echo 'SSH test successful'"

# Provides helpful troubleshooting if it fails:
# 1. Enable SSH: sudo systemctl enable ssh
# 2. Setup keys: ssh-copy-id user@pi
# 3. Test manual: ssh user@pi  
# 4. Check IP/hostname
```

## Error Handling Improvements

### **File Transfer Errors**
```bash
# Enhanced SCP with error handling:
scp $ssh_opts $ssh_key -r files/ pi@host:~/rew-receiver/ || {
    error "File transfer failed"
    echo "Try: ssh-copy-id $ssh_target"
    exit 1
}
```

### **Remote Execution Errors**  
```bash
# Enhanced SSH execution with fallback:
ssh $ssh_opts $ssh_key $target "commands" || {
    error "Remote execution failed"
    echo "Manual fallback: ssh $target"
    echo "cd ~/rew-receiver && ./remote-deploy.sh"
    exit 1
}
```

### **Docker Group Handling**
```bash
# Improved Pi-side Docker group activation:
if groups | grep -q docker; then
    ./deploy-to-pi.sh build-pi
else
    newgrp docker << 'COMMANDS'
    ./deploy-to-pi.sh build-pi
    COMMANDS
fi
```

## Complete Workflow

### **Option A: Automatic Setup (Recommended)**
```bash
cd pi-receiver

# 1. Setup SSH keys (one-time)
./deploy-to-pi.sh setup-ssh pi@192.168.1.100

# 2. Deploy to Pi (passwordless)  
./deploy-to-pi.sh deploy-remote pi@192.168.1.100

# 3. Check deployment
./deploy-to-pi.sh logs
```

### **Option B: Manual Setup**
```bash
# 1. Generate SSH key manually
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# 2. Copy key to Pi  
ssh-copy-id -i ~/.ssh/id_ed25519.pub pi@192.168.1.100

# 3. Deploy (will now use key automatically)
./deploy-to-pi.sh deploy-remote pi@192.168.1.100
```

## Troubleshooting

### **SSH Connection Issues**
```bash
# Test basic connectivity
ping 192.168.1.100

# Test SSH manually
ssh pi@192.168.1.100

# Enable SSH on Pi (if disabled)
sudo systemctl enable ssh
sudo systemctl start ssh
```

### **Permission Issues**
```bash
# Fix SSH key permissions
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 700 ~/.ssh

# Fix Pi-side permissions  
ssh pi@192.168.1.100
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### **Docker Group Issues**
```bash
# On Pi, after Docker installation:
sudo usermod -aG docker $USER

# Logout and back in, or:
newgrp docker
```

## Security Features

### **Key Types Supported**
- ✅ **ED25519**: Modern, secure (preferred)
- ✅ **RSA**: Traditional, compatible (fallback)
- ✅ **SSH Agent**: If keys are loaded in agent

### **Connection Security**
- ✅ **Key-based auth**: No password transmission
- ✅ **Connection timeout**: Prevents hanging
- ✅ **Keep-alive**: Maintains stable connections
- ✅ **Error recovery**: Graceful failure handling

### **Pi Security**
- ✅ **Non-root containers**: REW receiver runs as `rew` user
- ✅ **Minimal privileges**: Only required capabilities
- ✅ **Resource limits**: Container memory/CPU constraints
- ✅ **Health monitoring**: Automated container health checks

## Success Indicators

After running setup-ssh, you should see:
```
✅ SSH key generated: /home/user/.ssh/id_ed25519
✅ SSH key authentication is working!
You can now use: ./deploy-to-pi.sh deploy-remote pi@192.168.1.100
```

After deployment, you should see:
```
✅ SSH connectivity verified
✅ Files transferred successfully  
✅ Remote deployment completed successfully

Next steps:
1. SSH to Pi: ssh pi@192.168.1.100
2. Check status: cd ~/rew-receiver && ./deploy-to-pi.sh status
3. View logs: ./deploy-to-pi.sh logs
4. Test HTTP API: curl http://pi-ip:8080/status
```

## 🎉 Result

The Pi deployment now works seamlessly with SSH keys:
- **One-time setup**: `setup-ssh` command configures everything
- **Passwordless deployment**: No more password prompts during deployment
- **Error recovery**: Clear messages and fallback options if issues occur
- **Security**: Modern ED25519 keys with proper connection handling

Your Docker-based Pi receiver deployment is now production-ready! 🚀