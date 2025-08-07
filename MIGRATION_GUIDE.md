# Migration Guide: From Overseerr to Overseerr Content Filtering v1.4.0

## 🚀 One-Command Migration

**The easiest way to migrate is with our automated script:**

```bash
# Download migration script
curl -fsSL https://github.com/Larrikinau/overseerr-content-filtering/raw/main/migrate-to-overseerr-content-filtering.sh -o migrate-to-overseerr-content-filtering.sh
chmod +x migrate-to-overseerr-content-filtering.sh

# Run migration script (add sudo if you get Docker permission errors)
sudo ./migrate-to-overseerr-content-filtering.sh
```

These commands will:
- ✅ Detect your existing Overseerr installation (Docker, Snap, or systemd)
- ✅ Automatically backup your configuration
- ✅ Stop your existing installation safely
- ✅ Install overseerr-content-filtering with Docker
- ✅ Migrate all your settings, users, and request history
- ✅ Verify the new installation is working

## 📋 What Gets Preserved

### 🔒 **100% Data Preservation**
- **User accounts**: All existing users and permissions
- **Request history**: Complete request and approval history
- **Settings**: Plex servers, Sonarr/Radarr configurations
- **Database**: Entire SQLite database with all relationships
- **Notifications**: All notification agent configurations

### 🆕 **New Features Added**
- **Smart content blocking**: Adult content blocked by default, with admin-configurable per-user overrides
- **Admin-only rating controls**: Centralized content management
- **TMDB Curated Discovery**: Quality-filtered content discovery
- **Enhanced safety controls**: Multi-layer content filtering

## 🔧 Migration Process Details

### Supported Source Installations
| Installation Type | Supported | Notes |
|------------------|-----------|-------|
| **Docker** | ✅ Yes | Seamless volume migration |
| **Snap** | ✅ Yes | Config copied to Docker volume |
| **Systemd Service** | ✅ Yes | Config migrated automatically |
| **Manual Install** | ⚠️ Partial | May require manual config path |

### What The Script Does

#### 1. **Detection Phase**
```bash
# Automatically detects:
- Docker containers named "overseerr"
- Snap installations: snap list | grep overseerr  
- Systemd services: systemctl list-units | grep overseerr
```

#### 2. **Backup Phase**
```bash
# Creates timestamped backups:
- Docker: Preserves existing volumes
- Snap: /var/snap/overseerr/common → backup
- Systemd: /opt/overseerr/config → backup
```

#### 3. **Migration Phase**
```bash
# Stops old installation and starts new:
docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -v overseerr_config:/app/config \
  -e NODE_ENV=production \
  -e RUN_MIGRATIONS=true \
larrikinau/overseerr-content-filtering:latest
```

#### 4. **Verification Phase**
```bash
# Confirms successful migration:
- Container is running
- Service responds on port 5055
- Database migrations completed
- All existing data accessible
```

## 🛠️ Manual Migration (Advanced Users)

If you prefer manual control or have a custom setup:

### For Docker Users
```bash
# 1. Stop existing container
sudo docker stop overseerr && sudo docker rm overseerr

# 2. Pull new image
sudo docker pull larrikinau/overseerr-content-filtering:latest

# 3. Start with existing volume
sudo docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -v overseerr_config:/app/config \
  -e TMDB_API_KEY=db55323b8d3e4154498498a75642b381 \
  -e NODE_ENV=production \
  -e RUN_MIGRATIONS=true \
  --restart unless-stopped \
  larrikinau/overseerr-content-filtering:latest
```

### For Snap Users
```bash
# 1. Backup snap config
sudo cp -r /var/snap/overseerr/common /var/snap/overseerr/common.backup

# 2. Remove snap installation
sudo snap remove overseerr

# 3. Install Docker (if needed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 4. Create Docker volume and copy config
sudo docker volume create overseerr_config
sudo docker run --rm -v overseerr_config:/dest -v /var/snap/overseerr/common:/src alpine sh -c "cp -r /src/* /dest/"

# 5. Start overseerr-content-filtering
sudo docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -v overseerr_config:/app/config \
  -e TMDB_API_KEY=db55323b8d3e4154498498a75642b381 \
  -e NODE_ENV=production \
  -e RUN_MIGRATIONS=true \
  --restart unless-stopped \
  larrikinau/overseerr-content-filtering:latest
```

### For Systemd Service Users
```bash
# 1. Stop and disable service
sudo systemctl stop overseerr
sudo systemctl disable overseerr

# 2. Backup configuration
sudo cp -r /opt/overseerr/config /opt/overseerr/config.backup

# 3. Install Docker and migrate config
sudo docker volume create overseerr_config
sudo docker run --rm -v overseerr_config:/dest -v /opt/overseerr/config:/src alpine sh -c "cp -r /src/* /dest/"

# 4. Start new container
sudo docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -v overseerr_config:/app/config \
  -e TMDB_API_KEY=db55323b8d3e4154498498a75642b381 \
  -e NODE_ENV=production \
  -e RUN_MIGRATIONS=true \
  --restart unless-stopped \
  larrikinau/overseerr-content-filtering:latest
```

## 🔍 Post-Migration Verification

### 1. **Check Container Status**
```bash
sudo docker ps | grep overseerr-content-filtering
```

### 2. **Verify Service Response**
```bash
curl http://localhost:5055/api/v1/status
```

### 3. **Check Migration Logs**
```bash
sudo docker logs overseerr-content-filtering | grep -i migration
```
Look for: `[info][Database] Database migrations completed successfully`

### 4. **Test Web Interface**
1. Navigate to `http://localhost:5055`
2. Login with existing credentials
3. Verify users and settings are preserved
4. Check that requests history is intact

### 5. **Verify New Features**
1. **Admin users**: Go to Settings → Users → User Settings
2. **Check for**: "Content Rating Filtering" section
3. **Verify**: Adult content blocking is active
4. **Test**: TMDB Curated Discovery in Settings → General

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Issue: Container won't start
```bash
# Check logs for errors
sudo docker logs overseerr-content-filtering

# Ensure migrations are enabled
sudo docker run -d ... -e RUN_MIGRATIONS=true ...
```

#### Issue: Database migration errors
```bash
# Force migration run
sudo docker exec overseerr-content-filtering sqlite3 /app/config/db/db.sqlite3 "PRAGMA integrity_check;"

# Restart with fresh migration
sudo docker rm overseerr-content-filtering
sudo docker run -d ... -e NODE_ENV=production -e RUN_MIGRATIONS=true ...
```

#### Issue: Port 5055 already in use
```bash
# Use different host port
sudo docker run -d ... -p 5056:5055 ...
# Access via http://localhost:5056
```

#### Issue: Permission denied on config folder
```bash
# Fix Docker volume permissions
sudo docker exec overseerr-content-filtering chown -R overseerr:nodejs /app/config
```

### Getting Help

If migration fails or you encounter issues:

1. **Check logs**: `sudo docker logs overseerr-content-filtering`
2. **Enable debug**: Add `-e LOG_LEVEL=debug` to Docker command
3. **Backup verification**: Ensure your backup was created successfully
4. **GitHub Issues**: [Report issues](https://github.com/Larrikinau/overseerr-content-filtering/issues) with:
   - Migration script output
   - Container logs
   - Source installation type (Docker/Snap/Systemd)
   - Operating system details

## 🎯 Post-Migration Configuration

### Configure Content Filtering (Admin Users Only)

1. **Navigate to**: Settings → Users → User Settings
2. **Select user** to configure
3. **Set content ratings**:
   - **Max Movie Rating**: G, PG, PG-13, R, NC-17
   - **Max TV Rating**: TV-Y, TV-Y7, TV-G, TV-PG, TV-14, TV-MA
4. **Save settings** - filtering applies immediately

### Configure TMDB Curated Discovery

1. **Admin settings**: Settings → General → TMDB Curated Discovery
   - **Default Min Votes**: 3000 (recommended)
   - **Default Min Rating**: 6.0 (recommended)
   - **Allow User Override**: Enable/disable user customization

2. **User settings**: Settings → General → Discovery Preferences
   - **Discovery Mode**: Standard vs Curated
   - **Custom Thresholds**: Adjust if enabled by admin

## ✅ Benefits After Migration

### 🛡️ **Enhanced Security**
- **Zero adult content**: Blocked at API level
- **Family-safe browsing**: All discovery content appropriate
- **Admin controls**: Centralized content management

### 🎯 **Better Discovery**
- **Quality filtering**: Only well-rated content in discovery
- **Dual modes**: Standard and curated discovery options
- **Smart recommendations**: Enhanced with quality thresholds

### 🔧 **Improved Management**
- **Per-user settings**: Individual rating controls
- **Preserved functionality**: All original Overseerr features
- **Docker benefits**: Better resource management and updates

---

## 📞 Support

- **📖 Documentation**: [Complete guide](README.md)
- **🐛 Issues**: [GitHub Issues](https://github.com/Larrikinau/overseerr-content-filtering/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/Larrikinau/overseerr-content-filtering/discussions)
- **📋 Migration Script**: [migrate-to-overseerr-content-filtering.sh](migrate-to-overseerr-content-filtering.sh)

**Migration takes ~2-5 minutes and preserves all your data!**
