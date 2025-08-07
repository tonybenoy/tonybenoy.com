#!/bin/bash

# Setup automated log rotation and backup cron jobs
# This script configures cron jobs for maintenance tasks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

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

# Check if running as root (required for system cron jobs)
if [ "$EUID" -eq 0 ]; then
    CRON_USER="root"
    CRON_FILE="/etc/cron.d/tonybenoy-maintenance"
else
    CRON_USER="$(whoami)"
    CRON_FILE="/tmp/tonybenoy-crontab"
    warn "Not running as root. Installing user cron jobs for $CRON_USER"
fi

# Create cron job configuration
create_cron_config() {
    log "Creating cron configuration..."
    
    cat > "$CRON_FILE" << EOF
# TonyBenoy.com Maintenance Cron Jobs
# Generated on $(date)

SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root

# Log rotation - Daily at 2:30 AM
30 2 * * * $CRON_USER $SCRIPT_DIR/log-rotate.sh rotate >> /var/log/tonybenoy-cron.log 2>&1

# Full backup - Daily at 3:00 AM
0 3 * * * $CRON_USER $SCRIPT_DIR/backup.sh full >> /var/log/tonybenoy-cron.log 2>&1

# Data-only backup - Every 6 hours (for frequent data changes)
0 */6 * * * $CRON_USER $SCRIPT_DIR/backup.sh data >> /var/log/tonybenoy-cron.log 2>&1

# Backup cleanup - Weekly on Sunday at 4:00 AM
0 4 * * 0 $CRON_USER $SCRIPT_DIR/backup.sh cleanup >> /var/log/tonybenoy-cron.log 2>&1

# Health monitoring - Every 15 minutes
*/15 * * * * $CRON_USER $SCRIPT_DIR/monitor.sh >> /var/log/tonybenoy-monitor.log 2>&1

# Log rotation report - Weekly on Monday at 8:00 AM
0 8 * * 1 $CRON_USER $SCRIPT_DIR/log-rotate.sh report >> /var/log/tonybenoy-cron.log 2>&1

# Docker system cleanup - Monthly on 1st at 5:00 AM
0 5 1 * * $CRON_USER docker system prune -f >> /var/log/tonybenoy-cron.log 2>&1

EOF

    if [ "$EUID" -eq 0 ]; then
        # System-wide cron job
        chmod 644 "$CRON_FILE"
        log "System cron job created: $CRON_FILE"
    else
        # User cron job
        crontab "$CRON_FILE"
        log "User cron jobs installed for $CRON_USER"
        rm -f "$CRON_FILE"
    fi
}

# Create logrotate configuration (alternative to our custom script)
create_logrotate_config() {
    if [ "$EUID" -ne 0 ]; then
        warn "Skipping logrotate configuration (requires root)"
        return
    fi
    
    log "Creating logrotate configuration..."
    
    cat > /etc/logrotate.d/tonybenoy << 'EOF'
# TonyBenoy.com log rotation configuration

/var/log/tonybenoy*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    create 644 root root
}

/var/backups/tonybenoy-logs/*.log {
    weekly
    missingok
    rotate 12
    compress
    delaycompress
    notifempty
    create 644 root root
}

# Docker container logs (if accessible)
/var/lib/docker/containers/*/*-json.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    maxsize 100M
}
EOF

    log "Logrotate configuration created: /etc/logrotate.d/tonybenoy"
}

# Create systemd service for monitoring (alternative to cron)
create_systemd_service() {
    if [ "$EUID" -ne 0 ]; then
        warn "Skipping systemd service creation (requires root)"
        return
    fi
    
    log "Creating systemd monitoring service..."
    
    # Create service file
    cat > /etc/systemd/system/tonybenoy-monitor.service << EOF
[Unit]
Description=TonyBenoy.com Health Monitor
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/monitor.sh
User=$CRON_USER
WorkingDirectory=$PROJECT_DIR
StandardOutput=append:/var/log/tonybenoy-monitor.log
StandardError=append:/var/log/tonybenoy-monitor.log

[Install]
WantedBy=multi-user.target
EOF

    # Create timer file
    cat > /etc/systemd/system/tonybenoy-monitor.timer << EOF
[Unit]
Description=TonyBenoy.com Health Monitor Timer
Requires=tonybenoy-monitor.service

[Timer]
OnCalendar=*:0/15
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Create backup service
    cat > /etc/systemd/system/tonybenoy-backup.service << EOF
[Unit]
Description=TonyBenoy.com Backup Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=$SCRIPT_DIR/backup.sh full
User=$CRON_USER
WorkingDirectory=$PROJECT_DIR
StandardOutput=append:/var/log/tonybenoy-cron.log
StandardError=append:/var/log/tonybenoy-cron.log

[Install]
WantedBy=multi-user.target
EOF

    # Create backup timer
    cat > /etc/systemd/system/tonybenoy-backup.timer << EOF
[Unit]
Description=TonyBenoy.com Daily Backup Timer
Requires=tonybenoy-backup.service

[Timer]
OnCalendar=daily
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload systemd and enable services
    systemctl daemon-reload
    systemctl enable tonybenoy-monitor.timer
    systemctl enable tonybenoy-backup.timer
    systemctl start tonybenoy-monitor.timer
    systemctl start tonybenoy-backup.timer
    
    log "Systemd services created and enabled"
}

# Create log monitoring script
create_log_monitor() {
    log "Creating log monitoring script..."
    
    cat > "$SCRIPT_DIR/log-alert.sh" << 'EOF'
#!/bin/bash

# Log monitoring and alerting script
# Monitors logs for errors and sends alerts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALERT_THRESHOLD=10  # Number of errors before alerting
TIME_WINDOW=300     # 5 minutes in seconds

# Function to check for errors in logs
check_errors() {
    local log_patterns=(
        "ERROR"
        "FATAL"
        "CRITICAL"
        "500 Internal Server Error"
        "502 Bad Gateway"
        "503 Service Unavailable"
    )
    
    local error_count=0
    local since_time=$(date -d "$TIME_WINDOW seconds ago" "+%Y-%m-%d %H:%M:%S")
    
    # Check Docker logs
    for container in tonybenoy-nginx tonybenoy-app; do
        if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
            for pattern in "${log_patterns[@]}"; do
                local count=$(docker logs "$container" --since="${TIME_WINDOW}s" 2>&1 | grep -c "$pattern" || echo "0")
                error_count=$((error_count + count))
            done
        fi
    done
    
    # Check system logs
    for log_file in /var/log/tonybenoy*.log; do
        if [ -f "$log_file" ]; then
            for pattern in "${log_patterns[@]}"; do
                local count=$(awk -v since="$since_time" '$0 >= since' "$log_file" | grep -c "$pattern" || echo "0")
                error_count=$((error_count + count))
            done
        fi
    done
    
    if [ "$error_count" -gt "$ALERT_THRESHOLD" ]; then
        echo "ALERT: $error_count errors detected in the last $((TIME_WINDOW / 60)) minutes"
        
        # Send alert (could be email, webhook, etc.)
        logger -t tonybenoy-alert "High error rate detected: $error_count errors in $((TIME_WINDOW / 60)) minutes"
        
        # Could add email notification here:
        # echo "High error rate detected on $(hostname)" | mail -s "TonyBenoy.com Alert" admin@example.com
    fi
}

# Function to check disk space
check_disk_space() {
    local threshold=90  # Alert if disk usage > 90%
    
    while read -r usage mount; do
        if [ "$usage" -gt "$threshold" ]; then
            echo "ALERT: Disk usage at $usage% for $mount"
            logger -t tonybenoy-alert "High disk usage: $usage% for $mount"
        fi
    done < <(df | awk 'NR>1 {print $5 " " $6}' | sed 's/%//')
}

# Function to check service availability
check_services() {
    local services=("tonybenoy-nginx" "tonybenoy-app")
    
    for service in "${services[@]}"; do
        if ! docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
            echo "ALERT: Service $service is not running"
            logger -t tonybenoy-alert "Service down: $service"
        fi
    done
    
    # Check application health
    if ! curl -f -s -o /dev/null "http://localhost:8000/health" --max-time 10; then
        echo "ALERT: Application health check failed"
        logger -t tonybenoy-alert "Application health check failed"
    fi
}

# Main monitoring function
main() {
    check_errors
    check_disk_space
    check_services
}

main "$@"
EOF

    chmod +x "$SCRIPT_DIR/log-alert.sh"
    log "Log monitoring script created: $SCRIPT_DIR/log-alert.sh"
}

# Setup function
setup_maintenance() {
    log "Setting up automated maintenance for TonyBenoy.com..."
    
    # Create necessary directories
    mkdir -p /var/log 2>/dev/null || warn "Could not create /var/log (may already exist)"
    mkdir -p /var/backups 2>/dev/null || warn "Could not create /var/backups (may already exist)"
    
    # Create configurations based on system capabilities
    create_cron_config
    
    if [ "$EUID" -eq 0 ]; then
        create_logrotate_config
        
        # Ask user preference for systemd vs cron
        echo -n "Use systemd timers instead of cron? (recommended for modern systems) [Y/n]: "
        read -r response
        if [[ ! "$response" =~ ^[nN]$ ]]; then
            create_systemd_service
        fi
    fi
    
    create_log_monitor
    
    # Test scripts
    log "Testing maintenance scripts..."
    
    if [ -x "$SCRIPT_DIR/monitor.sh" ]; then
        log "Testing monitoring script..."
        "$SCRIPT_DIR/monitor.sh" >/dev/null 2>&1 && log "✓ Monitor script works" || warn "✗ Monitor script failed"
    fi
    
    if [ -x "$SCRIPT_DIR/backup.sh" ]; then
        log "Testing backup script (list only)..."
        "$SCRIPT_DIR/backup.sh" list >/dev/null 2>&1 && log "✓ Backup script works" || warn "✗ Backup script failed"
    fi
    
    if [ -x "$SCRIPT_DIR/log-rotate.sh" ]; then
        log "Testing log rotation script (status only)..."
        "$SCRIPT_DIR/log-rotate.sh" status >/dev/null 2>&1 && log "✓ Log rotation script works" || warn "✗ Log rotation script failed"
    fi
    
    log "Maintenance setup completed!"
    
    echo ""
    echo "=== Setup Summary ==="
    echo "Cron jobs: $([ -f "$CRON_FILE" ] && echo "✓ Installed" || echo "✓ User crontab updated")"
    echo "Logrotate: $([ -f "/etc/logrotate.d/tonybenoy" ] && echo "✓ Configured" || echo "- Skipped (requires root)")"
    echo "Systemd: $([ -f "/etc/systemd/system/tonybenoy-monitor.timer" ] && echo "✓ Configured" || echo "- Not configured")"
    echo "Log monitoring: ✓ Configured"
    
    echo ""
    echo "=== Scheduled Tasks ==="
    echo "• Log rotation: Daily at 2:30 AM"
    echo "• Full backup: Daily at 3:00 AM"
    echo "• Data backup: Every 6 hours"
    echo "• Health monitoring: Every 15 minutes"
    echo "• Backup cleanup: Weekly on Sunday"
    echo "• System cleanup: Monthly on 1st"
    
    echo ""
    echo "=== Manual Commands ==="
    echo "• Run backup: $SCRIPT_DIR/backup.sh [full|data|config]"
    echo "• Check logs: $SCRIPT_DIR/log-rotate.sh status"
    echo "• Monitor health: $SCRIPT_DIR/monitor.sh"
    echo "• View backups: $SCRIPT_DIR/backup.sh list"
    echo "• Restore: $SCRIPT_DIR/restore.sh <backup_date>"
    
    echo ""
    echo "=== Log Files ==="
    echo "• Cron logs: /var/log/tonybenoy-cron.log"
    echo "• Monitor logs: /var/log/tonybenoy-monitor.log"
    echo "• System logs: journalctl -u tonybenoy-*"
}

# Handle script arguments
case "${1:-setup}" in
    "setup")
        setup_maintenance
        ;;
    "remove")
        log "Removing maintenance configuration..."
        
        # Remove cron jobs
        if [ "$EUID" -eq 0 ]; then
            rm -f /etc/cron.d/tonybenoy-maintenance
            rm -f /etc/logrotate.d/tonybenoy
            
            # Remove systemd services
            systemctl stop tonybenoy-monitor.timer tonybenoy-backup.timer 2>/dev/null || true
            systemctl disable tonybenoy-monitor.timer tonybenoy-backup.timer 2>/dev/null || true
            rm -f /etc/systemd/system/tonybenoy-*.{service,timer}
            systemctl daemon-reload
        else
            crontab -l | grep -v tonybenoy | crontab - 2>/dev/null || warn "Could not update user crontab"
        fi
        
        log "Maintenance configuration removed"
        ;;
    "status")
        log "Maintenance status:"
        
        echo ""
        echo "=== Cron Jobs ==="
        if [ "$EUID" -eq 0 ]; then
            if [ -f "/etc/cron.d/tonybenoy-maintenance" ]; then
                echo "System cron jobs: ✓ Active"
                grep -v "^#" /etc/cron.d/tonybenoy-maintenance | grep -v "^$"
            else
                echo "System cron jobs: ✗ Not configured"
            fi
        else
            echo "User cron jobs:"
            crontab -l 2>/dev/null | grep tonybenoy || echo "No user cron jobs found"
        fi
        
        echo ""
        echo "=== Systemd Services ==="
        if [ -f "/etc/systemd/system/tonybenoy-monitor.timer" ]; then
            systemctl is-active tonybenoy-monitor.timer || echo "tonybenoy-monitor.timer: inactive"
            systemctl is-active tonybenoy-backup.timer || echo "tonybenoy-backup.timer: inactive"
        else
            echo "Systemd services: Not configured"
        fi
        
        echo ""
        echo "=== Recent Activity ==="
        if [ -f "/var/log/tonybenoy-cron.log" ]; then
            echo "Last 5 cron entries:"
            tail -n 5 /var/log/tonybenoy-cron.log
        else
            echo "No cron activity logs found"
        fi
        ;;
    *)
        echo "Usage: $0 [setup|remove|status]"
        echo ""
        echo "Commands:"
        echo "  setup  - Install maintenance cron jobs and configurations (default)"
        echo "  remove - Remove all maintenance configurations"
        echo "  status - Show current maintenance status"
        exit 1
        ;;
esac