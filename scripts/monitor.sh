#!/bin/bash

# Website Monitoring Script
# This script checks the health of all services and logs the status
# Usage: ./scripts/monitor.sh [local|dev|prod]

ENV="${1:-local}"
LOGFILE="/var/log/tonybenoy-monitor-$ENV.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Function to log with timestamp
log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOGFILE"
}

# Validate environment
if [ ! -f "$PROJECT_DIR/.env.$ENV" ]; then
    echo "Environment file .env.$ENV not found, using default monitoring"
fi

log "=== Monitoring $ENV environment ==="

# Check if running in Docker environment
if command -v docker &> /dev/null; then
    # Docker environment checks
    log "=== Docker Services Health Check ==="
    
    # Check container status
    log "Container Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tee -a "$LOGFILE"
    
    # Check container health
    log "\nContainer Health:"
    for container in tonybenoy-nginx tonybenoy-app; do
        if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
            health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
            log "$container: RUNNING ($health)"
        else
            log "$container: NOT RUNNING"
        fi
    done
    
    # Check resource usage
    log "\nResource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | tee -a "$LOGFILE"
else
    log "Not running in Docker environment"
fi

# Application health checks
log "\n=== Application Health Checks ==="

# Environment-specific health checks
case "$ENV" in
    "local")
        # Check main application endpoint directly
        if curl -f -s -o /dev/null "http://localhost:8000/health"; then
            log "FastAPI Health: OK"
        else
            log "FastAPI Health: FAILED"
        fi
        
        # Check nginx proxy
        if curl -f -s -o /dev/null "http://localhost/test"; then
            log "Nginx Proxy: OK"
        else
            log "Nginx Proxy: FAILED"
        fi
        ;;
    "dev")
        # Check web server
        if curl -f -s -o /dev/null "http://localhost/test"; then
            log "Application (via Nginx): OK"
        else
            log "Application (via Nginx): FAILED"
        fi
        ;;
    "prod")
        # Check HTTPS endpoint
        if curl -f -s -o /dev/null "https://tonybenoy.com/test"; then
            log "Production HTTPS: OK"
        else
            log "Production HTTPS: FAILED"
        fi
        
        # Check HTTP redirect
        if curl -s -o /dev/null -w "%{http_code}" "http://tonybenoy.com/test" | grep -q "301\|302"; then
            log "HTTP to HTTPS Redirect: OK"
        else
            log "HTTP to HTTPS Redirect: FAILED"
        fi
        ;;
esac

# Redis monitoring removed

# Check SSL certificate expiry (if HTTPS is configured)
if command -v openssl &> /dev/null; then
    if echo | timeout 5 openssl s_client -servername tonybenoy.com -connect tonybenoy.com:443 2>/dev/null | openssl x509 -noout -dates > /tmp/ssl_dates 2>/dev/null; then
        expiry_date=$(grep "notAfter" /tmp/ssl_dates | cut -d= -f2)
        expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
        current_timestamp=$(date +%s)
        days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [ "$days_until_expiry" -gt 30 ]; then
            log "SSL Certificate: OK ($days_until_expiry days until expiry)"
        elif [ "$days_until_expiry" -gt 7 ]; then
            log "SSL Certificate: WARNING ($days_until_expiry days until expiry)"
        else
            log "SSL Certificate: CRITICAL ($days_until_expiry days until expiry)"
        fi
        rm -f /tmp/ssl_dates
    else
        log "SSL Certificate: Could not check"
    fi
fi

# System resource checks
log "\n=== System Resources ==="
log "Disk Usage: $(df -h / | awk 'NR==2{print $5}' | tr -d '%')% used"
log "Memory Usage: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
log "Load Average: $(uptime | awk -F'load average:' '{print $2}')"

# Log file sizes
log "\n=== Log File Sizes ==="
for logdir in /var/log/nginx /app/logs; do
    if [ -d "$logdir" ]; then
        log "Logs in $logdir:"
        find "$logdir" -name "*.log" -type f -exec ls -lh {} \; 2>/dev/null | awk '{print $9 ": " $5}' | tee -a "$LOGFILE"
    fi
done

log "=== Health Check Complete ===\n"

# Exit with error if critical services are down
if ! curl -f -s -o /dev/null "http://localhost:8000/health"; then
    exit 1
fi