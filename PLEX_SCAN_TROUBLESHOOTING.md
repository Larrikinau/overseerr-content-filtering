# Plex Scan Troubleshooting Guide

If you're experiencing Plex scan failures after migrating to Overseerr Content Filtering, this guide will help you diagnose and resolve the issues.

## Common Plex Scan Issues

### 1. **Authentication Issues**

**Symptoms:**
- Plex scan fails with authentication errors
- "No admin configured" messages in logs
- "Plex Token not found" errors

**Solutions:**

#### Check Admin User Configuration
```bash
# Check if admin user exists and has Plex token
docker exec overseerr-content-filtering sqlite3 /app/config/db/db.sqlite3 "SELECT id, plexToken FROM user WHERE id = 1;"
```

#### Re-authenticate with Plex
1. Go to Settings → Plex
2. Click "Sign In" and re-authenticate with your Plex account
3. Verify the Plex server connection is working

#### Manual Token Configuration
If web authentication fails, you can manually set your Plex token:
```bash
# Get your Plex token from: https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
# Then update the database:
docker exec overseerr-content-filtering sqlite3 /app/config/db/db.sqlite3 "UPDATE user SET plexToken = 'YOUR_PLEX_TOKEN_HERE' WHERE id = 1;"
```

### 2. **Network/Connectivity Issues**

**Symptoms:**
- Timeouts when scanning libraries
- "Cannot connect to Plex server" errors
- Intermittent scan failures

**Solutions:**

#### Verify Plex Server Settings
1. Check Settings → Plex → General:
   - Server IP/hostname is correct
   - Port is correct (default: 32400)
   - SSL settings match your Plex server

#### Test Network Connectivity
```bash
# Test from within the container
docker exec overseerr-content-filtering curl -I http://YOUR_PLEX_IP:32400/web/index.html

# Test with SSL if enabled
docker exec overseerr-content-filtering curl -I https://YOUR_PLEX_IP:32400/web/index.html
```

#### Docker Network Issues
If using Docker, ensure containers can communicate:
```bash
# Check if both containers are on the same network
docker network ls
docker network inspect bridge  # or your custom network
```

### 3. **Library Configuration Issues**

**Symptoms:**
- Some libraries don't scan
- "Library not found" errors
- Metadata agent errors

**Solutions:**

#### Sync Plex Libraries
1. Go to Settings → Plex → Libraries
2. Click "Sync Libraries" to refresh the library list
3. Enable the libraries you want to scan

#### Check Library Agents
Ensure your Plex libraries use supported metadata agents:
- **Supported:** Plex Movie, Plex TV Series, TMDB, TVDB, IMDb
- **Not supported:** Personal Media, None

#### Manual Library Check
```bash
# Check available libraries
docker exec overseerr-content-filtering curl -H "X-Plex-Token: YOUR_TOKEN" "http://YOUR_PLEX_IP:32400/library/sections"
```

### 4. **Performance Issues**

**Symptoms:**
- Scans take extremely long
- High CPU/memory usage
- Timeout errors

**Solutions:**

#### Adjust Scan Settings
1. Go to Settings → Jobs & Cache
2. Reduce scan frequency for large libraries
3. Use "Recently Added" scans instead of full scans

#### Optimize Database
```bash
# Vacuum the database to optimize performance
docker exec overseerr-content-filtering sqlite3 /app/config/db/db.sqlite3 "VACUUM;"
```

#### Container Resource Limits
```bash
# Start container with resource limits
docker run -d --name overseerr-content-filtering \
  --memory=1g --cpus=0.5 \
  # ... other options
```

### 5. **Database/Migration Issues**

**Symptoms:**
- Scan fails after migration
- "Database locked" errors
- Missing media data

**Solutions:**

#### Check Database Integrity
```bash
# Check database integrity
docker exec overseerr-content-filtering sqlite3 /app/config/db/db.sqlite3 "PRAGMA integrity_check;"
```

#### Verify Content Filtering Migrations
```bash
# Check if content filtering columns exist
docker exec overseerr-content-filtering sqlite3 /app/config/db/db.sqlite3 ".schema user_settings" | grep -E "(maxMovieRating|maxTvRating|tmdbSortingMode)"
```

#### Reset Scan Data (if needed)
```bash
# This will reset all scan data and force a full rescan
docker exec overseerr-content-filtering sqlite3 /app/config/db/db.sqlite3 "DELETE FROM media;"
```

## Diagnostic Commands

### Check Container Logs
```bash
# View recent logs
docker logs overseerr-content-filtering --tail 100 -f

# Filter for Plex-related logs
docker logs overseerr-content-filtering 2>&1 | grep -i plex
```

### Check Plex Scan Status
```bash
# Check scan status via API
curl -s "http://localhost:5055/api/v1/settings/jobs" | jq '.jobs[] | select(.id | contains("plex"))'
```

### Test Plex API Connectivity
```bash
# Test basic Plex API connection
curl -H "X-Plex-Token: YOUR_TOKEN" "http://YOUR_PLEX_IP:32400/library/sections"
```

## Environment Variables for Troubleshooting

Add these to your Docker environment for better debugging:

```bash
# Enable debug logging
LOG_LEVEL=debug

# Plex-specific debugging
PLEX_DEBUG=true
```

## When to Contact Support

Contact support if you experience:
- Persistent authentication failures after trying all solutions
- Database corruption that can't be resolved
- Scan failures that work in vanilla Overseerr but not in the content filtering version

## Common Error Messages and Solutions

| Error Message | Likely Cause | Solution |
|---------------|--------------|----------|
| "No admin configured" | Admin user missing or no Plex token | Re-authenticate with Plex |
| "Plex Token not found" | Invalid/expired token | Get new token from Plex |
| "Cannot connect to Plex server" | Network/connection issue | Check IP, port, SSL settings |
| "Library not found" | Library disabled or removed | Sync libraries and enable |
| "Database locked" | Concurrent access issue | Restart container, check file permissions |
| "Scan interrupted" | Timeout or resource issue | Reduce scan frequency, add resources |

## Prevention Tips

1. **Regular Monitoring**: Check scan logs regularly
2. **Incremental Scans**: Use "Recently Added" scans for large libraries
3. **Resource Management**: Monitor container resource usage
4. **Backup Strategy**: Regular database backups before major changes
5. **Update Schedule**: Keep both Plex and Overseerr updated

## Additional Resources

- [Plex Authentication Token Guide](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/)
- [Overseerr Docker Configuration](https://docs.overseerr.dev/getting-started/installation#docker)
- [Plex API Documentation](https://www.plexopedia.com/plex-media-server/api/)

---

*This guide is specifically for Overseerr Content Filtering. For general Overseerr issues, consult the [official documentation](https://docs.overseerr.dev/).*
