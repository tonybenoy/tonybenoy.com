#!/bin/bash

# Quick Start Script for TonyBenoy.com
# Usage: ./scripts/start.sh [local|dev|prod] [--build]

set -e

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

# Wait for services to be ready
log "Waiting for services to start..."
sleep 10

# Check if services are running
if docker_compose "$ENV" ps | grep -q "Up"; then
    log "Services started successfully!"
    
    # Show access URLs
    case "$ENV" in
        "local")
            info "🌐 Application: http://localhost:8000"
            info "🔧 Nginx proxy: http://localhost"
            ;;
        "dev")
            info "🌐 Application: http://localhost"
            info "🔧 Development server ready"
            ;;
        "prod")
            info "🌐 Production: https://tonybenoy.com"
            info "🔒 SSL enabled with automatic redirect"
            ;;
    esac
    
    echo ""
    echo "Useful commands:"
    echo "  📋 View logs: ./scripts/start.sh $ENV logs -f"
    echo "  📊 Service status: ./scripts/start.sh $ENV ps"  
    echo "  🛑 Stop services: ./scripts/stop.sh $ENV"
    echo "  🔄 Restart service: ./scripts/start.sh $ENV restart <service>"
    echo "  🏥 Health check: curl http://localhost/test (or :8000 for local)"
else
    error "Failed to start services"
    exit 1
fi