# Overseerr Content Filtering Documentation

Welcome to the **Overseerr Content Filtering** documentation. This fork adds comprehensive admin-controlled content rating filters to Overseerr for family-safe media management.

## What is Overseerr Content Filtering?

Overseerr Content Filtering is a specialized fork of [Overseerr](https://github.com/sct/overseerr) that adds **parental control features** while preserving all original Overseerr functionality. Based on **Overseerr v1.34.0**, it provides:

🔒 **Admin-Controlled Content Rating Filters**  
👨‍👩‍👧‍👦 **Per-User Parental Controls**  
🎬 **Movie Ratings**: G, PG, PG-13, R, NC-17 filtering  
📺 **TV Ratings**: TV-Y, TV-Y7, TV-G, TV-PG, TV-14, TV-MA filtering  
🛡️ **Comprehensive Protection**: Applied across all discovery, search, and browsing  
👤 **User Privacy**: Regular users cannot see or modify their own restrictions

## All Original Overseerr Features Preserved

- ✅ **Full Plex integration** - Login and manage user access with Plex
- ✅ **Library sync** - Shows what titles you already have
- ✅ **Sonarr & Radarr integration** - Seamless media management
- ✅ **Easy request system** - Request movies and TV shows in a clean UI
- ✅ **Mobile-friendly design** - Approve requests on the go
- ✅ **Granular permissions** - Control what users can do
- ✅ **Localization** - Multiple language support

## Content Filtering Features

### 🔒 Admin-Only Controls
- Only administrators can view and modify content rating settings
- Per-user configuration with different limits for each user
- Users cannot see or bypass their own restrictions
- Centralized management through admin interface

### 🎯 Comprehensive Filtering
- **Person Pages** - Actor/actress pages respect rating filters
- **Collection Pages** - Movie collections filter by user settings
- **Trending Pages** - Trending content filtered appropriately
- **Series Discovery** - TV show discovery respects TV ratings
- **Network Browsing** - Network pages (Netflix, HBO, etc.) filtered correctly
- **Search Results** - All search results respect user limits

### ✨ Smart Features
- **Curated Quality Filters** - Optional minimum vote count and rating thresholds
- **Conditional Filtering** - Quality filters can be disabled (set to 0) for unrestricted browsing
- **Infinite Scroll** - Full catalog browsing with proper pagination
- **TV Rating Mappings** - Complete support for TV-Y through TV-MA ratings

## Quick Links

- 🚀 [Installation Guide](getting-started/installation.md)
- 🔧 [Configuration](using-overseerr/settings/README.md)
- 👥 [User Management & Content Filtering](using-overseerr/users/README.md)
- 🐛 [Troubleshooting](support/faq.md)
- 📚 [Changelog](../CHANGELOG.md)

## Latest Release: v1.5.8

**What's New:**
- ✅ Person pages now filter cast/crew by certification (R-rated/NR content blocked)
- ✅ Collection pages now filter parts by user rating restrictions
- ✅ Series view has server-side TV rating backup filter (fixes TV-14 breakthrough)
- ✅ Trending page restored to vanilla behavior + curated filter support
- ✅ Post-filtering architecture for reliable certification enforcement

📖 [Full v1.5.8 Release Notes](https://github.com/Larrikinau/overseerr-content-filtering/releases/tag/v1.5.8)

## Project Links

- 🐛 [GitHub Repository](https://github.com/Larrikinau/overseerr-content-filtering)
- 🐳 [Docker Hub](https://hub.docker.com/r/larrikinau/overseerr-content-filtering)
- 💬 [Issue Tracker](https://github.com/Larrikinau/overseerr-content-filtering/issues)
- ⬆️ [Upstream Overseerr](https://github.com/sct/overseerr)

## About This Fork

**Overseerr Content Filtering** is maintained independently from the upstream Overseerr project. It focuses specifically on adding parental control and content filtering capabilities for family-safe media server management.

**Based on:** Overseerr v1.34.0  
**Current Version:** 1.5.8  
**License:** MIT

## Contributing

Contributions are welcome! Whether it's:
- 🐛 Reporting bugs
- 💡 Suggesting features
- 📝 Improving documentation
- 🔧 Submitting code fixes

Please open an issue or pull request on [GitHub](https://github.com/Larrikinau/overseerr-content-filtering).

---

**Note:** This fork is specifically designed for users who need content filtering and parental controls. If you don't need these features, consider using [upstream Overseerr](https://github.com/sct/overseerr) instead.
