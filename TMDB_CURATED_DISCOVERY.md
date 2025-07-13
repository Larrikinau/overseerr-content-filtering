# 🎯 TMDB Curated Discovery - Complete Guide

## 📋 Overview

TMDB Curated Discovery is a revolutionary content filtering system introduced in v1.1.5 that transforms how users discover movies and TV shows. Instead of showing all available content, it intelligently filters results based on quality metrics to surface only high-quality, well-regarded content.

## 🔍 How It Works

### **Quality Metrics**
The system uses two primary quality indicators from TMDB:
- **Vote Count**: Number of user ratings (popularity indicator)
- **Vote Average**: Average user rating (quality indicator)

### **Discovery Modes**
Users can toggle between two discovery experiences:

#### **Standard Mode** (Default)
- Shows all available content regardless of quality metrics
- Identical to original Overseerr behavior
- No filtering applied to discovery results
- Search results remain unfiltered

#### **Curated Mode** (New)
- Applies quality thresholds to filter content
- Only shows movies/TV shows meeting minimum standards
- Enhanced recommendations using quality filtering
- Search results remain comprehensive (unfiltered)

### **Where Filtering Applies**

#### **Filtered Sections** (Curated Mode Only):
- **Discover Movies/TV Shows**: Main discovery pages
- **Trending Content**: Popular content carousels
- **Upcoming Releases**: Future content previews
- **Similar Content**: "More like this" recommendations
- **Genre Browsing**: Category-based discovery
- **Movie/TV Recommendations**: Personalized suggestions

#### **Unfiltered Sections** (Always):
- **Search Results**: Direct search always shows all results
- **User Requests**: Existing request management
- **Recently Added**: Recently requested/available content
- **Watchlists**: Personal saved content

## ⚙️ Admin Configuration

### **Initial Setup**

1. **Access Admin Settings**:
   - Login as an administrator
   - Navigate to **Settings** → **General**
   - Scroll to **TMDB Curated Discovery** section

2. **Global Configuration Options**:

   ```
   Enable TMDB Curated Discovery: [✓] Yes / [ ] No
   Default Discovery Mode: [Standard] / [Curated]
   Allow User Mode Override: [✓] Yes / [ ] No
   
   Quality Thresholds:
   Default Minimum Votes: [3000]
   Default Minimum Rating: [6.0]
   
   Movie-Specific Thresholds:
   Min Movie Votes: [3000] (overrides default)
   Min Movie Rating: [6.0] (overrides default)
   
   TV Show-Specific Thresholds:
   Min TV Votes: [1500] (typically lower than movies)
   Min TV Rating: [6.5] (typically higher than movies)
   ```

### **Configuration Options Explained**

#### **Enable TMDB Curated Discovery**
- **Enabled**: Curated mode becomes available to users
- **Disabled**: Only standard mode available (original behavior)

#### **Default Discovery Mode**
- **Standard**: New users default to showing all content
- **Curated**: New users default to quality-filtered content

#### **Allow User Mode Override**
- **Yes**: Users can toggle between Standard/Curated modes
- **No**: Users locked to admin-chosen default mode

#### **Quality Thresholds**
- **Minimum Votes**: Exclude content with fewer user ratings
- **Minimum Rating**: Exclude content below average rating threshold
- **Content Type Specific**: Different standards for movies vs TV shows

### **Recommended Threshold Settings**

#### **Conservative (Family-Friendly)**
```
Movie Votes: 5000+
Movie Rating: 6.5+
TV Votes: 2000+
TV Rating: 7.0+
```

#### **Balanced (Recommended Default)**
```
Movie Votes: 3000+
Movie Rating: 6.0+
TV Votes: 1500+
TV Rating: 6.5+
```

#### **Liberal (More Content)**
```
Movie Votes: 1000+
Movie Rating: 5.5+
TV Votes: 500+
TV Rating: 6.0+
```

## 👥 User Experience

### **Switching Discovery Modes**

If admin allows user override:

1. **Access User Settings**:
   - Navigate to **Settings** → **General**
   - Find **Discovery Preferences** section

2. **Mode Selection**:
   ```
   Discovery Mode: [●] Standard  [○] Curated
   
   When Curated mode is selected:
   Custom Vote Threshold: [3000] (if admin allows)
   Custom Rating Threshold: [6.0] (if admin allows)
   ```

### **Visual Indicators**

#### **Discovery Mode Indicator**
- Top-right corner shows current mode: "Standard" or "Curated"
- Click to toggle (if permissions allow)

#### **Content Filtering Notice**
- Curated mode shows: "Showing quality-filtered content (3000+ votes, 6.0+ rating)"
- Standard mode shows: "Showing all available content"

#### **Filtered Content Count**
- Footer indicates: "X of Y movies/shows meet quality standards"

## 🔧 Technical Implementation

### **API Behavior**

#### **TMDB API Parameters**
When curated mode is active, requests include:
```
vote_count.gte=3000
vote_average.gte=6.0
```

#### **Caching Strategy**
- Quality thresholds cached for 1 hour
- Content results cached based on quality parameters
- User mode preferences stored in database

#### **Performance Optimization**
- Combined API parameters reduce total requests
- Intelligent caching minimizes repeated calls
- Background pre-loading for popular content

### **Database Schema**

New tables/fields added in v1.1.5:
```sql
-- User discovery preferences
user_discovery_settings:
  - user_id (foreign key)
  - discovery_mode (standard/curated)
  - custom_min_votes (nullable)
  - custom_min_rating (nullable)
  - created_at
  - updated_at

-- Global configuration
settings:
  - curated_discovery_enabled (boolean)
  - default_discovery_mode (enum)
  - allow_user_override (boolean)
  - default_min_votes (integer)
  - default_min_rating (decimal)
  - movie_min_votes (integer, nullable)
  - movie_min_rating (decimal, nullable)
  - tv_min_votes (integer, nullable)
  - tv_min_rating (decimal, nullable)
```

## 📊 Content Examples

### **Movies That Meet Default Thresholds (3000+ votes, 6.0+ rating)**
- The Dark Knight (2008): 2.5M votes, 9.0 rating ✅
- Inception (2010): 2.2M votes, 8.8 rating ✅
- Interstellar (2014): 1.6M votes, 8.6 rating ✅
- Avengers: Endgame (2019): 850K votes, 8.4 rating ✅

### **Movies Filtered Out by Default Thresholds**
- Obscure indie films with <3000 votes ❌
- Low-rated B-movies with <6.0 rating ❌
- Very new releases without enough votes yet ❌

### **TV Shows That Meet Default Thresholds (1500+ votes, 6.5+ rating)**
- Breaking Bad: 1.6M votes, 9.5 rating ✅
- Game of Thrones: 1.9M votes, 9.2 rating ✅
- Stranger Things: 850K votes, 8.7 rating ✅
- The Office: 750K votes, 8.9 rating ✅

## 🎛️ Advanced Configuration

### **Per-User Custom Thresholds**

If admin enables user customization, users can set personal thresholds:

```javascript
// Example API call for user preferences
PUT /api/v1/user/discovery-settings
{
  "discoveryMode": "curated",
  "customMinVotes": 5000,
  "customMinRating": 7.0
}
```

### **Genre-Specific Settings** (Future Enhancement)

Planned for v1.2.x:
```
Action Movies: 5000+ votes, 6.5+ rating
Comedy Movies: 2000+ votes, 6.0+ rating
Documentaries: 1000+ votes, 7.0+ rating
```

### **Integration with Content Filtering**

Curated Discovery works alongside existing content filtering:
1. **Age Rating Filter** applied first (admin-controlled)
2. **Quality Filter** applied second (curated mode)
3. **Final Results** shown to user

Example workflow:
```
All TMDB Content
    ↓
Age Rating Filter (PG-13 max)
    ↓
Quality Filter (3000+ votes, 6.0+ rating)
    ↓
Final Discovery Results
```

## 🚨 Troubleshooting

### **Common Issues**

#### **"No Content Found" in Curated Mode**
**Cause**: Thresholds too restrictive
**Solution**: Lower vote count or rating thresholds

#### **Too Much Content in Curated Mode**
**Cause**: Thresholds too permissive
**Solution**: Increase vote count or rating thresholds

#### **Users Can't Change Mode**
**Cause**: Admin disabled user override
**Solution**: Enable "Allow User Mode Override" in admin settings

#### **Settings Not Saving**
**Cause**: Database permission issues
**Solution**: Check file permissions on settings database

### **Debug Information**

Enable debug logging to see filtering in action:
```bash
# View filtering decisions
sudo journalctl -u overseerr-filtering -f | grep "curated"

# Check database queries
sudo journalctl -u overseerr-filtering -f | grep "vote_count"
```

## 📈 Usage Analytics

### **Tracking Discovery Mode Usage**

Admin dashboard shows:
- Percentage of users using each mode
- Average content discovery per mode
- Most popular quality thresholds
- Content discovery efficiency metrics

### **Quality Metrics**

Monitor content quality improvements:
- Average rating of discovered content
- User engagement with filtered results
- Request completion rates by discovery mode

## 🔄 Migration from Previous Versions

See [UPGRADE_GUIDE.md](UPGRADE_GUIDE.md) for detailed migration instructions from pre-v1.1.5 installations.

---

**Need Help?** Check the [FAQ](FAQ.md) or [open an issue](https://github.com/Larrikinau/overseerr-content-filtering/issues) for support.
