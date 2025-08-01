#!/bin/bash

# Log Rotation and Cleanup Script
# This script manages log files for all services with proper rotation and archival

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_BACKUP_DIR="/var/backups/tonybenoy-logs"
RETENTION_DAYS=30
ARCHIVE_RETENTION_DAYS=90

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Ensure backup directory exists
mkdir -p "$LOG_BACKUP_DIR"

# Function to rotate a log file
rotate_log() {
    local log_file="$1"
    local max_size_mb="${2:-100}"  # Default 100MB
    local keep_files="${3:-7}"     # Keep 7 rotated files
    
    if [ ! -f "$log_file" ]; then
        return 0
    fi
    
    local file_size_mb=$(du -m "$log_file" | cut -f1)
    local base_name=$(basename "$log_file")
    local dir_name=$(dirname "$log_file")
    
    if [ "$file_size_mb" -gt "$max_size_mb" ]; then
        log "Rotating $log_file (${file_size_mb}MB > ${max_size_mb}MB)"
        
        # Create backup before rotation
        local backup_file="$LOG_BACKUP_DIR/${base_name}.$(date +%Y%m%d-%H%M%S).gz"
        gzip -c "$log_file" > "$backup_file"
        log "Backup created: $backup_file"
        
        # Rotate existing numbered files
        for i in $(seq $((keep_files - 1)) -1 1); do
            if [ -f "${log_file}.$i" ]; then
                mv "${log_file}.$i" "${log_file}.$((i + 1))"
            fi
        done
        
        # Move current log to .1
        if [ -f "$log_file" ]; then
            mv "$log_file" "${log_file}.1"
        fi
        
        # Create new empty log file with correct permissions
        touch "$log_file"
        chmod 644 "$log_file"
        
        # Remove old rotated files
        find "$dir_name" -name "${base_name}.*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        
        log "Log rotation completed for $log_file"
    fi
}

# Function to rotate Docker container logs
rotate_docker_logs() {
    log "Rotating Docker container logs..."
    
    # Get all running containers
    local containers=$(docker ps --format "{{.Names}}" 2>/dev/null || echo "")
    
    for container in $containers; do
        if docker inspect "$container" >/dev/null 2>&1; then
            local log_path=$(docker inspect "$container" --format='{{.LogPath}}' 2>/dev/null || echo "")
            
            if [ -n "$log_path" ] && [ -f "$log_path" ]; then
                log "Processing Docker log for container: $container"
                
                # Check log size
                local size_mb=$(du -m "$log_path" 2>/dev/null | cut -f1 || echo "0")
                
                if [ "$size_mb" -gt 100 ]; then
                    log "Docker log for $container is ${size_mb}MB, creating backup..."
                    
                    # Create compressed backup
                    local backup_file="$LOG_BACKUP_DIR/docker-${container}.$(date +%Y%m%d-%H%M%S).json.gz"
                    docker logs "$container" | gzip > "$backup_file" 2>/dev/null || warn "Could not backup logs for $container"
                    
                    # Truncate the log file (requires stopping and starting container)
                    # Note: This is aggressive - consider using Docker's built-in log rotation instead
                    warn "Docker log for $container is large (${size_mb}MB). Consider configuring Docker log rotation."
                fi
            fi
        fi
    done
}

# Function to rotate application logs
rotate_app_logs() {
    log "Rotating application logs..."
    
    # Application logs in Docker volumes
    if docker volume ls | grep -q "tonybenoy.*app-logs"; then
        # Use a temporary container to access the volume
        docker run --rm \
            -v tonybenoy_app-logs:/logs:ro \
            -v "$LOG_BACKUP_DIR":/backup \
            alpine sh -c '
                find /logs -name "*.log" -type f -size +100M -exec sh -c '"'"'
                    echo "Backing up large log file: $1"
                    gzip -c "$1" > "/backup/app-$(basename "$1").$(date +%Y%m%d-%H%M%S).gz"
                    > "$1"  # Truncate the file
                '"'"' _ {} \;
            ' 2>/dev/null || warn "Could not rotate application logs"
    fi
    
    # Nginx logs
    if docker volume ls | grep -q "tonybenoy.*nginx-logs"; then
        docker run --rm \
            -v tonybenoy_nginx-logs:/logs \
            -v "$LOG_BACKUP_DIR":/backup \
            alpine sh -c '
                for log_file in /logs/*.log; do
                    if [ -f "$log_file" ]; then
                        size_kb=$(du -k "$log_file" | cut -f1)
                        if [ "$size_kb" -gt 102400 ]; then  # 100MB
                            echo "Rotating nginx log: $log_file"
                            gzip -c "$log_file" > "/backup/nginx-$(basename "$log_file").$(date +%Y%m%d-%H%M%S).gz"
                            > "$log_file"  # Truncate
                            
                            # Send USR1 signal to nginx to reopen log files
                            if pgrep nginx >/dev/null 2>&1; then
                                kill -USR1 $(pgrep nginx) 2>/dev/null || true
                            fi
                        fi
                    fi
                done
            ' 2>/dev/null || warn "Could not rotate nginx logs"
    fi
}

# Function to clean up old backups
cleanup_old_backups() {
    log "Cleaning up old log backups..."
    
    # Remove backups older than retention period
    find "$LOG_BACKUP_DIR" -name "*.gz" -type f -mtime +$ARCHIVE_RETENTION_DAYS -delete 2>/dev/null || true
    
    # Log current backup status
    local backup_count=$(find "$LOG_BACKUP_DIR" -name "*.gz" -type f | wc -l)
    local backup_size=$(du -sh "$LOG_BACKUP_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    
    log "Log backup status: $backup_count files, $backup_size total"
}

# Function to generate log rotation report
generate_report() {
    local report_file="/var/log/log-rotation-report.log"
    
    {
        echo "=== Log Rotation Report - $(date) ==="
        echo "Retention Policy: $RETENTION_DAYS days (logs), $ARCHIVE_RETENTION_DAYS days (archives)"
        echo "Backup Location: $LOG_BACKUP_DIR"
        echo ""
        
        echo "=== Backup Summary ==="
        if [ -d "$LOG_BACKUP_DIR" ]; then
            find "$LOG_BACKUP_DIR" -name "*.gz" -type f -printf "%TY-%Tm-%Td %TH:%TM %s %f\n" | \
                sort -r | head -20
        else
            echo "No backups found"
        fi
        echo ""
        
        echo "=== Current Log Sizes ==="
        # Check Docker volumes
        if docker volume ls | grep -q "tonybenoy"; then
            docker run --rm \
                -v tonybenoy_nginx-logs:/nginx-logs:ro \
                -v tonybenoy_app-logs:/app-logs:ro \
                alpine sh -c '
                    echo "Nginx logs:"
                    find /nginx-logs -name "*.log" -type f -exec ls -lh {} \; 2>/dev/null | awk "{print \$9 \": \" \$5}" || echo "No nginx logs"
                    echo "Application logs:"
                    find /app-logs -name "*.log" -type f -exec ls -lh {} \; 2>/dev/null | awk "{print \$9 \": \" \$5}" || echo "No app logs"
                ' 2>/dev/null || echo "Could not check volume logs"
        fi
        
        echo ""
        echo "=== Disk Usage ==="
        df -h | head -1
        df -h | grep -E '(/$|/var)'
        
        echo ""
        echo "=== Next Rotation Due ==="
        echo "Log rotation runs daily. Large logs (>100MB) are rotated immediately."
        echo "=== End Report ==="
        echo ""
        
    } >> "$report_file"
    
    # Keep only last 30 reports
    if [ -f "$report_file" ]; then
        tail -n 1000 "$report_file" > "${report_file}.tmp" && mv "${report_file}.tmp" "$report_file"
    fi
    
    log "Report generated: $report_file"
}

# Main execution
main() {
    log "Starting log rotation and cleanup..."
    
    # Create required directories
    mkdir -p "$LOG_BACKUP_DIR"
    
    # Rotate different types of logs
    rotate_docker_logs
    rotate_app_logs
    
    # Rotate system logs if they exist
    for log_file in /var/log/tonybenoy*.log; do
        if [ -f "$log_file" ]; then
            rotate_log "$log_file" 50 5  # 50MB max, keep 5 files
        fi
    done
    
    # Clean up old backups
    cleanup_old_backups
    
    # Generate report
    generate_report
    
    log "Log rotation and cleanup completed successfully"
    
    # Display summary
    echo ""
    echo "=== Summary ==="
    echo "Backup directory: $LOG_BACKUP_DIR"
    echo "Retention: $RETENTION_DAYS days (active logs), $ARCHIVE_RETENTION_DAYS days (archives)"
    echo "Total backups: $(find "$LOG_BACKUP_DIR" -name "*.gz" -type f | wc -l)"
    echo "Backup size: $(du -sh "$LOG_BACKUP_DIR" 2>/dev/null | cut -f1)"
}

# Handle script arguments
case "${1:-rotate}" in
    "rotate")
        main
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    "report")
        generate_report
        ;;
    "status")
        log "Log rotation status:"
        echo "Backup directory: $LOG_BACKUP_DIR"
        if [ -d "$LOG_BACKUP_DIR" ]; then
            echo "Total backups: $(find "$LOG_BACKUP_DIR" -name "*.gz" -type f | wc -l)"
            echo "Backup size: $(du -sh "$LOG_BACKUP_DIR" 2>/dev/null | cut -f1)"
            echo "Latest backups:"
            find "$LOG_BACKUP_DIR" -name "*.gz" -type f -printf "%TY-%Tm-%Td %TH:%TM %f\n" | sort -r | head -5
        else
            echo "No backup directory found"
        fi
        ;;
    *)
        echo "Usage: $0 [rotate|cleanup|report|status]"
        echo "  rotate  - Rotate logs and create backups (default)"
        echo "  cleanup - Clean up old backups only"
        echo "  report  - Generate rotation report"
        echo "  status  - Show current backup status"
        exit 1
        ;;
esac