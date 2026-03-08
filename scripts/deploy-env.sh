#!/bin/bash

# Environment-based Deployment Script for TonyBenoy.com
# Usage: ./scripts/deploy-env.sh [local|dev|prod]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV="${1:-local}"

# Source common functions
source "$SCRIPT_DIR/common.sh"

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
            if ! docker-compose --env-file ".env.$ENV" config | grep -q "letsencrypt"; then
                warn "SSL certificates may not be configured. Run ./scripts/init-ssl.sh first."
            fi
            ;;
    esac
}

# Get health URL for current environment
get_health_url() {
    if [ "$ENV" = "local" ]; then
        echo "http://localhost:8000/health"
    else
        echo "http://localhost/health"
    fi
}

# Main deployment process
main() {
    log "Starting deployment of TonyBenoy.com..."
    log "Environment: $ENV"

    cd "$PROJECT_DIR"

    # Validate environment
    validate_env "$ENV" "$PROJECT_DIR"

    # Configure environment-specific settings
    configure_environment

    # Pre-deployment checks
    log "Running pre-deployment checks..."

    if [ ! -f "docker-compose.yml" ]; then
        error "docker-compose.yml not found"
        exit 1
    fi

    if ! docker-compose --env-file ".env.$ENV" config >/dev/null 2>&1; then
        error "Invalid docker-compose configuration for $ENV environment"
        exit 1
    fi

    # Pull latest images
    log "Pulling latest images..."
    docker-compose --env-file ".env.$ENV" pull || true

    # Build application image
    log "Building application image..."
    docker-compose --env-file ".env.$ENV" build fastapi

    # Deploy application
    log "Deploying application..."
    docker-compose --env-file ".env.$ENV" up -d fastapi

    log "Waiting for application to be ready..."
    local health_url
    health_url=$(get_health_url)

    if ! check_health 30 "$health_url"; then
        error "Application health check failed"
        docker-compose --env-file ".env.$ENV" logs --tail=30 fastapi
        exit 1
    fi

    # Deploy nginx
    docker-compose --env-file ".env.$ENV" up -d nginx

    # Deploy certbot for production
    if [ "$ENV" = "prod" ]; then
        docker-compose --env-file ".env.$ENV" up -d certbot
    fi

    # Final health check
    log "Running final health check..."
    if ! check_health 15 "$health_url"; then
        error "Final health check failed"
        docker-compose --env-file ".env.$ENV" logs --tail=30
        exit 1
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
            ;;
        "prod")
            info "Production application is running at: https://tonybenoy.com"
            info "HTTP traffic is redirected to HTTPS"
            ;;
    esac

    echo ""
    echo "Useful commands for $ENV environment:"
    echo "  View logs: docker-compose --env-file .env.$ENV logs -f"
    echo "  Monitor: $SCRIPT_DIR/monitor.sh $ENV"
    echo "  Stop services: docker-compose --env-file .env.$ENV down"
}

# Handle script arguments
case "${1:-local}" in
    "local"|"dev"|"prod")
        ENV="$1"
        main
        ;;
    "health")
        ENV="${2:-local}"
        validate_env "$ENV" "$PROJECT_DIR"
        check_health 10 "$(get_health_url)"
        ;;
    *)
        echo "Usage: $0 [local|dev|prod|health <env>]"
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
        exit 1
        ;;
esac
