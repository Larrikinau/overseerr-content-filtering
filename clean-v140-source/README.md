# Overseerr Content Filtering with TMDB Curated Discovery

<p align="center">
<img src="./public/logo_full.svg" alt="Overseerr Content Filtering" style="margin: 20px 0;">
</p>

<p align="center">
<strong>🔒 Enhanced Content Management</strong>
</p>

<p align="center">
<a href="#installation"><img src="https://img.shields.io/badge/Install-Quick%20Setup-brightgreen" alt="Quick Install"></a>&nbsp;
<a href="#features"><img src="https://img.shields.io/badge/Feature-Content%20Filtering-orange" alt="Content Filtering"></a>&nbsp;
<a href="LICENSE"><img alt="GitHub" src="https://img.shields.io/github/license/sct/overseerr"></a>
</p>

## Overview

**Overseerr Content Filtering** is an enhanced fork of Overseerr that adds intelligent content filtering capabilities with enterprise-grade family safety controls. **Version 1.3.5** represents a major stability and feature release with comprehensive improvements to content discovery, API handling, and user experience.

### 🚀 **What's New in v1.3.5: Major Feature & Stability Release**

- **🎯 Enhanced Content Filtering System**: Complete overhaul with advanced genre, rating, and keyword filters
- **🌟 TMDB Curated Discovery**: Advanced movie and TV show discovery with curated content recommendations
- **🔧 API Improvements**: Enhanced Sonarr/Radarr integration with better error handling and retry logic
- **🐛 Critical Bug Fixes**: Fixed TMDB API key handling and database migration issues
- **🏗️ Technical Improvements**: Enhanced error handling, performance optimizations, and code quality
- **📚 Documentation**: Updated installation guides and comprehensive setup instructions
- **🚀 Docker Hub**: Updated images larrikinau/overseerr-content-filtering:1.3.5 and :latest

**📋 Major Changes in v1.3.5:**

- **✨ Advanced Discover Interface**: Redesigned discovery page with enhanced filtering capabilities
- **🎮 Content Rating Preferences**: User-configurable rating system preferences (TMDB, IMDB, RT)
- **🔄 Database Schema Updates**: Added content filtering columns and rating preference storage
- **🛡️ Better TMDB API Management**: Robust API key validation and error handling
- **⚡ Performance Optimizations**: Improved query performance and caching strategies

### 📋 **TMDB Curated Discovery**

This major release introduces an entirely new content discovery paradigm:

- **🎯 Quality-First Discovery**: Admin-configurable minimum vote counts and ratings ensure only high-quality content appears in discovery
- **🔄 Dual Discovery Modes**: Users can toggle between 'Standard' (all content) and 'Curated' (quality-filtered) discovery experiences
- **🎬 Enhanced Recommendations**: Movie/TV recommendations and "similar content" suggestions now use intelligent quality filtering
- **⚙️ Admin Control**: Set global quality thresholds (default: 3000+ votes, 6.0+ rating) with granular user permissions
- **🚀 Performance Optimized**: Smart API parameter combination minimizes external calls while maximizing content quality

## 📋 Why This Fork Exists: Comprehensive Content Filtering

Overseerr with TMDB Curated Discovery provides a refined content experience:

### Key Features:

- **Standard Discovery Mode**: Shows content with all existing safety and age rating controls active (no quality filtering)
- **Curated Discovery Mode**: Adds quality-based filtering on top of existing safety controls (vote counts, ratings)
- Separate TV rating filters for precise content control
- Search offers results within admin-configured safety boundaries
- Discovery and recommendations incorporate curated quality filtering when enabled

Adult content is universally blocked for enhanced safety. Users can toggle between 'Standard' (safety + age rating controls) and 'Curated' (safety + age rating + quality controls) discovery modes.

1. **User Preference Storage**: Individual rating limits stored in user settings
2. **Multi-Layer Protection**: Combined API-level and application-level filtering
3. **Automatic Application**: All discovery, search, and browse results filtered
4. **Performance Optimized**: Minimal overhead on existing functionality

### How Content Filtering Works

This fork uses **dual-layer filtering architecture** to ensure reliable content management across all age rating categories.

**📖 For detailed technical explanation:** See [TECHNICAL_IMPLEMENTATION.md](TECHNICAL_IMPLEMENTATION.md)

**Key Features:**

- Admin-configurable movie ratings (G, PG, PG-13, R, NC-17)
- Admin-configurable TV ratings (TV-Y, TV-Y7, TV-G, TV-PG, TV-14, TV-MA)
- Hardcoded baseline safety parameters for API reliability
- Database-driven user preferences with family-safe defaults
- Comprehensive filtering across all discovery and search endpoints

## ✨ Enhanced Features

### 🛡️ **Smart Content Blocking**

- **Default Safety**: Adult content blocked by default for all users
- **Admin Override**: Administrators can configure individual user rating limits as needed
- **Consistent Enforcement**: Applied to all discovery, search, and genre browsing
- **TMDb API Override**: Hardcoded filtering bypasses API inconsistencies

### 👥 **Admin-Only Content Controls**

- **Centralized Management**: Only admins can modify content rating settings for any user
- **Per-User Configuration**: Admins can set different rating limits for each individual user
- **User Protection**: Regular users cannot see or change their own rating restrictions
- **Permission-Based**: Uses standard admin permissions for consistency
- **Setting Preservation**: Existing rating preferences maintained during upgrade

### 🔧 **Enhanced Docker Support**

- **Automatic Migrations**: Database migrations run automatically in Docker environments
- **Environment Detection**: Smart detection of development vs production environments
- **Comprehensive Logging**: Detailed migration status and error reporting
- **Troubleshooting Guide**: Complete `DOCKER_TROUBLESHOOTING.md` documentation
- **Build Fixes**: Resolved TypeScript compilation and build system issues

### 🔒 **Smart Content Filtering**

- **Movie Ratings**: Admin-configurable limits from G through NC-17
- **TV Ratings**: Admin-configurable limits from TV-Y through TV-MA
- **Automatic application**: Filtering works across all discovery and search
- **Family-safe defaults**: New users start with age-appropriate content settings
- **Professional implementation**: Dual-layer filtering architecture for reliability

### 🎯 **TMDB Curated Discovery**

- **Standard Mode**: Shows content with all existing safety and age rating controls (no quality filtering added)
- **Curated Mode**: Adds admin-configurable quality thresholds on top of existing safety controls
- **Discovery vs Search**: Search returns results within safety boundaries; discovery applies additional quality filters in curated mode
- **Recommendation Enhancement**: Movie/TV recommendations and similar content use curated filtering when enabled
- **User Control**: Toggle between 'Standard' (safety + age rating controls) and 'Curated' (safety + age rating + quality controls)
- **Admin Configuration**: Set global quality thresholds that I define (default: 3000+ votes, 6.0+ rating)
- **Performance Optimized**: Intelligent parameter combination minimizes API calls

### 🚀 **All Original Overseerr Features**

- Full Plex integration with user authentication
- Seamless Sonarr and Radarr integration
- Customizable request system for movies and TV shows
- Granular permission system
- Mobile-friendly responsive design
- Multiple notification agents
- Real-time request management

## 🔄 Migrating from Existing Overseerr?

**Already have Overseerr installed?** Migrate to overseerr-content-filtering with these commands that preserve all your data:

```bash
curl -fsSL https://github.com/Larrikinau/overseerr-content-filtering/raw/main/migrate-to-content-filtering.sh -o migrate-to-content-filtering.sh
chmod +x migrate-to-content-filtering.sh
sudo ./migrate-to-content-filtering.sh
```

**Migration Features:**

- ✅ **Migrates FROM**: Docker, Snap, or systemd installations
- ✅ **Migrates TO**: Docker container (larrikinau/overseerr-content-filtering:latest)
- ✅ **100% data preservation**: Users, requests, settings, database
- ✅ **Automatic backup**: Creates timestamped backups before migration
- ✅ **Seamless transition**: ~2-5 minutes with zero downtime

📖 **[Complete Migration Guide](MIGRATION_GUIDE.md)** - Detailed instructions and troubleshooting

## 🛠️ Troubleshooting & Diagnostics

### 🔍 **Automatic Diagnostics**

If you're experiencing issues with your Overseerr Content Filtering installation, run the automated diagnostic script:

```bash
# Download and run diagnostic script
curl -fsSL https://github.com/Larrikinau/overseerr-content-filtering/raw/main/diagnose-overseerr-issues.sh | bash
```

This script will:

- ✅ Check container status and configuration
- ✅ Verify database integrity and migrations
- ✅ Test API connectivity and Plex integration
- ✅ Validate environment variables and settings
- ✅ Generate detailed diagnostic report

### 📚 **Comprehensive Troubleshooting Guides**

- **[Plex Scan Troubleshooting](PLEX_SCAN_TROUBLESHOOTING.md)** - Diagnose and fix Plex scan failures
- **[TVDB Configuration Guide](TVDB_CONFIGURATION.md)** - Optional TVDB API setup and troubleshooting
- **[Docker Deployment Guide](DOCKER_DEPLOYMENT.md)** - Advanced Docker configuration and security
- **[Migration Guide](MIGRATION_GUIDE.md)** - Complete migration instructions and troubleshooting

### 🎯 **Common Issues & Quick Fixes**

#### Migration Script Issues

- **Mount detection problems**: Enhanced detection logic handles various Docker configurations
- **Region settings not migrated**: Automatic region/locale extraction from existing settings
- **TVDB API key warnings**: TVDB is now optional, migration continues gracefully

#### Plex Integration Issues

- **Scan failures**: Use diagnostic script to check authentication and connectivity
- **Missing libraries**: Verify Plex settings and library synchronization
- **Token issues**: Re-authenticate or manually configure Plex token

#### Database Issues

- **Migration failures**: Docker containers now run migrations automatically
- **Content filtering not working**: Diagnostic script verifies column existence
- **Performance issues**: Built-in database optimization recommendations

---

## 📥 Installation

**Two Installation Options Available:**

### 🚀 Option 1: Pre-built Installation (Recommended)

**Best for:** Most users who want quick setup without compilation

**Advantages:**

- ✅ **Instant deployment** - no compilation time
- ✅ **Tested binaries** - pre-built and verified
- ✅ **Minimal dependencies** - no Node.js/build tools required
- ✅ **Easy updates** - simple container/package updates
- ✅ **Production ready** - optimized builds

#### Quick Install Script

```bash
curl -fsSL https://github.com/Larrikinau/overseerr-content-filtering/raw/main/install-overseerr-filtering.sh | bash
```

#### Pre-built Package Download

```bash
# Download the latest pre-built package (v1.3.5)
wget https://github.com/Larrikinau/overseerr-content-filtering/releases/download/v1.3.5/overseerr-content-filtering-v1.3.5-ubuntu.tar.gz

# Extract and install
tar -xzf overseerr-content-filtering-v1.3.5-ubuntu.tar.gz
cd overseerr-content-filtering-v1.3.5-ubuntu
sudo ./install.sh
```

#### Docker (Recommended)

✅ **Now Available on Docker Hub** - No workarounds needed!

```bash
sudo docker pull larrikinau/overseerr-content-filtering:latest

sudo docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -e TMDB_API_KEY=db55323b8d3e4154498498a75642b381 \
  -v /path/to/appdata/config:/app/config \
  --restart unless-stopped \
  larrikinau/overseerr-content-filtering:latest
```

🔗 **Docker Hub Repository**: https://hub.docker.com/r/larrikinau/overseerr-content-filtering

📦 **Latest Version**: `larrikinau/overseerr-content-filtering:latest`

📖 **[Complete Docker Deployment Guide](DOCKER_DEPLOYMENT.md)** - Advanced configuration, security, troubleshooting

#### Docker Compose

```yaml
version: '3.8'
services:
  overseerr-content-filtering:
    image: larrikinau/overseerr-content-filtering:latest
    container_name: overseerr-content-filtering
    ports:
      - 5055:5055
    volumes:
      - /path/to/appdata/config:/app/config
    environment:
      - TMDB_API_KEY=db55323b8d3e4154498498a75642b381  # Required for movie/TV data
      - NODE_ENV=production
      - RUN_MIGRATIONS=true
    restart: unless-stopped
```

### 🔧 Option 2: Build from Source

**Best for:** Developers, customization needs, or contributing to the project

**Advantages:**

- ✅ **Full control** - modify code before building
- ✅ **Latest changes** - access to unreleased features
- ✅ **Development setup** - for contributing improvements
- ✅ **Custom builds** - optimize for specific environments
- ✅ **Learning opportunity** - understand the codebase

**Requirements:**

- Node.js 18+ and npm/yarn
- Git
- 15-20 minutes build time

#### Development Setup

```bash
git clone https://github.com/Larrikinau/overseerr-content-filtering.git
cd overseerr-content-filtering
yarn install
yarn dev
```

#### Production Build

```bash
yarn build
yarn start
```

---

### 🤔 Which Option Should You Choose?

| Use Case                     | Recommended Option | Why                          |
| ---------------------------- | ------------------ | ---------------------------- |
| **Home media server**        | Pre-built (Docker) | Quick setup, reliable        |
| **Production deployment**    | Pre-built (Docker) | Tested, optimized            |
| **Quick testing**            | Pre-built (Script) | Fastest to try               |
| **Development/Contributing** | Build from Source  | Full development environment |
| **Custom modifications**     | Build from Source  | Need to modify code          |
| **Learning the codebase**    | Build from Source  | Understand implementation    |

## 🔧 Configuration

### Content Filtering Setup

**Admin Users Only:**

1. Navigate to **Users**
2. Click **Edit** on the user you want to configure
3. Go to **General** tab
4. Configure **Content Rating Filtering** for that specific user:
   - **Max Movie Rating**: Set maximum allowed movie rating for this user
   - **Max TV Rating**: Set maximum allowed TV show rating for this user
5. Save settings - filtering applies immediately to that user

**Important Notes:**

- **Admin Control**: Only administrators can modify content rating settings for any user
- **Per-User Settings**: Admins can set different rating limits for each individual user
- **User Restrictions**: Regular users cannot see or change their own rating restrictions
- **Centralized Management**: All content filtering decisions are made by administrators

### TMDB Curated Discovery Setup

**Admin Configuration:**

1. Navigate to **Settings** → **General**
2. Configure **TMDB Curated Discovery** settings:
   - **Default Min Votes**: Set global minimum vote count threshold (default: 3000)
   - **Default Min Rating**: Set global minimum rating threshold (default: 6.0)
   - **Allow User Override**: Whether users can change their discovery mode

**User Configuration:**

1. Navigate to **Settings** → **General** (if allowed by admin)
2. Configure **Discovery Preferences**:
   - **Discovery Mode**: Choose between 'Standard' (safety + age rating controls) and 'Curated' (safety + age rating + quality controls)
   - **Custom Thresholds**: Adjust personal quality preferences within admin-defined ranges (if enabled)

### Rating System

- **Movies**: G → PG → PG-13 → R → NC-17 (admins set maximum allowed rating per user)
- **TV Shows**: TV-Y → TV-Y7 → TV-G → TV-PG → TV-14 → TV-MA (admins set maximum allowed rating per user)
- **Defaults**: New users start with PG-13 (movies) and TV-PG (TV shows) for family-safe browsing
- **Curated Quality**: Default 3000+ votes and 6.0+ rating for curated discovery

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/enhancement`)
3. Commit changes (`git commit -am 'Add enhancement'`)
4. Push to branch (`git push origin feature/enhancement`)
5. Create a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Original [Overseerr](https://github.com/sct/overseerr) project and contributors
- The open-source community for inspiration and support

## 📞 Support

- 📖 [Documentation](docs/)
- 🐛 [Issue Tracker](../../issues)
- 💬 [Discussions](../../discussions)

---

<p align="center">
Built with ❤️ for better content management
</p>
