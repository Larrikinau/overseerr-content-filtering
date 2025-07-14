#!/bin/bash

# Test script for migration fix validation
# This script helps users test if the database migration issue has been resolved

echo "=========================================="
echo "  Migration Fix Test Script"
echo "=========================================="
echo ""

# Function to check Docker status
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is not installed"
        exit 1
    fi
    
    if ! docker ps &> /dev/null; then
        echo "❌ Docker is not running or permissions issue"
        exit 1
    fi
    
    echo "✅ Docker is available"
}

# Function to stop existing container
stop_existing() {
    if docker ps -a --format "table {{.Names}}" | grep -q "overseerr-content-filtering"; then
        echo "🔄 Stopping existing overseerr-content-filtering container..."
        docker stop overseerr-content-filtering 2>/dev/null || true
        docker rm overseerr-content-filtering 2>/dev/null || true
        echo "✅ Existing container removed"
    fi
}

# Function to pull latest image
pull_latest() {
    echo "🔄 Pulling latest image..."
    docker pull larrikinau/overseerr-content-filtering:latest
    echo "✅ Latest image pulled"
}

# Function to create volume backup
backup_volume() {
    if docker volume ls | grep -q "overseerr_config"; then
        echo "🔄 Creating backup of existing volume..."
        docker run --rm -v overseerr_config:/source -v $(pwd):/backup alpine tar czf /backup/overseerr_config_backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /source .
        echo "✅ Volume backup created"
    else
        echo "ℹ️  No existing volume found - this will be a fresh installation"
    fi
}

# Function to start container with enhanced logging
start_container() {
    echo "🔄 Starting overseerr-content-filtering with enhanced logging..."
    
    docker run -d \
        --name overseerr-content-filtering \
        -p 5055:5055 \
        -v overseerr_config:/app/config \
        -e NODE_ENV=production \
        -e RUN_MIGRATIONS=true \
        -e LOG_LEVEL=info \
        --restart unless-stopped \
        larrikinau/overseerr-content-filtering:latest
    
    echo "✅ Container started"
}

# Function to check migration logs
check_migration_logs() {
    echo "🔄 Checking migration logs..."
    sleep 10
    
    echo ""
    echo "📋 Migration-related logs:"
    docker logs overseerr-content-filtering 2>&1 | grep -i "database\|migration" | head -20
    
    echo ""
    echo "📋 Last 10 log lines:"
    docker logs overseerr-content-filtering 2>&1 | tail -10
}

# Function to verify content filtering columns
verify_columns() {
    echo "🔄 Verifying content filtering columns..."
    
    # Wait for container to be ready
    for i in {1..30}; do
        if curl -s http://localhost:5055/api/v1/status > /dev/null 2>&1; then
            echo "✅ Service is responding"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "⚠️  Service not responding yet, but continuing..."
        fi
        sleep 2
    done
    
    # Check if the container logs show successful column verification
    if docker logs overseerr-content-filtering 2>&1 | grep -q "Content filtering columns verified"; then
        echo "✅ Content filtering columns verified successfully"
    elif docker logs overseerr-content-filtering 2>&1 | grep -q "Content filtering columns may not exist"; then
        echo "❌ Content filtering columns NOT found - migration failed"
        echo "📋 Migration error details:"
        docker logs overseerr-content-filtering 2>&1 | grep -A5 -B5 "Content filtering columns may not exist"
    else
        echo "⚠️  Unable to determine column verification status"
    fi
}

# Function to show next steps
show_next_steps() {
    echo ""
    echo "=========================================="
    echo "  Next Steps"
    echo "=========================================="
    echo ""
    echo "1. Access Overseerr at: http://localhost:5055"
    echo "2. Try to login with existing credentials"
    echo "3. Check if Settings → Users → User Settings shows content filtering options"
    echo "4. Look for 'Content Rating Filtering' section"
    echo ""
    echo "📋 Useful commands:"
    echo "  View logs: docker logs overseerr-content-filtering"
    echo "  Stop container: docker stop overseerr-content-filtering"
    echo "  Remove container: docker rm overseerr-content-filtering"
    echo "  Check status: docker ps | grep overseerr-content-filtering"
    echo ""
    echo "🐛 If issues persist, please provide:"
    echo "  - Full container logs: docker logs overseerr-content-filtering"
    echo "  - Migration section of logs"
    echo "  - Any error messages when trying to access settings"
}

# Main execution
main() {
    check_docker
    stop_existing
    pull_latest
    backup_volume
    start_container
    check_migration_logs
    verify_columns
    show_next_steps
}

# Run main function
main
