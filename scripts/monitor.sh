#!/bin/bash

# Website Monitoring Script
# This script checks the health of all services and logs the status
# Usage: ./scripts/monitor.sh [local|dev|prod]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

ENV="${1:-local}"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
LOGFILE="$LOG_DIR/monitor-$ENV.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Override log to also write to logfile
monitor_log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOGFILE"
}

# Validate environment
if [ ! -f "$PROJECT_DIR/.env.$ENV" ]; then
    warn "Environment file .env.$ENV not found, using default monitoring"
fi

monitor_log "=== Monitoring $ENV environment ==="

# Check if running in Docker environment
if command -v docker &> /dev/null; then
    monitor_log "=== Docker Services Health Check ==="

    # Check container status
    monitor_log "Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tee -a "$LOGFILE"

    # Check container health
    monitor_log "Container Health:"
    for container in tonybenoy-nginx tonybenoy-app; do
        if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
            health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
            monitor_log "$container: RUNNING ($health)"
        else
            monitor_log "$container: NOT RUNNING"
        fi
    done

    # Check resource usage
    monitor_log "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tee -a "$LOGFILE"
else
    monitor_log "Not running in Docker environment"
fi

# Application health checks
monitor_log "=== Application Health Checks ==="

health_ok=true

case "$ENV" in
    "local")
        if curl -f -s -o /dev/null "http://localhost:8000/health"; then
            monitor_log "FastAPI Health: OK"
        else
            monitor_log "FastAPI Health: FAILED"
            health_ok=false
        fi

        if curl -f -s -o /dev/null "http://localhost/test"; then
            monitor_log "Nginx Proxy: OK"
        else
            monitor_log "Nginx Proxy: FAILED"
        fi
        ;;
    "dev")
        if curl -f -s -o /dev/null "http://localhost/test"; then
            monitor_log "Application (via Nginx): OK"
        else
            monitor_log "Application (via Nginx): FAILED"
            health_ok=false
        fi
        ;;
    "prod")
        if curl -f -s -o /dev/null "https://tonybenoy.com/test"; then
            monitor_log "Production HTTPS: OK"
        else
            monitor_log "Production HTTPS: FAILED"
            health_ok=false
        fi

        http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://tonybenoy.com/test" || echo "000")
        if [[ "$http_code" == "301" || "$http_code" == "302" ]]; then
            monitor_log "HTTP to HTTPS Redirect: OK"
        else
            monitor_log "HTTP to HTTPS Redirect: FAILED"
        fi
        ;;
esac

# Check SSL certificate expiry (production only)
if [ "$ENV" = "prod" ] && command -v openssl &> /dev/null; then
    ssl_dates_file=$(mktemp)
    trap 'rm -f "$ssl_dates_file"' EXIT

    if echo | timeout 5 openssl s_client -servername tonybenoy.com -connect tonybenoy.com:443 2>/dev/null | openssl x509 -noout -dates > "$ssl_dates_file" 2>/dev/null; then
        expiry_date=$(grep "notAfter" "$ssl_dates_file" | cut -d= -f2)
        expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
        current_timestamp=$(date +%s)
        days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))

        if [ "$days_until_expiry" -gt 30 ]; then
            monitor_log "SSL Certificate: OK ($days_until_expiry days until expiry)"
        elif [ "$days_until_expiry" -gt 7 ]; then
            monitor_log "SSL Certificate: WARNING ($days_until_expiry days until expiry)"
        else
            monitor_log "SSL Certificate: CRITICAL ($days_until_expiry days until expiry)"
        fi
    else
        monitor_log "SSL Certificate: Could not check"
    fi
fi

# System resource checks
monitor_log "=== System Resources ==="
monitor_log "Disk Usage: $(df -h / | awk 'NR==2{print $5}' | tr -d '%')% used"
monitor_log "Memory Usage: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
monitor_log "Load Average: $(uptime | awk -F'load average:' '{print $2}')"

monitor_log "=== Health Check Complete ==="

# Exit with error if critical services are down
if [ "$health_ok" = false ]; then
    exit 1
fi
