#!/bin/bash

# Stop Script for TonyBenoy.com
# Usage: ./scripts/stop.sh [local|dev|prod] [--remove-volumes]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV="${1:-local}"
REMOVE_VOLUMES=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-volumes)
            REMOVE_VOLUMES="-v"
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

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}"
}

# Validate environment
if [ ! -f "$PROJECT_DIR/.env.$ENV" ]; then
    error "Environment file .env.$ENV not found"
    exit 1
fi

cd "$PROJECT_DIR"

log "Stopping TonyBenoy.com in $ENV environment..."

# Stop and remove containers
if [ -n "$REMOVE_VOLUMES" ]; then
    warn "Removing volumes - all data will be lost!"
    docker-compose --env-file ".env.$ENV" down $REMOVE_VOLUMES
else
    docker-compose --env-file ".env.$ENV" down
fi

log "Services stopped successfully!"

# Show cleanup commands
echo ""
echo "Additional cleanup commands:"
echo "  🧹 Remove unused images: docker image prune -f"
echo "  🗑️  Remove all unused resources: docker system prune -f"
if [ -z "$REMOVE_VOLUMES" ]; then
    echo "  💾 Remove volumes: $0 $ENV --remove-volumes"
fi