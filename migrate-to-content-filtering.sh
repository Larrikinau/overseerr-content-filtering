#!/bin/bash

# Overseerr Content Filtering Migration Script
# Automatically migrates from vanilla Overseerr to overseerr-content-filtering
# Preserves all data while adding enhanced content filtering capabilities
# Usage: curl -fsSL https://github.com/Larrikinau/overseerr-content-filtering/raw/main/migrate-to-content-filtering.sh -o migrate-to-content-filtering.sh
#        chmod +x migrate-to-content-filtering.sh
#        sudo ./migrate-to-content-filtering.sh

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
    touch "/tmp/migration_warnings"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# Check if Docker is installed and accessible
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    log_success "Docker is installed"
    
    # Check if Docker daemon is running and accessible
    if ! docker info &> /dev/null; then
        log_error "Cannot connect to Docker daemon. This could be because:"
        log_error "1. Docker daemon is not running"
        log_error "2. Permission issues accessing Docker"
        log_error ""
        log_error "Solutions:"
        log_error "• On macOS: Make sure Docker Desktop is running"
        log_error "• On Linux: Start Docker service: sudo systemctl start docker"
        log_error "• This script is designed to run with sudo for reliable Docker access"
        exit 1
    fi
    log_success "Docker daemon is accessible"
}

# Detect existing Overseerr installation
detect_overseerr() {
    log "Detecting existing Overseerr installation..."
    
    # Check for docker-compose.yml files first (highest priority)
    for compose_file in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
        if [ -f "$compose_file" ] && grep -q "overseerr" "$compose_file"; then
            OVERSEERR_TYPE="docker-compose"
            COMPOSE_FILE="$compose_file"
            # Extract container name from compose file
            CONTAINER_NAME=$(docker ps -a --format "{{.Names}}" | grep overseerr | head -1)
            if [ -z "$CONTAINER_NAME" ]; then
                # Try to get it from the compose file
                CONTAINER_NAME=$(grep -A 10 "container_name:" "$compose_file" | grep "overseerr" | head -1 | sed 's/.*container_name: *//; s/"//g; s/'\''//g')
            fi
            log_success "Found Docker Compose installation: $compose_file (container: $CONTAINER_NAME)"
            return 0
        fi
    done
    
    # Check for Docker container (fallback to regular docker)
    if docker ps -a --format "table {{.Names}}" | grep -q "overseerr"; then
        OVERSEERR_TYPE="docker"
        CONTAINER_NAME=$(docker ps -a --format "{{.Names}}" | grep overseerr | head -1)
        log_success "Found Docker installation: $CONTAINER_NAME"
        return 0
    fi
    
    # Check for containers with "overseerr" in the image name
    if docker ps -a --format "table {{.Names}}\t{{.Image}}" | grep -i overseerr | head -1 | cut -f1 > /dev/null 2>&1; then
        OVERSEERR_TYPE="docker"
        CONTAINER_NAME=$(docker ps -a --format "table {{.Names}}\t{{.Image}}" | grep -i overseerr | head -1 | cut -f1)
        log_success "Found Docker installation by image: $CONTAINER_NAME"
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

# Backup existing configuration and detect mount details
backup_config() {
    log "Creating backup of existing configuration..."
    
    case $OVERSEERR_TYPE in
        "docker-compose"|"docker")
            # Handle docker-compose backup - backup compose file if present
            if [ "$OVERSEERR_TYPE" = "docker-compose" ] && [ -f "$COMPOSE_FILE" ]; then
                cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
                log_success "Docker Compose file backed up: $COMPOSE_FILE"
            fi
            # Get detailed mount information from Docker inspect - try multiple mount patterns
            MOUNT_INFO=$(docker inspect $CONTAINER_NAME --format='{{range .Mounts}}{{if eq .Destination "/app/config"}}{{.Type}}:{{.Source}}:{{.Destination}}{{end}}{{end}}')
            
            # If no /app/config mount found, try common alternatives
            if [ -z "$MOUNT_INFO" ]; then
                MOUNT_INFO=$(docker inspect $CONTAINER_NAME --format='{{range .Mounts}}{{if eq .Destination "/config"}}{{.Type}}:{{.Source}}:{{.Destination}}{{end}}{{end}}')
                if [ ! -z "$MOUNT_INFO" ]; then
                    log "Found alternative config mount at /config"
                fi
            fi
            
            # Try to detect any volume/bind mount that might contain config
            if [ -z "$MOUNT_INFO" ]; then
                # Look for any mount containing settings.json or db files
                ALL_MOUNTS=$(docker inspect $CONTAINER_NAME --format='{{range .Mounts}}{{.Type}}:{{.Source}}:{{.Destination}}|{{end}}')
                for mount in $(echo $ALL_MOUNTS | tr '|' ' '); do
                    if [ ! -z "$mount" ]; then
                        MOUNT_TYPE=$(echo $mount | cut -d':' -f1)
                        MOUNT_SOURCE=$(echo $mount | cut -d':' -f2)
                        MOUNT_DEST=$(echo $mount | cut -d':' -f3)
                        
                        if [ "$MOUNT_TYPE" = "bind" ] && [ -d "$MOUNT_SOURCE" ]; then
                            # Check if this bind mount contains Overseerr data
                            if [ -f "$MOUNT_SOURCE/settings.json" ] || [ -f "$MOUNT_SOURCE/db/db.sqlite3" ]; then
                                MOUNT_INFO="$mount"
                                log "Found Overseerr config in bind mount: $MOUNT_SOURCE -> $MOUNT_DEST"
                                break
                            fi
                        fi
                    fi
                done
            fi
            
            if [ ! -z "$MOUNT_INFO" ]; then
                MOUNT_TYPE=$(echo $MOUNT_INFO | cut -d':' -f1)
                MOUNT_SOURCE=$(echo $MOUNT_INFO | cut -d':' -f2)
                
                log "Found Docker mount: Type=$MOUNT_TYPE, Source=$MOUNT_SOURCE"
                
                if [ "$MOUNT_TYPE" = "bind" ]; then
                    # Bind mount - backup the host directory
                    DOCKER_CONFIG_PATH="$MOUNT_SOURCE"
                    if [ -d "$DOCKER_CONFIG_PATH" ]; then
                        cp -r "$DOCKER_CONFIG_PATH" "${DOCKER_CONFIG_PATH}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || log_warning "Could not create filesystem backup"
                        log_success "Docker bind mount backed up from $DOCKER_CONFIG_PATH"
                    fi
                elif [ "$MOUNT_TYPE" = "volume" ]; then
                    # Named volume - backup the volume
                    DOCKER_VOLUME_NAME="$MOUNT_SOURCE"
                    docker run --rm -v $DOCKER_VOLUME_NAME:/source -v $(pwd):/backup alpine tar czf /backup/overseerr_volume_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /source . 2>/dev/null || log_warning "Could not create volume backup"
                    log_success "Docker volume '$DOCKER_VOLUME_NAME' backed up"
                fi
            else
                log_warning "No config mount found in existing container - this may cause data loss"
                log_warning "You may need to manually copy your Overseerr configuration to the new container"
            fi
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

# Extract TMDB and TVDB API keys from existing installation before stopping
extract_api_keys() {
    log "Extracting API keys from existing installation..."
    
    case $OVERSEERR_TYPE in
        "docker-compose"|"docker")
            # For Docker, extract from running container or mounted volume
            if [ "$MOUNT_TYPE" = "bind" ] && [ -f "$DOCKER_CONFIG_PATH/settings.json" ]; then
                # Bind mount - read directly from host filesystem
                if command -v jq > /dev/null 2>&1; then
                    TMDB_API_KEY=$(jq -r '.main.tmdbApiKey // null' "$DOCKER_CONFIG_PATH/settings.json" 2>/dev/null)
                    if [ "$TMDB_API_KEY" != "null" ] && [ "$TMDB_API_KEY" != "" ]; then
                        log "Found TMDB API key in bind mount settings"
                        echo "TMDB_API_KEY=$TMDB_API_KEY" >> /tmp/overseerr_env_backup
                    fi
                    
                    # Extract TVDB API key (optional)
                    TVDB_API_KEY=$(jq -r '.tvdb.apiKey // null' "$DOCKER_CONFIG_PATH/settings.json" 2>/dev/null)
                    if [ "$TVDB_API_KEY" != "null" ] && [ "$TVDB_API_KEY" != "" ]; then
                        log "Found TVDB API key in bind mount settings"
                        echo "TVDB_API_KEY=$TVDB_API_KEY" >> /tmp/overseerr_env_backup
                    else
                        log "No TVDB API key found (optional - you can configure this later)"
                    fi
                fi
            elif [ "$MOUNT_TYPE" = "volume" ]; then
                # Volume mount - extract from running container
                if docker exec $CONTAINER_NAME test -f /app/config/settings.json 2>/dev/null; then
                    TMDB_API_KEY=$(docker exec $CONTAINER_NAME cat /app/config/settings.json 2>/dev/null | jq -r '.main.tmdbApiKey // null' 2>/dev/null)
                    if [ "$TMDB_API_KEY" != "null" ] && [ "$TMDB_API_KEY" != "" ]; then
                        log "Found TMDB API key in volume settings"
                        echo "TMDB_API_KEY=$TMDB_API_KEY" >> /tmp/overseerr_env_backup
                    fi
                    
                    # Extract TVDB API key (optional)
                    TVDB_API_KEY=$(docker exec $CONTAINER_NAME cat /app/config/settings.json 2>/dev/null | jq -r '.tvdb.apiKey // null' 2>/dev/null)
                    if [ "$TVDB_API_KEY" != "null" ] && [ "$TVDB_API_KEY" != "" ]; then
                        log "Found TVDB API key in volume settings"
                        echo "TVDB_API_KEY=$TVDB_API_KEY" >> /tmp/overseerr_env_backup
                    else
                        log "No TVDB API key found (optional - you can configure this later)"
                    fi
                fi
            fi
            
            # Also extract environment variables from running container
            if [ -n "$CONTAINER_NAME" ]; then
                docker inspect "$CONTAINER_NAME" --format="{{range .Config.Env}}{{println .}}{{end}}" | grep -E '^(TMDB_API_KEY|TVDB_API_KEY|CONFIG_DIRECTORY|TZ)=' >> /tmp/overseerr_env_backup 2>/dev/null || true
            fi
            ;;
        "snap")
            # Extract from snap settings
            if [ -f "/var/snap/overseerr/common/settings.json" ] && command -v jq > /dev/null 2>&1; then
                TMDB_API_KEY=$(jq -r '.main.tmdbApiKey // null' "/var/snap/overseerr/common/settings.json" 2>/dev/null)
                if [ "$TMDB_API_KEY" != "null" ] && [ "$TMDB_API_KEY" != "" ]; then
                    log "Found TMDB API key in snap settings"
                    echo "TMDB_API_KEY=$TMDB_API_KEY" >> /tmp/overseerr_env_backup
                fi
                
                # Extract TVDB API key (optional)
                TVDB_API_KEY=$(jq -r '.tvdb.apiKey // null' "/var/snap/overseerr/common/settings.json" 2>/dev/null)
                if [ "$TVDB_API_KEY" != "null" ] && [ "$TVDB_API_KEY" != "" ]; then
                    log "Found TVDB API key in snap settings"
                    echo "TVDB_API_KEY=$TVDB_API_KEY" >> /tmp/overseerr_env_backup
                else
                    log "No TVDB API key found (optional - you can configure this later)"
                fi
            fi
            ;;
        "systemd")
            # Extract from systemd settings
            if [ ! -z "$SYSTEMD_CONFIG_PATH" ] && [ -f "$SYSTEMD_CONFIG_PATH/settings.json" ] && command -v jq > /dev/null 2>&1; then
                TMDB_API_KEY=$(jq -r '.main.tmdbApiKey // null' "$SYSTEMD_CONFIG_PATH/settings.json" 2>/dev/null)
                if [ "$TMDB_API_KEY" != "null" ] && [ "$TMDB_API_KEY" != "" ]; then
                    log "Found TMDB API key in systemd settings"
                    echo "TMDB_API_KEY=$TMDB_API_KEY" >> /tmp/overseerr_env_backup
                fi
                
                # Extract TVDB API key (optional)
                TVDB_API_KEY=$(jq -r '.tvdb.apiKey // null' "$SYSTEMD_CONFIG_PATH/settings.json" 2>/dev/null)
                if [ "$TVDB_API_KEY" != "null" ] && [ "$TVDB_API_KEY" != "" ]; then
                    log "Found TVDB API key in systemd settings"
                    echo "TVDB_API_KEY=$TVDB_API_KEY" >> /tmp/overseerr_env_backup
                else
                    log "No TVDB API key found (optional - you can configure this later)"
                fi
            fi
            ;;
    esac
}

# Stop existing Overseerr
stop_existing() {
    log "Stopping existing Overseerr installation..."
    
    case $OVERSEERR_TYPE in
        "docker-compose")
            # Stop docker-compose services
            if [ -f "$COMPOSE_FILE" ]; then
                docker-compose -f "$COMPOSE_FILE" down || log_warning "Docker Compose services were not running"
                log_success "Docker Compose services stopped and removed"
            else
                # Fallback to manual container stop
                docker stop $CONTAINER_NAME || log_warning "Container was not running"
                docker rm $CONTAINER_NAME || log_warning "Could not remove container"
                log_success "Docker container stopped and removed"
            fi
            ;;
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

# Detect existing port configuration
detect_port_config() {
    log "Detecting existing port configuration..."
    
    # Default port
    HOST_PORT=5055
    CONTAINER_PORT=5055
    
    case $OVERSEERR_TYPE in
        "docker-compose"|"docker")
            if [ -n "$CONTAINER_NAME" ]; then
                # Get port mappings from existing container
                PORT_MAPPING=$(docker inspect $CONTAINER_NAME --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{$p}} -> {{(index $conf 0).HostPort}}{{end}}{{end}}' 2>/dev/null | grep '5055/tcp' | head -1)
                
                if [ -n "$PORT_MAPPING" ]; then
                    # Extract host port from mapping like "5055/tcp -> 5056"
                    HOST_PORT=$(echo $PORT_MAPPING | sed 's/.*-> //')
                    log "Found existing Docker port mapping: host port $HOST_PORT"
                else
                    # Fallback: check docker inspect for HostConfig.PortBindings
                    HOST_PORT=$(docker inspect $CONTAINER_NAME --format='{{range $p, $conf := .HostConfig.PortBindings}}{{if eq $p "5055/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}' 2>/dev/null)
                    if [ -n "$HOST_PORT" ]; then
                        log "Found existing Docker host port: $HOST_PORT"
                    else
                        log "No existing port mapping found, using default port 5055"
                        HOST_PORT=5055
                    fi
                fi
                
                # Check if PORT environment variable was set in existing container
                CONTAINER_PORT_ENV=$(docker inspect $CONTAINER_NAME --format='{{range .Config.Env}}{{if eq (index (split . "=") 0) "PORT"}}{{index (split . "=") 1}}{{end}}{{end}}' 2>/dev/null)
                if [ -n "$CONTAINER_PORT_ENV" ]; then
                    CONTAINER_PORT=$CONTAINER_PORT_ENV
                    log "Found existing container PORT environment variable: $CONTAINER_PORT"
                else
                    CONTAINER_PORT=5055
                fi
            fi
            ;;
        "snap")
            # Check if snap was configured with a different port
            if [ -f "/var/snap/overseerr/common/settings.json" ] && command -v jq > /dev/null 2>&1; then
                SNAP_PORT=$(jq -r '.main.port // null' "/var/snap/overseerr/common/settings.json" 2>/dev/null)
                if [ "$SNAP_PORT" != "null" ] && [ "$SNAP_PORT" != "" ]; then
                    HOST_PORT=$SNAP_PORT
                    CONTAINER_PORT=$SNAP_PORT
                    log "Found snap port configuration: $HOST_PORT"
                fi
            fi
            ;;
        "systemd")
            # Check systemd service configuration for port
            if [ -f "/etc/systemd/system/overseerr.service" ]; then
                SYSTEMD_PORT=$(grep -E 'Environment=.*PORT=' /etc/systemd/system/overseerr.service | sed 's/.*PORT=//' | head -1)
                if [ -n "$SYSTEMD_PORT" ]; then
                    HOST_PORT=$SYSTEMD_PORT
                    CONTAINER_PORT=$SYSTEMD_PORT
                    log "Found systemd service port configuration: $HOST_PORT"
                fi
            elif [ ! -z "$SYSTEMD_CONFIG_PATH" ] && [ -f "$SYSTEMD_CONFIG_PATH/settings.json" ] && command -v jq > /dev/null 2>&1; then
                SYSTEMD_PORT=$(jq -r '.main.port // null' "$SYSTEMD_CONFIG_PATH/settings.json" 2>/dev/null)
                if [ "$SYSTEMD_PORT" != "null" ] && [ "$SYSTEMD_PORT" != "" ]; then
                    HOST_PORT=$SYSTEMD_PORT
                    CONTAINER_PORT=$SYSTEMD_PORT
                    log "Found systemd port configuration: $HOST_PORT"
                fi
            fi
            ;;
        "none")
            log "Fresh installation, using default port 5055"
            ;;
    esac
    
    log_success "Port configuration detected: host port $HOST_PORT, container port $CONTAINER_PORT"
}

# Install overseerr-content-filtering
install_content_filtering() {
    log "Installing overseerr-content-filtering..."
    
    # Pull the latest image
    docker pull larrikinau/overseerr-content-filtering:latest
    log_success "Image pulled successfully"
    
    # Initialize environment variables file
    cat > env.list << EOF
NODE_ENV=production
RUN_MIGRATIONS=true
LOG_LEVEL=info
EOF
    
    # Add PORT environment variable if container port is different from default
    if [ "$CONTAINER_PORT" != "5055" ]; then
        echo "PORT=$CONTAINER_PORT" >> env.list
        log "Added PORT=$CONTAINER_PORT to environment variables"
    fi
    
    # Initialize TMDB API key tracking
    TMDB_KEY_FOUND=false
    EXTRACTED_TMDB_KEY=""

    # Check for extracted TMDB API key
    if [ -f "/tmp/overseerr_env_backup" ]; then
        log "Adding extracted environment variables from previous installation"
        # Filter out TMDB_API_KEY from backup to avoid duplicates
        grep -v "^TMDB_API_KEY=" /tmp/overseerr_env_backup >> env.list 2>/dev/null || true

        # Extract TMDB API key from backup
        EXTRACTED_TMDB_KEY=$(grep "^TMDB_API_KEY=" /tmp/overseerr_env_backup | head -1 | cut -d'=' -f2-)
        if [ -n "$EXTRACTED_TMDB_KEY" ] && [ "$EXTRACTED_TMDB_KEY" != "null" ] && [ "$EXTRACTED_TMDB_KEY" != "db55323b8d3e4154498498a75642b381" ]; then
            echo "TMDB_API_KEY=$EXTRACTED_TMDB_KEY" >> env.list
            TMDB_KEY_FOUND=true
            log_success "Found valid TMDB API key in backup: ${EXTRACTED_TMDB_KEY:0:8}..."
        else
            log_warning "No TMDB API key found in backup"
        fi
    fi

    
    # Determine configuration volume/path
    case $OVERSEERR_TYPE in
        "docker-compose"|"docker")
            # Use the detected mount information from backup_config
            if [ ! -z "$MOUNT_INFO" ]; then
                if [ "$MOUNT_TYPE" = "bind" ]; then
                    # Reuse the same bind mount path
                    VOLUME_ARG="-v $DOCKER_CONFIG_PATH:/app/config"
                    log "Reusing existing bind mount: $DOCKER_CONFIG_PATH"
                elif [ "$MOUNT_TYPE" = "volume" ]; then
                    # Reuse the same named volume
                    VOLUME_ARG="-v $DOCKER_VOLUME_NAME:/app/config"
                    log "Reusing existing volume: $DOCKER_VOLUME_NAME"
                fi
                # Try to extract TMDB API key from bind mount settings.json
                if [ "$TMDB_KEY_FOUND" = "false" ] && [ -f "$DOCKER_CONFIG_PATH/settings.json" ] && command -v jq > /dev/null 2>&1; then
                    TMDB_API_KEY=$(jq -r '.main.tmdbApiKey // null' "$DOCKER_CONFIG_PATH/settings.json" 2>/dev/null)
                    if [ "$TMDB_API_KEY" != "null" ] && [ "$TMDB_API_KEY" != "" ] && [ "$TMDB_API_KEY" != "db55323b8d3e4154498498a75642b381" ]; then
                        log_success "Found TMDB API key in bind mount settings: ${TMDB_API_KEY:0:8}..."
                        echo "TMDB_API_KEY=$TMDB_API_KEY" >> env.list
                        TMDB_KEY_FOUND=true
                    fi
                fi
                
                # Migrate region settings from existing configuration
                if [ -f "$DOCKER_CONFIG_PATH/settings.json" ] && command -v jq > /dev/null 2>&1; then
                    # Extract region from main settings
                    REGION_SETTING=$(jq -r '.main.region // null' "$DOCKER_CONFIG_PATH/settings.json" 2>/dev/null)
                    if [ "$REGION_SETTING" != "null" ] && [ "$REGION_SETTING" != "" ]; then
                        log "Found region setting: $REGION_SETTING"
                        echo "REGION=$REGION_SETTING" >> env.list
                    fi
                    
                    # Extract original language from main settings
                    ORIGINAL_LANG=$(jq -r '.main.originalLanguage // null' "$DOCKER_CONFIG_PATH/settings.json" 2>/dev/null)
                    if [ "$ORIGINAL_LANG" != "null" ] && [ "$ORIGINAL_LANG" != "" ]; then
                        log "Found original language setting: $ORIGINAL_LANG"
                        echo "ORIGINAL_LANGUAGE=$ORIGINAL_LANG" >> env.list
                    fi
                    
                    # Extract locale from main settings
                    LOCALE_SETTING=$(jq -r '.main.locale // null' "$DOCKER_CONFIG_PATH/settings.json" 2>/dev/null)
                    if [ "$LOCALE_SETTING" != "null" ] && [ "$LOCALE_SETTING" != "" ]; then
                        log "Found locale setting: $LOCALE_SETTING"
                        echo "LOCALE=$LOCALE_SETTING" >> env.list
                    fi
                fi

                # Preserve environment variables from existing .env file (excluding TMDB_API_KEY to avoid duplicates)
                if [ -f "$DOCKER_CONFIG_PATH/.env" ]; then
                    log "Preserving environment variables from .env file"
                    grep -v "^TMDB_API_KEY=" "$DOCKER_CONFIG_PATH/.env" >> env.list 2>/dev/null || true
                    
                    # Extract TMDB API key
                    if [ "$TMDB_KEY_FOUND" = "false" ]; then
                        if grep -q "^TMDB_API_KEY=" "$DOCKER_CONFIG_PATH/.env" 2>/dev/null; then
                            ENV_TMDB_KEY=$(grep "^TMDB_API_KEY=" "$DOCKER_CONFIG_PATH/.env" | head -1 | cut -d'=' -f2-)
                            if [ -n "$ENV_TMDB_KEY" ] && [ "$ENV_TMDB_KEY" != "null" ] && [ "$ENV_TMDB_KEY" != "db55323b8d3e4154498498a75642b381" ]; then
                                echo "TMDB_API_KEY=$ENV_TMDB_KEY" >> env.list
                                TMDB_KEY_FOUND=true
                                log_success "Found TMDB API key in .env file: ${ENV_TMDB_KEY:0:8}..."
                            fi
                        fi
                    fi
                fi
                
                # Preserve other environment variables from existing container (excluding TMDB_API_KEY to avoid duplicates)
                if [ -n "$CONTAINER_NAME" ]; then
                    log "Preserving environment variables from existing container"
                    docker inspect "$CONTAINER_NAME" --format='{{range .Config.Env}}{{println .}}{{end}}' | grep -E '^(CONFIG_DIRECTORY|TZ)=' >> env.list 2>/dev/null || true
                    
                    # Extract TMDB API key
                    if [ "$TMDB_KEY_FOUND" = "false" ]; then
                        CONTAINER_TMDB_KEY=$(docker inspect "$CONTAINER_NAME" --format='{{range .Config.Env}}{{println .}}{{end}}' | grep "^TMDB_API_KEY=" | head -1 | cut -d'=' -f2- 2>/dev/null)
                        if [ -n "$CONTAINER_TMDB_KEY" ] && [ "$CONTAINER_TMDB_KEY" != "null" ] && [ "$CONTAINER_TMDB_KEY" != "db55323b8d3e4154498498a75642b381" ]; then
                            echo "TMDB_API_KEY=$CONTAINER_TMDB_KEY" >> env.list
                            TMDB_KEY_FOUND=true
                            log_success "Found TMDB API key in container environment: ${CONTAINER_TMDB_KEY:0:8}..."
                        fi
                    fi
                fi
            else
                # Fallback to creating new volume if no mount detected
                docker volume create overseerr_config
                VOLUME_ARG="-v overseerr_config:/app/config"
                log_warning "No existing mount found, created new volume: overseerr_config"
            fi
            ;;
        "snap")
            # Copy snap config to Docker volume
            docker volume create overseerr_config
            if [ -d "/var/snap/overseerr/common" ]; then
                docker run --rm -v overseerr_config:/dest -v /var/snap/overseerr/common:/src alpine sh -c "cp -r /src/* /dest/"
                log_success "Snap configuration migrated to Docker volume"
                # Only try to extract TMDB API key if we haven't found one yet
                if [ "$TMDB_KEY_FOUND" = "false" ]; then
                    if [ -f "/var/snap/overseerr/common/settings.json" ] && command -v jq > /dev/null 2>&1; then
                        TMDB_API_KEY=$(jq -r '.main.tmdbApiKey // null' "/var/snap/overseerr/common/settings.json" 2>/dev/null)
                        if [ "$TMDB_API_KEY" != "null" ] && [ "$TMDB_API_KEY" != "" ] && [ "$TMDB_API_KEY" != "db55323b8d3e4154498498a75642b381" ]; then
                            log "Found TMDB API key in snap settings"
                            echo "TMDB_API_KEY=$TMDB_API_KEY" >> env.list
                            TMDB_KEY_FOUND=true
                        fi
                    fi
                fi
            else
                log_warning "Snap config directory not found, starting with empty volume"
            fi
            VOLUME_ARG="-v overseerr_config:/app/config"
            ;;
        "systemd")
            # Copy systemd config to Docker volume  
            docker volume create overseerr_config
            if [ ! -z "$SYSTEMD_CONFIG_PATH" ]; then
                docker run --rm -v overseerr_config:/dest -v "$SYSTEMD_CONFIG_PATH":/src alpine sh -c "cp -r /src/* /dest/"
                log_success "Systemd configuration migrated to Docker volume"
                
                # Preserve TMDB API Key from systemd settings
                if [ -f "$SYSTEMD_CONFIG_PATH/settings.json" ] && command -v jq > /dev/null 2>&1; then
                    TMDB_API_KEY=$(jq -r '.main.tmdbApiKey // null' "$SYSTEMD_CONFIG_PATH/settings.json" 2>/dev/null)
                    if [ "$TMDB_API_KEY" != "null" ] && [ "$TMDB_API_KEY" != "" ]; then
                        log "Preserving TMDB API Key from systemd settings"
                        echo "TMDB_API_KEY=$TMDB_API_KEY" >> env.list
                    fi
                fi
            else
                log_warning "Systemd config path not found, starting with empty volume"
            fi
            VOLUME_ARG="-v overseerr_config:/app/config"
            ;;
        "none")
            # Fresh installation
            docker volume create overseerr_config
            VOLUME_ARG="-v overseerr_config:/app/config"
            log "Creating fresh installation with new volume: overseerr_config"
            ;;
    esac
    
    # Final check: add default TMDB API key if none found
    if [ "$TMDB_KEY_FOUND" = "false" ]; then
        echo "TMDB_API_KEY=db55323b8d3e4154498498a75642b381" >> env.list
        log_success "Default TMDB API key added (from Overseerr)"
    elif [ "$TMDB_KEY_FOUND" = "true" ]; then
        log_success "TMDB API key successfully migrated from existing installation"
    fi
    
    # Handle different deployment types
    if [ "$OVERSEERR_TYPE" = "docker-compose" ]; then
        # Create new docker-compose.yml with migrated API keys
        log "Creating new docker-compose.yml file with migrated configuration..."
        
        # Determine volume configuration based on detected mount
        if [ "$MOUNT_TYPE" = "bind" ] && [ -n "$DOCKER_CONFIG_PATH" ]; then
            COMPOSE_VOLUMES="      - $DOCKER_CONFIG_PATH:/app/config"
        elif [ "$MOUNT_TYPE" = "volume" ] && [ -n "$DOCKER_VOLUME_NAME" ]; then
            COMPOSE_VOLUMES="      - $DOCKER_VOLUME_NAME:/app/config"
        else
            COMPOSE_VOLUMES="      - overseerr-config:/app/config"
        fi
        
        # Create docker-compose.yml
        cat > docker-compose.yml <<EOF
version: '3.8'

services:
  overseerr-content-filtering:
    image: larrikinau/overseerr-content-filtering:1.3.4
    container_name: overseerr-content-filtering
    ports:
      - "$HOST_PORT:$CONTAINER_PORT"
    volumes:
$COMPOSE_VOLUMES
      - overseerr-logs:/app/logs
    environment:
      - NODE_ENV=production
      - RUN_MIGRATIONS=true
      - LOG_LEVEL=info
      - TZ=UTC
EOF
        
        # Add TMDB API Key if found
        if [ "$TMDB_KEY_FOUND" = "true" ] && [ -n "$EXTRACTED_TMDB_KEY" ]; then
            echo "      - TMDB_API_KEY=$EXTRACTED_TMDB_KEY" >> docker-compose.yml
            log_success "TMDB API key added to docker-compose.yml: ${EXTRACTED_TMDB_KEY:0:8}..."
        else
            echo "      - TMDB_API_KEY=db55323b8d3e4154498498a75642b381" >> docker-compose.yml
            log_success "Default TMDB API key added to docker-compose.yml (from Overseerr)"
        fi
        
        # Add other environment variables from env.list (excluding duplicates)
        if [ -f "env.list" ]; then
            while IFS= read -r line; do
                if ! echo "$line" | grep -E '^(NODE_ENV|RUN_MIGRATIONS|LOG_LEVEL|TZ|TMDB_API_KEY)=' > /dev/null; then
                    echo "      - $line" >> docker-compose.yml
                fi
            done < env.list
        fi
        
        # Complete docker-compose.yml
        cat >> docker-compose.yml <<EOF
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:$CONTAINER_PORT/api/v1/status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - overseerr-network

volumes:
EOF
        
        # Add volume definitions only if using named volumes
        if [ "$MOUNT_TYPE" = "volume" ] && [ -n "$DOCKER_VOLUME_NAME" ]; then
            echo "  $DOCKER_VOLUME_NAME:" >> docker-compose.yml
            echo "    external: true" >> docker-compose.yml
        elif [ "$MOUNT_TYPE" != "bind" ]; then
            echo "  overseerr-config:" >> docker-compose.yml
            echo "    driver: local" >> docker-compose.yml
        fi
        
        echo "  overseerr-logs:" >> docker-compose.yml
        echo "    driver: local" >> docker-compose.yml
        echo "" >> docker-compose.yml
        echo "networks:" >> docker-compose.yml
        echo "  overseerr-network:" >> docker-compose.yml
        echo "    driver: bridge" >> docker-compose.yml
        
        log_success "Generated docker-compose.yml with migrated configuration"
        
        # Start with docker-compose
        docker-compose up -d
        log_success "overseerr-content-filtering started with Docker Compose"
        
    else
        # Start with regular docker run
        docker run -d \
            --name overseerr-content-filtering \
            -p $HOST_PORT:$CONTAINER_PORT \
            $VOLUME_ARG \
            --env-file env.list \
            --restart unless-stopped \
            larrikinau/overseerr-content-filtering:latest
        
        log_success "overseerr-content-filtering container started"
    fi
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
    i=1
    while [ $i -le 30 ]; do
        if curl -s http://localhost:$HOST_PORT/api/v1/status > /dev/null 2>&1; then
            log_success "Service is responding on http://localhost:$HOST_PORT"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Service is not responding. Check logs with: docker logs overseerr-content-filtering"
            exit 1
        fi
        sleep 2
        i=$((i + 1))
    done
    
    # Verify database migrations completed
    log "Verifying database migrations..."
    sleep 5  # Give migrations time to complete
    
    # Check migration logs
    if docker logs overseerr-content-filtering 2>&1 | grep -q "Database migrations completed successfully"; then
        log_success "Database migrations completed successfully"
    elif docker logs overseerr-content-filtering 2>&1 | grep -q "Database schema is up to date"; then
        log_success "Database schema is up to date"
    else
        log_warning "Could not verify database migration status. Check logs: docker logs overseerr-content-filtering"
    fi
    
    # Check if content filtering columns exist
    if docker logs overseerr-content-filtering 2>&1 | grep -q "Content filtering columns verified"; then
        log_success "Content filtering columns verified"
    else
        log_warning "Content filtering columns may not exist. Check logs for migration errors."
    fi
    
    # Verify data preservation (if migrating from existing installation)
    if [ "$OVERSEERR_TYPE" != "none" ]; then
        log "Verifying data preservation..."
        
        # Check if the API responds with valid data structure
        if curl -s http://localhost:5055/api/v1/settings/main 2>/dev/null | grep -q "apikey"; then
            log_success "Settings data preserved successfully"
        else
            log_warning "Settings may not have been preserved. You may need to reconfigure."
        fi
        
        # Check if users exist (simplified check)
        if curl -s http://localhost:5055/api/v1/auth/me 2>/dev/null | grep -q "id"; then
            log_success "User data appears to be preserved"
        else
            log_warning "User data may not be preserved. You may need to set up users again."
        fi
    fi
    
    # Verify TMDB API key configuration
    log "Verifying TMDB API key configuration..."
    if docker logs overseerr-content-filtering 2>&1 | grep -q "db55323b8d3e4154498498a75642b381"; then
        log_warning "TMDB API key may not be configured correctly. You may need to set it in the settings."
    else
        log_success "TMDB API key appears to be configured"
    fi
    
    # Test TMDB API connectivity by checking if API key was migrated
    sleep 3
    # Check if we can access the container's settings to verify API key migration
    if docker exec overseerr-content-filtering ls -la /app/config/settings.json > /dev/null 2>&1; then
        # Check if settings.json contains a TMDB API key
        if docker exec overseerr-content-filtering cat /app/config/settings.json 2>/dev/null | grep -q "tmdbApiKey"; then
            log_success "TMDB API key appears to be migrated successfully"
        else
            log_warning "TMDB API key may not be configured. Please configure it in Settings → General → TMDB API."
        fi
    else
        # Fall back to basic connectivity test
        if curl -s "http://localhost:5055/api/v1/status" 2>/dev/null | grep -q "version"; then
            log_success "Service is running - TMDB API key needs to be configured in web interface"
        else
            log_warning "Service may not be responding correctly. Check container logs."
        fi
    fi
    
    # Final status check
    log "Final verification..."
    if docker logs overseerr-content-filtering 2>&1 | grep -q "Starting Overseerr"; then
        log_success "Overseerr Content Filtering is running properly"
    else
        log_error "Service may not have started correctly. Check logs: docker logs overseerr-content-filtering"
    fi
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
    echo "Note: This script runs with sudo for reliable Docker access."
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    if ! echo "$REPLY" | grep -E '^[Yy]$' > /dev/null; then
        log "Migration cancelled by user"
        exit 0
    fi
    
    check_docker
    detect_overseerr
    backup_config
    extract_api_keys
    detect_port_config
    stop_existing
    install_content_filtering
    verify_installation
    
    echo ""
    echo "=================================================="
    log_success "Migration completed successfully!"
    echo "=================================================="
    echo ""
    echo "🎉 Your Overseerr Content Filtering is now running!"
    echo "🌐 Access it at: http://localhost:$HOST_PORT"
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
    
    # Final TMDB API key information if needed
    if [ "$TMDB_KEY_FOUND" = "false" ] && [ "$OVERSEERR_TYPE" != "none" ]; then
        echo "=================================================="
        echo "   📝  TMDB API KEY INFORMATION"
        echo "=================================================="
        echo ""
        echo "No TMDB API key was found during migration."
        echo ""
        echo "Overseerr Content Filtering works without an API key, but enhanced features"
        echo "require one. To get the best experience:"
        echo ""
        echo "1. Get a free TMDB API key from: https://www.themoviedb.org/"
        echo "2. Go to Settings → General → TMDB API Key in your browser"
        echo "3. Enter your API key and save settings"
        echo ""
        echo "Benefits of configuring a TMDB API key:"
        echo "• Enhanced movie/TV show metadata and ratings"
        echo "• Improved content discovery and recommendations"
        echo "• Better poster and backdrop images"
        echo "• More accurate content filtering"
        echo ""
    fi
    
    # Show troubleshooting information if any warnings occurred
    if [ -f "/tmp/migration_warnings" ]; then
        echo ""
        echo "=================================================="
        echo "   ⚠️  MIGRATION WARNINGS DETECTED"
        echo "=================================================="
        echo ""
        echo "Some warnings were detected during migration. If you experience issues:"
        echo ""
        echo "1. Check container logs: docker logs overseerr-content-filtering"
        echo "2. Verify data integrity: curl -s http://localhost:5055/api/v1/settings/main"
        echo "3. Test content filtering: Visit Settings → Users in the web interface"
        echo "4. If issues persist, restore from backup and contact support"
        echo ""
        echo "Backups created:"
        if [ "$OVERSEERR_TYPE" = "docker" ] && [ ! -z "$DOCKER_CONFIG_PATH" ]; then
            echo "  - Docker bind mount: ${DOCKER_CONFIG_PATH}.backup.*"
        fi
        if [ "$OVERSEERR_TYPE" = "docker" ] && [ ! -z "$DOCKER_VOLUME_NAME" ]; then
            echo "  - Docker volume: overseerr_volume_backup_*.tar.gz"
        fi
        echo ""
        rm -f "/tmp/migration_warnings"
    fi
}

# Run main function
main
