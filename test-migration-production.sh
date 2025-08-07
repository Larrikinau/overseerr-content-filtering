#!/bin/bash

# PRODUCTION TEST VERSION - Overseerr Content Filtering Migration Script v1.4.0
# This version includes extra safety checks and detailed logging for production testing
# DO NOT USE IN PRODUCTION WITHOUT TESTING FIRST

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

# PRODUCTION TEST MODE - Extra safety
PRODUCTION_TEST_MODE=true
DRY_RUN=false  # Set to true for dry run mode

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

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

# Production safety check
production_safety_check() {
    log_test "=== PRODUCTION SAFETY CHECK ==="
    
    # Check if this looks like a production environment
    if [ -f "docker-compose.yml" ] || [ "$(docker ps -q)" ]; then
        log_warning "This appears to be an active Docker environment"
        log_warning "PRODUCTION TEST MODE is enabled - extra safety checks will be performed"
        
        echo ""
        echo "Current Docker containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers running"
        echo ""
        
        echo "Current docker-compose.yml contents (first 20 lines):"
        if [ -f "docker-compose.yml" ]; then
            head -20 docker-compose.yml | cat -n
        else
            echo "No docker-compose.yml found"
        fi
        echo ""
        
        read -p "Continue with migration? (type 'YES' to continue): " confirm
        if [ "$confirm" != "YES" ]; then
            log_info "Migration cancelled by user"
            exit 0
        fi
    fi
}

# Enhanced backup with verification
create_production_backup() {
    log_info "Creating PRODUCTION backup of current setup..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup current directory state
    log_info "Creating snapshot of current directory..."
    ls -la > "$BACKUP_DIR/directory-listing.txt"
    
    # Backup docker-compose.yml if it exists
    if [ -f "$COMPOSE_FILE" ]; then
        cp "$COMPOSE_FILE" "$BACKUP_DIR/"
        log_success "Backed up $COMPOSE_FILE"
    fi
    
    # Backup all compose-related files
    for file in docker-compose.*.yml docker-compose.*.yaml compose.*.yml compose.*.yaml; do
        if [ -f "$file" ]; then
            cp "$file" "$BACKUP_DIR/"
            log_success "Backed up $file"
        fi
    done
    
    # Save current Docker state
    log_info "Saving current Docker state..."
    docker ps -a > "$BACKUP_DIR/docker-containers-before.txt" 2>/dev/null || echo "No Docker available" > "$BACKUP_DIR/docker-containers-before.txt"
    docker images > "$BACKUP_DIR/docker-images-before.txt" 2>/dev/null || echo "No Docker available" > "$BACKUP_DIR/docker-images-before.txt"
    docker volume ls > "$BACKUP_DIR/docker-volumes-before.txt" 2>/dev/null || echo "No Docker available" > "$BACKUP_DIR/docker-volumes-before.txt"
    
    # Detect and backup volume/config data
    local volume_info=$(detect_docker_volumes)
    local volume_type=$(echo "$volume_info" | cut -d'|' -f1)
    local volume_path=$(echo "$volume_info" | cut -d'|' -f2)
    
    case "$volume_type" in
        "docker_volume")
            log_info "Backing up Docker volume: $volume_path"
            if [ "$DRY_RUN" = "false" ]; then
                docker run --rm -v "$volume_path":/source -v "$PWD/$BACKUP_DIR":/backup alpine sh -c "cd /source && tar czf /backup/config-volume-backup.tar.gz ."
                log_success "Docker volume backed up to $BACKUP_DIR/config-volume-backup.tar.gz"
            else
                log_test "DRY RUN: Would backup Docker volume $volume_path"
            fi
            ;;
        "bind_mount")
            log_info "Backing up bind mount: $volume_path"
            if [ -d "$volume_path" ]; then
                if [ "$DRY_RUN" = "false" ]; then
                    cp -r "$volume_path" "$BACKUP_DIR/config-bind-mount"
                    log_success "Bind mount backed up to $BACKUP_DIR/config-bind-mount"
                else
                    log_test "DRY RUN: Would backup bind mount $volume_path"
                fi
            fi
            ;;
        *)
            # Backup traditional config directory if it exists
            for config_dir in "./config" "./overseerr-config" "$CONFIG_DIR"; do
                if [ -d "$config_dir" ]; then
                    if [ "$DRY_RUN" = "false" ]; then
                        cp -r "$config_dir" "$BACKUP_DIR/$(basename "$config_dir")"
                        log_success "Backed up configuration directory: $config_dir"
                    else
                        log_test "DRY RUN: Would backup config directory $config_dir"
                    fi
                fi
            done
            ;;
    esac
    
    log_success "Production backup completed at: $BACKUP_DIR"
    
    # Verify backup
    log_info "Verifying backup contents..."
    ls -la "$BACKUP_DIR/"
    du -sh "$BACKUP_DIR"
}

# All the previous functions from the main script...
# (I'll include the key ones for testing)

# Check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        log_info "Visit https://docs.docker.com/get-docker/ for installation instructions"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker first."
        log_info "Try: sudo systemctl start docker (Linux) or start Docker Desktop (Windows/Mac)"
        exit 1
    fi
    
    # Check Docker permissions
    if ! docker ps &> /dev/null; then
        log_warning "Docker requires sudo permissions. This is normal on some systems."
        log_info "The script will use 'docker' commands. Add 'sudo' manually if needed."
    fi
    
    log_success "Docker is available and running"
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
    
    log_success "Docker Compose available as: $COMPOSE_CMD"
}

# Detect and preserve existing Docker setup details
detect_existing_setup() {
    local detected_container_name=""
    local detected_service_name=""
    local detected_compose_file=""
    
    log_info "Detecting existing Docker setup..."
    
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
                detected_container_name=$(echo "$container_name_line" | sed 's/.*container_name:[[:space:]]*\([^[:space:]]*\).*/\1/' | tr -d '"'"'"'' )
            fi
            break
        fi
    done
    
    # If no compose file found, check for running containers
    if [ -z "$detected_container_name" ]; then
        # Look for containers with overseerr-like names
        local running_containers=$(docker ps -a --format "{{.Names}}" | grep -i "overseerr\|seerr")
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
    
    log_success "Detected setup: container='$CONTAINER_NAME', service='$SERVICE_NAME', compose='$COMPOSE_FILE'"
    
    # Log current status for verification
    log_info "Current container status:"
    if docker inspect "$CONTAINER_NAME" &> /dev/null; then
        docker inspect "$CONTAINER_NAME" --format "{{.State.Status}}: {{.Config.Image}}" || echo "Unable to inspect container"
    else
        log_info "Container '$CONTAINER_NAME' not found or not running"
    fi
}

# Detect Docker volumes and config locations
detect_docker_volumes() {
    local config_volume=""
    local volume_type="none"
    
    # Check if container exists and get volume info
    if docker inspect "$CONTAINER_NAME" &> /dev/null; then
        # Get volume mount information
        config_volume=$(docker inspect "$CONTAINER_NAME" --format '{{range .Mounts}}{{if eq .Destination "/app/config"}}{{.Source}}{{end}}{{end}}' 2>/dev/null || echo "")
        
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

# Production test main function
main() {
    echo ""
    echo "🧪 PRODUCTION TEST - Overseerr Content Filtering Migration Script v1.4.0"
    echo "========================================================================="
    echo ""
    
    if [ "$1" = "--dry-run" ]; then
        DRY_RUN=true
        log_warning "DRY RUN MODE ENABLED - No actual changes will be made"
        echo ""
    fi
    
    # Production safety check
    production_safety_check
    
    # Check prerequisites
    log_info "Checking prerequisites..."
    check_docker
    check_compose
    
    # Detect existing setup first to get accurate names and paths
    detect_existing_setup
    
    # Create production backup
    create_production_backup
    
    # Show what would happen
    log_test "=== MIGRATION PLAN ==="
    log_test "Current setup detected:"
    log_test "  - Container name: $CONTAINER_NAME"
    log_test "  - Service name: $SERVICE_NAME"
    log_test "  - Compose file: $COMPOSE_FILE"
    
    local volume_info=$(detect_docker_volumes)
    local volume_type=$(echo "$volume_info" | cut -d'|' -f1)
    local volume_path=$(echo "$volume_info" | cut -d'|' -f2)
    
    log_test "  - Volume type: $volume_type"
    if [ -n "$volume_path" ]; then
        log_test "  - Volume path: $volume_path"
    fi
    
    echo ""
    log_test "Proposed changes:"
    log_test "  - Update image to: $IMAGE_NAME:$TAG"
    log_test "  - Preserve all existing configuration"
    log_test "  - Maintain volume mounts exactly as configured"
    log_test "  - Keep container and service names unchanged"
    
    echo ""
    if [ "$DRY_RUN" = "true" ]; then
        log_success "DRY RUN completed successfully!"
        log_info "No actual changes were made. Review the output above to verify the migration plan."
    else
        read -p "Proceed with actual migration? (type 'MIGRATE' to continue): " confirm
        if [ "$confirm" != "MIGRATE" ]; then
            log_info "Migration cancelled by user"
            log_info "Backup preserved at: $BACKUP_DIR"
            exit 0
        fi
        
        log_error "ACTUAL MIGRATION NOT IMPLEMENTED IN TEST SCRIPT"
        log_error "Use the main migration script for actual migration"
        log_info "This test script is only for validation and backup creation"
    fi
    
    echo ""
    log_success "Production test completed!"
    log_info "Backup location: $BACKUP_DIR"
    log_info "Review the logs above to ensure everything looks correct"
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Run main function with all arguments
main "$@"
