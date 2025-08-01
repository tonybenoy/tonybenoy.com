#!/bin/bash

# Restore Script for TonyBenoy.com
# This script restores from backups created by backup.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_BASE_DIR="${BACKUP_DIR:-/var/backups/tonybenoy}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Function to show backup manifest
show_manifest() {
    local backup_date="$1"
    local backup_dir="$BACKUP_BASE_DIR/$backup_date"
    
    if [ ! -f "$backup_dir/MANIFEST.txt" ]; then
        error "Backup manifest not found: $backup_dir/MANIFEST.txt"
        return 1
    fi
    
    echo ""
    cat "$backup_dir/MANIFEST.txt"
    echo ""
}

# Function to restore Redis data
restore_redis() {
    local backup_dir="$1"
    
    log "Restoring Redis data..."
    
    if [ ! -d "$backup_dir/redis" ]; then
        warn "No Redis backup found, skipping"
        return
    fi
    
    # Stop Redis container if running
    if docker ps | grep -q tonybenoy-redis; then
        log "Stopping Redis container..."
        docker stop tonybenoy-redis || warn "Could not stop Redis container"
    fi
    
    # Restore Redis volume
    if [ -f "$backup_dir/redis/redis-volume.tar.gz" ]; then
        log "Restoring Redis volume..."
        docker run --rm \
            -v tonybenoy_redis-data:/target \
            -v "$backup_dir/redis":/backup \
            alpine sh -c "cd /target && rm -rf * && tar xzf /backup/redis-volume.tar.gz" || warn "Could not restore Redis volume"
    fi
    
    # Restore RDB file if available
    if [ -f "$backup_dir/redis/dump.rdb" ]; then
        log "Restoring Redis RDB file..."
        docker run --rm \
            -v tonybenoy_redis-data:/target \
            -v "$backup_dir/redis":/backup \
            alpine cp /backup/dump.rdb /target/dump.rdb || warn "Could not restore RDB file"
    fi
    
    log "Redis data restoration completed"
}

# Function to restore application data
restore_application() {
    local backup_dir="$1"
    
    log "Restoring application data..."
    
    if [ ! -d "$backup_dir/application" ]; then
        warn "No application backup found, skipping"
        return
    fi
    
    # Restore application logs
    if [ -f "$backup_dir/application/app-logs.tar.gz" ]; then
        log "Restoring application logs..."
        docker run --rm \
            -v tonybenoy_app-logs:/target \
            -v "$backup_dir/application":/backup \
            alpine sh -c "cd /target && rm -rf * && tar xzf /backup/app-logs.tar.gz" || warn "Could not restore app logs"
    fi
    
    # Restore container image if available
    if [ -f "$backup_dir/application/app-container.tar.gz" ]; then
        log "Restoring application container image..."
        gunzip -c "$backup_dir/application/app-container.tar.gz" | docker load || warn "Could not restore container image"
    fi
    
    log "Application data restoration completed"
}

# Function to restore nginx configuration and logs
restore_nginx() {
    local backup_dir="$1"
    
    log "Restoring nginx configuration and logs..."
    
    if [ ! -d "$backup_dir/nginx" ]; then
        warn "No nginx backup found, skipping"
        return
    fi
    
    # Restore nginx configuration
    if [ -d "$backup_dir/nginx/config" ]; then
        log "Restoring nginx configuration..."
        if [ -d "$PROJECT_DIR/nginx" ]; then
            cp -r "$PROJECT_DIR/nginx" "$PROJECT_DIR/nginx.backup.$(date +%Y%m%d-%H%M%S)" || warn "Could not backup current nginx config"
        fi
        cp -r "$backup_dir/nginx/config" "$PROJECT_DIR/nginx" || warn "Could not restore nginx config"
    fi
    
    # Restore nginx logs
    if [ -f "$backup_dir/nginx/nginx-logs.tar.gz" ]; then
        log "Restoring nginx logs..."
        docker run --rm \
            -v tonybenoy_nginx-logs:/target \
            -v "$backup_dir/nginx":/backup \
            alpine sh -c "cd /target && rm -rf * && tar xzf /backup/nginx-logs.tar.gz" || warn "Could not restore nginx logs"
    fi
    
    log "Nginx restoration completed"
}

# Function to restore SSL certificates
restore_ssl() {
    local backup_dir="$1"
    
    log "Restoring SSL certificates..."
    
    if [ ! -d "$backup_dir/ssl" ]; then
        warn "No SSL backup found, skipping"
        return
    fi
    
    # Restore Let's Encrypt certificates
    if [ -f "$backup_dir/ssl/letsencrypt.tar.gz" ]; then
        log "Restoring Let's Encrypt certificates..."
        docker run --rm \
            -v tonybenoy_certbot-conf:/target \
            -v "$backup_dir/ssl":/backup \
            alpine sh -c "cd /target && rm -rf * && tar xzf /backup/letsencrypt.tar.gz" || warn "Could not restore SSL certificates"
    fi
    
    # Restore certbot www directory
    if [ -f "$backup_dir/ssl/certbot-www.tar.gz" ]; then
        log "Restoring certbot www directory..."
        docker run --rm \
            -v tonybenoy_certbot-www:/target \
            -v "$backup_dir/ssl":/backup \
            alpine sh -c "cd /target && rm -rf * && tar xzf /backup/certbot-www.tar.gz" || warn "Could not restore certbot www"
    fi
    
    log "SSL restoration completed"
}

# Function to restore project configuration
restore_config() {
    local backup_dir="$1"
    
    log "Restoring project configuration..."
    
    if [ ! -d "$backup_dir/config" ]; then
        warn "No configuration backup found, skipping"
        return
    fi
    
    cd "$PROJECT_DIR"
    
    # Backup current configuration
    local current_backup_dir="config.backup.$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$current_backup_dir"
    
    # Restore configuration files
    for file in docker-compose.yml .env .env.example; do
        if [ -f "$backup_dir/config/$file" ]; then
            if [ -f "$file" ]; then
                cp "$file" "$current_backup_dir/" || warn "Could not backup current $file"
            fi
            cp "$backup_dir/config/$file" . || warn "Could not restore $file"
            log "Restored: $file"
        fi
    done
    
    # Restore scripts directory
    if [ -d "$backup_dir/config/scripts" ]; then
        if [ -d "scripts" ]; then
            cp -r scripts "$current_backup_dir/" || warn "Could not backup current scripts"
        fi
        cp -r "$backup_dir/config/scripts" . || warn "Could not restore scripts"
        chmod +x scripts/*.sh 2>/dev/null || warn "Could not set script permissions"
        log "Restored: scripts directory"
    fi
    
    # Restore source code
    if [ -f "$backup_dir/config/source-code.tar.gz" ]; then
        log "Restoring source code..."
        if [ -d "src" ]; then
            tar czf "$current_backup_dir/src.tar.gz" src/ || warn "Could not backup current source"
        fi
        tar xzf "$backup_dir/config/source-code.tar.gz" || warn "Could not restore source code"
        log "Restored: source code"
    fi
    
    log "Configuration restoration completed"
    info "Current configuration backed up to: $current_backup_dir"
}

# Function to verify restoration
verify_restore() {
    local backup_dir="$1"
    
    log "Verifying restoration..."
    
    local issues=0
    
    # Check if volumes were restored
    if [ -f "$backup_dir/redis/redis-volume.tar.gz" ]; then
        if ! docker volume ls | grep -q tonybenoy_redis-data; then
            warn "Redis data volume not found"
            ((issues++))
        fi
    fi
    
    if [ -f "$backup_dir/application/app-logs.tar.gz" ]; then
        if ! docker volume ls | grep -q tonybenoy_app-logs; then
            warn "Application logs volume not found"
            ((issues++))
        fi
    fi
    
    # Check configuration files
    cd "$PROJECT_DIR"
    for file in docker-compose.yml; do
        if [ ! -f "$file" ]; then
            warn "Configuration file missing: $file"
            ((issues++))
        fi
    done
    
    if [ "$issues" -eq 0 ]; then
        log "Restoration verification completed successfully"
        return 0
    else
        warn "Restoration verification found $issues issues"
        return 1
    fi
}

# Function to perform full restore
perform_restore() {
    local backup_date="$1"
    local restore_type="${2:-full}"
    local backup_dir="$BACKUP_BASE_DIR/$backup_date"
    
    if [ ! -d "$backup_dir" ]; then
        error "Backup directory not found: $backup_dir"
        exit 1
    fi
    
    log "Starting $restore_type restore from backup: $backup_date"
    
    # Show backup manifest
    show_manifest "$backup_date"
    
    # Confirm restoration
    if [ "${FORCE:-false}" != "true" ]; then
        echo -n "Continue with restoration? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[yY]$ ]]; then
            log "Restoration cancelled by user"
            exit 0
        fi
    fi
    
    # Stop all services before restoration
    log "Stopping all services..."
    cd "$PROJECT_DIR"
    docker-compose down || warn "Could not stop services"
    
    # Perform restoration based on type
    case "$restore_type" in
        "full")
            restore_redis "$backup_dir"
            restore_application "$backup_dir"
            restore_nginx "$backup_dir"
            restore_ssl "$backup_dir"
            restore_config "$backup_dir"
            ;;
        "data")
            restore_redis "$backup_dir"
            restore_application "$backup_dir"
            ;;
        "config")
            restore_nginx "$backup_dir"
            restore_ssl "$backup_dir"
            restore_config "$backup_dir"
            ;;
        *)
            error "Unknown restore type: $restore_type"
            exit 1
            ;;
    esac
    
    # Verify restoration
    verify_restore "$backup_dir"
    
    log "Restoration completed successfully!"
    
    # Ask to start services
    if [ "${AUTO_START:-false}" = "true" ]; then
        log "Starting services..."
        docker-compose up -d
    else
        echo -n "Start services now? (Y/n): "
        read -r response
        if [[ ! "$response" =~ ^[nN]$ ]]; then
            log "Starting services..."
            docker-compose up -d
            
            # Wait for services to be ready
            sleep 10
            
            # Basic health check
            if curl -f -s -o /dev/null "http://localhost:8000/health" 2>/dev/null; then
                log "Services started successfully and health check passed"
            else
                warn "Services started but health check failed"
            fi
        fi
    fi
    
    echo ""
    echo "=== Restoration Summary ==="
    echo "Backup date: $backup_date"
    echo "Restore type: $restore_type"
    echo "Backup location: $backup_dir"
    echo "Project directory: $PROJECT_DIR"
    
    echo ""
    echo "Next steps:"
    echo "1. Verify all services are running: docker-compose ps"
    echo "2. Check application health: curl http://localhost:8000/health"
    echo "3. Test website access: curl http://localhost/test"
    echo "4. Monitor logs: docker-compose logs -f"
}

# Handle script arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_date> [restore_type]"
    echo ""
    echo "Available backups:"
    "$SCRIPT_DIR/backup.sh" list
    exit 1
fi

backup_date="$1"
restore_type="${2:-full}"

case "$restore_type" in
    "full"|"data"|"config")
        perform_restore "$backup_date" "$restore_type"
        ;;
    "show"|"manifest")
        show_manifest "$backup_date"
        ;;
    *)
        error "Unknown restore type: $restore_type"
        echo ""
        echo "Usage: $0 <backup_date> [full|data|config|show]"
        echo ""
        echo "Restore types:"
        echo "  full   - Complete restore (default)"
        echo "  data   - Data only (Redis, application logs)"
        echo "  config - Configuration only (nginx, SSL, source code)"
        echo "  show   - Show backup manifest only"
        echo ""
        echo "Environment variables:"
        echo "  FORCE=true      - Skip confirmation prompts"
        echo "  AUTO_START=true - Automatically start services after restore"
        echo "  BACKUP_DIR      - Base backup directory (default: /var/backups/tonybenoy)"
        exit 1
        ;;
esac