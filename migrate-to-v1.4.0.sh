#!/bin/bash

# Overseerr Content Filtering v1.4.0 Migration Script
# Auto-detects and preserves current production API keys

set -e

echo "🚀 Overseerr Content Filtering v1.4.0 Migration Script"
echo "======================================================"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found in current directory"
    echo "Please run this script from your Overseerr installation directory"
    exit 1
fi

# Detect production container
echo "🔍 Detecting running Overseerr container..."
CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep -i overseerr | head -1)

if [ -z "$CONTAINER_NAME" ]; then
    echo "❌ Error: No running Overseerr container found"
    echo "Please ensure your Overseerr container is running before migration"
    exit 1
fi

echo "📦 Found container: $CONTAINER_NAME"

# Backup current docker-compose.yml
echo "📁 Creating backup of current docker-compose.yml..."
cp docker-compose.yml docker-compose.yml.pre-v1.4.0-backup
echo "✅ Backup created: docker-compose.yml.pre-v1.4.0-backup"

echo ""
echo "🔍 Detecting current production API keys..."

# Detect current TMDB API key from running container
DETECTED_TMDB_KEY=$(docker exec $CONTAINER_NAME env | grep TMDB_API_KEY | cut -d= -f2- || echo "")

if [ -n "$DETECTED_TMDB_KEY" ]; then
    echo "✅ Found production TMDB API key: ${DETECTED_TMDB_KEY:0:8}...****** (preserving)"
    TMDB_KEY_TO_USE=$DETECTED_TMDB_KEY
else
    echo "➕ No TMDB API key detected, will use public default"
    TMDB_KEY_TO_USE="db55323b8d3e4154498498a75642b381"
fi

# Define required environment variables
declare -A REQUIRED_VARS=(
    ["RUN_MIGRATIONS"]="true"
    ["ALGOLIA_API_KEY"]="175588f6e5f8319b27702e4cc4013561"
    ["TMDB_API_KEY"]="$TMDB_KEY_TO_USE"
)

echo ""
echo "🔧 Analyzing current docker-compose.yml..."

# Check existing environment variables
missing_vars=()
needs_update=()

for var_name in "${!REQUIRED_VARS[@]}"; do
    if grep -q "$var_name=" docker-compose.yml; then
        current_value=$(grep "$var_name=" docker-compose.yml | head -1 | cut -d= -f2-)
        expected_value="${REQUIRED_VARS[$var_name]}"
        
        if [ "$current_value" != "$expected_value" ]; then
            echo "⚠️  $var_name needs update (current: ${current_value:0:8}...*****, detected: ${expected_value:0:8}...******)"
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

if [ $total_changes -eq 0 ]; then
    echo "✅ All environment variables are already correct!"
else
    echo ""
    echo "🔧 Updating docker-compose.yml..."
    
    # Add missing variables
    for var_name in "${missing_vars[@]}"; do
        value="${REQUIRED_VARS[$var_name]}"
        echo "   Adding: $var_name"
        sed -i "/environment:/a\\      - $var_name=$value" docker-compose.yml
    done
    
    # Update existing variables
    for var_name in "${needs_update[@]}"; do
        value="${REQUIRED_VARS[$var_name]}"
        echo "   Updating: $var_name"
        sed -i "s|$var_name=.*|$var_name=$value|" docker-compose.yml
    done
fi

# Update image version
echo "🐳 Updating image version to v1.4.0..."
sed -i s
