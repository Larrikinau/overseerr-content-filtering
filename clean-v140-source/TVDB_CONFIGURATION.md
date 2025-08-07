# TVDB API Configuration Guide

**Overseerr Content Filtering** works perfectly with just TMDB (The Movie Database) API data, but you can optionally enhance your TV show metadata by configuring TVDB (The TV Database) API access.

## Do You Need TVDB?

**Short answer: No, it's optional.**

Your Overseerr Content Filtering installation works completely without TVDB:

✅ **TV show search and discovery** - Works with TMDB data  
✅ **Content filtering and safety controls** - All based on TMDB data  
✅ **User requests and management** - Full functionality  
✅ **Plex integration** - Complete integration

## What TVDB Adds (Optional Enhancements)

If you configure TVDB, you'll get:

- **Enhanced TV show metadata** - More detailed episode information
- **Additional artwork** - Extra posters, banners, and fanart
- **More comprehensive cast/crew information** - Extended credits
- **Alternative series titles** - Names in different languages
- **TVDB-specific ratings** - Additional rating sources

## Getting a TVDB API Key

### 1. Create a TVDB Account
1. Go to [https://thetvdb.com/](https://thetvdb.com/)
2. Click "Sign Up" to create a free account
3. Verify your email address
4. Complete your profile setup

### 2. Request API Access
1. Once logged in, go to [https://thetvdb.com/api-information](https://thetvdb.com/api-information)
2. Click "Request API Key"
3. Fill out the application form:
   - **Project Name**: "Personal Overseerr Instance"
   - **Project Description**: "Personal media management and discovery"
   - **Project URL**: Your Overseerr URL (e.g., "http://localhost:5055")
   - **Contact Email**: Your email address
   - **Intended Use**: "Personal media server metadata enhancement"

### 3. API Key Details
- **Cost**: Free for personal/non-commercial use
- **Approval Time**: Usually immediate to a few hours
- **Rate Limits**: Generous limits for personal use
- **Format**: You'll receive a string like `1e722fb646416fa55d471b9595ee83becadd`

## Configuring TVDB in Overseerr

### Method 1: Manual Configuration (Recommended)

1. **Get your TVDB API key** (see above)
2. **Stop your Overseerr container**:
   ```bash
   docker stop overseerr-content-filtering
   ```
3. **Edit your settings.json file**:
   ```bash
   # Find your config directory (usually bind mount or volume)
   docker inspect overseerr-content-filtering --format='{{range .Mounts}}{{if eq .Destination "/app/config"}}{{.Source}}{{end}}{{end}}'
   
   # Edit the settings file
   nano /path/to/your/config/settings.json
   ```
4. **Add TVDB section** to your settings.json:
   ```json
   {
     "main": { ... },
     "tvdb": {
       "apiKey": "your-tvdb-api-key-here"
     },
     "plex": { ... }
   }
   ```
5. **Restart your container**:
   ```bash
   docker start overseerr-content-filtering
   ```

### Method 2: Environment Variable (Docker)

Add the TVDB API key as an environment variable:

```bash
docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -v /path/to/config:/app/config \
  -e TVDB_API_KEY=your-tvdb-api-key-here \
  --restart unless-stopped \
  larrikinau/overseerr-content-filtering:latest
```

### Method 3: Docker Compose

```yaml
version: '3.8'
services:
  overseerr-content-filtering:
    image: larrikinau/overseerr-content-filtering:latest
    container_name: overseerr-content-filtering
    ports:
      - 5055:5055
    volumes:
      - /path/to/config:/app/config
    environment:
      - NODE_ENV=production
      - RUN_MIGRATIONS=true
      - TVDB_API_KEY=your-tvdb-api-key-here
    restart: unless-stopped
```

## Migration Script and TVDB

The migration script (`migrate-to-content-filtering.sh`) will:

✅ **Automatically detect** existing TVDB API keys from your old installation  
✅ **Migrate them** to the new content filtering installation  
✅ **Handle missing keys gracefully** - won't fail if TVDB isn't configured  
✅ **Provide helpful messages** about optional TVDB configuration  

**If migration reports missing TVDB key:**
```
No TVDB API key found (optional - you can configure this later)
```

This is **not an error** - it's just informing you that TVDB wasn't configured in your original installation.

## Troubleshooting

### Q: Migration failed because of missing TVDB API key
**A**: This shouldn't happen with the updated migration script. TVDB is optional and missing keys are handled gracefully.

### Q: I want to add TVDB after migration
**A**: Follow the manual configuration steps above - you can add it anytime.

### Q: How do I know if TVDB is working?
**A**: Look for enhanced TV show metadata, additional artwork, and more detailed episode information in your Overseerr interface.

### Q: Can I remove TVDB later?
**A**: Yes, just remove the `tvdb` section from your settings.json and restart the container.

## Your Content Filtering Still Works

Remember: **All your content filtering features work with or without TVDB**:

- ✅ Global adult content blocking
- ✅ Admin-only rating controls  
- ✅ TMDB Curated Discovery
- ✅ Age rating restrictions
- ✅ Family safety controls

TVDB only adds extra metadata - it doesn't change your content filtering functionality.

## Support

If you have issues with TVDB configuration:

1. **Check your API key** - Make sure it's valid and active
2. **Verify JSON syntax** - Ensure settings.json is properly formatted
3. **Check container logs** - `docker logs overseerr-content-filtering`
4. **Test without TVDB** - Your installation works fine without it

For more help, see the main project documentation or create an issue on GitHub.
