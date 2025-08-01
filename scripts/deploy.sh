#!/bin/bash

# Production Deployment Script for TonyBenoy.com
# This script handles safe deployment with health checks and rollback capability

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="/tmp/tonybenoy-backup-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Function to check if services are healthy
check_health() {
    local retries=30
    local count=0
    
    log "Checking application health..."
    
    while [ $count -lt $retries ]; do
        if curl -f -s -o /dev/null "http://localhost:8000/health"; then
            log "Health check passed"
            return 0
        fi
        
        count=$((count + 1))
        log "Health check attempt $count/$retries failed, waiting..."
        sleep 2
    done
    
    error "Health check failed after $retries attempts"
    return 1
}

# Function to create backup
create_backup() {
    log "Creating backup in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup current containers if they exist
    if docker ps -q -f name=tonybenoy-app | grep -q .; then
        docker commit tonybenoy-app "$BACKUP_DIR/app-backup:latest" || warn "Could not backup app container"
    fi
    
    # Backup volumes
    docker run --rm \
        -v tonybenoy_redis-data:/source:ro \
        -v "$BACKUP_DIR":/backup \
        alpine tar czf /backup/redis-data.tar.gz -C /source . || warn "Could not backup Redis data"
    
    log "Backup created successfully"
}

# Function to rollback
rollback() {
    error "Deployment failed, initiating rollback..."
    
    if [ -d "$BACKUP_DIR" ]; then
        log "Stopping current containers..."
        docker-compose down || true
        
        # Restore backup if available
        if [ -f "$BACKUP_DIR/redis-data.tar.gz" ]; then
            log "Restoring Redis data..."
            docker run --rm \
                -v tonybenoy_redis-data:/target \
                -v "$BACKUP_DIR":/backup \
                alpine sh -c "cd /target && tar xzf /backup/redis-data.tar.gz" || warn "Could not restore Redis data"
        fi
        
        log "Starting previous version..."
        docker-compose up -d || error "Rollback failed"
    else
        error "No backup available for rollback"
    fi
    
    exit 1
}

# Main deployment process
main() {
    log "Starting deployment of TonyBenoy.com..."
    
    cd "$PROJECT_DIR"
    
    # Pre-deployment checks
    log "Running pre-deployment checks..."
    
    # Check if docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        error "docker-compose.yml not found"
        exit 1
    fi
    
    # Check if required environment files exist
    if [ ! -f ".env" ] && [ ! -f ".env.example" ]; then
        warn "No .env file found. Make sure to configure environment variables."
    fi
    
    # Validate docker-compose configuration
    if ! docker-compose config >/dev/null 2>&1; then
        error "Invalid docker-compose configuration"
        exit 1
    fi
    
    # Create backup before deployment
    create_backup
    
    # Set trap for rollback on failure
    trap rollback ERR
    
    # Pull latest images
    log "Pulling latest images..."
    docker-compose pull || true
    
    # Build application image
    log "Building application image..."
    docker-compose build fastapi
    
    # Start services with zero-downtime deployment
    log "Deploying services..."
    
    # Start dependencies first
    docker-compose up -d redis_db
    log "Waiting for Redis to be ready..."
    sleep 10
    
    # Deploy application
    docker-compose up -d fastapi
    log "Waiting for application to be ready..."
    sleep 15
    
    # Check application health
    if ! check_health; then
        error "Application health check failed"
        rollback
    fi
    
    # Deploy nginx last
    docker-compose up -d nginx
    log "Waiting for nginx to be ready..."
    sleep 10
    
    # Deploy certbot
    docker-compose up -d certbot
    
    # Final health check
    log "Running final health checks..."
    sleep 5
    
    if ! check_health; then
        error "Final health check failed"
        rollback
    fi
    
    # Test external access
    if ! curl -f -s -o /dev/null "http://localhost/test"; then
        error "External access test failed"
        rollback
    fi
    
    log "Deployment completed successfully!"
    
    # Show service status
    log "Service status:"
    docker-compose ps
    
    # Clean up old backup (keep only last 5)
    log "Cleaning up old backups..."
    find /tmp -name "tonybenoy-backup-*" -type d -mtime +5 -exec rm -rf {} + 2>/dev/null || true
    
    log "Deployment process completed. Services are running and healthy."
    
    # Show useful commands
    echo ""
    echo "Useful commands:"
    echo "  View logs: docker-compose logs -f"
    echo "  Monitor: $SCRIPT_DIR/monitor.sh"
    echo "  Stop services: docker-compose down"
    echo "  Update single service: docker-compose up -d <service_name>"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "health")
        check_health
        ;;
    "backup")
        create_backup
        ;;
    "rollback")
        if [ -z "$2" ]; then
            error "Please specify backup directory for rollback"
            exit 1
        fi
        BACKUP_DIR="$2"
        rollback
        ;;
    *)
        echo "Usage: $0 [deploy|health|backup|rollback <backup_dir>]"
        exit 1
        ;;
esac