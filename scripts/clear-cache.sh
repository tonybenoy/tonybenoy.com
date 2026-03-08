#!/bin/bash

# Clear nginx cache on deployment
# Usage: ./scripts/clear-cache.sh [local|dev|prod]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV="${1:-local}"

# Source common functions
source "$SCRIPT_DIR/common.sh"

cd "$PROJECT_DIR"

if [ ! -f ".env.$ENV" ]; then
    error ".env.$ENV file not found"
    exit 1
fi

# Check if nginx container is running
if docker_compose "$ENV" ps nginx 2>/dev/null | grep -q "Up\|running"; then
    log "Clearing nginx cache for $ENV environment..."

    # Clear proxy cache files if the cache directory exists
    docker_compose "$ENV" exec -T nginx sh -c 'rm -rf /var/cache/nginx/* 2>/dev/null; true'

    # Reload nginx to pick up changes
    docker_compose "$ENV" exec -T nginx nginx -s reload

    log "Nginx cache cleared for $ENV environment"
else
    info "Nginx container not running for $ENV environment"
fi
