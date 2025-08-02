#!/bin/bash

# Environment-based Deployment Script for TonyBenoy.com
# Usage: ./scripts/deploy-env.sh [local|dev|prod]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV="${1:-local}"
BACKUP_DIR="/tmp/tonybenoy-backup-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Validate environment
validate_env() {
    case "$ENV" in
        "local"|"dev"|"prod")
            info "Deploying to $ENV environment"
            ;;
        *)
            error "Invalid environment: $ENV. Use: local, dev, or prod"
            exit 1
            ;;
    esac
    
    # Check if environment file exists
    if [ ! -f "$PROJECT_DIR/.env.$ENV" ]; then
        error "Environment file .env.$ENV not found"
        exit 1
    fi
}

# Function to check if services are healthy
check_health() {
    local retries=30
    local count=0
    local health_url="http://localhost/test"
    
    # Use different health check URL for local environment
    if [ "$ENV" = "local" ]; then
        health_url="http://localhost:8000/test"
    fi
    
    log "Checking application health at $health_url..."
    
    while [ $count -lt $retries ]; do
        if curl -f -s -o /dev/null "$health_url"; then
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
    if docker volume ls -q | grep -q tonybenoy_redis-data; then
        docker run --rm \
            -v tonybenoy_redis-data:/source:ro \
            -v "$BACKUP_DIR":/backup \
            alpine tar czf /backup/redis-data.tar.gz -C /source . || warn "Could not backup Redis data"
    fi
    
    log "Backup created successfully"
}

# Function to rollback
rollback() {
    error "Deployment failed, initiating rollback..."
    
    if [ -d "$BACKUP_DIR" ]; then
        log "Stopping current containers..."
        docker-compose --env-file ".env.$ENV" down || true
        
        # Restore backup if available
        if [ -f "$BACKUP_DIR/redis-data.tar.gz" ]; then
            log "Restoring Redis data..."
            docker run --rm \
                -v tonybenoy_redis-data:/target \
                -v "$BACKUP_DIR":/backup \
                alpine sh -c "cd /target && tar xzf /backup/redis-data.tar.gz" || warn "Could not restore Redis data"
        fi
        
        log "Starting previous version..."
        docker-compose --env-file ".env.$ENV" up -d || error "Rollback failed"
    else
        error "No backup available for rollback"
    fi
    
    exit 1
}

# Environment-specific configurations
configure_environment() {
    case "$ENV" in
        "local")
            info "Configuring for local development..."
            log "Using HTTP only configuration on port 8000"
            ;;
        "dev")
            info "Configuring for development environment..."
            log "Using HTTP configuration with development settings"
            ;;
        "prod")
            info "Configuring for production environment..."
            log "Using HTTPS configuration with SSL certificates"
            # Check if SSL certificates exist for production
            if ! docker-compose --env-file ".env.$ENV" config | grep -q "letsencrypt"; then
                warn "SSL certificates may not be configured. Run ./scripts/init-ssl.sh first."
            fi
            ;;
    esac
}

# Main deployment process
main() {
    log "Starting environment-based deployment of TonyBenoy.com..."
    log "Environment: $ENV"
    
    cd "$PROJECT_DIR"
    
    # Validate environment
    validate_env
    
    # Configure environment-specific settings
    configure_environment
    
    # Pre-deployment checks
    log "Running pre-deployment checks..."
    
    # Check if docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        error "docker-compose.yml not found"
        exit 1
    fi
    
    # Validate docker-compose configuration with environment file
    if ! docker-compose --env-file ".env.$ENV" config >/dev/null 2>&1; then
        error "Invalid docker-compose configuration for $ENV environment"
        exit 1
    fi
    
    # Create backup before deployment
    create_backup
    
    # Set trap for rollback on failure
    trap rollback ERR
    
    # Pull latest images
    log "Pulling latest images..."
    docker-compose --env-file ".env.$ENV" pull || true
    
    # Build application image
    log "Building application image..."
    docker-compose --env-file ".env.$ENV" build fastapi
    
    # Start services with zero-downtime deployment
    log "Deploying services..."
    
    # Start dependencies first
    docker-compose --env-file ".env.$ENV" up -d redis_db
    log "Waiting for Redis to be ready..."
    sleep 10
    
    # Deploy application
    docker-compose --env-file ".env.$ENV" up -d fastapi
    log "Waiting for application to be ready..."
    sleep 15
    
    # Check application health
    if ! check_health; then
        error "Application health check failed"
        rollback
    fi
    
    # Deploy nginx
    docker-compose --env-file ".env.$ENV" up -d nginx
    log "Waiting for nginx to be ready..."
    sleep 10
    
    # Deploy certbot for production
    if [ "$ENV" = "prod" ]; then
        docker-compose --env-file ".env.$ENV" up -d certbot
    fi
    
    # Final health check
    log "Running final health checks..."
    sleep 5
    
    if ! check_health; then
        error "Final health check failed"
        rollback
    fi
    
    log "Deployment completed successfully!"
    
    # Show service status
    log "Service status:"
    docker-compose --env-file ".env.$ENV" ps
    
    # Environment-specific success messages
    case "$ENV" in
        "local")
            info "Application is running at: http://localhost:8000"
            info "Nginx proxy is available at: http://localhost"
            ;;
        "dev")
            info "Application is running at: http://localhost"
            info "Development environment is ready"
            ;;
        "prod")
            info "Production application is running at: https://tonybenoy.com"
            info "HTTP traffic is redirected to HTTPS"
            ;;
    esac
    
    # Clean up old backups (keep only last 5)
    log "Cleaning up old backups..."
    find /tmp -name "tonybenoy-backup-*" -type d -mtime +5 -exec rm -rf {} + 2>/dev/null || true
    
    log "Deployment process completed. Services are running and healthy."
    
    # Show useful commands
    echo ""
    echo "Useful commands for $ENV environment:"
    echo "  View logs: docker-compose --env-file .env.$ENV logs -f"
    echo "  Monitor: $SCRIPT_DIR/monitor.sh"
    echo "  Stop services: docker-compose --env-file .env.$ENV down"
    echo "  Restart service: docker-compose --env-file .env.$ENV restart <service_name>"
}

# Handle script arguments
case "${1:-local}" in
    "local"|"dev"|"prod")
        ENV="$1"
        main
        ;;
    "health")
        ENV="${2:-local}"
        validate_env
        check_health
        ;;
    "backup")
        create_backup
        ;;
    *)
        echo "Usage: $0 [local|dev|prod|health <env>|backup]"
        echo ""
        echo "Environments:"
        echo "  local  - Local development (HTTP, debug mode)"
        echo "  dev    - Development server (HTTP, relaxed security)"
        echo "  prod   - Production server (HTTPS, SSL, security headers)"
        echo ""
        echo "Examples:"
        echo "  $0 local          # Deploy to local environment"
        echo "  $0 prod           # Deploy to production"
        echo "  $0 health prod    # Check production health"
        echo "  $0 backup         # Create backup only"
        exit 1
        ;;
esac