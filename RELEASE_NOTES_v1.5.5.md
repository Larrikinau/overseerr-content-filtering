# Release Notes - v1.5.5

**Release Date:** October 3, 2025  
**Type:** Bug Fix Release (Critical)

---

## Overview

Version 1.5.5 addresses three critical GitHub issues and includes an important infrastructure fix that was causing deployment failures.

---

## Issues Fixed

### Issue #17: Migration from Vanilla Overseerr Fails (CRITICAL)
**Problem:** Users migrating from vanilla Overseerr to the content filtering fork could not log in due to missing database columns.

**Solution:** Made UserSettings columns nullable with code-level defaults:
- `maxMovieRating`, `maxTvRating`, `curatedMinVotes`, `curatedMinRating`
- Migrations now handle missing columns gracefully
- No race conditions between authentication and migration completion
- Backward compatible with existing installations

### Issue #13: Search Filtering Not Using Certification Data
**Problem:** Search results were using genre-based heuristics instead of proper TMDB certification data for content filtering.

**Solution:** Implemented certification-based filtering in search routes:
- Search now uses actual TMDB certification lookups via API calls
- Uses `filterMoviesByCertification()` and `filterTvByRating()` methods
- Consistent with other discovery endpoints
- More accurate content filtering
- Properly handles NR (Not Rated) content according to user restrictions

### Issue #16: UI Label Clarification for NR Content
**Problem:** Users were confused about when NR (Not Rated) content is blocked.

**Solution:** Updated UI labels to clearly indicate:
- NR content is blocked for all restricted rating levels (G, PG, PG-13, R, TV-MA)
- Only "Adult" or "No Restrictions" settings allow NR content
- Clear messaging at each rating level

---

## Critical Infrastructure Fix

### Missing overseerr-api.yml File
**Problem:** The OpenAPI specification file (`overseerr-api.yml`) was listed in `.gitignore`, causing it to be excluded from the repository. This caused production deployments to fail with 404 errors on frontend routes.

**Solution:** 
- Removed `overseerr-api.yml` from `.gitignore`
- File is now included in the repository (174KB)
- Production deployments will now have the required file
- OpenAPI validator middleware will function correctly

**This was the root cause of the v1.5.5 deployment failure and rollback.**

---

## Upgrade Instructions

### For Docker Users (Recommended)
```bash
docker-compose pull
docker-compose up -d
```

### For Manual Installations
1. Pull latest code from GitHub
2. Run `yarn install` to update dependencies
3. Run `yarn build` to compile
4. Restart your Overseerr instance
5. Migrations will run automatically on startup

---

## Database Migrations

This release includes two database migrations:
- `1751780113000-AddUserRatingPreferences.ts`
- `1751780113001-AddTmdbSortingAndCuratedColumns.ts`

Both migrations are **backward compatible** and will run automatically.

**Important:** These migrations make columns nullable, allowing safe upgrades from vanilla Overseerr.

---

## Testing

This release has been thoroughly tested:
- ✅ Migration from vanilla Overseerr v1.33.2
- ✅ Upgrade from v1.5.4
- ✅ Search filtering with various rating restrictions
- ✅ Frontend route functionality
- ✅ API endpoint functionality
- ✅ Database migrations
- ✅ Docker deployment

---

## Known Issues

None at this time.

---

## Breaking Changes

None. This is a backward-compatible bug fix release.

---

## Contributors

- Larrikinau

---

## Support

If you encounter issues with this release:
1. Check the [GitHub Issues](https://github.com/Larrikinau/overseerr-content-filtering/issues)
2. Review the [Migration Guide](MIGRATION_GUIDE.md)
3. Check the [Docker Deployment Guide](DOCKER_DEPLOYMENT.md)

---

## Rollback Instructions

If you need to rollback to v1.5.4:

```bash
docker pull larrikinau/overseerr-content-filtering:1.5.4
docker-compose down
# Edit docker-compose.yml to use :1.5.4 tag
docker-compose up -d
```

---

**Thank you for using Overseerr Content Filtering!**
