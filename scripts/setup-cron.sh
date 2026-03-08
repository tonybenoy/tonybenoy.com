#!/bin/bash

# Setup automated log rotation and backup cron jobs
# This script configures cron jobs for maintenance tasks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

# Check if running as root
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

# Log rotation - Daily at 2:30 AM
30 2 * * * $CRON_USER cd $PROJECT_DIR && $SCRIPT_DIR/log-rotate.sh rotate >> $PROJECT_DIR/logs/cron.log 2>&1

# Full backup - Daily at 3:00 AM
0 3 * * * $CRON_USER cd $PROJECT_DIR && $SCRIPT_DIR/backup.sh full >> $PROJECT_DIR/logs/cron.log 2>&1

# Backup cleanup - Weekly on Sunday at 4:00 AM
0 4 * * 0 $CRON_USER cd $PROJECT_DIR && $SCRIPT_DIR/backup.sh cleanup >> $PROJECT_DIR/logs/cron.log 2>&1

# Health monitoring - Every 15 minutes
*/15 * * * * $CRON_USER cd $PROJECT_DIR && $SCRIPT_DIR/monitor.sh >> $PROJECT_DIR/logs/monitor.log 2>&1

# Docker system cleanup - Monthly on 1st at 5:00 AM
0 5 1 * * $CRON_USER docker system prune -f >> $PROJECT_DIR/logs/cron.log 2>&1

EOF

    if [ "$EUID" -eq 0 ]; then
        chmod 644 "$CRON_FILE"
        log "System cron job created: $CRON_FILE"
    else
        crontab "$CRON_FILE"
        log "User cron jobs installed for $CRON_USER"
        rm -f "$CRON_FILE"
    fi
}

# Create logrotate configuration
create_logrotate_config() {
    if [ "$EUID" -ne 0 ]; then
        warn "Skipping logrotate configuration (requires root)"
        return
    fi

    log "Creating logrotate configuration..."

    cat > /etc/logrotate.d/tonybenoy << EOF
# TonyBenoy.com log rotation configuration

$PROJECT_DIR/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
    create 644 $CRON_USER $CRON_USER
}
EOF

    log "Logrotate configuration created: /etc/logrotate.d/tonybenoy"
}

# Setup function
setup_maintenance() {
    log "Setting up automated maintenance for TonyBenoy.com..."

    # Create log directory
    mkdir -p "$PROJECT_DIR/logs"

    create_cron_config

    if [ "$EUID" -eq 0 ]; then
        create_logrotate_config
    fi

    # Test scripts
    log "Testing maintenance scripts..."

    if [ -x "$SCRIPT_DIR/monitor.sh" ]; then
        "$SCRIPT_DIR/monitor.sh" >/dev/null 2>&1 && log "Monitor script: OK" || warn "Monitor script: FAILED"
    fi

    if [ -x "$SCRIPT_DIR/backup.sh" ]; then
        "$SCRIPT_DIR/backup.sh" list >/dev/null 2>&1 && log "Backup script: OK" || warn "Backup script: FAILED"
    fi

    if [ -x "$SCRIPT_DIR/log-rotate.sh" ]; then
        "$SCRIPT_DIR/log-rotate.sh" status >/dev/null 2>&1 && log "Log rotation script: OK" || warn "Log rotation script: FAILED"
    fi

    log "Maintenance setup completed!"

    echo ""
    echo "=== Scheduled Tasks ==="
    echo "  Log rotation: Daily at 2:30 AM"
    echo "  Full backup: Daily at 3:00 AM"
    echo "  Health monitoring: Every 15 minutes"
    echo "  Backup cleanup: Weekly on Sunday"
    echo "  System cleanup: Monthly on 1st"

    echo ""
    echo "=== Log Files ==="
    echo "  Cron logs: $PROJECT_DIR/logs/cron.log"
    echo "  Monitor logs: $PROJECT_DIR/logs/monitor.log"
}

# Handle script arguments
case "${1:-setup}" in
    "setup")
        setup_maintenance
        ;;
    "remove")
        log "Removing maintenance configuration..."

        if [ "$EUID" -eq 0 ]; then
            rm -f /etc/cron.d/tonybenoy-maintenance
            rm -f /etc/logrotate.d/tonybenoy
        else
            crontab -l 2>/dev/null | grep -v tonybenoy | crontab - 2>/dev/null || warn "Could not update user crontab"
        fi

        log "Maintenance configuration removed"
        ;;
    "status")
        log "Maintenance status:"

        echo ""
        echo "=== Cron Jobs ==="
        if [ "$EUID" -eq 0 ]; then
            if [ -f "/etc/cron.d/tonybenoy-maintenance" ]; then
                echo "System cron jobs: Active"
                grep -v "^#" /etc/cron.d/tonybenoy-maintenance | grep -v "^$" | grep -v "^SHELL\|^PATH\|^MAILTO"
            else
                echo "System cron jobs: Not configured"
            fi
        else
            echo "User cron jobs:"
            crontab -l 2>/dev/null | grep tonybenoy || echo "No user cron jobs found"
        fi

        echo ""
        echo "=== Recent Activity ==="
        if [ -f "$PROJECT_DIR/logs/cron.log" ]; then
            echo "Last 5 cron entries:"
            tail -n 5 "$PROJECT_DIR/logs/cron.log"
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
