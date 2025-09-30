# Overseerr Content Filtering

<p align="center">
<img src="./public/logo_full.svg" alt="Overseerr Content Filtering" style="margin: 20px 0;">
</p>

<p align="center">
<strong>🔒 Enhanced Content Management with Admin-Controlled Rating Filters</strong>
</p>

<p align="center">
<a href="#installation"><img src="https://img.shields.io/badge/Install-Docker%20Ready-brightgreen" alt="Docker Install"></a>&nbsp;
<a href="#features"><img src="https://img.shields.io/badge/Feature-Content%20Filtering-orange" alt="Content Filtering"></a>&nbsp;
<a href="LICENSE"><img alt="GitHub" src="https://img.shields.io/github/license/sct/overseerr"></a>
</p>

## Overview

**Overseerr Content Filtering** is a specialized fork of Overseerr that adds **admin-controlled content rating filters** for family-safe media management. **Version 1.4.2** provides comprehensive content filtering capabilities while preserving all original Overseerr functionality, with the latest Plex API compatibility fixes.

### 🔧 **What's Fixed in v1.4.2**

- **🔗 Updated Plex API Endpoints**: Fixed Plex watchlist synchronization by updating from deprecated `metadata.provider.plex.tv` to new `discover.provider.plex.tv`
- **✅ Resolved 404 Errors**: Eliminates persistent "Failed to retrieve watchlist items" errors in logs
- **🚀 Enhanced Compatibility**: Full compatibility with Plex Media Server 1.42.1+ versions
- **📱 Seamless Integration**: All existing Plex functionality preserved with updated APIs

### 🚀 **Core Features from v1.4.0**

- **🔒 Admin-Only Content Controls**: Only administrators can set content rating limits for users
- **🛡️ Smart Content Blocking**: Adult content blocked by default, with admin-configurable per-user rating limits
- **🎬 Content Rating Filtering**: Filter by G, PG, PG-13, R, NC-17 (movies) and TV-Y through TV-MA (TV shows)
- **👤 Per-User Configuration**: Admins can set different rating limits for each individual user
- **🔐 User Protection**: Regular users cannot see or change their own rating restrictions
- **🔑 Flexible API Key Management**: Environment variable support for TMDB and other APIs
- **🐳 Enhanced Docker Support**: Containerized deployment with automatic migrations
- **📊 Database Schema Updates**: Added content filtering columns with automatic migration
- **⚡ Performance Optimized**: Minimal overhead on existing Overseerr functionality

### 🔑 **API Key Improvements in v1.4.0**

**v1.4.0 moves away from hardcoded API keys to flexible configuration:**

- **Environment Variable Support**: Set `TMDB_API_KEY` and other external service API keys via Docker environment variables
- **Private API Key Support**: Use your own private TMDB, Rotten Tomatoes, or other API keys if desired
- **Fallback to Existing Keys**: If no environment variables are set, uses the same API keys that come with standard Overseerr
- **Existing Configuration Preserved**: Your current API keys (if configured) are automatically retained during upgrade
- **No Configuration Required**: Works out-of-the-box with default API keys, just like standard Overseerr

### 🎆 **Why Use Private API Keys? (Optional but Recommended)**

**✨ This application works perfectly without private API keys**, but using your own provides several benefits:

#### **💰 They're Free!**
- **TMDB API**: Free forever - just sign up at https://www.themoviedb.org/settings/api
- **Rotten Tomatoes API**: Free tier available - sign up at https://developer.fandango.com/rotten_tomatoes
- **Takes 2-3 minutes** to get your keys

#### **🚀 Performance Benefits:**
- **Higher Rate Limits**: Your own dedicated API quota instead of shared limits
- **Faster Response Times**: Direct API access without potential throttling
- **More Reliable Service**: Not dependent on shared API key availability
- **Better Uptime**: If shared keys have issues, your private keys keep working

#### **🔒 Privacy Benefits:**
- **Your Own Quota**: API calls don't count against shared community limits
- **Independent Service**: Not affected by other users' API usage patterns
- **Direct Relationship**: You control your own API terms and usage

#### **🔧 Easy Setup:**
```yaml
environment:
  - TMDB_API_KEY=your_private_tmdb_key_here
```

**⚠️ Remember: This is completely optional!** The application works great with the included API keys - private keys just give you better performance and reliability.

## 🎯 What This Fork Provides

### **Core Content Filtering Features:**

✅ **Administrator-Controlled Rating Limits**
- Only admins can modify content rating settings for any user
- Per-user configuration with different rating limits for each user
- Centralized management through standard admin interface

✅ **Comprehensive Rating System**
- **Movies**: G, PG, PG-13, R, NC-17 filtering
- **TV Shows**: TV-Y, TV-Y7, TV-G, TV-PG, TV-14, TV-MA filtering
- **Default Settings**: New users start with family-safe PG-13/TV-PG limits

✅ **Smart Content Blocking**
- Adult content blocked by default for all users, with admin-configurable rating overrides
- Applied consistently across all discovery, search, and browsing
- Hardcoded filtering logic bypasses API inconsistencies for reliable results

✅ **Seamless Integration**
- All original Overseerr features preserved and functional
- Content filtering applied automatically to all endpoints
- No impact on existing workflows or user experience

### **Enhanced Discovery Features:**

✅ **Quality-Based Filtering**: Content filtered by vote count and rating thresholds  
✅ **Curated Discovery Mode**: Enhanced discovery with quality controls  
✅ **Admin-Configurable Thresholds**: Set minimum votes and ratings for content  
✅ **Multi-Layer Content Filtering**: Combined rating and quality filtering system

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
- **Automatic Application**: Filtering works across all discovery and search
- **Family-Safe Defaults**: New users start with age-appropriate content settings
- **Reliable Implementation**: Content filtering applied consistently across all endpoints

### 🚀 **All Original Overseerr Features**

- Full Plex integration with user authentication
- Seamless Sonarr and Radarr integration
- Customizable request system for movies and TV shows
- Granular permission system
- Mobile-friendly responsive design
- Multiple notification agents
- Real-time request management

## 🔄 Migrating from Existing Overseerr?

### 📋 **One-Time Migration to v1.4.0**

**Already have Overseerr installed?** Migrate to overseerr-content-filtering with these commands that preserve all your data:

```bash
curl -fsSL https://github.com/Larrikinau/overseerr-content-filtering/raw/main/migrate-to-overseerr-content-filtering.sh -o migrate-to-overseerr-content-filtering.sh
chmod +x migrate-to-overseerr-content-filtering.sh
./migrate-to-overseerr-content-filtering.sh
```

### 🔑 **What This Migration Preserves:**

- ✅ **Your Complete Docker Setup**: All volumes, networks, ports, restart policies, and custom configurations
- ✅ **Your Existing API Keys**: If you've configured private TMDB, TVDB, or other API keys, they're kept exactly as-is
- ✅ **All Your Data**: Users, requests, settings, Plex configuration, notification settings, everything
- ✅ **Custom Environment Variables**: Any custom environment variables you've added are preserved
- ✅ **Network Configuration**: Custom networks, port mappings, and Docker Compose configurations maintained

### ⚡ **Simple Updates for v1.4.0+ Users**

**🎉 Already running v1.4.0? Upgrading to v1.4.2 is just a standard Docker update!**

#### **For v1.4.0 → v1.4.2 (Simple Docker Update)**

```bash
# Pull the latest version with Plex API fixes
docker pull larrikinau/overseerr-content-filtering:latest

# Restart your container
docker-compose restart overseerr-content-filtering
# OR if using docker run:
docker stop overseerr-content-filtering
docker rm overseerr-content-filtering
# Then run your original docker run command with :latest
```

**That's it! No migration script needed for v1.4.0 → v1.4.2 upgrades.**

### 🔄 **Migration Script vs Simple Updates**

#### **Migration Script Required For:**
- **Pre-v1.4.0 Overseerr installations** (any version before 1.4.0)
- **Other Overseerr forks** migrating to this content filtering fork
- **Snap/Systemd installations** moving to Docker

#### **Simple Docker Pull For:**
- **✅ v1.4.0 → v1.4.2** - Just pull latest image and restart
- **✅ Any future v1.4.x updates** - Standard Docker workflows
- **✅ v1.4.0+ users** - No migration scripts ever needed again

**Why the difference?**
- v1.4.0 **containerized** the entire application properly
- v1.4.2+ releases are **standard Docker image updates**
- Your configuration is now **portable** and **version-controlled**
- Database migrations run automatically in Docker containers

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

### 🚀 Option 1: Docker Installation (Recommended)

**Best for:** Most users who want quick setup and easy updates

**Advantages:**

- ✅ **Instant deployment** - pre-built Docker images
- ✅ **Tested and verified** - production-ready containers
- ✅ **Easy updates** - simple `docker pull` updates
- ✅ **Isolated environment** - containerized for security
- ✅ **Cross-platform** - works on any Docker-capable system

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
| **Home media server**        | Docker             | Quick setup, reliable        |
| **Production deployment**    | Docker             | Tested, optimized            |
| **Quick testing**            | Docker             | Fastest to try               |
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

### Rating System

- **Movies**: G → PG → PG-13 → R → NC-17 (admins set maximum allowed rating per user)
- **TV Shows**: TV-Y → TV-Y7 → TV-G → TV-PG → TV-14 → TV-MA (admins set maximum allowed rating per user)
- **Defaults**: New users start with PG-13 (movies) and TV-PG (TV shows) for family-safe browsing
- **Smart Default**: Adult content blocked by default, with admin-configurable overrides per user

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
