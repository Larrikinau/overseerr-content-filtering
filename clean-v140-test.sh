#!/bin/bash

# Clean Overseerr v1.4.0 Test Script
# This script runs the v1.4.0 Docker image with no sensitive data
# - Uses empty/default API keys
# - Creates fresh database
# - No production data mounted

echo "=== Starting Clean Overseerr v1.4.0 Test ==="
echo "This will run v1.4.0 with no sensitive data or production volumes"

# Stop and remove any existing clean test container
ssh markvos@plex-ub 'docker stop overseerr-clean-test 2>/dev/null || true'
ssh markvos@plex-ub 'docker rm overseerr-clean-test 2>/dev/null || true'

# Create a temporary directory for clean config
ssh markvos@plex-ub 'rm -rf /tmp/overseerr-clean-test && mkdir -p /tmp/overseerr-clean-test'

echo "Starting clean v1.4.0 container..."

# Rebuild the Docker image with updated v1.4.0 package.json
echo "Rebuilding Docker image with v1.4.0 package.json..."
scp ./package.json markvos@plex-ub:/tmp/package.json.v140
ssh markvos@plex-ub 'cd /opt/overseerr-v1.4.0-source/complete-source && cp /tmp/package.json.v140 ./package.json && docker build -t larrikinau/overseerr-content-filtering:v1.4.0-updated --build-arg COMMIT_TAG=v1.4.0 .'

# Set proper permissions for config directory
ssh markvos@plex-ub 'rm -rf /tmp/overseerr-clean-test && mkdir -p /tmp/overseerr-clean-test && chmod 777 /tmp/overseerr-clean-test'

# Run the container with clean environment
ssh markvos@plex-ub 'docker run -d \
  --name overseerr-clean-test \
  --restart unless-stopped \
  -e LOG_LEVEL=info \
  -e TZ=Australia/Melbourne \
  -e PORT=5055 \
  -e TMDB_API_KEY= \
  -e OVERSEERR_API_KEY= \
  --user 1001:1001 \
  -p 5056:5055 \
  -v /tmp/overseerr-clean-test:/app/config \
  larrikinau/overseerr-content-filtering:v1.4.0-updated'

echo "Waiting for container to start..."
sleep 10

# Check if container is running
echo "=== Container Status ==="
ssh markvos@plex-ub 'docker ps --filter name=overseerr-clean-test --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Check container logs
echo ""
echo "=== Container Logs ==="
ssh markvos@plex-ub 'docker logs overseerr-clean-test 2>&1 | tail -20'

# Test if the web interface is responding
echo ""
echo "=== Testing Web Interface ==="
sleep 5
if ssh markvos@plex-ub 'curl -s -o /dev/null -w "%{http_code}" http://localhost:5056' | grep -q "200\|302"; then
    echo "✅ Web interface is responding"
    echo "Access the clean test instance at: http://plex-ub:5056"
    echo ""
    echo "This instance has:"
    echo "- Fresh database (no production data)"
    echo "- Empty API keys (will show warnings)"
    echo "- Clean configuration"
    echo "- v1.4.0 source code with bug fixes"
else
    echo "❌ Web interface not responding yet"
    echo "Check logs above for any startup issues"
fi

echo ""
echo "=== Version Verification ==="
echo "Checking package.json version in the running container:"
ssh markvos@plex-ub 'docker exec overseerr-clean-test cat /app/package.json | grep -A1 -B1 version || echo "Could not read package.json"'

echo ""
echo "=== Container Information ==="
ssh markvos@plex-ub 'docker inspect overseerr-clean-test --format="Image: {{.Config.Image}}"'
ssh markvos@plex-ub 'docker inspect overseerr-clean-test --format="Created: {{.Created}}"'

echo ""
echo "To stop the clean test:"
echo "ssh markvos@plex-ub 'docker stop overseerr-clean-test && docker rm overseerr-clean-test'"
echo ""
echo "To view live logs:"
echo "ssh markvos@plex-ub 'docker logs -f overseerr-clean-test'"
