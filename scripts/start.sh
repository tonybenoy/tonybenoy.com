#!/bin/bash

# Quick Start Script for TonyBenoy.com
# Usage: ./scripts/start.sh [local|dev|prod] [--build]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV="${1:-local}"
BUILD_FLAG=""

# Source common functions
source "$SCRIPT_DIR/common.sh"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_FLAG="--build"
            shift
            ;;
        local|dev|prod)
            ENV="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate environment
validate_env "$ENV" "$PROJECT_DIR"

# Ensure /tmp/empty exists for non-local environments
if [ ! -d "/tmp/empty" ]; then
    log "Creating /tmp/empty directory for volume mounting..."
    mkdir -p /tmp/empty
fi

cd "$PROJECT_DIR"

info "Starting TonyBenoy.com in $ENV environment..."

# Check if Docker image exists, build if needed
if ! docker image inspect tonybenoy-com:latest >/dev/null 2>&1; then
    log "Docker image not found. Building services..."
    docker_compose "$ENV" build
elif [ -n "$BUILD_FLAG" ]; then
    log "Building services..."
    docker_compose "$ENV" build
fi

# Start services
log "Starting services..."
docker_compose "$ENV" up -d

# Wait for health check
log "Waiting for services to be ready..."
case "$ENV" in
    "local")
        health_url="http://localhost:8000/health"
        ;;
    *)
        health_url="http://localhost/health"
        ;;
esac

if check_health 30 "$health_url"; then
    log "Services started successfully!"

    # Show access URLs
    case "$ENV" in
        "local")
            info "Application: http://localhost:8000"
            info "Nginx proxy: http://localhost"
            ;;
        "dev")
            info "Application: http://localhost"
            ;;
        "prod")
            info "Production: https://tonybenoy.com"
            info "SSL enabled with automatic redirect"
            ;;
    esac

    echo ""
    echo "Useful commands:"
    echo "  View logs: docker-compose --env-file .env.$ENV logs -f"
    echo "  Stop services: ./scripts/stop.sh $ENV"
else
    error "Services failed health check"
    docker_compose "$ENV" logs --tail=20
    exit 1
fi
