#!/bin/bash

# Comprehensive Backup System for TonyBenoy.com
# This script handles full system backups including data, configurations, and logs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

BACKUP_BASE_DIR="${BACKUP_DIR:-/var/backups/tonybenoy}"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/$DATE"

# Retention settings
DAILY_RETENTION=7
WEEKLY_RETENTION=4
MONTHLY_RETENTION=12

# Function to backup application data
backup_application() {
    log "Backing up application data..."

    local app_backup_dir="$BACKUP_DIR/application"
    mkdir -p "$app_backup_dir"

    # Backup application logs
    if docker volume ls | grep -q tonybenoy_app-logs; then
        docker run --rm \
            -v tonybenoy_app-logs:/source:ro \
            -v "$app_backup_dir":/backup \
            alpine tar czf /backup/app-logs.tar.gz -C /source . 2>/dev/null || warn "Could not backup app logs"
    fi

    log "Application backup completed: $(calculate_size "$app_backup_dir")"
}

# Function to backup nginx configuration and logs
backup_nginx() {
    log "Backing up nginx configuration and logs..."

    local nginx_backup_dir="$BACKUP_DIR/nginx"
    mkdir -p "$nginx_backup_dir"

    # Backup nginx configuration
    if [ -d "$PROJECT_DIR/nginx" ]; then
        cp -r "$PROJECT_DIR/nginx" "$nginx_backup_dir/config" || warn "Could not backup nginx config"
    fi

    # Backup nginx logs
    if docker volume ls | grep -q tonybenoy_nginx-logs; then
        docker run --rm \
            -v tonybenoy_nginx-logs:/source:ro \
            -v "$nginx_backup_dir":/backup \
            alpine tar czf /backup/nginx-logs.tar.gz -C /source . 2>/dev/null || warn "Could not backup nginx logs"
    fi

    log "Nginx backup completed: $(calculate_size "$nginx_backup_dir")"
}

# Function to backup SSL certificates
backup_ssl() {
    log "Backing up SSL certificates..."

    local ssl_backup_dir="$BACKUP_DIR/ssl"
    mkdir -p "$ssl_backup_dir"

    if docker volume ls | grep -q tonybenoy_certbot-conf; then
        docker run --rm \
            -v tonybenoy_certbot-conf:/source:ro \
            -v "$ssl_backup_dir":/backup \
            alpine tar czf /backup/letsencrypt.tar.gz -C /source . 2>/dev/null || warn "Could not backup SSL certificates"

        if docker volume ls | grep -q tonybenoy_certbot-www; then
            docker run --rm \
                -v tonybenoy_certbot-www:/source:ro \
                -v "$ssl_backup_dir":/backup \
                alpine tar czf /backup/certbot-www.tar.gz -C /source . 2>/dev/null || warn "Could not backup certbot www"
        fi
    fi

    log "SSL backup completed: $(calculate_size "$ssl_backup_dir")"
}

# Function to backup project configuration
backup_config() {
    log "Backing up project configuration..."

    local config_backup_dir="$BACKUP_DIR/config"
    mkdir -p "$config_backup_dir"

    cd "$PROJECT_DIR"

    # Backup essential configuration files
    for file in docker-compose.yml .env .env.example; do
        if [ -f "$file" ]; then
            cp "$file" "$config_backup_dir/" || warn "Could not backup $file"
        fi
    done

    # Backup scripts directory
    if [ -d "scripts" ]; then
        cp -r scripts "$config_backup_dir/" || warn "Could not backup scripts"
    fi

    # Backup source code (without caches)
    if [ -d "app" ]; then
        tar czf "$config_backup_dir/source-code.tar.gz" \
            --exclude="app/__pycache__" \
            --exclude="app/.venv" \
            --exclude="app/node_modules" \
            --exclude="app/*.pyc" \
            --exclude="app/.pytest_cache" \
            app/ 2>/dev/null || warn "Could not backup source code"
    fi

    # Create system info snapshot
    {
        echo "=== Backup Information ==="
        echo "Date: $(date)"
        echo "Host: $(hostname)"
        echo "User: $(whoami)"
        echo "Project Directory: $PROJECT_DIR"
        echo ""
        echo "=== Docker Information ==="
        docker version 2>/dev/null || echo "Docker not available"
        echo ""
        echo "=== Container Status ==="
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || echo "No containers"
        echo ""
        echo "=== Volume Information ==="
        docker volume ls --format "table {{.Name}}\t{{.Driver}}" 2>/dev/null || echo "No volumes"
        echo ""
        echo "=== System Information ==="
        uname -a
        df -h
        free -h
    } > "$config_backup_dir/system-info.txt"

    log "Configuration backup completed: $(calculate_size "$config_backup_dir")"
}

# Function to create backup manifest
create_manifest() {
    log "Creating backup manifest..."

    local manifest_file="$BACKUP_DIR/MANIFEST.txt"

    {
        echo "=== TonyBenoy.com Backup Manifest ==="
        echo "Backup Date: $(date)"
        echo "Backup Directory: $BACKUP_DIR"
        echo "Backup Type: ${BACKUP_TYPE:-full}"
        echo ""
        echo "=== Backup Contents ==="

        find "$BACKUP_DIR" -type f -exec ls -lh {} \; | \
            awk '{print $9 ": " $5}' | \
            sed "s|$BACKUP_DIR/||g" | \
            sort

        echo ""
        echo "=== Total Backup Size ==="
        du -sh "$BACKUP_DIR" | cut -f1

        echo ""
        echo "=== Backup Verification ==="
        echo "Application logs: $([ -f "$BACKUP_DIR/application/app-logs.tar.gz" ] && echo "Y" || echo "N")"
        echo "Nginx config: $([ -d "$BACKUP_DIR/nginx/config" ] && echo "Y" || echo "N")"
        echo "SSL certificates: $([ -f "$BACKUP_DIR/ssl/letsencrypt.tar.gz" ] && echo "Y" || echo "N")"
        echo "Source code: $([ -f "$BACKUP_DIR/config/source-code.tar.gz" ] && echo "Y" || echo "N")"

        echo ""
        echo "=== Restore Instructions ==="
        echo "To restore from this backup:"
        echo "1. Stop all services: docker-compose down"
        echo "2. Run restore script: ./scripts/restore.sh $DATE"
        echo "3. Start services: docker-compose up -d"

    } > "$manifest_file"

    log "Manifest created: $manifest_file"
}

# Function to cleanup old backups based on retention policy
cleanup_old_backups() {
    log "Cleaning up old backups..."

    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        warn "Backup directory $BACKUP_BASE_DIR does not exist"
        return
    fi

    cd "$BACKUP_BASE_DIR"

    # Clean up daily backups (keep last N days)
    log "Cleaning daily backups (keeping $DAILY_RETENTION days)..."
    find . -maxdepth 1 -type d -name "????????-*" | sort -r | tail -n +$((DAILY_RETENTION + 1)) | while read -r backup_dir; do
        local backup_date
        backup_date=$(basename "$backup_dir" | cut -d- -f1)
        local days_old
        days_old=$(( ($(date +%s) - $(date -d "$backup_date" +%s 2>/dev/null || echo 0)) / 86400 ))

        if [ "$days_old" -gt "$DAILY_RETENTION" ]; then
            local backup_dow
            backup_dow=$(date -d "$backup_date" +%u 2>/dev/null || echo 0)

            # Keep weekly backups (Sunday)
            if [ "$backup_dow" -eq 7 ] && [ "$days_old" -le $((WEEKLY_RETENTION * 7)) ]; then
                log "Keeping weekly backup: $backup_dir"
                continue
            fi

            # Keep monthly backups (first Sunday of month)
            local backup_day
            backup_day=$(date -d "$backup_date" +%d 2>/dev/null || echo 0)
            if [ "$backup_dow" -eq 7 ] && [ "$backup_day" -le 7 ] && [ "$days_old" -le $((MONTHLY_RETENTION * 30)) ]; then
                log "Keeping monthly backup: $backup_dir"
                continue
            fi

            log "Removing old backup: $backup_dir ($days_old days old)"
            rm -rf "$backup_dir"
        fi
    done

    local total_backups
    total_backups=$(find . -maxdepth 1 -type d -name "????????-*" | wc -l)
    local total_size
    total_size=$(du -sh . 2>/dev/null | cut -f1)

    log "Backup cleanup completed. Current status: $total_backups backups, $total_size total"
}

# Function to verify backup integrity
verify_backup() {
    log "Verifying backup integrity..."

    local errors=0

    if [ ! -f "$BACKUP_DIR/MANIFEST.txt" ]; then
        error "Backup manifest missing"
        ((errors++)) || true
    fi

    # Use process substitution to avoid subshell variable scope issue
    while read -r archive; do
        if ! tar -tzf "$archive" >/dev/null 2>&1; then
            error "Corrupted archive: $archive"
            ((errors++)) || true
        fi
    done < <(find "$BACKUP_DIR" -name "*.tar.gz" -type f)

    if [ "$errors" -eq 0 ]; then
        log "Backup verification completed successfully"
        return 0
    else
        error "Backup verification failed with $errors errors"
        return 1
    fi
}

# Main backup function
perform_backup() {
    local backup_type="${1:-full}"

    log "Starting $backup_type backup to $BACKUP_DIR..."

    mkdir -p "$BACKUP_DIR"

    export BACKUP_TYPE="$backup_type"

    case "$backup_type" in
        "full")
            backup_application
            backup_nginx
            backup_ssl
            backup_config
            ;;
        "data")
            backup_application
            ;;
        "config")
            backup_nginx
            backup_ssl
            backup_config
            ;;
        *)
            error "Unknown backup type: $backup_type"
            exit 1
            ;;
    esac

    create_manifest
    verify_backup

    local backup_size
    backup_size=$(calculate_size "$BACKUP_DIR")

    log "Backup completed successfully!"
    info "Backup location: $BACKUP_DIR"
    info "Backup size: $backup_size"

    cleanup_old_backups

    return 0
}

# Function to list available backups
list_backups() {
    log "Available backups in $BACKUP_BASE_DIR:"

    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        warn "No backup directory found"
        return
    fi

    echo ""
    printf "%-20s %-10s %-15s %s\n" "DATE" "SIZE" "TYPE" "LOCATION"
    printf "%-20s %-10s %-15s %s\n" "----" "----" "----" "--------"

    find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "????????-*" | sort -r | while read -r backup_dir; do
        local backup_date
        backup_date=$(basename "$backup_dir")
        local backup_size
        backup_size=$(calculate_size "$backup_dir")
        local backup_type="unknown"

        if [ -f "$backup_dir/MANIFEST.txt" ]; then
            backup_type=$(grep "Backup Type:" "$backup_dir/MANIFEST.txt" | cut -d: -f2 | xargs || echo "unknown")
        fi

        printf "%-20s %-10s %-15s %s\n" "$backup_date" "$backup_size" "$backup_type" "$backup_dir"
    done

    echo ""
    local total_backups
    total_backups=$(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "????????-*" | wc -l)
    local total_size
    total_size=$(calculate_size "$BACKUP_BASE_DIR")
    echo "Total: $total_backups backups, $total_size"
}

# Handle script arguments
case "${1:-full}" in
    "full"|"data"|"config")
        perform_backup "$1"
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    "list")
        list_backups
        ;;
    "verify")
        if [ -n "${2:-}" ]; then
            BACKUP_DIR="$BACKUP_BASE_DIR/$2"
            if [ -d "$BACKUP_DIR" ]; then
                verify_backup
            else
                error "Backup directory not found: $BACKUP_DIR"
                exit 1
            fi
        else
            error "Please specify backup date for verification"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 [full|data|config|cleanup|list|verify <date>]"
        echo ""
        echo "Backup types:"
        echo "  full   - Complete backup (default)"
        echo "  data   - Data only (application logs)"
        echo "  config - Configuration only (nginx, SSL, source code)"
        echo ""
        echo "Other commands:"
        echo "  cleanup - Remove old backups per retention policy"
        echo "  list    - List all available backups"
        echo "  verify  - Verify backup integrity"
        echo ""
        echo "Environment variables:"
        echo "  BACKUP_DIR - Base backup directory (default: /var/backups/tonybenoy)"
        exit 1
        ;;
esac
