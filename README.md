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

**Overseerr Content Filtering** is a specialized fork of Overseerr that adds **admin-controlled content rating filters** for family-safe media management. **Version 1.5.4** is based on **upstream Overseerr v1.34.0** (latest release) and provides comprehensive content filtering capabilities while preserving all original Overseerr functionality.

### 🚀 **Core Features**

- **🔒 Admin-Only Content Controls**: Only administrators can set content rating limits for users
- **🛡️ Smart Content Blocking**: Content filtered by rating across all discovery, search, and browse functions
- **🎬 Content Rating Filtering**: Filter by G, PG, PG-13, R, NC-17 (movies) and TV-Y through TV-MA (TV shows)
- **👤 Per-User Configuration**: Admins can set different rating limits for each individual user
- **🔐 User Protection**: Regular users cannot see or change their own rating restrictions
- **📊 Database Schema Updates**: Content filtering columns with automatic migrations
- **⚡ Performance Optimized**: Minimal overhead on existing Overseerr functionality
- **🐳 Production Ready**: Containerized deployment with automatic database migrations

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

## 🔄 Switching from Standard Overseerr?

**Already have standard Overseerr installed?** Switching is simple - just swap the Docker image!

### 📋 **Simple 3-Step Switch**

```bash
# 1. Stop your existing Overseerr container
docker stop overseerr && docker rm overseerr

# 2. Start this fork using the SAME config volume
docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -v overseerr_config:/app/config \
  -e TMDB_API_KEY=db55323b8d3e4154498498a75642b381 \
  --restart unless-stopped \
  larrikinau/overseerr-content-filtering:latest

# 3. That's it! Your data, users, and settings are preserved.
```

### 🔑 **About the TMDB API Key**

**The API key shown above (`db55323b8d3e4154498498a75642b381`) is the standard Overseerr community key.**

- ✅ **Works out-of-the-box** - No signup required
- ✅ **Same key standard Overseerr uses** - Shared community key
- ✅ **100% Free** - No costs or restrictions

**Want your own private API key?** (Optional but recommended for better performance)

1. Sign up at https://www.themoviedb.org/signup
2. Get your API key at https://www.themoviedb.org/settings/api
3. Replace the key in the Docker command above with your own
4. **Benefits**: Higher rate limits, faster responses, independent quota

### ✅ **What Gets Preserved**

- ✅ **All your data**: Users, requests, settings, history
- ✅ **Plex configuration**: Servers, libraries, authentication
- ✅ **Sonarr/Radarr**: All download client configurations
- ✅ **Notifications**: All notification agent setups
- ✅ **Database**: Complete SQLite database with all relationships

### 🔄 **Updating This Fork**

Once you're running this fork, updates are simple:

```bash
# Pull the latest version
docker pull larrikinau/overseerr-content-filtering:latest

# Restart your container
docker restart overseerr-content-filtering
```

**Database migrations run automatically** - no manual steps needed!

---

## 📥 Installation

**Two Installation Options Available:**

### 🚀 Option 1: Docker Installation (Recommended)

**Best for:** Most users who want quick setup and easy updates

#### Quick Start (Docker Run)

```bash
docker pull larrikinau/overseerr-content-filtering:latest

docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -e TMDB_API_KEY=db55323b8d3e4154498498a75642b381 \
  -v /path/to/appdata/config:/app/config \
  --restart unless-stopped \
  larrikinau/overseerr-content-filtering:latest
```

#### Docker Compose (Recommended)

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
      # Standard Overseerr community key (works out-of-the-box)
      - TMDB_API_KEY=db55323b8d3e4154498498a75642b381
      # Optional: Use your own key from https://www.themoviedb.org/settings/api
      # - TMDB_API_KEY=your_private_key_here
    restart: unless-stopped
```

#### 🔑 About the TMDB API Key

**The key shown above is the standard Overseerr community key** - works immediately, no signup needed!

**Want your own key for better performance?**
- Sign up (free): https://www.themoviedb.org/signup  
- Get API key: https://www.themoviedb.org/settings/api
- Benefits: Higher rate limits, faster responses, independent quota

🔗 **Docker Hub**: https://hub.docker.com/r/larrikinau/overseerr-content-filtering  
📖 **[Advanced Docker Guide](DOCKER_DEPLOYMENT.md)** - Security, networking, troubleshooting

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
