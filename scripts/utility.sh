#!/bin/bash

# Utility Script for TonyBenoy.com - Common operations
# Usage: ./scripts/utility.sh <command> [environment] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common functions
source "$SCRIPT_DIR/common.sh"

show_usage() {
    cat << EOF
Usage: $0 <command> [environment] [options]

Commands:
  logs [env]        - View logs for environment
  ps [env]          - Show service status  
  restart [env]     - Restart all services
  health [env]      - Check service health
  exec [env] <svc>  - Execute shell in service
  build [env]       - Build services
  pull [env]        - Pull latest images

Environment: local, dev, prod (default: local)

Examples:
  $0 logs prod             # View production logs
  $0 ps dev                # Show dev service status
  $0 restart local         # Restart local services
  $0 health prod           # Check production health
  $0 exec dev nginx bash   # Shell into nginx container

EOF
}

# Get environment from arguments or default to local
get_env() {
    local env="${1:-local}"
    case "$env" in
        local|dev|prod) echo "$env" ;;
        *) echo "local" ;;
    esac
}

main() {
    local command="$1"
    local env=$(get_env "$2")
    
    if [ -z "$command" ]; then
        show_usage
        exit 1
    fi
    
    cd "$PROJECT_DIR"
    
    # Validate environment exists
    if [ ! -f ".env.$env" ]; then
        error "Environment file .env.$env not found"
        exit 1
    fi
    
    case "$command" in
        "logs")
            info "Viewing logs for $env environment..."
            docker_compose "$env" logs -f
            ;;
        "ps"|"status")
            info "Service status for $env environment:"
            docker_compose "$env" ps
            ;;
        "restart")
            info "Restarting services in $env environment..."
            docker_compose "$env" restart
            log "Services restarted successfully"
            ;;
        "health")
            case "$env" in
                "local") check_health 10 "http://localhost:8000/health" ;;
                *) check_health 10 "http://localhost/health" ;;
            esac
            ;;
        "exec")
            local service="$3"
            local shell="${4:-sh}"
            if [ -z "$service" ]; then
                error "Service name required for exec command"
                exit 1
            fi
            info "Executing $shell in $service..."
            docker_compose "$env" exec "$service" "$shell"
            ;;
        "build")
            info "Building services for $env environment..."
            docker_compose "$env" build
            log "Build completed successfully"
            ;;
        "pull")
            info "Pulling latest images for $env environment..."
            docker_compose "$env" pull
            log "Pull completed successfully"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"