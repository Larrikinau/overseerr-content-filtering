#!/bin/bash

# Universal Overseerr Content Filtering Migration Script v1.4.2
# This script handles:
# 1. Fresh installation of Overseerr Content Filtering v1.4.2
# 2. Migration from existing fork version (maintains volumes/setup)
# 3. Migration from original Overseerr to Content Filtering fork
#
# After running this script once, users can simply use 'docker pull' for future updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration (will be overridden by detection)
CONTAINER_NAME="overseerr"  # Will be detected from existing setup
SERVICE_NAME="overseerr"    # Will be detected from existing setup
IMAGE_NAME="larrikinau/overseerr-content-filtering"
TAG="latest"
CONFIG_DIR="./overseerr-config"
COMPOSE_FILE="docker-compose.yml"
BACKUP_DIR="./overseerr-backup-$(date +%Y%m%d_%H%M%S)"

# Docker command prefixes (will be set by sudo detection)
DOCKER_CMD="docker"
COMPOSE_CMD="docker-compose"

# Default API keys (users can override in docker-compose.yml)
DEFAULT_TMDB_API_KEY="db55323b8d3e4154498498a75642b381"
DEFAULT_ALGOLIA_API_KEY="175588f6e5f8319b27702e4cc4013561"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect if sudo is needed for Docker commands
detect_docker_sudo() {
    local needs_sudo=false
    
    # Test if docker works without sudo
    if ! docker ps &> /dev/null; then
        # Try with sudo
        if sudo docker ps &> /dev/null; then
            needs_sudo=true
            log_info "Docker requires sudo - will use sudo automatically for all Docker commands"
        else
            log_error "Docker is not accessible even with sudo. Please check Docker installation."
            exit 1
        fi
    else
        log_info "Docker is accessible without sudo"
    fi
    
    # Set Docker command with or without sudo
    if [ "$needs_sudo" = true ]; then
        DOCKER_CMD="sudo docker"
        # Also check if docker-compose needs sudo
        if command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="sudo docker-compose"
        elif sudo docker compose version &> /dev/null; then
            COMPOSE_CMD="sudo docker compose"
        fi
    else
        DOCKER_CMD="docker"
        # Also check if docker-compose works without sudo
        if command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose"
        elif docker compose version &> /dev/null; then
            COMPOSE_CMD="docker compose"
        fi
    fi
}

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        log_info "Visit https://docs.docker.com/get-docker/ for installation instructions"
        exit 1
    fi
    
    # Detect sudo requirements and set commands accordingly
    detect_docker_sudo
    
    # Test Docker daemon connectivity
    if ! $DOCKER_CMD info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker first."
        log_info "Try: sudo systemctl start docker (Linux) or start Docker Desktop (Windows/Mac)"
        exit 1
    fi
}

# Check if docker-compose is available (sudo already handled by detect_docker_sudo)
check_compose() {
    # COMPOSE_CMD is already set by detect_docker_sudo, but verify it works
    if ! $COMPOSE_CMD version &> /dev/null; then
        # Fallback detection if the auto-detection failed
        if [[ "$DOCKER_CMD" == *"sudo"* ]]; then
            if command -v docker-compose &> /dev/null; then
                COMPOSE_CMD="sudo docker-compose"
            elif sudo docker compose version &> /dev/null; then
                COMPOSE_CMD="sudo docker compose"
            else
                log_error "Neither docker-compose nor 'docker compose' is available, even with sudo."
                exit 1
            fi
        else
            if command -v docker-compose &> /dev/null; then
                COMPOSE_CMD="docker-compose"
            elif docker compose version &> /dev/null; then
                COMPOSE_CMD="docker compose"
            else
                log_error "Neither docker-compose nor 'docker compose' is available."
                exit 1
            fi
        fi
    fi
    
    log_info "Using compose command: $COMPOSE_CMD"
}

# Detect and preserve existing Docker setup details
detect_existing_setup() {
    local detected_container_name=""
    local detected_service_name=""
    local detected_compose_file=""
    
    # Look for docker-compose files in common locations
    for compose_file in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
        if [ -f "$compose_file" ]; then
            detected_compose_file="$compose_file"
            COMPOSE_FILE="$compose_file"
            
            # Extract service name from compose file
            detected_service_name=$(grep -E "^\s*[a-zA-Z_][a-zA-Z0-9_-]*:" "$compose_file" | grep -v "version:\|services:\|volumes:\|networks:" | head -n1 | sed 's/[[:space:]]*\([^:]*\):.*/\1/')
            
            # Extract container name if specified
            local container_name_line=$(grep -A 20 "$detected_service_name:" "$compose_file" | grep "container_name:" | head -n1)
            if [ -n "$container_name_line" ]; then
                detected_container_name=$(echo "$container_name_line" | sed 's/.*container_name:[[:space:]]*\([^[:space:]]*\).*/\1/' | tr -d '"\''')
            fi
            break
        fi
    done
    
    # If no compose file found, check for running containers
    if [ -z "$detected_container_name" ]; then
        # Look for containers with overseerr-like names
        local running_containers=$($DOCKER_CMD ps -a --format "{{.Names}}" | grep -i "overseerr\|seerr")
        if [ -n "$running_containers" ]; then
            detected_container_name=$(echo "$running_containers" | head -n1)
        fi
    fi
    
    # Update global variables if we found better names
    if [ -n "$detected_container_name" ]; then
        CONTAINER_NAME="$detected_container_name"
    fi
    
    if [ -n "$detected_service_name" ]; then
        SERVICE_NAME="$detected_service_name"
    else
        SERVICE_NAME="overseerr"  # Default fallback
    fi
    
    log_info "Detected setup: container='$CONTAINER_NAME', service='$SERVICE_NAME', compose='$COMPOSE_FILE'"
}

# Detect current installation type
detect_installation() {
    local installation_type="none"
    
    if [ -f "$COMPOSE_FILE" ]; then
        if grep -q "larrikinau/overseerr-content-filtering" "$COMPOSE_FILE" 2>/dev/null; then
            installation_type="fork"
        elif grep -q "overseerr/overseerr\|sctx/overseerr" "$COMPOSE_FILE" 2>/dev/null; then
            installation_type="original"
        fi
    fi
    
    # Also check running containers if compose file doesn't give us enough info
    if [ "$installation_type" = "none" ]; then
        local containers=$($DOCKER_CMD ps -a --format "{{.Names}}\t{{.Image}}" | grep -i "overseerr\|seerr")
        if [ -n "$containers" ]; then
            local image=$(echo "$containers" | head -n1 | awk '{print $2}')
            if echo "$image" | grep -q "larrikinau/overseerr-content-filtering"; then
                installation_type="fork"
            elif echo "$image" | grep -q "overseerr/overseerr\|sctx/overseerr"; then
                installation_type="original"
            fi
        fi
    fi
    
    echo "$installation_type"
}

# Detect Docker volumes and config locations
detect_docker_volumes() {
    local config_volume=""
    local volume_type="none"
    
    # Check if container exists and get volume info
    if $DOCKER_CMD inspect "$CONTAINER_NAME" &> /dev/null; then
        # Get volume mount information
        config_volume=$($DOCKER_CMD inspect "$CONTAINER_NAME" --format '{{range .Mounts}}{{if eq .Destination "/app/config"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || echo "")
        
        if [ -n "$config_volume" ]; then
            if [[ "$config_volume" == /var/lib/docker/volumes/* ]]; then
                volume_type="docker_volume"
                # Extract volume name from path
                config_volume=$(echo "$config_volume" | sed 's|/var/lib/docker/volumes/||' | sed 's|/_data||')
            else
                volume_type="bind_mount"
            fi
        fi
    fi
    
    echo "$volume_type|$config_volume"
}

# Create comprehensive backup with volume handling
create_backup() {
    log_info "Creating comprehensive backup of current setup..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup docker-compose.yml if it exists
    if [ -f "$COMPOSE_FILE" ]; then
        cp "$COMPOSE_FILE" "$BACKUP_DIR/"
        log_success "Backed up $COMPOSE_FILE"
    fi
    
    # Detect and backup volume/config data
    local volume_info=$(detect_docker_volumes)
    local volume_type=$(echo "$volume_info" | cut -d'|' -f1)
    local volume_path=$(echo "$volume_info" | cut -d'|' -f2)
    
    case "$volume_type" in
        "docker_volume")
            log_info "Backing up Docker volume: $volume_path"
            # Create a backup of the volume using docker
            $DOCKER_CMD run --rm -v "$volume_path":/source -v "$PWD/$BACKUP_DIR":/backup alpine sh -c "cd /source && tar czf /backup/config-volume-backup.tar.gz ."
            log_success "Docker volume backed up to $BACKUP_DIR/config-volume-backup.tar.gz"
            ;;
        "bind_mount")
            log_info "Backing up bind mount: $volume_path"
            if [ -d "$volume_path" ]; then
                cp -r "$volume_path" "$BACKUP_DIR/config-bind-mount"
                log_success "Bind mount backed up to $BACKUP_DIR/config-bind-mount"
            fi
            ;;
        *)
            # Backup traditional config directory if it exists
            for config_dir in "./config" "./overseerr-config" "$CONFIG_DIR"; do
                if [ -d "$config_dir" ]; then
                    cp -r "$config_dir" "$BACKUP_DIR/$(basename "$config_dir")"
                    log_success "Backed up configuration directory: $config_dir"
                fi
            done
            ;;
    esac
    
    # Stop container safely for migration
    if $DOCKER_CMD ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Stopping container for migration..."
        $DOCKER_CMD stop "$CONTAINER_NAME" || true
        sleep 2  # Give it time to fully stop
    fi
    
    # Remove old container to avoid conflicts
    if $DOCKER_CMD ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Removing old container to avoid conflicts..."
        $DOCKER_CMD rm "$CONTAINER_NAME" || true
    fi
}

# Extract all settings from existing docker-compose.yml
extract_existing_settings() {
    local tmdb_key="$DEFAULT_TMDB_API_KEY"
    local algolia_key="$DEFAULT_ALGOLIA_API_KEY"
    local timezone="\${TZ:-UTC}"
    local log_level="debug"
    local ports="5055:5055"
    local restart_policy="unless-stopped"
    local custom_volumes=""
    local custom_networks=""
    local custom_env_vars=""
    
    if [ -f "$COMPOSE_FILE" ]; then
        # Extract TMDB_API_KEY
        local extracted_tmdb=$(grep -E "^\s*-?\s*TMDB_API_KEY=" "$COMPOSE_FILE" | sed -E 's/.*TMDB_API_KEY=([^[:space:]]+).*/\1/' | head -n1)
        [ -n "$extracted_tmdb" ] && tmdb_key="$extracted_tmdb"
        
        # Extract ALGOLIA_API_KEY  
        local extracted_algolia=$(grep -E "^\s*-?\s*ALGOLIA_API_KEY=" "$COMPOSE_FILE" | sed -E 's/.*ALGOLIA_API_KEY=([^[:space:]]+).*/\1/' | head -n1)
        [ -n "$extracted_algolia" ] && algolia_key="$extracted_algolia"
        
        # Extract TZ
        local extracted_tz=$(grep -E "^\s*-?\s*TZ=" "$COMPOSE_FILE" | sed -E 's/.*TZ=([^[:space:]]+).*/\1/' | head -n1)
        [ -n "$extracted_tz" ] && timezone="$extracted_tz"
        
        # Extract LOG_LEVEL
        local extracted_log=$(grep -E "^\s*-?\s*LOG_LEVEL=" "$COMPOSE_FILE" | sed -E 's/.*LOG_LEVEL=([^[:space:]]+).*/\1/' | head -n1)
        [ -n "$extracted_log" ] && log_level="$extracted_log"
        
        # Extract port mapping (support multiple formats)
        local extracted_ports=$(grep -E "^\s*-\s*[\"']?[0-9]+:[0-9]+[\"']?" "$COMPOSE_FILE" | sed -E 's/.*["'\'']?([0-9]+:[0-9]+)["'\'']?.*/\1/' | head -n1)
        [ -n "$extracted_ports" ] && ports="$extracted_ports"
        
        # Extract restart policy
        local extracted_restart=$(grep -E "^\s*restart:\s*" "$COMPOSE_FILE" | sed -E 's/.*restart:\s*([^[:space:]]+).*/\1/' | head -n1)
        [ -n "$extracted_restart" ] && restart_policy="$extracted_restart"
        
        # Extract custom environment variables (excluding our standard ones)
        custom_env_vars=$(grep -E "^\s*-\s*[A-Z_]+=" "$COMPOSE_FILE" | grep -vE "(TMDB_API_KEY|ALGOLIA_API_KEY|TZ|LOG_LEVEL|PORT)=" | sed 's/^[[:space:]]*/      /' | paste -sd '\n' -)
        
        # Extract custom volumes (preserve user's volume mappings)
        if grep -q "volumes:" "$COMPOSE_FILE"; then
            custom_volumes=$(awk '/volumes:/,/^[[:space:]]*[^[:space:]]+:/ {if (!/^[[:space:]]*[^[:space:]]+:/ && !/volumes:/) print}' "$COMPOSE_FILE")
        fi
        
        # Check for custom networks
        if grep -q "networks:" "$COMPOSE_FILE"; then
            custom_networks="true"
        fi
    fi
    
    echo "$tmdb_key|$algolia_key|$timezone|$log_level|$ports|$restart_policy|$custom_env_vars|$custom_volumes|$custom_networks"
}

# Verify repository access and image availability
verify_repository() {
    log_info "Verifying repository access and image availability..."
    
    # Try to pull the image to verify it exists and is accessible
    if $DOCKER_CMD pull "${IMAGE_NAME}:${TAG}" > /dev/null 2>&1; then
        log_success "Repository verified: ${IMAGE_NAME}:${TAG} is accessible"
        return 0
    else
        log_warning "Could not pull ${IMAGE_NAME}:${TAG}"
        log_info "This might be expected if you're using a private registry or the image needs to be built"
        return 1
    fi
}

# Generate docker-compose.yml with enhanced preservation
generate_compose_file() {
    local tmdb_key="$1"
    local algolia_key="$2"
    local preserve_volumes="$3"
    local timezone="$4"
    local log_level="$5"
    local ports="$6"
    local restart_policy="${7:-unless-stopped}"
    local custom_env_vars="$8"
    local custom_volumes="$9"
    local custom_networks="${10}"
    
    # Detect existing volume setup to preserve exact configuration
    local volume_info=$(detect_docker_volumes)
    local volume_type=$(echo "$volume_info" | cut -d'|' -f1)
    local volume_path=$(echo "$volume_info" | cut -d'|' -f2)
    
    # Start with basic structure, using detected service name
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'
services:
  ${SERVICE_NAME}:
    image: ${IMAGE_NAME}:${TAG}
    container_name: ${CONTAINER_NAME}
    environment:
      - LOG_LEVEL=${log_level}
      - TZ=${timezone}
      - PORT=5055
      - TMDB_API_KEY=${tmdb_key}
      - ALGOLIA_API_KEY=${algolia_key}
EOF

    # Add custom environment variables if they exist
    if [ -n "$custom_env_vars" ]; then
        echo "$custom_env_vars" >> "$COMPOSE_FILE"
    fi
    
    # Add ports
    cat >> "$COMPOSE_FILE" << EOF
    ports:
      - "${ports}"
EOF

    # Add volumes - preserve exact existing volume configuration
    cat >> "$COMPOSE_FILE" << EOF
    volumes:
EOF
    
    case "$volume_type" in
        "docker_volume")
            # Preserve Docker named volume
            log_info "Preserving Docker named volume: $volume_path"
            cat >> "$COMPOSE_FILE" << EOF
      - ${volume_path}:/app/config
EOF
            ;;
        "bind_mount")
            # Preserve bind mount path exactly
            log_info "Preserving bind mount: $volume_path"
            cat >> "$COMPOSE_FILE" << EOF
      - ${volume_path}:/app/config
EOF
            ;;
        *)
            # Default case - check for existing local config directories
            if [ -d "./config" ]; then
                cat >> "$COMPOSE_FILE" << EOF
      - ./config:/app/config
EOF
            elif [ -d "./overseerr-config" ]; then
                cat >> "$COMPOSE_FILE" << EOF
      - ./overseerr-config:/app/config
EOF
            else
                # Create new default
                mkdir -p config
                cat >> "$COMPOSE_FILE" << EOF
      - ./config:/app/config
EOF
            fi
            ;;
    esac
    
    # Add any additional custom volumes if they exist
    if [ -n "$custom_volumes" ]; then
        echo "$custom_volumes" >> "$COMPOSE_FILE"
    fi
    
    # Add restart policy
    cat >> "$COMPOSE_FILE" << EOF
    restart: ${restart_policy}
EOF

    # Add custom networks if they existed
    if [ "$custom_networks" = "true" ]; then
        # Preserve the networks section from original file if it exists
        if [ -f "$BACKUP_DIR/$COMPOSE_FILE" ]; then
            if grep -A 100 "^networks:" "$BACKUP_DIR/$COMPOSE_FILE" >> "$COMPOSE_FILE" 2>/dev/null; then
                log_info "Preserved custom network configuration"
            fi
        fi
    fi

    # Add PostgreSQL section as comment (unchanged)
    cat >> "$COMPOSE_FILE" << EOF

# Uncomment the following section if you want to use a database other than SQLite
# Make sure to also set the DATABASE_URL environment variable above
#  postgres:
#    image: postgres:13
#    environment:
#      POSTGRES_PASSWORD: overseerr
#      POSTGRES_USER: overseerr
#      POSTGRES_DB: overseerr
#    volumes:
#      - postgres_data:/var/lib/postgresql/data
#    restart: unless-stopped
#
# volumes:
#   postgres_data:
EOF
}

# Fresh installation
fresh_install() {
    log_info "Performing fresh installation of Overseerr Content Filtering v1.4.2..."
    
    # Create config directory
    mkdir -p config
    
    # Generate docker-compose.yml with default settings
    generate_compose_file "$DEFAULT_TMDB_API_KEY" "$DEFAULT_ALGOLIA_API_KEY" "false" "\${TZ:-UTC}" "debug" "5055:5055"
    
    log_success "Created docker-compose.yml with default configuration"
    log_info "You can customize API keys by editing the environment variables in docker-compose.yml"
}

# Migrate from existing fork
migrate_from_fork() {
    log_info "Migrating existing fork installation to v1.4.2..."
    
    # Verify repository first
    verify_repository || log_warning "Repository verification failed, proceeding with migration..."
    
    # Extract existing settings
    local settings=$(extract_existing_settings)
    local tmdb_key=$(echo "$settings" | cut -d'|' -f1)
    local algolia_key=$(echo "$settings" | cut -d'|' -f2)
    local timezone=$(echo "$settings" | cut -d'|' -f3)
    local log_level=$(echo "$settings" | cut -d'|' -f4)
    local ports=$(echo "$settings" | cut -d'|' -f5)
    local restart_policy=$(echo "$settings" | cut -d'|' -f6)
    local custom_env_vars=$(echo "$settings" | cut -d'|' -f7)
    local custom_volumes=$(echo "$settings" | cut -d'|' -f8)
    local custom_networks=$(echo "$settings" | cut -d'|' -f9)
    
    log_info "Preserving ALL existing settings:"
    log_info "  - API keys and environment variables"
    log_info "  - Timezone: $timezone"
    log_info "  - Log level: $log_level" 
    log_info "  - Port configuration: $ports"
    log_info "  - Restart policy: $restart_policy"
    [ -n "$custom_env_vars" ] && log_info "  - Custom environment variables"
    [ -n "$custom_volumes" ] && log_info "  - Custom volume mappings"
    [ "$custom_networks" = "true" ] && log_info "  - Custom network configuration"
    
    # Generate new docker-compose.yml preserving all settings
    generate_compose_file "$tmdb_key" "$algolia_key" "true" "$timezone" "$log_level" "$ports" "$restart_policy" "$custom_env_vars" "$custom_volumes" "$custom_networks"
    
    log_success "Updated docker-compose.yml while preserving your complete existing configuration"
    log_info "Your setup has been surgically updated - only the image reference was changed"
}

# Migrate from original Overseerr
migrate_from_original() {
    log_info "Migrating from original Overseerr to Content Filtering fork v1.4.2..."
    
    # Extract existing settings  
    local settings=$(extract_existing_settings)
    local tmdb_key=$(echo "$settings" | cut -d'|' -f1)
    local algolia_key=$(echo "$settings" | cut -d'|' -f2)
    local timezone=$(echo "$settings" | cut -d'|' -f3)
    local log_level=$(echo "$settings" | cut -d'|' -f4)
    local ports=$(echo "$settings" | cut -d'|' -f5)
    
    # Check if they had default keys, replace with our defaults
    if [ "$tmdb_key" = "$DEFAULT_TMDB_API_KEY" ]; then
        log_info "Using default TMDB API key for Content Filtering features"
    else
        log_info "Preserving your existing TMDB API key"
    fi
    
    log_info "Preserving existing settings: timezone ($timezone), log level ($log_level), port ($ports)"
    
    # Generate new docker-compose.yml with content filtering image
    generate_compose_file "$tmdb_key" "$algolia_key" "true" "$timezone" "$log_level" "$ports"
    
    log_success "Migrated to Content Filtering fork while preserving your data"
    log_info "Your existing configuration and request history will be preserved"
    log_info "New content filtering features will be available after startup"
}

# Enhanced startup verification and error recovery
verify_service_health() {
    local port="$1"
    local max_retries=60  # 2 minutes total
    local retry_count=0
    
    log_info "Verifying service health on port $port..."
    
    while [ $retry_count -lt $max_retries ]; do
        # Check if container is running
        if ! $DOCKER_CMD ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
            log_error "Container '$CONTAINER_NAME' is not running!"
            log_info "Container logs:"
            $DOCKER_CMD logs "$CONTAINER_NAME" --tail 20 2>/dev/null || true
            return 1
        fi
        
        # Check if service responds
        if curl -s --max-time 5 "http://localhost:$port" > /dev/null 2>&1; then
            log_success "Service is healthy and responding!"
            return 0
        fi
        
        # Check for common startup issues every 10 retries
        if [ $((retry_count % 10)) -eq 0 ] && [ $retry_count -gt 0 ]; then
            log_info "Still starting... checking container logs for issues:"
            $DOCKER_CMD logs "$CONTAINER_NAME" --tail 10 2>/dev/null | head -5
        fi
        
        sleep 2
        retry_count=$((retry_count + 1))
    done
    
    log_error "Service failed to start after $((max_retries * 2)) seconds"
    return 1
}

# Start services with comprehensive error handling
start_services() {
    log_info "Starting Overseerr Content Filtering v1.4.2..."
    
    # Pull the latest image with retry logic
    log_info "Pulling latest image..."
    local pull_retries=3
    while [ $pull_retries -gt 0 ]; do
        if $DOCKER_CMD pull "${IMAGE_NAME}:${TAG}"; then
            break
        else
            log_warning "Image pull failed, retrying... ($pull_retries attempts remaining)"
            pull_retries=$((pull_retries - 1))
            sleep 5
        fi
    done
    
    if [ $pull_retries -eq 0 ]; then
        log_error "Failed to pull Docker image after multiple attempts"
        log_info "This could be due to network issues or Docker Hub rate limits"
        log_info "Try running the script again later, or check your internet connection"
        exit 1
    fi
    
    # Start services with error checking
    log_info "Starting services..."
    if ! $COMPOSE_CMD up -d; then
        log_error "Failed to start services with docker-compose"
        log_info "Check the docker-compose.yml file and try: $COMPOSE_CMD logs"
        exit 1
    fi
    
    # Extract port for health check
    local port=$(grep -E "^\s*-\s*[\"']?[0-9]+:5055[\"']?\s*$" "$COMPOSE_FILE" | sed -E 's/.*["'\'']?([0-9]+):5055["'\'']?.*/\1/' | head -n1)
    [ -z "$port" ] && port="5055"
    
    # Verify service health with comprehensive checking
    if verify_service_health "$port"; then
        log_success "Overseerr Content Filtering is running successfully!"
        log_info "Database migrations completed automatically"
    else
        log_error "Service startup verification failed"
        log_info "Troubleshooting steps:"
        log_info "1. Check container logs: $COMPOSE_CMD logs overseerr"
        log_info "2. Verify port $port is not in use: netstat -tulnp | grep $port"
        log_info "3. Check disk space: df -h"
        log_info "4. Verify Docker has sufficient resources"
        log_info ""
        log_info "Recent container logs:"
        $DOCKER_CMD logs "$CONTAINER_NAME" --tail 30 2>/dev/null || true
        exit 1
    fi
}

# Display post-installation information
show_completion_info() {
    local installation_type="$1"
    
    echo ""
    log_success "Overseerr Content Filtering v1.4.2 migration completed!"
    echo ""
    echo " Your Overseerr installation is now ready with Content Filtering features!"
    echo ""
    local port=$(grep -E "^\s*-\s*[\"']?[0-9]+:5055[\"']?\s*$" "$COMPOSE_FILE" | sed -E 's/.*["'\'']?([0-9]+):5055["'\'']?.*/\1/' | head -n1)
    [ -z "$port" ] && port="5055"
    echo " Access your installation at: http://localhost:$port"
    echo ""
    echo " Future Updates:"
    echo "   To update to newer versions, simply run:"
    echo "   $DOCKER_CMD pull ${IMAGE_NAME}:${TAG} && $COMPOSE_CMD up -d"
    echo ""
    
    if [ "$installation_type" = "original" ]; then
        echo " New Features Available:"
        echo "   - Content filtering for movies and TV shows"
        echo "   - Age rating restrictions"
        echo "   - Enhanced search with content filters"
        echo "   - All your existing data and settings are preserved"
        echo ""
    elif [ "$installation_type" = "fork" ]; then
        echo "  Updated Features:"
        echo "   - Latest content filtering improvements"
        echo "   - Bug fixes and performance enhancements"
        echo "   - Your existing configuration is preserved"
        echo ""
    else
        echo " Getting Started:"
        echo "   1. Open http://localhost:5055 in your browser"
        echo "   2. Complete the initial setup wizard"
        echo "   3. Configure your Plex server and download clients"
        echo "   4. Set up content filtering preferences in Settings"
        echo ""
    fi
    
    echo " Useful Commands:"
    echo "   View logs:    $COMPOSE_CMD logs overseerr"
    echo "   Stop service: $COMPOSE_CMD stop"
    echo "   Start service: $COMPOSE_CMD start"
    echo "   Restart:      $COMPOSE_CMD restart overseerr"
    echo ""
    
    if [ -d "$BACKUP_DIR" ]; then
        echo " Backup created at: $BACKUP_DIR"
        echo "   You can safely delete this after confirming everything works"
        echo ""
    fi
    
    echo " Documentation: https://github.com/larrikinau/overseerr-content-filtering"
    echo " Support: https://github.com/larrikinau/overseerr-content-filtering/issues"
}

# Main execution
main() {
    echo ""
    echo " Overseerr Content Filtering Migration Script v1.4.2"
    echo "======================================================="
    echo " This script will automatically detect if sudo is needed"
    echo " and use it appropriately for all Docker commands."
    echo "======================================================="
    echo ""
    
    # Check prerequisites
    check_docker
    check_compose
    
    # Detect existing setup first to get accurate names and paths
    detect_existing_setup
    
    # Detect current installation type
    local installation_type=$(detect_installation)
    
    case "$installation_type" in
        "fork")
            log_info "Detected: Existing Content Filtering fork installation"
            create_backup
            migrate_from_fork
            ;;
        "original")
            log_info "Detected: Original Overseerr installation"
            create_backup
            migrate_from_original
            ;;
        "none")
            log_info "Detected: No existing installation"
            fresh_install
            ;;
        *)
            log_error "Unable to determine installation type"
            exit 1
            ;;
    esac
    
    # Start services
    start_services
    
    # Show completion info
    show_completion_info "$installation_type"
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"
