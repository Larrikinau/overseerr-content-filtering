#!/bin/bash

# Overseerr Content Filtering Diagnostic Script
# This script helps diagnose common issues with Overseerr Content Filtering
# Usage: bash diagnose-overseerr-issues.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Container name to check
CONTAINER_NAME="overseerr-content-filtering"

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

# Check if container exists and is running
check_container_status() {
    log "Checking container status..."
    
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_error "Container '${CONTAINER_NAME}' not found"
        echo "Available containers:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
        return 1
    fi
    
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_success "Container is running"
    else
        log_warning "Container exists but is not running"
        echo "Container status: $(docker ps -a --format '{{.Status}}' --filter name=${CONTAINER_NAME})"
        return 1
    fi
}

# Check container logs for errors
check_container_logs() {
    log "Checking container logs for errors..."
    
    echo "=== Recent Container Logs ==="
    docker logs ${CONTAINER_NAME} --tail 50 2>&1 | tail -20
    echo
    
    # Check for specific error patterns
    if docker logs ${CONTAINER_NAME} 2>&1 | grep -i "error" | tail -5; then
        log_warning "Recent errors found in logs"
    else
        log_success "No recent errors in logs"
    fi
}

# Check database connectivity and integrity
check_database() {
    log "Checking database connectivity and integrity..."
    
    # Check if database file exists
    if docker exec ${CONTAINER_NAME} test -f /app/config/db/db.sqlite3; then
        log_success "Database file exists"
    else
        log_error "Database file not found"
        return 1
    fi
    
    # Check database integrity
    if docker exec ${CONTAINER_NAME} sqlite3 /app/config/db/db.sqlite3 "PRAGMA integrity_check;" | grep -q "ok"; then
        log_success "Database integrity check passed"
    else
        log_error "Database integrity check failed"
        return 1
    fi
    
    # Check if admin user exists
    ADMIN_CHECK=$(docker exec ${CONTAINER_NAME} sqlite3 /app/config/db/db.sqlite3 "SELECT COUNT(*) FROM user WHERE id = 1;" 2>/dev/null)
    if [ "$ADMIN_CHECK" = "1" ]; then
        log_success "Admin user exists"
    else
        log_error "Admin user not found"
    fi
    
    # Check if Plex token exists
    PLEX_TOKEN_CHECK=$(docker exec ${CONTAINER_NAME} sqlite3 /app/config/db/db.sqlite3 "SELECT LENGTH(plexToken) FROM user WHERE id = 1;" 2>/dev/null)
    if [ "$PLEX_TOKEN_CHECK" -gt 0 ] 2>/dev/null; then
        log_success "Plex token is configured"
    else
        log_warning "Plex token not configured or empty"
    fi
}

# Check content filtering migrations
check_content_filtering() {
    log "Checking content filtering migrations..."
    
    # Check if content filtering columns exist
    SCHEMA_CHECK=$(docker exec ${CONTAINER_NAME} sqlite3 /app/config/db/db.sqlite3 ".schema user_settings" 2>/dev/null | grep -E "(maxMovieRating|maxTvRating|tmdbSortingMode)" | wc -l)
    if [ "$SCHEMA_CHECK" -ge 3 ]; then
        log_success "Content filtering columns exist"
    else
        log_warning "Content filtering columns may be missing"
        echo "Current user_settings schema:"
        docker exec ${CONTAINER_NAME} sqlite3 /app/config/db/db.sqlite3 ".schema user_settings" 2>/dev/null | head -10
    fi
}

# Check API connectivity
check_api_connectivity() {
    log "Checking API connectivity..."
    
    # Get container port
    PORT=$(docker inspect ${CONTAINER_NAME} --format='{{range $p, $conf := .NetworkSettings.Ports}}{{if eq $p "5055/tcp"}}{{(index $conf 0).HostPort}}{{end}}{{end}}' 2>/dev/null)
    if [ -z "$PORT" ]; then
        PORT=5055
    fi
    
    # Test API status endpoint
    if curl -s -f "http://localhost:${PORT}/api/v1/status" > /dev/null 2>&1; then
        log_success "API is responding on port ${PORT}"
    else
        log_error "API is not responding on port ${PORT}"
        return 1
    fi
    
    # Test API settings endpoint
    if curl -s -f "http://localhost:${PORT}/api/v1/settings/public" > /dev/null 2>&1; then
        log_success "Public settings API is accessible"
    else
        log_warning "Public settings API is not accessible"
    fi
}

# Check environment variables
check_environment() {
    log "Checking environment variables..."
    
    echo "=== Environment Variables ==="
    docker exec ${CONTAINER_NAME} printenv | grep -E "(NODE_ENV|LOG_LEVEL|TMDB_API_KEY|REGION|LOCALE)" | sort
    echo
    
    # Check for TMDB API key
    if docker exec ${CONTAINER_NAME} printenv | grep -q "TMDB_API_KEY="; then
        log_success "TMDB API key environment variable is set"
    else
        log_warning "TMDB API key environment variable not found"
    fi
    
    # Check Node environment
    NODE_ENV=$(docker exec ${CONTAINER_NAME} printenv NODE_ENV 2>/dev/null || echo "not set")
    if [ "$NODE_ENV" = "production" ]; then
        log_success "NODE_ENV is set to production"
    else
        log_warning "NODE_ENV is '${NODE_ENV}' (should be 'production')"
    fi
}

# Check Plex connectivity
check_plex_connectivity() {
    log "Checking Plex connectivity..."
    
    # Get Plex settings from database
    PLEX_IP=$(docker exec ${CONTAINER_NAME} sqlite3 /app/config/db/db.sqlite3 "SELECT value FROM setting WHERE setting_id = 'plex' LIMIT 1;" 2>/dev/null | jq -r '.ip // "not configured"' 2>/dev/null || echo "not configured")
    PLEX_PORT=$(docker exec ${CONTAINER_NAME} sqlite3 /app/config/db/db.sqlite3 "SELECT value FROM setting WHERE setting_id = 'plex' LIMIT 1;" 2>/dev/null | jq -r '.port // 32400' 2>/dev/null || echo "32400")
    
    if [ "$PLEX_IP" = "not configured" ] || [ "$PLEX_IP" = "null" ]; then
        log_warning "Plex IP not configured in database"
        return 1
    fi
    
    log "Plex server configured at: ${PLEX_IP}:${PLEX_PORT}"
    
    # Test Plex connectivity from container
    if docker exec ${CONTAINER_NAME} curl -s -f "http://${PLEX_IP}:${PLEX_PORT}/web/index.html" > /dev/null 2>&1; then
        log_success "Plex server is reachable from container"
    else
        log_error "Cannot reach Plex server from container"
        return 1
    fi
}

# Check system resources
check_resources() {
    log "Checking system resources..."
    
    # Check container resource usage
    CONTAINER_STATS=$(docker stats ${CONTAINER_NAME} --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "=== Container Resource Usage ==="
        echo "CPU%    MEM USAGE/LIMIT    MEM%"
        echo "$CONTAINER_STATS"
        echo
        log_success "Container resource usage retrieved"
    else
        log_warning "Could not retrieve container resource usage"
    fi
    
    # Check disk usage
    DISK_USAGE=$(docker exec ${CONTAINER_NAME} df -h /app/config 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$DISK_USAGE" ]; then
        log_success "Available disk space: $DISK_USAGE"
    else
        log_warning "Could not check disk usage"
    fi
}

# Check for configuration issues
check_configuration() {
    log "Checking configuration..."
    
    # Check settings.json
    if docker exec ${CONTAINER_NAME} test -f /app/config/settings.json; then
        log_success "settings.json file exists"
        
        # Check TMDB API key in settings
        TMDB_KEY_IN_SETTINGS=$(docker exec ${CONTAINER_NAME} cat /app/config/settings.json 2>/dev/null | jq -r '.main.tmdbApiKey // "not found"' 2>/dev/null || echo "not found")
        if [ "$TMDB_KEY_IN_SETTINGS" != "not found" ] && [ "$TMDB_KEY_IN_SETTINGS" != "null" ] && [ "$TMDB_KEY_IN_SETTINGS" != "db55323b8d3e4154498498a75642b381" ]; then
            log_success "TMDB API key is configured in settings.json"
        else
            log_warning "TMDB API key not properly configured in settings.json"
        fi
        
        # Check region setting
        REGION_SETTING=$(docker exec ${CONTAINER_NAME} cat /app/config/settings.json 2>/dev/null | jq -r '.main.region // "not found"' 2>/dev/null || echo "not found")
        if [ "$REGION_SETTING" != "not found" ] && [ "$REGION_SETTING" != "null" ] && [ "$REGION_SETTING" != "" ]; then
            log_success "Region setting is configured: $REGION_SETTING"
        else
            log_warning "Region setting not configured"
        fi
    else
        log_warning "settings.json file not found"
    fi
}

# Generate report
generate_report() {
    log "Generating diagnostic report..."
    
    REPORT_FILE="/tmp/overseerr-diagnostic-report-$(date +%Y%m%d_%H%M%S).txt"
    
    echo "Overseerr Content Filtering Diagnostic Report" > "$REPORT_FILE"
    echo "Generated: $(date)" >> "$REPORT_FILE"
    echo "Container: ${CONTAINER_NAME}" >> "$REPORT_FILE"
    echo "=========================================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Container info
    echo "=== Container Information ===" >> "$REPORT_FILE"
    docker inspect ${CONTAINER_NAME} --format='Image: {{.Config.Image}}' >> "$REPORT_FILE"
    docker inspect ${CONTAINER_NAME} --format='Created: {{.Created}}' >> "$REPORT_FILE"
    docker inspect ${CONTAINER_NAME} --format='Status: {{.State.Status}}' >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Recent logs
    echo "=== Recent Logs ===" >> "$REPORT_FILE"
    docker logs ${CONTAINER_NAME} --tail 50 >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    
    # Environment
    echo "=== Environment Variables ===" >> "$REPORT_FILE"
    docker exec ${CONTAINER_NAME} printenv >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Database info
    echo "=== Database Information ===" >> "$REPORT_FILE"
    docker exec ${CONTAINER_NAME} sqlite3 /app/config/db/db.sqlite3 ".tables" >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    
    log_success "Diagnostic report saved to: $REPORT_FILE"
}

# Main diagnostic function
main() {
    echo ""
    echo "=================================================="
    echo "   Overseerr Content Filtering Diagnostic Tool   "
    echo "=================================================="
    echo ""
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if jq is available (optional but helpful)
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed - some checks will be limited"
    fi
    
    # Run all checks
    CHECKS_PASSED=0
    TOTAL_CHECKS=0
    
    echo "Running diagnostic checks..."
    echo ""
    
    # Container status
    ((TOTAL_CHECKS++))
    if check_container_status; then
        ((CHECKS_PASSED++))
    fi
    echo ""
    
    # Database checks
    ((TOTAL_CHECKS++))
    if check_database; then
        ((CHECKS_PASSED++))
    fi
    echo ""
    
    # Content filtering checks
    ((TOTAL_CHECKS++))
    if check_content_filtering; then
        ((CHECKS_PASSED++))
    fi
    echo ""
    
    # API connectivity
    ((TOTAL_CHECKS++))
    if check_api_connectivity; then
        ((CHECKS_PASSED++))
    fi
    echo ""
    
    # Environment checks
    ((TOTAL_CHECKS++))
    if check_environment; then
        ((CHECKS_PASSED++))
    fi
    echo ""
    
    # Plex connectivity
    ((TOTAL_CHECKS++))
    if check_plex_connectivity; then
        ((CHECKS_PASSED++))
    fi
    echo ""
    
    # Configuration checks
    ((TOTAL_CHECKS++))
    if check_configuration; then
        ((CHECKS_PASSED++))
    fi
    echo ""
    
    # Resource checks
    check_resources
    echo ""
    
    # Container logs
    check_container_logs
    echo ""
    
    # Generate report
    generate_report
    echo ""
    
    # Summary
    echo "=================================================="
    echo "                    SUMMARY                       "
    echo "=================================================="
    echo "Checks passed: ${CHECKS_PASSED}/${TOTAL_CHECKS}"
    
    if [ $CHECKS_PASSED -eq $TOTAL_CHECKS ]; then
        log_success "All checks passed! Your installation appears to be working correctly."
    elif [ $CHECKS_PASSED -gt $((TOTAL_CHECKS / 2)) ]; then
        log_warning "Most checks passed, but some issues were found. Review the warnings above."
    else
        log_error "Multiple issues found. Please review the errors above and consult the troubleshooting guides."
    fi
    
    echo ""
    echo "Next steps:"
    echo "1. Review the diagnostic output above"
    echo "2. Check the troubleshooting guides: PLEX_SCAN_TROUBLESHOOTING.md and TVDB_CONFIGURATION.md"
    echo "3. If issues persist, provide the diagnostic report when seeking support"
    echo ""
}

# Run main function
main
