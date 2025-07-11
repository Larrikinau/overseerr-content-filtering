#!/bin/bash

# Overseerr Content Filtering - One-Command Installation Script
# This script installs Overseerr with Content Filtering on Debian/Ubuntu systems

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
CONFIG_DIR="/etc/overseerr-content-filtering"
LOG_DIR="/var/log/overseerr-content-filtering"
DATA_DIR="/var/lib/overseerr-content-filtering"
BACKUP_DIR="/var/backups/overseerr-content-filtering"
RELEASE_URL="https://github.com/larrikinau/overseerr-content-filtering/releases/latest/download"
TARBALL_NAME="overseerr-content-filtering-ubuntu.tar.gz"

# Default configuration
DEFAULT_PORT=5055
DEFAULT_DB_PATH="$DATA_DIR/db/settings.db"

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Install Overseerr Content Filtering on Debian/Ubuntu systems"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -p, --port PORT         Set the port (default: 5055)"
    echo "  --data-dir DIR          Set data directory (default: $DATA_DIR)"
    echo "  --config-dir DIR        Set config directory (default: $CONFIG_DIR)"
    echo "  --install-dir DIR       Set installation directory (default: $INSTALL_DIR)"
    echo "  --user USER             Set service user (default: $SERVICE_USER)"
    echo "  --no-service            Don't install systemd service"
    echo "  --no-firewall           Don't configure firewall"
    echo "  --dev                   Install development version"
    echo "  --uninstall             Uninstall the application"
    echo "  --backup                Create backup before installation"
    echo "  --restore FILE          Restore from backup file"
    echo ""
    echo "Examples:"
    echo "  $0                      # Standard installation"
    echo "  $0 -p 3000              # Install on port 3000"
    echo "  $0 --backup             # Create backup and install"
    echo "  $0 --uninstall          # Uninstall application"
    echo "  $0 --restore backup.tar.gz  # Restore from backup"
}

# Logging function
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
    
    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" && "$ARCH" != "armv7l" ]]; then
        log_warning "Architecture $ARCH may not be supported. Continuing anyway..."
    fi
    
    # Check available space
    AVAILABLE_SPACE=$(df / | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE_SPACE" -lt 1048576 ]; then  # 1GB in KB
        log_error "Insufficient disk space. At least 1GB required."
        exit 1
    fi
    
    log_success "System requirements check passed"
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    apt-get update
    apt-get install -y \
        curl \
        wget \
        tar \
        gzip \
        systemd \
        ufw \
        logrotate \
        sqlite3 \
        ca-certificates \
        gnupg \
        lsb-release
    
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

# Create directories
create_directories() {
    log "Creating directories..."
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Set permissions
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$LOG_DIR"
    chown -R root:root "$CONFIG_DIR"
    chmod 755 "$CONFIG_DIR"
    chmod 750 "$DATA_DIR"
    chmod 750 "$LOG_DIR"
    
    log_success "Directories created"
}

# Download and extract application
download_application() {
    log "Downloading Overseerr Content Filtering..."
    
    cd /tmp
    
    # Download the latest release
    if [ "$DEV_VERSION" = true ]; then
        DOWNLOAD_URL="$RELEASE_URL/dev/$TARBALL_NAME"
    else
        DOWNLOAD_URL="$RELEASE_URL/$TARBALL_NAME"
    fi
    
    wget -O "$TARBALL_NAME" "$DOWNLOAD_URL" || {
        log_error "Failed to download application"
        exit 1
    }
    
    # Verify download
    if [ ! -f "$TARBALL_NAME" ]; then
        log_error "Download failed - file not found"
        exit 1
    fi
    
    # Extract to installation directory
    log "Extracting application..."
    tar -xzf "$TARBALL_NAME" -C "$INSTALL_DIR" --strip-components=1
    
    # Set permissions
    chown -R root:root "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/dist/index.js"
    
    # Clean up
    rm -f "$TARBALL_NAME"
    
    log_success "Application downloaded and extracted"
}

# Create configuration files
create_config() {
    log "Creating configuration files..."
    
    # Main configuration
    cat > "$CONFIG_DIR/config.json" << EOF
{
  "port": $PORT,
  "dbPath": "$DEFAULT_DB_PATH",
  "logLevel": "info",
  "logDir": "$LOG_DIR",
  "dataDir": "$DATA_DIR",
  "contentFiltering": {
    "enabled": true,
    "adultContentBlocked": true,
    "explicitLanguageFiltered": true,
    "violenceLevel": "moderate"
  },
  "security": {
    "enableHttps": false,
    "trustProxy": false,
    "sessionSecret": "$(openssl rand -hex 32)"
  }
}
EOF
    
    # Environment file
    cat > "$CONFIG_DIR/environment" << EOF
# Overseerr Content Filtering Environment Configuration
NODE_ENV=production
PORT=$PORT
CONFIG_FILE=$CONFIG_DIR/config.json
DATA_DIR=$DATA_DIR
LOG_DIR=$LOG_DIR
DB_PATH=$DEFAULT_DB_PATH
EOF
    
    # Set permissions
    chown root:root "$CONFIG_DIR/config.json"
    chown root:root "$CONFIG_DIR/environment"
    chmod 644 "$CONFIG_DIR/config.json"
    chmod 600 "$CONFIG_DIR/environment"
    
    log_success "Configuration files created"
}

# Create systemd service
create_service() {
    if [ "$NO_SERVICE" = true ]; then
        log "Skipping systemd service creation"
        return
    fi
    
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
EnvironmentFile=$CONFIG_DIR/environment

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR $LOG_DIR
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true

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
    if [ "$NO_FIREWALL" = true ]; then
        log "Skipping firewall configuration"
        return
    fi
    
    log "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        ufw allow "$PORT/tcp" comment "Overseerr Content Filtering"
        log_success "Firewall configured (UFW)"
    else
        log_warning "UFW not available, skipping firewall configuration"
    fi
}

# Configure log rotation
configure_logrotate() {
    log "Configuring log rotation..."
    
    cat > "/etc/logrotate.d/$SERVICE_NAME" << EOF
$LOG_DIR/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 $SERVICE_USER $SERVICE_USER
    postrotate
        systemctl reload $SERVICE_NAME 2>/dev/null || true
    endscript
}
EOF
    
    log_success "Log rotation configured"
}

# Start services
start_services() {
    if [ "$NO_SERVICE" = true ]; then
        log "Service installation skipped - manual start required"
        return
    fi
    
    log "Starting services..."
    
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

# Create backup
create_backup() {
    if [ "$BACKUP" != true ]; then
        return
    fi
    
    log "Creating backup..."
    
    BACKUP_FILE="$BACKUP_DIR/overseerr-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    if [ -d "$DATA_DIR" ]; then
        tar -czf "$BACKUP_FILE" -C "$DATA_DIR" . 2>/dev/null || true
        log_success "Backup created: $BACKUP_FILE"
    else
        log_warning "No existing data to backup"
    fi
}

# Restore from backup
restore_backup() {
    if [ -z "$RESTORE_FILE" ]; then
        return
    fi
    
    log "Restoring from backup: $RESTORE_FILE"
    
    if [ ! -f "$RESTORE_FILE" ]; then
        log_error "Backup file not found: $RESTORE_FILE"
        exit 1
    fi
    
    # Stop service if running
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl stop "$SERVICE_NAME"
    fi
    
    # Clear existing data
    rm -rf "$DATA_DIR"/*
    
    # Extract backup
    tar -xzf "$RESTORE_FILE" -C "$DATA_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    
    log_success "Backup restored"
}

# Uninstall application
uninstall() {
    log "Uninstalling Overseerr Content Filtering..."
    
    # Stop and disable service
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl stop "$SERVICE_NAME"
    fi
    
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME"
    fi
    
    # Remove service file
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    systemctl daemon-reload
    
    # Remove application files
    rm -rf "$INSTALL_DIR"
    rm -rf "$CONFIG_DIR"
    rm -rf "/etc/logrotate.d/$SERVICE_NAME"
    
    # Ask about data removal
    read -p "Remove all data and logs? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DATA_DIR"
        rm -rf "$LOG_DIR"
        rm -rf "$BACKUP_DIR"
        log_success "All data removed"
    else
        log "Data preserved in $DATA_DIR"
    fi
    
    # Ask about user removal
    read -p "Remove system user '$SERVICE_USER'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        userdel "$SERVICE_USER" 2>/dev/null || true
        log_success "System user removed"
    fi
    
    log_success "Uninstallation complete"
}

# Show status
show_status() {
    echo ""
    echo -e "${BLUE}=== Overseerr Content Filtering Status ===${NC}"
    echo ""
    
    # Service status
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${GREEN}Service Status: Running${NC}"
    else
        echo -e "${RED}Service Status: Not Running${NC}"
    fi
    
    # Network status
    if netstat -tuln | grep -q ":$PORT "; then
        echo -e "${GREEN}Network: Listening on port $PORT${NC}"
    else
        echo -e "${RED}Network: Not listening on port $PORT${NC}"
    fi
    
    # URLs
    echo ""
    echo -e "${YELLOW}Access URLs:${NC}"
    echo "  Local: http://localhost:$PORT"
    echo "  Network: http://$(hostname -I | awk '{print $1}'):$PORT"
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
    create_backup
    install_dependencies
    create_user
    create_directories
    download_application
    create_config
    create_service
    configure_firewall
    configure_logrotate
    restore_backup
    start_services
    
    log_success "Installation completed successfully!"
    show_status
}

# Parse command line arguments
UNINSTALL=false
BACKUP=false
RESTORE_FILE=""
NO_SERVICE=false
NO_FIREWALL=false
DEV_VERSION=false
PORT=$DEFAULT_PORT

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --config-dir)
            CONFIG_DIR="$2"
            shift 2
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --user)
            SERVICE_USER="$2"
            shift 2
            ;;
        --no-service)
            NO_SERVICE=true
            shift
            ;;
        --no-firewall)
            NO_FIREWALL=true
            shift
            ;;
        --dev)
            DEV_VERSION=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --backup)
            BACKUP=true
            shift
            ;;
        --restore)
            RESTORE_FILE="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
if [ "$UNINSTALL" = true ]; then
    check_root
    uninstall
else
    main_install
fi
