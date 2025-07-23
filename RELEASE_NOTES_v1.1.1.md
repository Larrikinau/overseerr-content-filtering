# Overseerr Content Filtering v1.1.1 Release Notes

## 🎉 Release Highlights

**v1.1.1** is a stability and reliability release that addresses critical TypeScript compilation issues and significantly improves Docker deployment experience. This release ensures smooth installation across all platforms while maintaining all content filtering capabilities.

## 🔧 What's Fixed

### 🐛 **TypeScript Compilation Issues**
- **Fixed**: Bash command substitution syntax in database migration files
- **Impact**: Eliminates build failures during installation
- **Benefit**: Reliable builds on all platforms and environments

### 🐳 **Docker Deployment Improvements**
- **Enhanced**: Automatic database migrations in Docker containers
- **Added**: `RUN_MIGRATIONS=true` environment variable for explicit control
- **Improved**: Comprehensive migration logging and error reporting
- **Created**: `DOCKER_TROUBLESHOOTING.md` guide for common issues

### 📦 **Build System Reliability**
- **Fixed**: Tar command parameter ordering in release scripts
- **Resolved**: GitHub file size limits by using GitHub Releases
- **Improved**: Error handling and user feedback during installation

## 🚀 New Features & Improvements

### ⚡ **Enhanced Installation Experience**
- **Automatic Migration Detection**: Smart detection of development vs production environments
- **Comprehensive Logging**: Detailed status messages for troubleshooting
- **Multiple Resolution Paths**: Various options for different deployment scenarios
- **Prevention Documentation**: Guides to avoid common installation pitfalls

### 🛡️ **Maintained Core Features**
- **Global Adult Content Blocking**: Zero tolerance policy remains active
- **Admin-Only Content Controls**: Centralized management preserved
- **Content Rating System**: Movie/TV rating filters working perfectly
- **All Original Overseerr Features**: Complete compatibility maintained

## 🔄 Upgrade Instructions

### For Docker Users
```bash
# Stop existing container
docker stop overseerr-content-filtering

# Pull latest image
docker pull larrikinau/overseerr-content-filtering:latest

# Start with migration environment variable
docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -v /path/to/config:/app/config \
  -e NODE_ENV=production \
  -e RUN_MIGRATIONS=true \
  --restart unless-stopped \
  larrikinau/overseerr-content-filtering:latest
```

### For Script Installation Users
```bash
# Download and run latest installation script
bash <(curl -fsSL https://raw.githubusercontent.com/Larrikinau/overseerr-content-filtering/main/install-overseerr-filtering.sh)
```

### For Manual Installation Users
1. Download the latest release from [GitHub Releases](https://github.com/Larrikinau/overseerr-content-filtering/releases/tag/v1.1.1)
2. Extract and follow the `INSTALL.txt` instructions
3. Ensure database migrations run during first startup

## 🆘 Troubleshooting

### Common Issues and Solutions

#### Issue: Docker container fails to start with database errors
**Solution**: Add environment variables to your Docker command:
```bash
-e NODE_ENV=production -e RUN_MIGRATIONS=true
```

#### Issue: Plex authentication loops after Docker deployment
**Solution**: Check container logs for migration completion:
```bash
docker logs overseerr-content-filtering
```
Look for: `[info][Database] Database migrations completed successfully`

#### Issue: Build fails with TypeScript errors
**Solution**: This is fixed in v1.1.1. Update to the latest version.

### 📖 Complete Troubleshooting Guide
For comprehensive troubleshooting, see: [DOCKER_TROUBLESHOOTING.md](DOCKER_TROUBLESHOOTING.md)

## 🔍 Verification Steps

After upgrading, verify your installation:

1. **Check Service Status**
   ```bash
   # For Docker
   docker ps | grep overseerr-content-filtering
   
   # For systemd
   systemctl status overseerr-content-filtering
   ```

2. **Access Web Interface**
   - Navigate to `http://localhost:5055`
   - Login with your existing credentials

3. **Verify Content Filtering**
   - Browse movie/TV genres
   - Confirm no adult content appears
   - Check admin-only rating controls (admin users only)

4. **Test Database Migrations**
   - Check container/service logs for migration success messages
   - Verify user settings are preserved

## 📞 Support

### Getting Help
- **📖 Documentation**: [Complete Installation Guide](INSTALL.md)
- **🐛 Issues**: [GitHub Issues](https://github.com/Larrikinau/overseerr-content-filtering/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/Larrikinau/overseerr-content-filtering/discussions)

### Before Reporting Issues
1. Check the [troubleshooting guide](DOCKER_TROUBLESHOOTING.md)
2. Verify you're using the latest version (v1.1.1)
3. Include relevant logs and configuration details

## 🙏 Acknowledgments

Thanks to the community for reporting issues and providing feedback:
- **@Geekerbyname** for reporting Docker migration issues
- **TrueNAS users** for Docker deployment feedback
- **All users** who provided installation feedback

## 📊 Technical Details

### Files Changed
- `server/migration/1751780113000-AddUserRatingPreferences.ts` - Fixed TypeScript syntax
- `server/index.ts` - Enhanced migration logic
- `Dockerfile` - Added production environment variables
- `DOCKER_TROUBLESHOOTING.md` - New troubleshooting guide
- Build scripts - Improved reliability and error handling

### Migration Logic
```typescript
// Enhanced migration detection
if (process.env.NODE_ENV === 'production' || process.env.RUN_MIGRATIONS === 'true') {
  logger.info('Running database migrations...', { label: 'Database' });
  await dbConnection.query('PRAGMA foreign_keys=OFF');
  await dbConnection.runMigrations();
  await dbConnection.query('PRAGMA foreign_keys=ON');
  logger.info('Database migrations completed successfully', { label: 'Database' });
}
```

## 🎯 Next Steps

### Upcoming Features
- **v1.2.2**: Enhanced rating system with regional compatibility
- **v1.3.0**: Advanced content filtering options
- **v1.4.0**: Improved admin dashboard for content management

### Community Contributions
- Contributions welcome on [GitHub](https://github.com/Larrikinau/overseerr-content-filtering)
- Check [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines

---

**Version**: 1.1.1
**Release Date**: July 11, 2025
**Compatibility**: All Overseerr installations
**Migration**: Automatic (for Docker users with environment variables)

Built with ❤️ for better content management
