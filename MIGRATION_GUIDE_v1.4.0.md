# Overseerr v1.4.0 Migration Guide

## 🎯 Universal Migration (Same for All Users)

### ✅ What's Fixed in v1.4.0
1. **Curated settings removed from global admin interface** (main bug fix)
2. **Environment variable support for API keys** (TMDB, Algolia)
3. **Proper adult content filtering** based on user rating preferences
4. **Single Docker image** that works for everyone

### 🚀 Migration Steps

#### 1. Update Docker Compose
Replace your existing docker-compose.yml with the new configuration:
- **Public API keys as defaults** (works out of the box)
- **Environment variable support** for private keys

#### 2. Optional: Customize API Keys
If you want to use private API keys:
1. Copy  to 
2. Set your private keys:
   

#### 3. Deploy


### 📋 Migration Compatibility
- **From original Overseerr**: Uses public API keys by default
- **From v1.3.5 private builds**: Works the same way - set private keys in .env if desired
- **Existing configurations**: Preserved in database (Pushover, etc.)

### 🔧 Technical Changes
- Curated filtering settings moved from global to user-level only
- API keys now configurable via environment variables
- Adult content filtering respects user rating preferences
- Single Docker image serves all use cases

## 📁 Files Changed
-  - Updated with environment variable support
-  - Template for user customization
- Source code - API keys now use environment variables with fallbacks

No special configurations needed - same migration for everyone! 🎉
