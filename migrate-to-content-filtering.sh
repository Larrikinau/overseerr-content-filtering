#!/bin/bash

# Overseerr Content Filtering Migration Script
# Automatically migrates from vanilla Overseerr (Docker or Snap) to overseerr-content-filtering
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/Larrikinau/overseerr-content-filtering/main/migrate-to-content-filtering.sh)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    log_success "Docker is installed"
}

# Detect existing Overseerr installation
detect_overseerr() {
    log "Detecting existing Overseerr installation..."
    
    # Check for Docker container
    if docker ps -a --format "table {{.Names}}" | grep -q "overseerr"; then
        OVERSEERR_TYPE="docker"
        CONTAINER_NAME=$(docker ps -a --format "{{.Names}}" | grep overseerr | head -1)
        log_success "Found Docker installation: $CONTAINER_NAME"
        return 0
    fi
    
    # Check for Snap installation
    if command -v snap &> /dev/null && snap list | grep -q overseerr; then
        OVERSEERR_TYPE="snap"
        log_success "Found Snap installation"
        return 0
    fi
    
    # Check for systemd service
    if systemctl list-units --type=service | grep -q overseerr; then
        OVERSEERR_TYPE="systemd"
        log_success "Found systemd service installation"
        return 0
    fi
    
    log_warning "No existing Overseerr installation detected. This will be a fresh installation."
    OVERSEERR_TYPE="none"
}

# Backup existing configuration
backup_config() {
    log "Creating backup of existing configuration..."
    
    case $OVERSEERR_TYPE in
        "docker")
            # Get the volume or bind mount path
            CONFIG_PATH=$(docker inspect $CONTAINER_NAME | grep -A 5 "Mounts" | grep "config" | awk -F'"' '{print $4}' | head -1)
            if [ ! -z "$CONFIG_PATH" ]; then
                cp -r "$CONFIG_PATH" "${CONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || log_warning "Could not create filesystem backup"
            fi
            log_success "Docker volume will be preserved automatically"
            ;;
        "snap")
            SNAP_CONFIG="/var/snap/overseerr/common"
            if [ -d "$SNAP_CONFIG" ]; then
                sudo cp -r "$SNAP_CONFIG" "${SNAP_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
                log_success "Snap configuration backed up"
            fi
            ;;
        "systemd")
            # Common systemd installation paths
            for path in "/opt/overseerr/config" "/etc/overseerr" "/var/lib/overseerr"; do
                if [ -d "$path" ]; then
                    sudo cp -r "$path" "${path}.backup.$(date +%Y%m%d_%H%M%S)"
                    log_success "Systemd configuration backed up from $path"
                    SYSTEMD_CONFIG_PATH="$path"
                    break
                fi
            done
            ;;
    esac
}

# Stop existing Overseerr
stop_existing() {
    log "Stopping existing Overseerr installation..."
    
    case $OVERSEERR_TYPE in
        "docker")
            docker stop $CONTAINER_NAME || log_warning "Container was not running"
            docker rm $CONTAINER_NAME || log_warning "Could not remove container"
            log_success "Docker container stopped and removed"
            ;;
        "snap")
            sudo snap stop overseerr
            sudo snap remove overseerr
            log_success "Snap installation removed"
            ;;
        "systemd")
            sudo systemctl stop overseerr
            sudo systemctl disable overseerr
            log_success "Systemd service stopped and disabled"
            ;;
    esac
}

# Install overseerr-content-filtering
install_content_filtering() {
    log "Installing overseerr-content-filtering..."
    
    # Pull the latest image
    docker pull larrikinau/overseerr-content-filtering:latest
    log_success "Image pulled successfully"
    
    # Determine configuration volume/path
    case $OVERSEERR_TYPE in
        "docker")
            # Reuse existing Docker volume or create new one
            VOLUME_ARG="-v overseerr_config:/app/config"
            ;;
        "snap")
            # Copy snap config to Docker volume
            if [ -d "/var/snap/overseerr/common" ]; then
                docker volume create overseerr_config
                docker run --rm -v overseerr_config:/dest -v /var/snap/overseerr/common:/src alpine sh -c "cp -r /src/* /dest/"
                log_success "Snap configuration migrated to Docker volume"
            fi
            VOLUME_ARG="-v overseerr_config:/app/config"
            ;;
        "systemd")
            # Copy systemd config to Docker volume  
            if [ ! -z "$SYSTEMD_CONFIG_PATH" ]; then
                docker volume create overseerr_config
                docker run --rm -v overseerr_config:/dest -v "$SYSTEMD_CONFIG_PATH":/src alpine sh -c "cp -r /src/* /dest/"
                log_success "Systemd configuration migrated to Docker volume"
            fi
            VOLUME_ARG="-v overseerr_config:/app/config"
            ;;
        "none")
            # Fresh installation
            VOLUME_ARG="-v overseerr_config:/app/config"
            ;;
    esac
    
    # Start the new container
    docker run -d \
        --name overseerr-content-filtering \
        -p 5055:5055 \
        $VOLUME_ARG \
        -e NODE_ENV=production \
        -e RUN_MIGRATIONS=true \
        -e LOG_LEVEL=info \
        --restart unless-stopped \
        larrikinau/overseerr-content-filtering:latest
    
    log_success "overseerr-content-filtering container started"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    # Wait a moment for the container to start
    sleep 5
    
    # Check if container is running
    if docker ps | grep -q overseerr-content-filtering; then
        log_success "Container is running"
    else
        log_error "Container failed to start. Check logs with: docker logs overseerr-content-filtering"
        exit 1
    fi
    
    # Check if service is responding
    for i in {1..30}; do
        if curl -s http://localhost:5055/api/v1/status > /dev/null 2>&1; then
            log_success "Service is responding on http://localhost:5055"
            break
        fi
        if [ $i -eq 30 ]; then
            log_warning "Service is not responding yet. Check logs with: docker logs overseerr-content-filtering"
        fi
        sleep 2
    done
}

# Main migration function
main() {
    echo ""
    echo "=================================================="
    echo "   Overseerr Content Filtering Migration Tool    "
    echo "=================================================="
    echo ""
    echo "This script will:"
    echo "1. Detect your existing Overseerr installation"
    echo "2. Backup your configuration"
    echo "3. Stop the existing installation"
    echo "4. Install overseerr-content-filtering"
    echo "5. Migrate your settings and data"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Migration cancelled by user"
        exit 0
    fi
    
    check_docker
    detect_overseerr
    backup_config
    stop_existing
    install_content_filtering
    verify_installation
    
    echo ""
    echo "=================================================="
    log_success "Migration completed successfully!"
    echo "=================================================="
    echo ""
    echo "🎉 Your Overseerr Content Filtering is now running!"
    echo "🌐 Access it at: http://localhost:5055"
    echo "📊 Check logs: docker logs overseerr-content-filtering"
    echo "🔧 Manage container: docker stop/start overseerr-content-filtering"
    echo ""
    echo "New features available:"
    echo "• Global adult content blocking"
    echo "• Admin-only rating controls"
    echo "• TMDB Curated Discovery"
    echo "• Enhanced family safety controls"
    echo ""
    echo "Visit Settings → Users to configure content filtering."
    echo ""
}

# Run main function
main
