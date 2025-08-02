#!/bin/bash

# Clear nginx cache on deployment
# Usage: ./scripts/clear-cache.sh [local|dev|prod]

set -e

ENV="${1:-local}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

cd "$PROJECT_DIR"

if [ ! -f ".env.$ENV" ]; then
    echo "Error: .env.$ENV file not found"
    exit 1
fi

# Check if nginx container is running
if docker-compose --env-file ".env.$ENV" ps nginx | grep -q "Up"; then
    log "Clearing nginx cache for $ENV environment..."
    
    # Send nginx reload signal to clear cache
    docker-compose --env-file ".env.$ENV" exec nginx nginx -s reload
    
    # Alternative: restart nginx container for complete cache clear
    # docker-compose --env-file ".env.$ENV" restart nginx
    
    log "Nginx cache cleared for $ENV environment"
else
    info "Nginx container not running for $ENV environment"
fi

# Clear browser cache headers by adding timestamp
TIMESTAMP=$(date +%s)
info "Cache busting timestamp: $TIMESTAMP"
info "For immediate cache clear, use browser hard refresh (Ctrl+F5)"