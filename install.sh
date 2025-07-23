#!/bin/bash

# Overseerr Content Filtering - Standalone Installation Script
# This script installs the extracted Overseerr Content Filtering package on Debian/Ubuntu systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/overseerr-content-filtering"
SERVICE_NAME="overseerr-content-filtering"
SERVICE_USER="overseerr"
DATA_DIR="/var/lib/overseerr-content-filtering"
DEFAULT_PORT=5055

# Get the directory where this script is located (the extracted package directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check OS
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot detect OS. This script is for Debian/Ubuntu systems only."
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log_error "This script is for Debian/Ubuntu systems only. Detected: $ID"
        exit 1
    fi
    
    log_success "Running on $PRETTY_NAME"
    
    # Check if we're in the extracted package directory
    if [ ! -f "$SCRIPT_DIR/dist/index.js" ]; then
        log_error "This script must be run from the extracted package directory"
        log_error "Expected to find dist/index.js in: $SCRIPT_DIR"
        exit 1
    fi
    
    log_success "Package directory validated"
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    apt-get update
    apt-get install -y curl systemd sqlite3 ca-certificates
    
    # Install Node.js 18
    if ! command -v node &> /dev/null || [ "$(node --version | cut -d'.' -f1 | cut -d'v' -f2)" -lt "18" ]; then
        log "Installing Node.js 18..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
    
    log_success "Dependencies installed"
}

# Create system user
create_user() {
    log "Creating system user '$SERVICE_USER'..."
    
    if id "$SERVICE_USER" &>/dev/null; then
        log_warning "User '$SERVICE_USER' already exists"
    else
        useradd --system --shell /bin/false --home-dir "$DATA_DIR" --create-home "$SERVICE_USER"
        log_success "User '$SERVICE_USER' created"
    fi
}

# Create directories and install application
install_application() {
    log "Installing application..."
    
    # Create directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"
    
    # Copy application files
    cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"
    
    # Set permissions
    chown -R root:root "$INSTALL_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    chmod +x "$INSTALL_DIR/dist/index.js"
    chmod 750 "$DATA_DIR"
    
    log_success "Application installed to $INSTALL_DIR"
}

# Create systemd service
create_service() {
    log "Creating systemd service..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Overseerr Content Filtering
Documentation=https://github.com/larrikinau/overseerr-content-filtering
After=network.target
Wants=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/node $INSTALL_DIR/dist/index.js
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME
Environment=NODE_ENV=production
Environment=PORT=$DEFAULT_PORT
Environment=TMDB_API_KEY=db55323b8d3e4154498498a75642b381

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    log_success "Systemd service created"
}

# Configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        ufw allow "$DEFAULT_PORT/tcp" comment "Overseerr Content Filtering"
        log_success "Firewall configured (UFW)"
    else
        log_warning "UFW not available, skipping firewall configuration"
    fi
}

# Start service
start_service() {
    log "Starting service..."
    
    systemctl start "$SERVICE_NAME"
    
    # Wait for service to start
    sleep 5
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log_success "Service started successfully"
    else
        log_error "Service failed to start"
        systemctl status "$SERVICE_NAME"
        exit 1
    fi
}

# Show status
show_status() {
    echo ""
    echo -e "${BLUE}=== Installation Complete ===${NC}"
    echo ""
    
    # Service status
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${GREEN}Service Status: Running${NC}"
    else
        echo -e "${RED}Service Status: Not Running${NC}"
    fi
    
    # URLs
    echo ""
    echo -e "${YELLOW}Access URLs:${NC}"
    echo "  Local: http://localhost:$DEFAULT_PORT"
    echo "  Network: http://$(hostname -I | awk '{print $1}'):$DEFAULT_PORT"
    echo ""
    
    # Useful commands
    echo -e "${YELLOW}Useful Commands:${NC}"
    echo "  Status: systemctl status $SERVICE_NAME"
    echo "  Logs: journalctl -u $SERVICE_NAME -f"
    echo "  Restart: systemctl restart $SERVICE_NAME"
    echo "  Stop: systemctl stop $SERVICE_NAME"
    echo ""
}

# Main installation function
main_install() {
    log "Starting Overseerr Content Filtering installation..."
    
    check_root
    check_requirements
    install_dependencies
    create_user
    install_application
    create_service
    configure_firewall
    start_service
    
    log_success "Installation completed successfully!"
    show_status
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Install Overseerr Content Filtering from extracted package"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "This script must be run from the extracted package directory with sudo/root privileges."
    echo ""
    echo "Example:"
    echo "  sudo ./install.sh"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main_install
