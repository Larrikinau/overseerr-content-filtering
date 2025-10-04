# Documentation Fixes Applied - v1.5.5

## Summary
This document summarizes all documentation corrections made to align with the actual codebase implementation.

---

## 1. ✅ Corrected Default Rating Values

### Files Modified:
- `README.md` (lines 290-294)

### Changes:
**Before:**
> Defaults: New users start with PG-13 (movies) and TV-PG (TV shows) for family-safe browsing

**After:**
> Defaults: New users have "Adult" for movies (blocks only XXX content) and no TV restrictions - admins configure per-user limits as needed
> Flexible Control: Administrators set appropriate content restrictions for each individual user

### Rationale:
The code actually sets:
- `maxMovieRating: 'Adult'` (server/routes/user/usersettings.ts line 126)
- `maxTvRating: ''` (empty string = no restrictions)

This gives admins full flexibility to set appropriate restrictions per user rather than imposing a default that may not fit their use case.

---

## 2. ✅ Corrected CHANGELOG v1.5.5 Architecture Description

### Files Modified:
- `CHANGELOG.md` (lines 3-23)
- `RELEASE_NOTES_v1.5.5.md` (lines 25-30)

### Changes:

**Before:**
> - **Implemented middleware content filter validation** for all API routes
> - Content filtering middleware now applies to all API routes
> - Middleware Validator Global Application

**After:**
> - **Enhanced content filtering** applied consistently across all routes
> - Content filtering applied at TMDB API integration layer for consistent behavior
> - Comprehensive Route-Level Filtering

### Rationale:
There is NO actual middleware in `server/middleware/` for content filtering. The filtering happens within:
- TMDB API class methods (`filterMoviesByCertification`, `filterTvByRating`)
- Individual route handlers (search.ts, discover.ts, etc.)
- This is an architectural choice for performance (caching) and maintainability

The previous description was misleading about the implementation pattern.

---

## 3. ✅ Updated All Upstream Repository References

### Files Modified:
- `src/components/Settings/SettingsAbout/index.tsx` (lines 74, 108-109, 125-126, 170, 175)
- `DOCKER_DEPLOYMENT.md` (lines 104, 424)
- `README.md` (line 310)
- `CHANGELOG.md` (line 667)

### Changes:
All references to `https://github.com/sct/overseerr` updated to `https://github.com/Larrikinau/overseerr-content-filtering`

**Specific Updates:**
1. **Settings About page** - GitHub link in beta warning banner
2. **Version update badges** - "Out of Date" and "Up to Date" links now point to fork releases
3. **GitHub Discussions link** - Points to fork discussions
4. **Clone commands** - Use fork repository URL
5. **Acknowledgments** - Clarifies this is a fork building on upstream

### Rationale:
Users should be directed to the correct repository for:
- Release information
- Issue reporting
- Support and discussions
- Documentation

The fork is based on upstream v1.34.0 but has diverged with custom features.

---

## Verification Status

### ✅ Verified as Correct in Documentation:
1. **Nullable columns** - Migration code correctly implements nullable columns
2. **Admin-only controls** - UI component properly checks `Permission.MANAGE_USERS`
3. **Search certification filtering** - Uses `filterMoviesByCertification()` and `filterTvByRating()`
4. **NR content blocking** - Properly implemented in filter methods
5. **UI labels** - Accurately describe blocking behavior
6. **Version check** - `server/api/github.ts` correctly uses fork repository

### 🔧 Now Fixed:
1. Default rating values documentation
2. Architecture description accuracy
3. Repository references throughout codebase

---

## Impact Assessment

### User-Facing Changes:
- **Documentation clarity** - Users now understand actual default behavior
- **Correct expectations** - Admins know they must configure restrictions per user
- **Proper support channels** - Users directed to correct GitHub repository

### No Code Changes Required:
- All fixes are documentation-only
- No behavioral changes to the application
- No database migrations needed
- No Docker image rebuild required

---

## Next Steps

1. Review these changes
2. Commit with message: "docs: correct default values, architecture description, and repository references"
3. Consider adding to CHANGELOG as documentation clarification
4. Update any external documentation (wiki, forum posts, etc.) if applicable

---

## Files Changed Summary

```
Modified:
  README.md
  CHANGELOG.md  
  RELEASE_NOTES_v1.5.5.md
  DOCKER_DEPLOYMENT.md
  src/components/Settings/SettingsAbout/index.tsx

Created:
  DOCUMENTATION_FIXES.md (this file)
```

---

**Review Date:** 2025-10-04  
**Reviewer:** Documentation audit based on actual code implementation
