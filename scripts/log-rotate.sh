#!/bin/bash

# Log Rotation and Cleanup Script
# This script manages log files for all services with proper rotation and archival

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

LOG_BACKUP_DIR="${LOG_BACKUP_DIR:-$PROJECT_DIR/log-backups}"
RETENTION_DAYS=30
ARCHIVE_RETENTION_DAYS=90

mkdir -p "$LOG_BACKUP_DIR"

# Function to rotate a log file
rotate_log() {
    local log_file="$1"
    local max_size_mb="${2:-100}"
    local keep_files="${3:-7}"

    if [ ! -f "$log_file" ]; then
        return 0
    fi

    local file_size_mb
    file_size_mb=$(du -m "$log_file" | cut -f1)
    local base_name
    base_name=$(basename "$log_file")
    local dir_name
    dir_name=$(dirname "$log_file")

    if [ "$file_size_mb" -gt "$max_size_mb" ]; then
        log "Rotating $log_file (${file_size_mb}MB > ${max_size_mb}MB)"

        local backup_file="$LOG_BACKUP_DIR/${base_name}.$(date +%Y%m%d-%H%M%S).gz"
        gzip -c "$log_file" > "$backup_file"
        log "Backup created: $backup_file"

        for i in $(seq $((keep_files - 1)) -1 1); do
            if [ -f "${log_file}.$i" ]; then
                mv "${log_file}.$i" "${log_file}.$((i + 1))"
            fi
        done

        if [ -f "$log_file" ]; then
            mv "$log_file" "${log_file}.1"
        fi

        touch "$log_file"
        chmod 644 "$log_file"

        find "$dir_name" -name "${base_name}.*" -type f -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true

        log "Log rotation completed for $log_file"
    fi
}

# Function to rotate Docker container logs
rotate_docker_logs() {
    log "Checking Docker container log sizes..."

    local containers
    containers=$(docker ps --format "{{.Names}}" 2>/dev/null || echo "")

    for container in $containers; do
        if docker inspect "$container" >/dev/null 2>&1; then
            local log_path
            log_path=$(docker inspect "$container" --format='{{.LogPath}}' 2>/dev/null || echo "")

            if [ -n "$log_path" ] && [ -f "$log_path" ]; then
                local size_mb
                size_mb=$(du -m "$log_path" 2>/dev/null | cut -f1 || echo "0")

                if [ "$size_mb" -gt 100 ]; then
                    warn "Docker log for $container is ${size_mb}MB. Consider configuring Docker log rotation in daemon.json."
                fi
            fi
        fi
    done
}

# Function to rotate application logs in Docker volumes
rotate_app_logs() {
    log "Rotating application logs..."

    if docker volume ls | grep -q "tonybenoy.*app-logs"; then
        docker run --rm \
            -v tonybenoy_app-logs:/logs \
            -v "$LOG_BACKUP_DIR":/backup \
            alpine sh -c '
                find /logs -name "*.log" -type f -size +100M | while read -r f; do
                    echo "Backing up large log file: $f"
                    gzip -c "$f" > "/backup/app-$(basename "$f").$(date +%Y%m%d-%H%M%S).gz"
                    : > "$f"
                done
            ' 2>/dev/null || warn "Could not rotate application logs"
    fi

    if docker volume ls | grep -q "tonybenoy.*nginx-logs"; then
        docker run --rm \
            -v tonybenoy_nginx-logs:/logs \
            -v "$LOG_BACKUP_DIR":/backup \
            alpine sh -c '
                for log_file in /logs/*.log; do
                    [ -f "$log_file" ] || continue
                    size_kb=$(du -k "$log_file" | cut -f1)
                    if [ "$size_kb" -gt 102400 ]; then
                        echo "Rotating nginx log: $log_file"
                        gzip -c "$log_file" > "/backup/nginx-$(basename "$log_file").$(date +%Y%m%d-%H%M%S).gz"
                        : > "$log_file"
                    fi
                done
            ' 2>/dev/null || warn "Could not rotate nginx logs"
    fi
}

# Function to clean up old backups
cleanup_old_backups() {
    log "Cleaning up old log backups..."

    find "$LOG_BACKUP_DIR" -name "*.gz" -type f -mtime +"$ARCHIVE_RETENTION_DAYS" -delete 2>/dev/null || true

    local backup_count
    backup_count=$(find "$LOG_BACKUP_DIR" -name "*.gz" -type f | wc -l)
    local backup_size
    backup_size=$(du -sh "$LOG_BACKUP_DIR" 2>/dev/null | cut -f1 || echo "unknown")

    log "Log backup status: $backup_count files, $backup_size total"
}

# Main execution
main() {
    log "Starting log rotation and cleanup..."

    rotate_docker_logs
    rotate_app_logs

    # Rotate local monitor logs
    local log_dir="$PROJECT_DIR/logs"
    if [ -d "$log_dir" ]; then
        for log_file in "$log_dir"/*.log; do
            if [ -f "$log_file" ]; then
                rotate_log "$log_file" 50 5
            fi
        done
    fi

    cleanup_old_backups

    log "Log rotation and cleanup completed"

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
        echo "Usage: $0 [rotate|cleanup|status]"
        echo "  rotate  - Rotate logs and create backups (default)"
        echo "  cleanup - Clean up old backups only"
        echo "  status  - Show current backup status"
        exit 1
        ;;
esac
