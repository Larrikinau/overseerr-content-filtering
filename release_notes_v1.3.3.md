# Release Notes - v1.3.3: Enhanced Stability Release

**Release Date**: July 21, 2025  
**Version**: 1.3.3  

## 🚀 What's New

### 🏗️ **Enhanced Build Process**

This release addresses compatibility issues by providing improved build processes and enhanced stability.

- **✅ Stable Build**: Compiled with Node.js 18 LTS for maximum compatibility
- **✅ Enhanced Compatibility**: Eliminates architecture-specific compilation problems
- **✅ Improved Stability**: Clean build environment ensures reliable operation

### 📦 **Package Updates**

- **Package Name**: `overseerr-content-filtering-v1.3.3-ubuntu.tar.gz`
- **Size**: 118MB (optimized build)
- **Build Environment**: Clean Ubuntu 24.04 environment
- **Dependencies**: All included and verified

### 🛠️ **Technical Improvements**

- **Build Process**: Completely rebuilt from source with clean environment
- **Dependency Resolution**: All packages resolved and installed correctly
- **Performance**: Optimized build process for better performance
- **Compatibility**: Maximum compatibility with server environments

## 🔄 **Migration from Previous Versions**

### From v1.3.2 or Earlier

```bash
# Stop current service
sudo systemctl stop overseerr-content-filtering

# Download new version
wget https://github.com/Larrikinau/overseerr-content-filtering/releases/download/v1.3.3/overseerr-content-filtering-v1.3.3-ubuntu.tar.gz

# Extract and replace
sudo tar -xzf overseerr-content-filtering-v1.3.3-ubuntu.tar.gz -C /opt/overseerr-filtering --strip-components=1
sudo chown -R overseerr:overseerr /opt/overseerr-filtering

# Start service
sudo systemctl start overseerr-content-filtering
```

### Quick Update Script

```bash
curl -fsSL https://github.com/Larrikinau/overseerr-content-filtering/raw/main/install-overseerr-filtering.sh | sudo bash
```

## 🐛 **Bug Fixes**

- **Compatibility**: Resolved build issues for better compatibility
- **Dependency Conflicts**: Fixed Node.js module compatibility problems
- **Build Stability**: Eliminated compilation errors for more stable builds

## ⚙️ **System Requirements**

### Operating Systems
- Ubuntu 20.04+
- Debian 11+
- Other compatible Linux distributions

## 📋 **Installation Options**

### 1. Quick Install (Recommended)
```bash
curl -fsSL https://github.com/Larrikinau/overseerr-content-filtering/raw/main/install-overseerr-filtering.sh | bash
```

### 2. Docker
```bash
docker pull larrikinau/overseerr-content-filtering:1.3.3
docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -v /path/to/config:/app/config \
  larrikinau/overseerr-content-filtering:1.3.3
```

### 3. Manual Download
```bash
wget https://github.com/Larrikinau/overseerr-content-filtering/releases/download/v1.3.3/overseerr-content-filtering-v1.3.3-ubuntu.tar.gz
tar -xzf overseerr-content-filtering-v1.3.3-ubuntu.tar.gz
sudo ./install.sh
```

## 🔐 **Security & Verification**

### Package Verification
```bash
# Verify SHA256 checksum
sha256sum overseerr-content-filtering-v1.3.3-ubuntu.tar.gz
# Compare with: overseerr-content-filtering-v1.3.3-ubuntu.tar.gz.sha256
```

### Build Environment
- **Clean Environment**: Built in isolated Ubuntu 24.04 container
- **Verified Dependencies**: All dependencies verified and tested

## 📊 **Performance Improvements**

### Build Performance
- **Compilation Speed**: Optimized build process
- **Enhanced Optimization**: Build-specific optimizations enabled
- **Memory Usage**: Efficient memory utilization during build

### Runtime Performance
- **Startup Time**: Improved application startup
- **Memory Footprint**: Optimized memory management
- **Processing Speed**: Enhanced overall performance

## 🔄 **Docker Hub Updates**

### Available Tags
- `larrikinau/overseerr-content-filtering:1.3.3` - Latest stable version
- `larrikinau/overseerr-content-filtering:latest` - Always points to latest release

### Docker Usage
```bash
# Pull latest version
docker pull larrikinau/overseerr-content-filtering:latest

# Pull specific version
docker pull larrikinau/overseerr-content-filtering:1.3.3
```

## 📚 **Documentation Updates**

- All installation documentation updated for v1.3.3
- Docker deployment guides refreshed
- Migration instructions updated for seamless upgrades

## 🤝 **Support & Troubleshooting**

### Common Issues
- **System Compatibility**: Ensure you're running on compatible systems
- **Legacy Installations**: Migration from older versions is fully supported

### Getting Help
- **GitHub Issues**: https://github.com/Larrikinau/overseerr-content-filtering/issues
- **Documentation**: https://github.com/Larrikinau/overseerr-content-filtering
- **Discussions**: https://github.com/Larrikinau/overseerr-content-filtering/discussions

---

**Full Changelog**: https://github.com/Larrikinau/overseerr-content-filtering/compare/v1.3.2...v1.3.3
