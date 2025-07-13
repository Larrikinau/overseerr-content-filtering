#!/bin/bash

# Overseerr Content Filtering - Database Upgrade Script for Previous Fork Versions
# This script upgrades existing installations to version v1.1.5, handling any database migration requirements.
# WARNING: Make sure you have a backup of your database before running this script.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="overseerr-content-filtering"
INSTALL_DIR="/opt/overseerr-content-filtering"
DATA_DIR="/var/lib/overseerr-content-filtering"
DB_PATH="$DATA_DIR/db/settings.db"

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

# Verify backup
verify_backup() {
    log "Checking for database backup..."
    
    if [ ! -f "$DB_PATH.bak" ]; then
        log_warning "No backup found at $DB_PATH.bak. It's highly recommended to back up your database first."
    else
        log_success "Backup found at $DB_PATH.bak."
    fi
}

# Perform database migration
migrate_database() {
    log "Starting database migration..."
    
    sqlite3 "$DB_PATH" "BEGIN TRANSACTION;"

    # Add new tables/columns if not exist
    sqlite3 "$DB_PATH" "PRAGMA foreign_keys=off;"

    # Example migration step: Adding user discovery settings table
    sqlite3 "$DB_PATH" "CREATE TABLE IF NOT EXISTS user_discovery_settings (
        user_id INTEGER PRIMARY KEY,
        discovery_mode TEXT DEFAULT 'standard',
        custom_min_votes INTEGER DEFAULT NULL,
        custom_min_rating REAL DEFAULT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );"

    # Example migration step: Adding new fields to settings table
    sqlite3 "$DB_PATH" "ALTER TABLE settings ADD COLUMN curated_discovery_enabled BOOLEAN DEFAULT 0;" || { log_warning "Column 'curated_discovery_enabled' already exists."; }
    sqlite3 "$DB_PATH" "ALTER TABLE settings ADD COLUMN default_discovery_mode TEXT DEFAULT 'standard';" || { log_warning "Column 'default_discovery_mode' already exists."; }
    
    sqlite3 "$DB_PATH" "ALTER TABLE settings ADD COLUMN movie_min_votes INTEGER DEFAULT 3000;" || { log_warning "Column 'movie_min_votes' already exists."; }
    sqlite3 "$DB_PATH" "ALTER TABLE settings ADD COLUMN movie_min_rating REAL DEFAULT 6.0;" || { log_warning "Column 'movie_min_rating' already exists."; }
    sqlite3 "$DB_PATH" "ALTER TABLE settings ADD COLUMN tv_min_votes INTEGER DEFAULT 1500;" || { log_warning "Column 'tv_min_votes' already exists."; }
    sqlite3 "$DB_PATH" "ALTER TABLE settings ADD COLUMN tv_min_rating REAL DEFAULT 6.5;" || { log_warning "Column 'tv_min_rating' already exists."; }

    # Example migration step: Setting defaults for existing installations
    sqlite3 "$DB_PATH" "UPDATE settings SET curated_discovery_enabled = 1 WHERE curated_discovery_enabled IS NULL;"

    # Commit migration
    sqlite3 "$DB_PATH" "PRAGMA foreign_keys=on;"
    sqlite3 "$DB_PATH" "COMMIT;"

    log_success "Database migration completed."
}

# Restart service
restart_service() {
    log "Restarting Overseerr Content Filtering service..."
    
    systemctl restart "$SERVICE_NAME"
    log_success "Service restarted successfully."
}

show_status() {
    log "Upgrade process completed. Enjoy the new TMDB Curated Discovery features!"
}

# Main upgrade function
main_upgrade() {
    log "Starting Overseerr Content Filtering upgrade..."
    
    check_root
    verify_backup
    migrate_database
    restart_service
    
    log_success "Upgrade to v1.1.5 completed successfully!"
    show_status
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Main execution
main_upgrade
