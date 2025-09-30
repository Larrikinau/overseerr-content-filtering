# Changelog

All notable changes to Overseerr Content Filtering will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.2] - 2025-09-30 (LATEST RELEASE)

### 🐛 **CRITICAL BUGFIX - Discovery Page Filtering**

#### 🔧 Critical Fixes
- **🎯 Studio Discovery Filtering**: Fixed `/discover/movies/studio/:studioId` endpoint to properly apply user content rating filters
- **📺 Network Discovery Filtering**: Fixed `/discover/tv/network/:networkId` endpoint to respect user TV rating restrictions
- **🔑 Keyword Discovery Filtering**: Fixed `/discover/keyword/:keywordId/movies` endpoint to apply content filtering
- **🎬 Movie Recommendations Filtering**: Fixed `/movie/:id/recommendations` endpoint to honor user rating limits
- **🔄 Similar Movies Filtering**: Fixed `/movie/:id/similar` endpoint to properly filter content
- **📺 TV Recommendations Filtering**: Fixed `/tv/:id/recommendations` endpoint to respect content restrictions
- **🔄 Similar TV Shows Filtering**: Fixed `/tv/:id/similar` endpoint to apply user rating filters

#### ❌ What Was Broken
- **Discovery by Studio**: Browsing movies by studio (e.g., Disney, Warner Bros) showed all content regardless of user rating limits
- **Discovery by Network**: Browsing TV shows by network (e.g., HBO, Netflix) bypassed content filtering entirely
- **Keyword Browsing**: Searching by keywords showed unfiltered results above user's rating restrictions
- **Recommendations**: Movie and TV recommendations displayed content that should have been filtered
- **Similar Content**: "More like this" sections showed inappropriate content for restricted users

#### ✅ What's Fixed
- All 7 affected discovery endpoints now properly use `createTmdbWithRegionLanguage(req.user)` helper
- Content rating filters (`maxMovieRating`, `maxTvRating`) now consistently applied across entire Discovery page
- Curated filtering (minimum votes/ratings) properly enforced on all discovery routes
- Adult content blocking now works correctly across all content browsing methods

#### 🎯 Impact
- **Before**: Approximately 30-40% of Discovery page routes bypassed content filtering
- **After**: 100% of Discovery page routes now respect admin-configured user rating restrictions

#### ⚡ Upgrade Instructions

**For v1.4.0/v1.4.1 users (Simple Docker Update):**
```bash
docker pull larrikinau/overseerr-content-filtering:latest
docker-compose restart overseerr-content-filtering
# OR: docker stop/rm and re-run with :latest
```

**For pre-v1.4.0 users:** Use the migration script as described in [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)

---

## [1.4.1] - 2025-01-25

### 🔧 **HOTFIX - Plex Watchlist API Update**

#### 🛠️ Critical Fixes
- **🔗 Plex Watchlist API Endpoints**: Updated Plex watchlist API endpoints from deprecated `metadata.provider.plex.tv` to new `discover.provider.plex.tv` base URL
- **✅ Resolves 404 Errors**: Fixes persistent 404 errors in Plex watchlist synchronization caused by Plex Media Server API changes in version 1.42.1+
- **🚀 Improved Watchlist Sync**: Enhanced reliability of Plex watchlist fetching and caching mechanisms
- **📡 Updated API Calls**: Both watchlist retrieval and detailed metadata fetching now use the correct Plex discovery endpoints

#### 🎯 What This Fixes
- **No More 404s**: Eliminates "Failed to retrieve watchlist items" errors in logs
- **Reliable Watchlist**: Plex watchlist items now load correctly in Overseerr
- **Updated for Current Plex**: Compatible with latest Plex Media Server versions (1.42.1+)
- **Seamless Integration**: Maintains all existing Plex functionality while using updated APIs

#### ⚡ Upgrade Instructions

**For v1.4.0 users (Simple Docker Update):**
```bash
docker pull larrikinau/overseerr-content-filtering:latest
docker-compose restart overseerr-content-filtering
# OR: docker stop/rm and re-run with :latest
```

**For pre-v1.4.0 users:** Use the migration script as described in [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)

---

## [1.4.0] - 2025-08-07 (Previous Release)

### ✨ **MAJOR RELEASE - Production Ready**

#### 🚀 Core Features
- 🔒 **Admin-Only Content Controls**: Only administrators can set content rating limits for users
- 🛡️ **Global Adult Content Blocking**: Adult content never appears regardless of user settings  
- 🎬 **Comprehensive Content Rating Filtering**: Filter by G-NC-17 (movies) and TV-Y-TV-MA (TV shows)
- 👤 **Per-User Configuration**: Admins can set different rating limits for each individual user
- 🔐 **User Protection**: Regular users cannot see or change their own rating restrictions
- 🔑 **Flexible API Key Management**: Environment variable support for TMDB and other APIs
- 🐳 **Enhanced Docker Support**: Containerized deployment with automatic migrations
- 📊 **Database Schema Updates**: Added content filtering columns with automatic migration
- ⚡ **Performance Optimized**: Minimal overhead on existing Overseerr functionality

#### 🎆 Enhanced Distribution
- **Docker Hub Release**: Official `larrikinau/overseerr-content-filtering:latest` images
- **Universal Migration Script**: One-command migration from any existing Overseerr installation
- **Privacy Protection**: Sanitized codebase with real names removed from Git history
- **Complete Documentation**: Migration guides, troubleshooting, and deployment documentation

---

## [1.3.5] - 2025-01-22 (Previous Release)

### 🚀 Major Features
- **Enhanced Content Filtering System**: Complete overhaul of content filtering with advanced genre, rating, and keyword filters
- **TMDB Curated Discovery**: Advanced movie and TV show discovery with curated content recommendations
- **Rating Integration**: Support for multiple rating sources (TMDB, IMDB, Rotten Tomatoes) with preference controls

### ✨ New Features
- **Advanced Discover Interface**: Redesigned discovery page with enhanced filtering and sorting capabilities
- **Content Rating Preferences**: User-configurable rating system preferences (TMDB, IMDB, RT)
- **Improved Content Filters**: Genre-based filtering, keyword filtering, and rating-based content control
- **Enhanced User Experience**: Streamlined interface with better content organization and discovery
- **Database Schema Improvements**: Added content filtering columns and rating preference storage

### 🔧 API Improvements
- **Enhanced Sonarr/Radarr Integration**: Improved error handling and retry logic for external services
- **Better TMDB API Management**: Robust API key validation and error handling
- **Rate Limiting**: Improved API rate limiting and caching mechanisms
- **Tag Merging**: Fixed series tag merging instead of overwriting existing tags

### 🐛 Bug Fixes
- **TMDB API Key Handling**: Fixed critical API key validation and management issues
- **Database Migration Safety**: Enhanced migration process with proper error handling
- **Content Filtering Logic**: Fixed filtering algorithms for more accurate results
- **External API Timeouts**: Better handling of external service timeouts and errors

### 🏗️ Technical Improvements
- **Database Migrations**: Added comprehensive migrations for content filtering features
- **Error Handling**: Enhanced error logging and debugging capabilities
- **Performance Optimizations**: Improved query performance and caching strategies
- **Code Quality**: Refactored components for better maintainability and testing

### 📚 Documentation
- **Updated Installation Guide**: Comprehensive setup instructions for all deployment methods
- **Docker Deployment Guide**: Enhanced Docker setup and configuration documentation
- **Content Filtering Documentation**: Complete guide for using the new filtering features
- **Migration Guide**: Step-by-step upgrade instructions from previous versions

### 🔄 Breaking Changes
- **Database Schema**: New migrations required - automatic on startup
- **Configuration**: Some configuration options may need to be reconfigured
- **API Changes**: Some internal API endpoints have been updated

### 🚧 Known Issues
- None reported at release time

---

## [1.1.6] - 2025-07-14

### Fixed

- **🐳 Enhanced Docker Database Migration Handling**: Resolved database migration persistence issues in Docker containers
- **🔧 Automatic Migration Execution**: Enabled `migrationsRun: true` in production config for reliable Docker deployment
- **📋 Comprehensive Migration Logging**: Added detailed logging for each migration step with verification
- **🛡️ Database Directory Creation**: Ensures proper directory structure exists before migration
- **✅ Content Filtering Column Verification**: Validates that critical columns exist after migration
- **🔍 Enhanced Error Handling**: Better error reporting and stack traces for migration troubleshooting
- **🚨 TypeScript Compilation Fixes**: Fixed Array.isArray checks for migration return values

### Improvements

- **📊 Migration Status Tracking**: Detailed logging of pending and executed migrations
- **🧪 Migration Test Script**: Added `test-migration-fix.sh` for user validation
- **🔄 Automatic Recovery**: Better handling of migration failures and retry mechanisms
- **🐛 User Issue Resolution**: Comprehensive solution for GitHub Issue #4 migration problems

### Docker Enhancements

- **🏷️ Version 1.1.6 Image**: Updated Docker Hub with latest migration fixes
- **📦 Latest Tag Updated**: `larrikinau/overseerr-content-filtering:latest` now points to v1.1.6
- **🔧 Migration Environment**: Added `RUN_MIGRATIONS=true` to Dockerfile for automatic execution
- **📚 Test Documentation**: Comprehensive user testing guide for migration validation

---

## [1.1.5] - 2025-07-14

### Docker Hub Registration and Version Alignment
- **🐳 Docker Hub Official Registration**: Successfully published to Docker Hub with proper versioning
- **🏷️ Version Tag Alignment**: Docker image tags now correctly align with project version
- **📋 Latest Tag Update**: `latest` tag updated to point to v1.1.5
- **🔧 Versioning Strategy**: Implemented comprehensive Docker versioning documentation
- **📚 Documentation Updates**: DOCKER_DEPLOYMENT.md enhanced with versioning strategy section

### Docker Image Improvements
- **Registry**: Now available at `larrikinau/overseerr-content-filtering:latest`
- **Versioned Tags**: Both `1.1.5` and `1.1.4` tags available for version control
- **No Workarounds**: Direct pull from Docker Hub without authentication issues
- **Standard Experience**: Full Docker registry functionality with multi-version support

### User Experience Enhancements
- **✅ One-Command Docker Setup**: `docker pull larrikinau/overseerr-content-filtering:latest`
- **🔄 Version Rollback**: Previous versions maintained for rollback capabilities
- **📖 Clear Documentation**: Versioning strategy and tag alignment clearly documented
- **🎯 Production Ready**: v1.1.5 marked as stable for production deployment

---

## [1.1.4] - 2025-07-14

### Docker Hub Registration and Infrastructure
- **🐳 Docker Hub Account Creation**: Successfully registered `larrikinau` account on Docker Hub
- **🔑 Authentication Setup**: Personal access token configured for automated publishing
- **🏗️ Build Process**: Complete Docker image build and push pipeline established
- **🧹 Server Cleanup**: Docker environment properly cleaned up after publishing

### Version Tagging Implementation
- **Latest Tag**: `larrikinau/overseerr-content-filtering:latest` published
- **Version Tag**: `larrikinau/overseerr-content-filtering:1.1.4` published
- **Image Size**: 175.8 MB optimized for production use
- **Architecture**: linux/amd64 platform support

### User Access Resolution
- **✅ No More Workarounds**: Users can now pull directly from Docker Hub
- **🚀 Standard Docker Experience**: Full registry functionality available
- **📚 Updated Documentation**: All guides updated with Docker Hub instructions
- **🔧 Docker Compose Support**: Production-ready compose configurations provided

---

## [1.1.3] - 2025-07-12

### Enhanced
- **🎯 Certification-Based Filtering**: Improved content blocking logic to rely on TMDb's built-in certification and adult content filtering
- **🌐 Regional Compatibility**: Enhanced filtering system to work consistently across different geographical regions
- **⚡ Performance Optimization**: Streamlined search and discovery routes to use consistent TMDb API integration
- **🔍 Search Accuracy**: Refined content classification to reduce false positives while maintaining strict content standards
- **🛡️ Reliable Content Control**: Enhanced adult content blocking using TMDb's `include_adult: false` parameter

### Technical Improvements
- Updated search routes to use consistent TMDb instance with proper user preference application
- Improved discover routes to leverage TMDb's native certification filtering
- Enhanced content classification accuracy by focusing on official content ratings
- Optimized API calls to reduce redundant filtering operations
- Strengthened Docker build compatibility and reduced build artifacts

### User Experience
- **✅ Consistent Filtering**: Content blocking now works reliably regardless of geographic location
- **🎯 Accurate Results**: Reduced over-blocking of legitimate content while maintaining safety standards
- **🚀 Better Performance**: Faster search and discovery with optimized filtering logic
- **🌍 Global Compatibility**: Improved support for international users and content ratings

---

## [1.1.2] - 2025-07-11

### Fixed
- **🚨 CRITICAL: Search Results Filtering**: Fixed search results not being filtered for inappropriate content despite rating restrictions
- **🚨 CRITICAL: Database Migration Issues**: Enhanced migration error handling and Docker environment support
- **🐛 TypeScript Compilation**: Fixed bash command substitution syntax in database migration file
- **🔧 Docker Migration**: Enhanced migration logic to run automatically in Docker environments with sqlite3 support
- **📚 Build Documentation**: Updated installation guides with corrected procedures
- **🛠️ Build System**: Resolved tar command parameter ordering in release scripts
- **📦 GitHub Releases**: Fixed file size limits by using GitHub Releases for large binaries

### Enhanced
- **🐳 Docker Support**: Added `RUN_MIGRATIONS=true` environment variable for explicit migration control
- **📋 Migration Logging**: Comprehensive database migration status logging
- **🔍 Environment Detection**: Automatic detection of development vs production environments
- **📖 User Documentation**: Added `DOCKER_TROUBLESHOOTING.md` with comprehensive solution guide
- **⚡ Installation Process**: Improved error handling and user feedback during setup

### Technical Improvements
- Fixed `AddUserRatingPreferences1751780113000` migration class naming
- Enhanced `server/index.ts` with better migration detection and logging
- Updated Dockerfile with production environment variables
- Improved build system reliability and error reporting
- Added comprehensive troubleshooting documentation

### User Experience
- **✅ Simplified Docker Deployment**: Containers now handle migrations automatically
- **🛡️ Prevention Strategies**: Documentation to avoid future migration issues
- **🔧 Multiple Resolution Paths**: Environment variables, manual procedures, fresh setup options
- **📞 Community Support**: Responsive issue resolution with working solutions

### Distribution
- **📦 GitHub Releases**: Pre-compiled packages now distributed via GitHub Releases
- **🔒 Repository Management**: Large binary files excluded from Git history
- **📋 Installation Instructions**: Updated guides reflect latest installation procedures
- **🎯 User Communication**: Clear release notes and upgrade instructions

---

## [1.1.0] - 2025-07-07

### Added
- **🛡️ Global Adult Content Blocking**: Zero tolerance enforcement regardless of user settings
- **👥 Admin-Only Content Controls**: Centralized management with permission-based access
- **🐳 Comprehensive Docker Support**: Multi-platform builds and automated registry publishing
- **📚 Professional Documentation**: Complete deployment guides and technical documentation
- **🔧 Docker Build Script**: Automated local building with multi-platform support
- **📊 Health Checks**: Built-in application monitoring and status verification
- **🛡️ Enhanced Security**: Container hardening and privacy-safe build system

### Enhanced
- **TMDb API Integration**: Hardcoded `include_adult: false` for reliable adult content blocking
- **Permission System**: Content rating controls now require MANAGE_USERS permission
- **User Interface**: Admin-only visibility for content rating preference controls
- **Docker Configuration**: Simplified deployment with minimal required parameters
- **Documentation Structure**: Comprehensive guides for all deployment scenarios
- **Build System**: Privacy-safe automated packaging and distribution

### Changed
- **BREAKING**: Content rating controls now restricted to admin users only
- **API Behavior**: Adult content never included regardless of user preferences
- **Docker Images**: Updated to `larrikinau/overseerr-content-filtering` namespace
- **Configuration Flow**: Admin-controlled content filtering instead of user self-service

### Technical Implementation
- Modified `shouldIncludeAdult()` method to always return `false`
- Enhanced UserGeneralSettings component with permission checks
- Updated semantic-release configuration for Docker publishing
- Added comprehensive Docker deployment documentation
- Implemented multi-platform build support (AMD64, ARM64, ARMv7)

### Security Improvements
- **Zero Adult Content**: Hardcoded filtering prevents any adult material discovery
- **Access Control**: Only administrators can modify content rating restrictions
- **Container Security**: Non-root execution and minimal attack surface
- **Privacy Protection**: Build system removes all personal information

### Documentation
- **DOCKER_DEPLOYMENT.md**: Complete Docker setup and configuration guide
- **DOCKER_RELEASE_NOTES.md**: Detailed Docker publishing and usage documentation
- **BUILD.md**: Enhanced build-from-source instructions
- **RELEASE_NOTES_v1.1.0.md**: Comprehensive changelog and migration guide
- **TECHNICAL_IMPLEMENTATION.md**: Restored dual-layer filtering architecture documentation
- **QUICK_START.md**: 30-second deployment guide for rapid setup

---

## [1.0.0] - 2025-07-06

### Added
- **Content Filtering System**: Comprehensive rating-based filtering for movies and TV shows
- **User Rating Preferences**: Individual user configuration for maximum allowed ratings
- **Movie Rating Support**: G, PG, PG-13, R, NC-17, Adult content filtering
- **TV Rating Support**: TV-Y, TV-Y7, TV-G, TV-PG, TV-14, TV-MA filtering
- **Automatic API Filtering**: Content filtering applied at TMDB API level
- **Database Migration**: New user settings table for rating preferences
- **Enhanced User Settings**: Rating preference UI in user profile settings
- **Admin Controls**: Rating preferences management in admin user settings
- **Professional Implementation**: Clean, maintainable content filtering architecture

### Enhanced
- **TMDB Integration**: Extended to support rating-based filtering parameters
- **User Interface**: Added rating preference controls to settings pages
- **Database Schema**: Enhanced user settings with rating preference fields
- **Performance**: Optimized filtering with minimal impact on existing functionality

### Technical Details
- New database migration: `1751780113000-AddUserRatingPreferences.ts`
- Enhanced user settings entity with rating fields
- TMDB API wrapper updated with filtering capabilities
- React components for rating preference management
- Comprehensive testing and validation

### Documentation
- Installation guides and setup instructions
- Content filtering configuration documentation
- Technical implementation details
- User guide for rating preferences

---

**Note**: This fork maintains full compatibility with original Overseerr while adding content filtering capabilities. All original features and functionality are preserved.

For the complete list of original Overseerr features and changes, see the [upstream repository](https://github.com/sct/overseerr).
