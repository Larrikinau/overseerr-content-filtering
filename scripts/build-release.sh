#!/bin/bash

# Build Release Script for Overseerr Content Filtering
# This script creates distribution packages for Ubuntu/Debian systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"
RELEASE_DIR="$PROJECT_ROOT/releases"
TEMP_DIR="/tmp/overseerr-content-filtering-build"

# Package information
PACKAGE_NAME="overseerr-content-filtering"
VERSION=$(node -p "require('$PROJECT_ROOT/package.json').version")
TARBALL_NAME="$PACKAGE_NAME-ubuntu.tar.gz"
CHECKSUM_FILE="$PACKAGE_NAME-ubuntu.tar.gz.sha256"

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build release packages for Overseerr Content Filtering"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --version VER   Set package version (default: from package.json)"
    echo "  --clean             Clean build directories before building"
    echo "  --docker            Build Docker image as well"
    echo "  --push              Push Docker image to registry"
    echo "  --dev               Build development version"
    echo "  --no-compression    Skip compression optimization"
    echo ""
    echo "Examples:"
    echo "  $0                  # Build standard release"
    echo "  $0 --clean --docker # Clean build with Docker"
    echo "  $0 --dev            # Build development version"
}

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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if we're in the project root
    if [ ! -f "$PROJECT_ROOT/package.json" ]; then
        log_error "Must be run from project root directory"
        exit 1
    fi
    
    # Check Node.js version
    if ! command -v node &> /dev/null; then
        log_error "Node.js not found. Please install Node.js 18+"
        exit 1
    fi
    
    NODE_VERSION=$(node --version | cut -d'.' -f1 | cut -d'v' -f2)
    if [ "$NODE_VERSION" -lt 18 ]; then
        log_error "Node.js 18+ required. Current version: $(node --version)"
        exit 1
    fi
    
    # Check yarn
    if ! command -v yarn &> /dev/null; then
        log_error "Yarn not found. Please install Yarn"
        exit 1
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        log_error "Git not found. Please install Git"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Clean build directories
clean_build() {
    if [ "$CLEAN" = true ]; then
        log "Cleaning build directories..."
        rm -rf "$BUILD_DIR"
        rm -rf "$DIST_DIR"
        rm -rf "$RELEASE_DIR"
        rm -rf "$TEMP_DIR"
        log_success "Build directories cleaned"
    fi
}

# Create build directories
create_directories() {
    log "Creating build directories..."
    mkdir -p "$BUILD_DIR"
    mkdir -p "$RELEASE_DIR"
    mkdir -p "$TEMP_DIR"
    log_success "Build directories created"
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    cd "$PROJECT_ROOT"
    
    # Install production dependencies
    CYPRESS_INSTALL_BINARY=0 yarn install --frozen-lockfile --network-timeout 1000000
    
    log_success "Dependencies installed"
}

# Build application
build_application() {
    log "Building application..."
    cd "$PROJECT_ROOT"
    
    # Build the application
    yarn build
    
    # Verify build output
    if [ ! -f "$PROJECT_ROOT/dist/index.js" ]; then
        log_error "Build failed - dist/index.js not found"
        exit 1
    fi
    
    log_success "Application built successfully"
}

# Create release package
create_release_package() {
    log "Creating release package..."
    
    # Create staging directory
    STAGING_DIR="$TEMP_DIR/staging"
    mkdir -p "$STAGING_DIR"
    
    # Copy application files
    cp -r "$PROJECT_ROOT/dist" "$STAGING_DIR/"
    cp -r "$PROJECT_ROOT/public" "$STAGING_DIR/"
    cp -r "$PROJECT_ROOT/.next" "$STAGING_DIR/"
    cp -r "$PROJECT_ROOT/server/templates" "$STAGING_DIR/"
    
    # Copy configuration files
    cp "$PROJECT_ROOT/package.json" "$STAGING_DIR/"
    cp "$PROJECT_ROOT/yarn.lock" "$STAGING_DIR/"
    cp "$PROJECT_ROOT/next.config.js" "$STAGING_DIR/"
    
    # Copy documentation
    cp "$PROJECT_ROOT/README.md" "$STAGING_DIR/"
    cp "$PROJECT_ROOT/LICENSE" "$STAGING_DIR/"
    cp "$PROJECT_ROOT/CHANGELOG.md" "$STAGING_DIR/" 2>/dev/null || true
    
    # Create production node_modules
    log "Installing production dependencies..."
    cd "$STAGING_DIR"
    yarn install --production --ignore-scripts --prefer-offline
    
    # Clean up unnecessary files
    log "Cleaning up package..."
    find "$STAGING_DIR" -name "*.map" -delete
    find "$STAGING_DIR" -name "*.d.ts" -delete
    find "$STAGING_DIR" -name "*.test.js" -delete
    find "$STAGING_DIR" -name "*.test.ts" -delete
    find "$STAGING_DIR" -name "__tests__" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$STAGING_DIR" -name "test" -type d -exec rm -rf {} + 2>/dev/null || true
    find "$STAGING_DIR" -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Remove development files
    rm -rf "$STAGING_DIR/.next/cache"
    rm -rf "$STAGING_DIR/node_modules/.cache"
    
    # Create version info
    echo "{\"version\": \"$VERSION\", \"buildDate\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"gitCommit\": \"$(git rev-parse --short HEAD)\"}" > "$STAGING_DIR/version.json"
    
    # Create Docker marker
    mkdir -p "$STAGING_DIR/config"
    touch "$STAGING_DIR/config/DOCKER"
    
    log_success "Release package prepared"
}

# Create tarball
create_tarball() {
    log "Creating tarball..."
    
    cd "$TEMP_DIR"
    
    # Create tarball with compression
    if [ "$NO_COMPRESSION" = true ]; then
        tar -czf "$RELEASE_DIR/$TARBALL_NAME" -C staging .
    else
        # Use better compression
        tar -czf "$RELEASE_DIR/$TARBALL_NAME" -C staging . --exclude-vcs
    fi
    
    # Create checksum
    cd "$RELEASE_DIR"
    sha256sum "$TARBALL_NAME" > "$CHECKSUM_FILE"
    
    # Get package info
    PACKAGE_SIZE=$(du -h "$TARBALL_NAME" | cut -f1)
    PACKAGE_SHA256=$(cut -d' ' -f1 "$CHECKSUM_FILE")
    
    log_success "Tarball created: $TARBALL_NAME ($PACKAGE_SIZE)"
    log "SHA256: $PACKAGE_SHA256"
}

# Create installation instructions
create_install_instructions() {
    log "Creating installation instructions..."
    
    cat > "$RELEASE_DIR/INSTALL.txt" << EOF
# Overseerr Content Filtering - Installation Instructions

## Quick Install (Recommended)
curl -fsSL https://raw.githubusercontent.com/Larrikinau/overseerr-content-filtering/main/install-overseerr-filtering.sh | sudo bash

## Manual Install
1. Download: $TARBALL_NAME
2. Extract: tar -xzf $TARBALL_NAME
3. Install: sudo ./install-overseerr-filtering.sh

## Docker Install
docker run -d \\
  --name overseerr-content-filtering \\
  -p 5055:5055 \\
  -v /path/to/config:/app/config \\
  --restart unless-stopped \\
  larrikinau/overseerr-content-filtering

## Verification
SHA256: $PACKAGE_SHA256
Size: $PACKAGE_SIZE
Version: $VERSION
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Support
- Documentation: https://github.com/Larrikinau/overseerr-content-filtering
- Issues: https://github.com/Larrikinau/overseerr-content-filtering/issues
EOF
    
    log_success "Installation instructions created"
}

# Build Docker image
build_docker() {
    if [ "$BUILD_DOCKER" != true ]; then
        return
    fi
    
    log "Building Docker image..."
    cd "$PROJECT_ROOT"
    
    # Build Docker image
    docker build -t "larrikinau/overseerr-content-filtering:$VERSION" .
    docker tag "larrikinau/overseerr-content-filtering:$VERSION" "larrikinau/overseerr-content-filtering:latest"
    
    if [ "$PUSH_DOCKER" = true ]; then
        log "Pushing Docker image..."
        docker push "larrikinau/overseerr-content-filtering:$VERSION"
        docker push "larrikinau/overseerr-content-filtering:latest"
        log_success "Docker image pushed"
    fi
    
    log_success "Docker image built"
}

# Clean up temporary files
cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    log_success "Cleanup completed"
}

# Show build summary
show_summary() {
    echo ""
    echo -e "${BLUE}=== Build Summary ===${NC}"
    echo ""
    echo -e "${GREEN}Package: $PACKAGE_NAME${NC}"
    echo -e "${GREEN}Version: $VERSION${NC}"
    echo -e "${GREEN}Tarball: $TARBALL_NAME${NC}"
    echo -e "${GREEN}Size: $(du -h "$RELEASE_DIR/$TARBALL_NAME" | cut -f1)${NC}"
    echo -e "${GREEN}SHA256: $(cut -d' ' -f1 "$RELEASE_DIR/$CHECKSUM_FILE")${NC}"
    echo ""
    echo -e "${YELLOW}Files created:${NC}"
    echo "  $RELEASE_DIR/$TARBALL_NAME"
    echo "  $RELEASE_DIR/$CHECKSUM_FILE"
    echo "  $RELEASE_DIR/INSTALL.txt"
    echo ""
    echo -e "${YELLOW}Installation:${NC}"
    echo "  Quick: curl -fsSL https://raw.githubusercontent.com/Larrikinau/overseerr-content-filtering/main/install-overseerr-filtering.sh | sudo bash"
    echo "  Manual: tar -xzf $TARBALL_NAME && sudo ./install-overseerr-filtering.sh"
    echo ""
}

# Main build function
main_build() {
    log "Starting build process..."
    
    check_prerequisites
    clean_build
    create_directories
    install_dependencies
    build_application
    create_release_package
    create_tarball
    create_install_instructions
    build_docker
    cleanup
    
    log_success "Build completed successfully!"
    show_summary
}

# Parse command line arguments
CLEAN=false
BUILD_DOCKER=false
PUSH_DOCKER=false
DEV_VERSION=false
NO_COMPRESSION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --docker)
            BUILD_DOCKER=true
            shift
            ;;
        --push)
            PUSH_DOCKER=true
            BUILD_DOCKER=true
            shift
            ;;
        --dev)
            DEV_VERSION=true
            shift
            ;;
        --no-compression)
            NO_COMPRESSION=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Update version for dev builds
if [ "$DEV_VERSION" = true ]; then
    VERSION="$VERSION-dev"
    TARBALL_NAME="$PACKAGE_NAME-dev-ubuntu.tar.gz"
    CHECKSUM_FILE="$PACKAGE_NAME-dev-ubuntu.tar.gz.sha256"
fi

# Main execution
main_build
