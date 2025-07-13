# 🎉 Release Notes - v1.1.5: TMDB Curated Discovery

**Released**: July 13, 2025  
**Type**: Major Feature Release  
**Compatibility**: Full backward compatibility with existing installations

---

## 🚀 **Major New Feature: TMDB Curated Discovery**

Version 1.1.5 introduces a revolutionary content discovery system that transforms how users find and explore media. This isn't just an update—it's a complete reimagining of content discovery with intelligent quality filtering.

### ✨ **What's New**

#### 🎯 **Quality-First Discovery Engine**
- **Admin-Configurable Thresholds**: Set minimum vote counts and ratings for curated content
- **Default Settings**: 3000+ votes and 6.0+ rating ensure only quality content appears
- **Granular Control**: Fine-tune quality standards for your specific media preferences

#### 🔄 **Dual Discovery Modes**
- **Standard Mode**: Shows all available content (traditional Overseerr behavior)
- **Curated Mode**: Applies quality filtering to show only high-quality content
- **User Toggle**: Allow users to switch between modes or enforce admin-only control
- **Seamless Transition**: Switch modes instantly without page reloads

#### 🎬 **Enhanced Content Recommendations**
- **Smart Similar Content**: "Similar Movies/Shows" now use curated filtering
- **Quality Recommendations**: Movie and TV recommendations prioritize high-quality content
- **Intelligent Suggestions**: Combines user preferences with quality metrics
- **Performance Optimized**: Faster loading with reduced API calls

#### ⚙️ **Administrative Control**
- **Global Configuration**: Set organization-wide quality standards
- **Per-User Permissions**: Control which users can change discovery modes
- **Custom Thresholds**: Override global settings for specific user groups
- **Settings Integration**: Seamlessly integrated into existing admin interface

### 🔧 **Technical Improvements**

#### 🏗️ **Privacy & Security Enhancements**
- **Complete Data Sanitization**: All personal information removed from release packages
- **Environment Variable Support**: API keys and sensitive data properly externalized
- **Clean Build Process**: Automated sanitization during package creation
- **No Personal Paths**: Release packages contain no developer-specific information

#### 🛠️ **Build System Overhaul**
- **TypeScript Fixes**: Resolved method naming conflicts (getSimilarMovies/getSimilarTvShows)
- **Compilation Improvements**: Fixed build errors and type mismatches
- **macOS Compatibility**: Removed ._ attribute files that caused build issues
- **Ubuntu/Debian Optimization**: Native package format for Linux distributions

#### 📦 **Release Package Updates**
- **Versioned Naming**: Clear version identification in package names
- **Standalone Installer**: Included `install.sh` script for easy manual installation
- **Checksum Verification**: SHA256 checksums for package integrity verification
- **Documentation Updates**: Comprehensive installation and configuration guides

---

## 🎯 **Use Cases & Benefits**

### 🏠 **Home Media Servers**
- **Family-Friendly Discovery**: Quality filtering ensures appropriate content for all ages
- **Reduced Clutter**: Hide low-quality or obscure content from main discovery
- **Better Recommendations**: Surface content family members actually want to watch

### 🏢 **Enterprise Deployments**
- **Content Curation**: Maintain professional media libraries with quality standards
- **User Experience**: Improve content discovery efficiency for large organizations
- **Administrative Control**: Centralized quality management across user base

### 👨‍👩‍👧‍👦 **Multi-User Households**
- **Personalized Discovery**: Different quality standards for different family members
- **Age-Appropriate Content**: Combine quality filtering with existing rating controls
- **Flexible Configuration**: Toggle between discovery modes based on context

---

## 📋 **Configuration Guide**

### **Admin Setup (Required)**
1. Navigate to **Settings** → **General**
2. Locate **TMDB Curated Discovery** section
3. Configure global settings:
   ```
   Default Min Votes: 3000 (recommended)
   Default Min Rating: 6.0 (recommended)
   Allow User Override: Yes/No (your choice)
   ```

### **User Configuration (If Permitted)**
1. Access **Settings** → **General**
2. Find **Discovery Preferences**
3. Choose discovery mode:
   - **Standard**: Show all content
   - **Curated**: Apply quality filtering

### **Advanced Configuration**
- **Custom Thresholds**: Adjust per-user quality standards
- **Content Type Specific**: Different settings for movies vs TV shows
- **Genre-Based Filtering**: Apply different standards to different genres

---

## 🔄 **Migration & Compatibility**

### **Existing Installations**
- ✅ **Zero Breaking Changes**: All existing functionality preserved
- ✅ **Database Compatibility**: Existing settings and preferences maintained
- ✅ **User Accounts**: No impact on existing user configurations
- ✅ **Content Filtering**: All previous rating controls continue working

### **Upgrade Process**
- **Automatic Migration**: Database schema updates happen seamlessly
- **Default Behavior**: Existing users default to "Standard" mode (no change)
- **Gradual Adoption**: Enable curated discovery at your own pace

---

## 🛠️ **Installation Options**

### **Quick Installation (Recommended)**
```bash
curl -fsSL https://raw.githubusercontent.com/Larrikinau/overseerr-content-filtering/main/install-overseerr-filtering.sh | sudo bash
```

### **Manual Package Installation**
```bash
# Download v1.1.5 package
wget https://github.com/Larrikinau/overseerr-content-filtering/releases/download/v1.1.5/overseerr-content-filtering-v1.1.5-ubuntu.tar.gz

# Verify integrity
wget https://github.com/Larrikinau/overseerr-content-filtering/releases/download/v1.1.5/overseerr-content-filtering-v1.1.5-ubuntu.tar.gz.sha256
sha256sum -c overseerr-content-filtering-v1.1.5-ubuntu.tar.gz.sha256

# Extract and install
tar -xzf overseerr-content-filtering-v1.1.5-ubuntu.tar.gz
cd overseerr-content-filtering-v1.1.5
sudo ./install.sh
```

### **Docker Deployment**
```bash
docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -v /path/to/config:/app/config \
  --restart unless-stopped \
  larrikinau/overseerr-content-filtering:v1.1.5
```

---

## 📊 **Performance Impact**

### **Optimization Highlights**
- **Reduced API Calls**: Intelligent parameter combination minimizes external requests
- **Faster Loading**: Curated content loads more quickly due to focused datasets
- **Memory Efficiency**: Optimized caching for frequently accessed quality metrics
- **Database Performance**: Efficient indexing for new quality-based queries

### **Resource Usage**
- **CPU Impact**: Minimal additional processing for quality calculations
- **Memory Usage**: Slight increase for caching quality thresholds
- **Network Traffic**: Actually reduced due to more targeted API requests
- **Storage**: Negligible impact on database size

---

## 🐛 **Bug Fixes & Improvements**

### **Resolved Issues**
- 🔧 **TypeScript Compilation**: Fixed method naming conflicts in TMDB API calls
- 🔧 **Build Process**: Removed macOS metadata files causing Linux build issues
- 🔧 **Docker Support**: Improved container startup and configuration handling
- 🔧 **Database Migrations**: Enhanced automatic migration process reliability

### **Code Quality**
- 📝 **Type Safety**: Improved TypeScript definitions for better development experience
- 🧹 **Code Cleanup**: Removed unused dependencies and optimized bundle size
- 🔍 **Error Handling**: Enhanced error reporting for troubleshooting
- 📊 **Logging**: Improved debug information for configuration issues

---

## 🆘 **Support & Documentation**

### **New Documentation**
- 📖 **Configuration Guide**: Step-by-step setup for curated discovery
- 🔧 **Troubleshooting**: Common issues and solutions
- 🏗️ **Technical Implementation**: Detailed architecture documentation
- 📝 **Migration Guide**: Upgrading from previous versions

### **Getting Help**
- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/Larrikinau/overseerr-content-filtering/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/Larrikinau/overseerr-content-filtering/discussions)
- 📖 **Wiki**: [Project Documentation](https://github.com/Larrikinau/overseerr-content-filtering/wiki)

---

## 🔮 **What's Next**

### **Planned Features (v1.2.x)**
- **Genre-Specific Filtering**: Different quality standards per genre
- **User Rating Integration**: Incorporate personal rating history
- **Advanced Analytics**: Content discovery usage statistics
- **API Extensions**: External integrations for quality data

### **Community Feedback**
I'm eager to hear how you're using TMDB Curated Discovery! Share your experiences, suggestions, and use cases to help shape future development.

---

## 🙏 **Acknowledgments**

Special thanks to:
- The TMDB community for providing comprehensive movie/TV data
- Beta testers who provided valuable feedback during development
- The original Overseerr team for creating an excellent foundation
- Contributors who helped identify and resolve build issues

---

**Enjoy the enhanced content discovery experience in v1.1.5!** 🎬✨
