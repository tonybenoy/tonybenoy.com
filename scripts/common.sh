#!/bin/bash

# Common utility functions for TonyBenoy.com scripts
# Source this file in other scripts: source "$(dirname "$0")/common.sh"

set -euo pipefail

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# Common logging functions
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

# Retry a command with backoff
# Usage: retry <max_attempts> <delay_seconds> <command...>
retry() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    local attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
        if "$@"; then
            return 0
        fi
        if [ "$attempt" -lt "$max_attempts" ]; then
            log "Attempt $attempt/$max_attempts failed, retrying in ${delay}s..."
            sleep "$delay"
        fi
        attempt=$((attempt + 1))
    done

    error "Command failed after $max_attempts attempts"
    return 1
}

# Common health check function using retry
check_health() {
    local retries="${1:-30}"
    local health_url="${2:-http://localhost:8000/health}"

    log "Checking application health at $health_url..."

    if retry "$retries" 2 curl -f -s -o /dev/null "$health_url"; then
        log "Health check passed"
        return 0
    else
        error "Health check failed after $retries attempts"
        return 1
    fi
}

# Common environment validation
validate_env() {
    local env="$1"
    local project_dir="$2"

    case "$env" in
        "local"|"dev"|"prod")
            info "Using $env environment"
            ;;
        *)
            error "Invalid environment: $env. Use: local, dev, or prod"
            exit 1
            ;;
    esac

    if [ ! -f "$project_dir/.env.$env" ]; then
        error "Environment file .env.$env not found"
        exit 1
    fi
}

# Common size calculation
calculate_size() {
    local path="$1"
    if [ -d "$path" ]; then
        du -sh "$path" 2>/dev/null | cut -f1 || echo "unknown"
    else
        echo "0"
    fi
}

# Docker compose helper with environment
docker_compose() {
    local env="$1"
    shift
    docker-compose --env-file ".env.$env" "$@"
}
