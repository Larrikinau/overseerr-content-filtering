# Docker Troubleshooting Guide

## Common Issues and Solutions

### Database Migration Issues

#### Problem: "SQLITE_ERROR: no such column: User_settings.maxMovieRating"

This error occurs when the database schema doesn't include the content filtering columns. The content filtering fork adds new columns to the database that need to be created through migrations.

**Symptoms:**
- Plex sign-in fails and returns to setup screen
- Error logs show "no such column" messages
- Container appears to start but authentication fails

**Root Cause:**
The database migration process wasn't executed properly when the container started with an existing database.

**Solutions:**

#### Solution 1: Force Migration Run (Recommended)
Add the `RUN_MIGRATIONS=true` environment variable to your Docker compose file:

```yaml
version: '3.8'
services:
  overseerr:
    image: overseerr-content-filtering:latest
    container_name: overseerr-filtering
    ports:
      - "5056:5055"
    volumes:
      - ./config:/app/config
      - ./logs:/app/logs
    environment:
      - NODE_ENV=production
      - RUN_MIGRATIONS=true
      - LOG_LEVEL=info
    restart: unless-stopped
```

Then restart your container:
```bash
docker compose down
docker compose up -d
```

#### Solution 2: Fresh Database (If no existing data)
If you don't have important data to preserve:

```bash
# Stop container
docker compose down

# Remove database
rm -rf ./config/db

# Start container (will create fresh database with proper schema)
docker compose up -d
```

#### Solution 3: Manual Migration (Advanced)
If you need to preserve existing data:

```bash
# Stop container
docker compose down

# Install sqlite3
sudo apt-get install sqlite3

# Access database
sqlite3 ./config/db/db.sqlite3

# Run migration SQL
ALTER TABLE user_settings ADD COLUMN maxMovieRating varchar;
ALTER TABLE user_settings ADD COLUMN maxTvRating varchar;
UPDATE user_settings SET maxMovieRating = 'PG-13' WHERE maxMovieRating IS NULL;
UPDATE user_settings SET maxTvRating = 'TV-PG' WHERE maxTvRating IS NULL;

# Verify
PRAGMA table_info(user_settings);

# Exit
.quit

# Start container
docker compose up -d
```

### Environment Variables

#### Required Variables for Content Filtering:
- `NODE_ENV=production` - Enables production mode
- `RUN_MIGRATIONS=true` - Forces database migrations to run
- `LOG_LEVEL=info` - Provides detailed logging

#### Optional Variables:
- `CONFIG_DIRECTORY=/app/config` - Custom config directory
- `TZ=America/New_York` - Timezone setting

### Verification Steps

After applying a solution:

1. **Check logs:**
   ```bash
   docker logs overseerr-filtering -f
   ```

2. **Look for migration success:**
   ```
   [info][Database] Running database migrations...
   [info][Database] Database migrations completed successfully
   ```

3. **Test login:**
   - Access web interface
   - Complete Plex authentication
   - Verify no errors in logs

4. **Verify content filtering:**
   - Log in as admin user
   - Go to Settings → User Settings
   - Check that "Content Rating Filtering" section is visible

### Common Docker Compose Issues

#### Volume Mounting
Ensure your volumes are mounted correctly:
```yaml
volumes:
  - ./config:/app/config     # Not /app/config/config
  - ./logs:/app/logs         # Optional for log access
```

#### Port Conflicts
If port 5055 is in use, change the host port:
```yaml
ports:
  - "5056:5055"  # Host:Container
```

#### File Permissions
If running on Linux, ensure proper permissions:
```bash
# Make sure Docker can write to config directory
chmod 755 ./config
sudo chown -R 1000:1000 ./config
```

### Getting Help

If you continue to experience issues:

1. **Enable debug logging:**
   ```yaml
   environment:
     - LOG_LEVEL=debug
   ```

2. **Collect logs:**
   ```bash
   docker logs overseerr-filtering > overseerr-debug.log 2>&1
   ```

3. **Check database schema:**
   ```bash
   docker exec overseerr-filtering sqlite3 /app/config/db/db.sqlite3 "PRAGMA table_info(user_settings);"
   ```

4. **Verify migration files:**
   ```bash
   docker exec overseerr-filtering ls -la /app/dist/migration/
   ```

### Prevention

To avoid future issues:

1. **Always set environment variables:**
   ```yaml
   environment:
     - NODE_ENV=production
     - RUN_MIGRATIONS=true
   ```

2. **Backup before updates:**
   ```bash
   cp -r ./config ./config.backup
   ```

3. **Test with minimal setup first:**
   ```bash
   # Use fresh database for testing
   docker run --rm -p 5056:5055 -e NODE_ENV=production -e RUN_MIGRATIONS=true overseerr-content-filtering:latest
   ```

4. **Monitor startup logs:**
   ```bash
   docker logs overseerr-filtering -f
   ```
