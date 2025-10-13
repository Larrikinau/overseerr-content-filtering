# Docker Deployment Guide

## Overseerr Content Filtering Docker Setup

This guide covers advanced Docker deployment options for Overseerr Content Filtering v1.5.8, including security, networking, and troubleshooting.

## 🎉 Official Docker Hub Release

**✅ Production-Ready Docker Images Available**

- **Registry**: https://hub.docker.com/r/larrikinau/overseerr-content-filtering
- **Current Version**: `larrikinau/overseerr-content-filtering:latest` (v1.5.8)
- **Multi-Platform Support**: AMD64, ARM64, ARMv7

## 🐳 Quick Start with Pre-built Images

### Option 1: Docker Run

```bash
# Pull the latest image
docker pull larrikinau/overseerr-content-filtering:latest

# Run the container
docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -e TMDB_API_KEY=db55323b8d3e4154498498a75642b381 \
  -v /path/to/appdata/config:/app/config \
  --restart unless-stopped \
  larrikinau/overseerr-content-filtering:latest
```

### Option 2: Docker Compose

Create a `docker-compose.yml` file:

```yaml
version: '3.8'

services:
  overseerr-content-filtering:
    image: larrikinau/overseerr-content-filtering:latest
    container_name: overseerr-content-filtering
    environment:
      - TMDB_API_KEY=db55323b8d3e4154498498a75642b381  # Required for movie/TV data
      - TZ=Asia/Tokyo # optional
    ports:
      - '5055:5055'
    volumes:
      - /path/to/appdata/config:/app/config
    restart: unless-stopped
    healthcheck:
      test:
        [
          'CMD',
          'wget',
          '--no-verbose',
          '--tries=1',
          '--spider',
          'http://localhost:5055/api/v1/status',
        ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

Then run:

```bash
docker-compose up -d
```

## 🏗️ Building from Source

### Prerequisites

- Docker with BuildKit enabled
- Git
- Optional: Docker Buildx for multi-platform builds

### Build Script

Use the provided build script for easy building:

```bash
# Basic build
./scripts/build-docker.sh

# Build with specific tag
./scripts/build-docker.sh -t v1.3.1

# Multi-platform build and push
./scripts/build-docker.sh --multi-platform --push

# Build without cache
./scripts/build-docker.sh --no-cache
```

### Manual Build

```bash
# Clone the repository
git clone https://github.com/Larrikinau/overseerr-content-filtering.git
cd overseerr-content-filtering

# Build the image
docker build -t overseerr-content-filtering:local .

# Run the container
docker run -d \
  --name overseerr-content-filtering \
  -p 5055:5055 \
  -v overseerr-config:/app/config \
  overseerr-content-filtering:local
```

## 🔧 Environment Variables

| Variable           | Description                              | Default       | Required |
| ------------------ | ---------------------------------------- | ------------- | -------- |
| `TMDB_API_KEY`     | The Movie Database API key               | None          | **Yes**  |
| `LOG_LEVEL`        | Logging level (debug, info, warn, error) | `info`        | No       |
| `TZ`               | Timezone for the container               | `UTC`         | No       |
| `PORT`             | Port for the web interface               | `5055`        | No       |
| `CONFIG_DIRECTORY` | Path to config directory                 | `/app/config` | No       |

## 📁 Volume Mounts

### Required Volumes

- **Config Directory**: `/app/config`
  - Contains database, logs, and configuration files
  - Must be persistent across container restarts
  - **Important**: Use named volumes on Windows to avoid database corruption

### Example Volume Configurations

#### Linux/macOS (Host Path)

```bash
-v /opt/overseerr/config:/app/config
```

#### Windows (Named Volume)

```bash
-v overseerr-data:/app/config
```

#### Docker Compose (Named Volume)

```yaml
volumes:
  - overseerr-data:/app/config

volumes:
  overseerr-data:
```

## 🌐 Network Configuration

### Port Mapping

- **Default Port**: 5055
- **Custom Port**: Set via `PORT` environment variable
- **Host Port**: Map to any available host port

```bash
# Default mapping
-p 5055:5055

# Custom host port
-p 8080:5055

# Custom container port
-e PORT=8080 -p 8080:8080
```

### Reverse Proxy Setup

#### Nginx Example

```nginx
server {
    listen 80;
    server_name overseerr.yourdomain.com;

    location / {
        proxy_pass http://localhost:5055;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### Traefik Example

```yaml
services:
  overseerr-content-filtering:
    image: larrikinau/overseerr-content-filtering:latest
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.overseerr.rule=Host(`overseerr.yourdomain.com`)'
      - 'traefik.http.routers.overseerr.tls=true'
      - 'traefik.http.routers.overseerr.tls.certresolver=letsencrypt'
      - 'traefik.http.services.overseerr.loadbalancer.server.port=5055'
```

## 🔒 Security Considerations

### Container Security

1. **Run as non-root user** (built into image)
2. **Read-only root filesystem** (optional)
3. **Drop unnecessary capabilities**
4. **Use specific image tags** instead of `latest`

#### Enhanced Security Example

```bash
docker run -d \
  --name overseerr-content-filtering \
  --user 1001:1001 \
  --read-only \
  --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  -e LOG_LEVEL=info \
  -p 5055:5055 \
  -v overseerr-config:/app/config \
larrikinau/overseerr-content-filtering:latest
```

### Network Security

```bash
# Create isolated network
sudo docker network create overseerr-net

# Run with custom network
sudo docker run -d \
  --name overseerr-content-filtering \
  --network overseerr-net \
  -p 127.0.0.1:5055:5055 \  # Bind to localhost only
  larrikinau/overseerr-content-filtering:latest
```

## 📊 Health Checks

### Built-in Health Check

The Docker image includes a health check that monitors the application status:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5055/api/v1/status || exit 1
```

### Custom Health Check

```yaml
healthcheck:
  test: ['CMD', 'curl', '-f', 'http://localhost:5055/api/v1/status']
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

## 🔄 Updates and Maintenance

### Updating the Container

#### Docker Run

```bash
# Stop and remove old container
sudo docker stop overseerr-content-filtering
sudo docker rm overseerr-content-filtering

# Pull latest image
sudo docker pull larrikinau/overseerr-content-filtering:latest

# Start new container with same configuration
sudo docker run -d --name overseerr-content-filtering [options] larrikinau/overseerr-content-filtering:latest
```

#### Docker Compose

```bash
# Pull and restart
docker-compose pull
docker-compose up -d overseerr-content-filtering
```

### Backup Configuration

```bash
# Create backup of config volume
sudo docker run --rm \
  -v overseerr-config:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/overseerr-backup-$(date +%Y%m%d).tar.gz /data
```

### Restore Configuration

```bash
# Restore from backup
sudo docker run --rm \
  -v overseerr-config:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/overseerr-backup-YYYYMMDD.tar.gz -C /
```

## 🐛 Troubleshooting

### Common Issues

1. **Permission denied errors**

   ```bash
   # Fix ownership
   sudo docker exec overseerr-content-filtering chown -R app:app /app/config
   ```

2. **Database corruption (Windows)**

   - Use named volumes instead of host mounts
   - Ensure WSL2 is enabled

3. **Port conflicts**

   ```bash
   # Check what's using the port
   netstat -tlnp | grep :5055

   # Use different host port
   sudo docker run ... -p 8080:5055 ...
   ```

4. **Memory issues**
   ```bash
   # Increase container memory limit
   sudo docker run ... --memory=2g ...
   ```

### Debug Mode

```bash
# Enable debug logging
sudo docker run ... -e LOG_LEVEL=debug ...

# Check logs
sudo docker logs overseerr-content-filtering -f
```

### Container Shell Access

```bash
# Access container shell
sudo docker exec -it overseerr-content-filtering sh

# Check application status
sudo docker exec overseerr-content-filtering ps aux
```

## 📚 Additional Resources

- [Official Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Project Documentation](docs/)
- [Issue Tracker](../../issues)

## 🏷️ Image Tags

### Available Tags

- `latest` - Latest stable release (v1.4.0)
- `1.4.0` - Enhanced content filtering with admin controls
- `1.3.5` - Previous stable version
- `develop` - Development branch (unstable)

### Docker Versioning Strategy

**Version Alignment**: Docker image tags align with the project version in `package.json`:

- The `latest` tag always points to the most recent stable release
- Semantic version tags (e.g., `1.3.1`) correspond to specific GitHub releases
- Both `latest` and specific version tags are updated simultaneously during releases

**Tag Updates**: When a new version is released:

1. Project version is updated in `package.json`
2. Docker image is built with the new version tag
3. Both `X.Y.Z` and `latest` tags are pushed to Docker Hub
4. Previous version tags remain available for rollback purposes

**Recommended Usage**:

- **Production**: Use specific version tags (e.g., `1.4.0`) for reproducible deployments
- **Development/Testing**: Use `latest` for the most current stable features
- **Bleeding Edge**: Use `develop` for unreleased features (not recommended for production)

### Multi-Platform Support

The images support multiple architectures:

- `linux/amd64` (x86_64)
- `linux/arm64` (ARM64/v8)
- `linux/arm/v7` (ARM32/v7)

```bash
# Pull specific architecture
sudo docker pull --platform linux/arm64 larrikinau/overseerr-content-filtering:latest
```

---

For more information, visit the [project repository](https://github.com/Larrikinau/overseerr-content-filtering).
