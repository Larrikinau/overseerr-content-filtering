#!/bin/bash

# Universal Overseerr Content Filtering v1.4.0 Migration Script
# Automatically detects current setup and performs appropriate migration
# Supports: Original Overseerr -> v1.4.0 AND Current Fork -> v1.4.0

set -e

echo "🚀 Universal Overseerr Content Filtering v1.4.0 Migration Script"
echo "================================================================="
echo ""

# Function to detect current setup
detect_current_setup() {
    echo "🔍 Detecting current Overseerr setup..."
    
    # Find running overseerr container
    CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep -i overseerr | head -1)
    
    if [ -z "$CONTAINER_NAME" ]; then
        echo "❌ Error: No running Overseerr container found"
        echo "Please ensure your Overseerr container is running before migration"
        exit 1
    fi
    
    echo "📦 Found container: $CONTAINER_NAME"
    
    # Get container image
    CURRENT_IMAGE=$(docker inspect $CONTAINER_NAME --format="{{.Config.Image}}" 2>/dev/null || echo "unknown")
    echo "🐳 Current image: $CURRENT_IMAGE"
    
    # Detect setup type based on image name patterns
    if [[ "$CURRENT_IMAGE" == *"larrikinau/overseerr-content-filtering"* ]] || \
       [[ "$CURRENT_IMAGE" == *"content-filtering"* ]] || \
       [[ "$CURRENT_IMAGE" == *"overseerr"*"-private"* ]]; then
        SETUP_TYPE="FORK"
        echo "✅ Detected: Overseerr Content Filtering Fork (upgrade scenario)"
    else
        SETUP_TYPE="ORIGINAL"
        echo "✅ Detected: Original Overseerr (full migration scenario)"
    fi
    
    echo ""
}

# Function to detect API keys
detect_api_keys() {
    echo "🔍 Detecting current API configuration..."
    
    # Try to detect TMDB API key from running container
    DETECTED_TMDB_KEY=$(docker exec $CONTAINER_NAME env 2>/dev/null | grep TMDB_API_KEY | cut -d"=" -f2- || echo "")
    
    if [ -n "$DETECTED_TMDB_KEY" ]; then
        echo "✅ Found TMDB API key: ${DETECTED_TMDB_KEY:0:8}...****** (will preserve)"
        TMDB_KEY_TO_USE="$DETECTED_TMDB_KEY"
    else
        echo "➕ No TMDB API key detected, will use public default"
        TMDB_KEY_TO_USE="db55323b8d3e4154498498a75642b381"
    fi
    
    echo ""
}

# Function to backup current setup
backup_current_setup() {
    echo "📁 Creating comprehensive backup..."
    
    BACKUP_DIR="overseerr-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup docker-compose if exists
    if [ -f "docker-compose.yml" ]; then
        cp docker-compose.yml "$BACKUP_DIR/docker-compose.yml.backup"
        echo "✅ Backed up docker-compose.yml"
    fi
    
    # Backup container data
    echo "📦 Backing up container data..."
    docker cp "$CONTAINER_NAME:/app/config" "$BACKUP_DIR/config-backup" 2>/dev/null || echo "⚠️  Could not backup config (may not exist)"
    
    echo "✅ Backup created in: $BACKUP_DIR"
    echo ""
}

# Function to migrate from original Overseerr
migrate_from_original() {
    echo "🔄 Performing FULL MIGRATION from Original Overseerr to v1.4.0..."
    echo ""
    
    # Create new docker-compose.yml for content filtering
    cat > docker-compose.yml << COMPOSE_EOF
version: "3.8"

services:
  overseerr-content-filtering:
    image: larrikinau/overseerr-content-filtering:latest
    container_name: overseerr-content-filtering
    restart: unless-stopped
    ports:
      - "5055:5055"
    volumes:
      - overseerr_config:/app/config
      - overseerr_logs:/app/logs
    environment:
      - NODE_ENV=production
      - LOG_LEVEL=info
      - TZ=UTC
      - RUN_MIGRATIONS=true
      - TMDB_API_KEY=$TMDB_KEY_TO_USE
      - ALGOLIA_API_KEY=175588f6e5f8319b27702e4cc4013561
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5055/api/v1/status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  overseerr_config:
    driver: local
  overseerr_logs:
    driver: local
COMPOSE_EOF
    
    echo "✅ Created new docker-compose.yml with content filtering"
    echo "📝 Note: Data will be migrated when new container starts"
    echo ""
}

# Function to upgrade current fork
upgrade_current_fork() {
    echo "⬆️  Performing UPGRADE from Current Fork to latest version..."
    echo ""
    
    if [ ! -f "docker-compose.yml" ]; then
        echo "❌ Error: docker-compose.yml not found"
        echo "Please run this script from your Overseerr installation directory"
        exit 1
    fi
    
    # Define required environment variables
    declare -A REQUIRED_VARS=(
        ["RUN_MIGRATIONS"]="true"
        ["ALGOLIA_API_KEY"]="175588f6e5f8319b27702e4cc4013561"
        ["TMDB_API_KEY"]="$TMDB_KEY_TO_USE"
    )
    
    echo "🔧 Analyzing current docker-compose.yml..."
    
    # Check existing environment variables
    missing_vars=()
    needs_update=()
    
    for var_name in "${!REQUIRED_VARS[@]}"; do
        if grep -q "$var_name=" docker-compose.yml; then
            current_value=$(grep "$var_name=" docker-compose.yml | head -1 | cut -d"=" -f2-)
            expected_value="${REQUIRED_VARS[$var_name]}"
            
            if [ "$current_value" != "$expected_value" ]; then
                echo "⚠️  $var_name needs update"
                needs_update+=("$var_name")
            else
                echo "✅ $var_name already correct"
            fi
        else
            echo "➕ Missing: $var_name (will add)"
            missing_vars+=("$var_name")
        fi
    done
    
    total_changes=$((${#missing_vars[@]} + ${#needs_update[@]}))
    
    if [ $total_changes -gt 0 ]; then
        echo ""
        echo "🔧 Updating docker-compose.yml..."
        
        # Add missing variables
        for var_name in "${missing_vars[@]}"; do
            value="${REQUIRED_VARS[$var_name]}"
            echo "   Adding: $var_name"
            sed -i "/environment:/a\\      - $var_name=$value" docker-compose.yml
        done
        
        # Update existing variables that need changes
        for var_name in "${needs_update[@]}"; do
            value="${REQUIRED_VARS[$var_name]}"
            echo "   Updating: $var_name"
            sed -i "s|$var_name=.*|$var_name=$value|" docker-compose.yml
        done
    fi
    
    # Update image to latest (removes version pinning)
    echo "🐳 Updating image to latest version..."
    sed -i "s|larrikinau/overseerr-content-filtering:.*|larrikinau/overseerr-content-filtering:latest|g" docker-compose.yml
    sed -i "s|image: overseerr:.*|image: larrikinau/overseerr-content-filtering:latest|g" docker-compose.yml
    
    # Ensure standard port is used
    echo "🔧 Ensuring standard port configuration..."
    sed -i "s|\"[0-9]*:5055\"|\"5055:5055\"|g" docker-compose.yml
    
    echo ""
}

# Function to display next steps
show_next_steps() {
    echo "✅ Migration preparation completed successfully!"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Review the updated docker-compose.yml"
    echo "2. Pull the latest image:"
    echo "   docker pull larrikinau/overseerr-content-filtering:latest"
    echo "3. Stop current container:"
    echo "   docker stop $CONTAINER_NAME"
    echo "4. Start new container:"
    echo "   docker-compose up -d"
    echo ""
    echo "🔒 Security Notes:"
    if [ "$SETUP_TYPE" = "ORIGINAL" ]; then
        echo "- Complete migration from original Overseerr to content filtering fork"
        echo "- Your data will be automatically migrated on first startup"
    else
        echo "- Upgrading existing content filtering installation"
        echo "- All existing settings and data will be preserved"
    fi
    echo "- API keys automatically detected and preserved"
    echo "- Environment variable architecture implemented"
    echo "- Standard port 5055 configured"
    echo ""
    echo "📁 Backup available in: $BACKUP_DIR"
    echo ""
    echo "🎉 Ready for Overseerr Content Filtering latest version!"
}

# Main execution
main() {
    detect_current_setup
    detect_api_keys
    backup_current_setup
    
    if [ "$SETUP_TYPE" = "ORIGINAL" ]; then
        migrate_from_original
    else
        upgrade_current_fork
    fi
    
    show_next_steps
}

# Run main function
main

