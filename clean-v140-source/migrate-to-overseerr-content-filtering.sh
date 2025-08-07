#!/bin/bash

# Universal Overseerr Content Filtering Migration Script v1.4.0
# This script handles:
# 1. Fresh installation of Overseerr Content Filtering v1.4.0
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

# Configuration
CONTAINER_NAME="overseerr"
IMAGE_NAME="larrikinau/overseerr-content-filtering"
TAG="latest"
CONFIG_DIR="./overseerr-config"
COMPOSE_FILE="docker-compose.yml"
BACKUP_DIR="./overseerr-backup-$(date +%Y%m%d_%H%M%S)"

# Default API keys (users can override in docker-compose.yml)
DEFAULT_TMDB_API_KEY="eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJkMzYyY2QyOTU3MjJmZmJjYjUxOTk4MzUzNzIwNDEyZiIsInN1YiI6IjVhY2I3NzkyOTI1MTQxNzJmMTAyYWJjOCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.BmgTY6Q4-6FKt8FGlKKfX9-p1dDBKMfVFL7fT6TfaKs"
DEFAULT_ALGOLIA_API_KEY="f83c1e60b937b4ee2f97b5133d3f5c2b"

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

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Check if docker-compose is available
check_compose() {
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        log_error "Neither docker-compose nor 'docker compose' is available."
        exit 1
    fi
}

# Detect current installation type
detect_installation() {
    local installation_type="none"
    
    if [ -f "$COMPOSE_FILE" ]; then
        if grep -q "larrikinau/overseerr-content-filtering" "$COMPOSE_FILE" 2>/dev/null; then
            installation_type="fork"
        elif grep -q "overseerr/overseerr\|sctx/overseerr" "$COMPOSE_FILE" 2>/dev/null; then
            installation_type="original"
        elif docker ps -a --format "table {{.Names}}\t{{.Image}}" | grep -q "overseerr"; then
            # Check running containers for image type
            local image=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_NAME" 2>/dev/null || echo "")
            if echo "$image" | grep -q "larrikinau/overseerr-content-filtering"; then
                installation_type="fork"
            elif echo "$image" | grep -q "overseerr/overseerr\|sctx/overseerr"; then
                installation_type="original"
            fi
        fi
    fi
    
    echo "$installation_type"
}

# Create backup of current setup
create_backup() {
    log_info "Creating backup of current setup..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup docker-compose.yml if it exists
    if [ -f "$COMPOSE_FILE" ]; then
        cp "$COMPOSE_FILE" "$BACKUP_DIR/"
        log_success "Backed up $COMPOSE_FILE"
    fi
    
    # Backup config directory if it exists
    if [ -d "$CONFIG_DIR" ]; then
        cp -r "$CONFIG_DIR" "$BACKUP_DIR/"
        log_success "Backed up configuration directory"
    fi
    
    # Export container if running
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Stopping container for backup..."
        docker stop "$CONTAINER_NAME" || true
    fi
}

# Extract all settings from existing docker-compose.yml
extract_existing_settings() {
    local tmdb_key="$DEFAULT_TMDB_API_KEY"
    local algolia_key="$DEFAULT_ALGOLIA_API_KEY"
    local timezone="\${TZ:-UTC}"
    local log_level="debug"
    local ports="5055:5055"
    
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
        
        # Extract port mapping
        local extracted_ports=$(grep -E "^\s*-\s*\"[0-9]+:[0-9]+\"" "$COMPOSE_FILE" | sed -E 's/.*\"([0-9]+:[0-9]+)\".*/\1/' | head -n1)
        [ -n "$extracted_ports" ] && ports="$extracted_ports"
    fi
    
    echo "$tmdb_key|$algolia_key|$timezone|$log_level|$ports"
}

# Generate docker-compose.yml
generate_compose_file() {
    local tmdb_key="$1"
    local algolia_key="$2"
    local preserve_volumes="$3"
    local timezone="$4"
    local log_level="$5"
    local ports="$6"
    
    cat > "$COMPOSE_FILE" << EOF
version: '3.8'
services:
  overseerr:
    image: ${IMAGE_NAME}:${TAG}
    container_name: ${CONTAINER_NAME}
    environment:
      - LOG_LEVEL=${log_level}
      - TZ=${timezone}
      - PORT=5055
      - TMDB_API_KEY=${tmdb_key}
      - ALGOLIA_API_KEY=${algolia_key}
    ports:
      - "${ports}"
EOF

    if [ "$preserve_volumes" = "true" ] && [ -d "$CONFIG_DIR" ]; then
        cat >> "$COMPOSE_FILE" << EOF
    volumes:
      - ${CONFIG_DIR}:/app/config
EOF
    else
        cat >> "$COMPOSE_FILE" << EOF
    volumes:
      - ./config:/app/config
EOF
    fi

    cat >> "$COMPOSE_FILE" << EOF
    restart: unless-stopped

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
    log_info "Performing fresh installation of Overseerr Content Filtering v1.4.0..."
    
    # Create config directory
    mkdir -p config
    
    # Generate docker-compose.yml with default settings
    generate_compose_file "$DEFAULT_TMDB_API_KEY" "$DEFAULT_ALGOLIA_API_KEY" "false" "\${TZ:-UTC}" "debug" "5055:5055"
    
    log_success "Created docker-compose.yml with default configuration"
    log_info "You can customize API keys by editing the environment variables in docker-compose.yml"
}

# Migrate from existing fork
migrate_from_fork() {
    log_info "Migrating existing fork installation to v1.4.0..."
    
    # Extract existing settings
    local settings=$(extract_existing_settings)
    local tmdb_key=$(echo "$settings" | cut -d'|' -f1)
    local algolia_key=$(echo "$settings" | cut -d'|' -f2)
    local timezone=$(echo "$settings" | cut -d'|' -f3)
    local log_level=$(echo "$settings" | cut -d'|' -f4)
    local ports=$(echo "$settings" | cut -d'|' -f5)
    
    log_info "Preserving existing API keys, timezone ($timezone), log level ($log_level), and port configuration ($ports)..."
    
    # Generate new docker-compose.yml preserving all settings
    generate_compose_file "$tmdb_key" "$algolia_key" "true" "$timezone" "$log_level" "$ports"
    
    log_success "Updated docker-compose.yml while preserving your existing configuration"
}

# Migrate from original Overseerr
migrate_from_original() {
    log_info "Migrating from original Overseerr to Content Filtering fork v1.4.0..."
    
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

# Start services
start_services() {
    log_info "Starting Overseerr Content Filtering v1.4.0..."
    
    # Pull the latest image
    log_info "Pulling latest image..."
    docker pull "${IMAGE_NAME}:${TAG}"
    
    # Start services
    $COMPOSE_CMD up -d
    
    # Wait for service to be ready
    log_info "Waiting for service to start..."
    local retries=30
    local port=$(grep -E "^\s*-\s*[\"']?[0-9]+:5055[\"']?\s*$" "$COMPOSE_FILE" | sed -E 's/.*[\"'\'']?([0-9]+):5055[\"'\'']?.*/\1/' | head -n1)
    [ -z "$port" ] && port="5055"
    
    while [ $retries -gt 0 ]; do
        if curl -s "http://localhost:$port" > /dev/null 2>&1; then
            break
        fi
        sleep 2
        retries=$((retries-1))
    done
    
    if [ $retries -eq 0 ]; then
        log_warning "Service may still be starting up. Check with: $COMPOSE_CMD logs overseerr"
    else
        log_success "Service is running!"
    fi
}

# Display post-installation information
show_completion_info() {
    local installation_type="$1"
    
    echo ""
    log_success "Overseerr Content Filtering v1.4.0 migration completed!"
    echo ""
    echo "🎉 Your Overseerr installation is now ready with Content Filtering features!"
    echo ""
    local port=$(grep -E "^\s*-\s*[\"']?[0-9]+:5055[\"']?\s*$" "$COMPOSE_FILE" | sed -E 's/.*[\"'\'']?([0-9]+):5055[\"'\'']?.*/\1/' | head -n1)
    [ -z "$port" ] && port="5055"
    echo "📍 Access your installation at: http://localhost:$port"
    echo ""
    echo "🔄 Future Updates:"
    echo "   To update to newer versions, simply run:"
    echo "   docker pull ${IMAGE_NAME}:${TAG} && $COMPOSE_CMD up -d"
    echo ""
    
    if [ "$installation_type" = "original" ]; then
        echo "🆕 New Features Available:"
        echo "   - Content filtering for movies and TV shows"
        echo "   - Age rating restrictions"
        echo "   - Enhanced search with content filters"
        echo "   - All your existing data and settings are preserved"
        echo ""
    elif [ "$installation_type" = "fork" ]; then
        echo "⬆️  Updated Features:"
        echo "   - Latest content filtering improvements"
        echo "   - Bug fixes and performance enhancements"
        echo "   - Your existing configuration is preserved"
        echo ""
    else
        echo "🚀 Getting Started:"
        echo "   1. Open http://localhost:5055 in your browser"
        echo "   2. Complete the initial setup wizard"
        echo "   3. Configure your Plex server and download clients"
        echo "   4. Set up content filtering preferences in Settings"
        echo ""
    fi
    
    echo "📋 Useful Commands:"
    echo "   View logs:    $COMPOSE_CMD logs overseerr"
    echo "   Stop service: $COMPOSE_CMD stop"
    echo "   Start service: $COMPOSE_CMD start"
    echo "   Restart:      $COMPOSE_CMD restart overseerr"
    echo ""
    
    if [ -d "$BACKUP_DIR" ]; then
        echo "💾 Backup created at: $BACKUP_DIR"
        echo "   You can safely delete this after confirming everything works"
        echo ""
    fi
    
    echo "📚 Documentation: https://github.com/larrikinau/overseerr-content-filtering"
    echo "🐛 Support: https://github.com/larrikinau/overseerr-content-filtering/issues"
}

# Main execution
main() {
    echo ""
    echo "🎬 Overseerr Content Filtering Migration Script v1.4.0"
    echo "======================================================="
    echo ""
    
    # Check prerequisites
    check_docker
    check_compose
    
    # Detect current installation
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
