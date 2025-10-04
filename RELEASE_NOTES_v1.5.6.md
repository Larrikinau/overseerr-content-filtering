# Release Notes - v1.5.6

**Release Date:** October 4, 2025  
**Type:** Critical Bug Fix Release

---

## Overview

Version 1.5.6 fixes a critical migration issue that prevented users migrating from vanilla Overseerr from being able to log in, even after upgrading to v1.5.5.

---

## Critical Fix

### Issue: Migration State Mismatch During Vanilla Overseerr Migration

**Problem:** Users migrating from vanilla Overseerr experienced authentication failures with the error:
```
SQLITE_ERROR: no such column: User_settings.maxMovieRating
```

This occurred even when the migration system reported "Database schema is up to date."

**Root Cause:** 
- TypeORM's migration tracking table marked migrations as "complete"
- However, the actual database columns were never created (failed migration or interrupted process)
- The User entity has `eager: true` on the UserSettings relation
- During authentication, TypeORM automatically tried to load UserSettings with a JOIN
- The JOIN query included non-existent columns, causing authentication to fail

**Solution:** 
Implemented a self-healing migration verification system that:
1. Checks if migrations table says migrations are complete
2. **Verifies that critical columns actually exist in the database**
3. If columns are missing, automatically re-runs migrations to fix the schema
4. Logs detailed information about the fix process
5. Verifies columns exist after the fix

**Impact:** Users can now simply upgrade to v1.5.6 and the system will automatically detect and fix migration state mismatches on startup.

---

## What's Fixed

✅ **Automatic Migration Repair**
- Detects when migration table and actual schema are out of sync
- Automatically re-runs migrations to create missing columns
- No manual database intervention required

✅ **Enhanced Logging**
- Clear warning when missing columns are detected
- Detailed logging of migration re-execution
- Confirmation when schema is successfully repaired

✅ **Robust Error Handling**
- Graceful handling of verification failures
- Clear error messages if automatic repair fails
- Guidance for manual intervention if needed

---

## Upgrade Instructions

### For Docker Users (Recommended)

```bash
docker pull larrikinau/overseerr-content-filtering:latest
docker-compose restart
# OR: docker restart overseerr-content-filtering
```

### What You'll See in Logs (If Auto-Fix Needed)

```
[warn][Database]: Content filtering columns missing - attempting to fix by re-running migrations
[info][Database]: Successfully re-ran 2 migrations to fix schema
[info][Database]: Re-executed migration 1: AddUserRatingPreferences1751780113000
[info][Database]: Re-executed migration 2: AddTmdbSortingAndCuratedColumns1751780113001
[info][Database]: Content filtering columns now verified after migration fix
```

### For Manual Installations

1. Pull latest code from GitHub
2. Run `yarn install` to update dependencies
3. Run `yarn build` to compile
4. Restart your Overseerr instance
5. Check logs for automatic migration repair messages

---

## Database Migrations

This release uses the same migrations as v1.5.5:
- `1751780113000-AddUserRatingPreferences.ts`
- `1751780113001-AddTmdbSortingAndCuratedColumns.ts`

The enhancement is in the **verification and auto-repair logic**, not the migrations themselves.

---

## Technical Details

### Files Modified

- `server/index.ts` - Enhanced migration verification with auto-repair logic
- `package.json` - Version bumped to 1.5.6

### How Auto-Repair Works

1. After TypeORM reports migrations are complete, verify columns exist:
   ```typescript
   SELECT maxMovieRating, maxTvRating, tmdbSortingMode, 
          curatedMinVotes, curatedMinRating 
   FROM user_settings LIMIT 1
   ```

2. If verification fails, automatically re-run migrations:
   ```typescript
   await dbConnection.runMigrations({ transaction: 'all' })
   ```

3. Verify columns now exist and log success

---

## Testing

This release has been tested with:
- ✅ Fresh vanilla Overseerr v1.33.2 database migration
- ✅ Upgrade from working v1.5.5 installation
- ✅ Simulated migration state mismatch scenarios
- ✅ Authentication after automatic repair
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

If you need to rollback to v1.5.5 (not recommended):

```bash
docker pull larrikinau/overseerr-content-filtering:1.5.5
docker-compose down
# Edit docker-compose.yml to use :1.5.5 tag
docker-compose up -d
```

---

**Thank you for using Overseerr Content Filtering!**
