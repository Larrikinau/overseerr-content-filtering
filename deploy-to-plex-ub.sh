#!/bin/bash

# Deploy Overseerr Content Filtering fixes to plex-ub
# Preserves TMDB API key: d447451a6c26c64a42e1ba6cbaaec4ae
# Sudo password: jnud4xa0

set -e  # Exit on error

# Configuration
PLEX_SERVER="plex-ub"
SUDO_PASS="jnud4xa0"
TMDB_API_KEY="d447451a6c26c64a42e1ba6cbaaec4ae"
CONTAINER_NAME="overseerr-content-filtering"
SOURCE_DIR="/Users/markvos/myfiles/Documents/github/overseerr-content-filtering-complete"
BUILD_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REMOTE_BUILD_DIR="/tmp/overseerr-build-$BUILD_TIMESTAMP"

echo "🚀 Starting deployment to plex-ub with API key preservation..."
echo "📅 Build timestamp: $BUILD_TIMESTAMP"

# Step 1: Create backup of current container configuration
echo "💾 Creating backup of current container configuration..."
ssh $PLEX_SERVER << EOF
echo "$SUDO_PASS" | sudo -S docker inspect $CONTAINER_NAME > /tmp/overseerr-backup-$BUILD_TIMESTAMP.json 2>/dev/null || echo "No existing container found"
echo "$SUDO_PASS" | sudo -S docker volume inspect overseerr_config > /tmp/overseerr-volume-backup-$BUILD_TIMESTAMP.json 2>/dev/null || echo "No existing volume found"
EOF

# Step 2: Stop current container (if running)
echo "🛑 Stopping current Overseerr container..."
ssh $PLEX_SERVER << EOF
echo "$SUDO_PASS" | sudo -S docker stop $CONTAINER_NAME 2>/dev/null || echo "Container not running"
echo "$SUDO_PASS" | sudo -S docker rm $CONTAINER_NAME 2>/dev/null || echo "Container already removed"
EOF

# Step 3: Copy source code to remote build directory
echo "📦 Copying source code to plex-ub build directory..."
ssh $PLEX_SERVER "rm -rf $REMOTE_BUILD_DIR && mkdir -p $REMOTE_BUILD_DIR"
rsync -av --progress \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='releases' \
  --exclude='.next' \
  --exclude='coverage' \
  --exclude='*.log' \
  --exclude='.DS_Store' \
  "$SOURCE_DIR/" $PLEX_SERVER:$REMOTE_BUILD_DIR/

# Step 4: Build Docker image on plex-ub
echo "🐳 Building Docker image on plex-ub..."
ssh $PLEX_SERVER << EOF
set -e
cd $REMOTE_BUILD_DIR

echo "🔧 Installing dependencies..."
yarn install --frozen-lockfile

echo "🏗️  Building application..."
yarn build

echo "🐳 Building Docker image..."
echo "$SUDO_PASS" | sudo -S docker build -t overseerr-content-filtering:fixed-$BUILD_TIMESTAMP .

echo "✅ Docker image built successfully"
EOF

# Step 5: Deploy new container with preserved API key
echo "🚀 Deploying new container with preserved API key..."
ssh $PLEX_SERVER << EOF
echo "$SUDO_PASS" | sudo -S docker run -d \
  --name $CONTAINER_NAME \
  -p 5055:5055 \
  -v overseerr_config:/app/config \
  --restart unless-stopped \
  -e NODE_ENV=production \
  -e RUN_MIGRATIONS=true \
  -e TMDB_API_KEY=$TMDB_API_KEY \
  overseerr-content-filtering:fixed-$BUILD_TIMESTAMP

echo "✅ New container deployed successfully"
EOF

# Step 6: Verify deployment
echo "🔍 Verifying deployment..."
sleep 10  # Give container time to start

ssh $PLEX_SERVER << EOF
echo "Checking container status..."
echo "$SUDO_PASS" | sudo -S docker ps | grep $CONTAINER_NAME || echo "❌ Container not running!"

echo "Checking container logs..."
echo "$SUDO_PASS" | sudo -S docker logs --tail 20 $CONTAINER_NAME

echo "Testing API endpoint..."
sleep 5
curl -s -f http://localhost:5055/api/v1/status && echo "✅ API responding" || echo "❌ API not responding"
EOF

# Step 7: Clean up build artifacts
echo "🧹 Cleaning up build artifacts..."
ssh $PLEX_SERVER << EOF
echo "Removing build directory..."
rm -rf $REMOTE_BUILD_DIR
echo "✅ Build directory $REMOTE_BUILD_DIR cleaned up"

echo "Removing old/unused Docker images..."
echo "$SUDO_PASS" | sudo -S docker image prune -f
echo "✅ Unused Docker images cleaned up"
EOF

# Step 8: Final verification and summary
echo "🎉 Deployment completed!"
echo ""
echo "📋 Deployment Summary:"
echo "  ✅ Source code synced to plex-ub"
echo "  ✅ Docker image built: overseerr-content-filtering:fixed-$BUILD_TIMESTAMP"
echo "  ✅ Container deployed with preserved TMDB API key"
echo "  ✅ Build artifacts cleaned up"
echo "  ✅ Old Docker images removed"
echo ""
echo "🌐 Access your updated Overseerr at: http://10.1.1.9:5055"
echo "🔧 Container name: $CONTAINER_NAME"
echo "🗂️  Data volume: overseerr_config (preserved)"
echo ""
echo "🔍 To check status:"
echo "  ssh $PLEX_SERVER"
echo "  sudo docker logs $CONTAINER_NAME"
echo "  sudo docker ps | grep $CONTAINER_NAME"
echo ""
echo "🚨 If issues occur, restore from backup:"
echo "  Backup files: /tmp/overseerr-*backup-$BUILD_TIMESTAMP.json"

EOF
