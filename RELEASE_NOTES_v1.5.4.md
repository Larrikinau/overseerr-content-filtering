# Release Notes - Version 1.5.4

**Release Date**: October 2, 2025  
**Base Version**: Overseerr v1.34.0 with Content Filtering Extensions

## Overview

Version 1.5.4 represents a comprehensive bug fix release that resolves all outstanding content discovery issues while maintaining full compatibility with upstream Overseerr v1.34.0. This release has been thoroughly tested in an isolated development environment with production database validation.

## What's Fixed

### Issue #1: Upcoming Movies and TV Shows Not Displaying ✅

**Problem**: Upcoming content pages were broken due to incorrect frontend routing that sent users to filtered discovery pages instead of dedicated upcoming endpoints.

**Solution**:
- Fixed frontend slider routing to use dedicated `/discover/movies/upcoming` and `/discover/tv/upcoming` pages
- Corrected API endpoint calls from generic discovery to specialized upcoming endpoints
- Backend logic properly implements conditional filtering:
  - Users with no restrictions see all upcoming content via native TMDB endpoints
  - Users with rating restrictions see appropriately filtered upcoming content
  - Curated filters (vote/rating thresholds) bypassed for upcoming content

**Files Changed**:
- `src/components/Discover/index.tsx` (lines 244-253, 271-280)

**Impact**: Upcoming Movies and Upcoming TV pages now display content correctly for all user permission levels.

### Issue #2: Network Pages Only Showing TV Shows ✅

**Problem**: Network browsing pages (Netflix, HBO, Apple TV+, etc.) only displayed TV shows, omitting movies entirely due to overly aggressive curated filtering.

**Solution**:
- Added `skipCuratedFilters: true` parameter to movie discovery in `getNetworkAll` method
- Network pages now fetch both movies and TV shows with balanced filtering
- Maintains content rating restrictions while showing broader catalog

**Files Changed**:
- `server/api/themoviedb/index.ts` (line ~1826)

**Impact**: Network pages now show mixed content (both movies and TV shows) as intended.

### Issue #13/#16: NR (Not Rated) Content Filtering ✅

**Status**: Already working in production (verified in v1.5.2)

**Solution Previously Implemented**:
- NR content now properly filtered using TMDB's `adult` flag
- Prevents unrated content from bypassing user restrictions
- Applied across Trending, Recommendations, and Similar content pages

**Impact**: Users with content restrictions no longer see inappropriate NR content.

## Technical Details

### Database Migrations
- **Total Migrations**: 37
  - 35 from upstream Overseerr
  - 2 custom for content filtering features
- **Status**: All migrations verified present and functional
- **Compatibility**: Fully compatible with existing v1.5.2 databases

### Upstream Integration
- Based on **Overseerr v1.34.0**
- All upstream features, fixes, and enhancements included
- Content filtering features seamlessly integrated
- No conflicts with upstream changes

### Testing Validation
- Tested in isolated development environment (port 5056)
- Production database copy used for realistic testing
- All three issues verified as resolved
- User settings and permissions preserved
- No regressions detected

## Upgrade Path

### From v1.5.2 (Current Production)
- **Risk**: Low
- **Database Changes**: None required (already at latest schema)
- **Downtime**: ~30 seconds (container restart)
- **Rollback**: Simple - revert to v1.5.2 image if needed

### From v1.5.0 or Earlier
- **Risk**: Medium
- **Database Changes**: Automatic migrations will run on first startup
- **Backup Recommended**: Yes - backup database before upgrading
- **Process**: Standard upgrade process applies

## Installation

### Docker (Recommended)

```bash
docker pull larrikinau/overseerr-content-filtering:1.5.4

# Or use latest tag
docker pull larrikinau/overseerr-content-filtering:latest
```

### Docker Compose

```yaml
services:
  overseerr-content-filtering:
    image: larrikinau/overseerr-content-filtering:1.5.4
    container_name: overseerr-content-filtering
    ports:
      - "5055:5055"
    volumes:
      - overseerr-config:/app/config
    environment:
      - NODE_ENV=production
      - LOG_LEVEL=info
      - TZ=your_timezone
      - TMDB_API_KEY=your_tmdb_key
      - ALGOLIA_API_KEY=your_algolia_key
    restart: unless-stopped
```

## Breaking Changes

**None** - This is a bug fix release with full backward compatibility.

## Known Issues

- None currently identified

## Credits

- Base: [Overseerr](https://github.com/sct/overseerr) by sct and contributors
- Content Filtering: Larrikinau
- Testing and Validation: Community feedback on Issues #1, #2, #13, #16

## Support

For issues, questions, or feature requests:
- GitHub Issues: [Repository Issues Page]
- Review the troubleshooting documentation
- Check existing closed issues for similar problems

## Checksums

Docker Image SHA256 digests will be available after build:
- `larrikinau/overseerr-content-filtering:1.5.4`
- `larrikinau/overseerr-content-filtering:latest`

---

**Full Changelog**: v1.5.2...v1.5.4
