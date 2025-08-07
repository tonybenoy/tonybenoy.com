#!/bin/bash

# create-env.sh - Generate environment configuration files
# Usage: ./scripts/create-env.sh [env_type] [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
DEFAULT_GITHUB_USERNAME="tonybenoy"
DEFAULT_DOMAIN="tonybenoy.com"
DEFAULT_EMAIL="admin@tonybenoy.com"

show_help() {
    echo -e "${BLUE}Create Environment Configuration Files${NC}"
    echo ""
    echo "Usage: $0 [env_type] [options]"
    echo ""
    echo "Environment Types:"
    echo "  local    - Local development with live reload and debug logging"
    echo "  dev      - Development environment with HTTP and debug logging"
    echo "  prod     - Production environment with HTTPS and SSL"
    echo "  all      - Create all three environment files"
    echo ""
    echo "Options:"
    echo "  -u, --username USERNAME    GitHub username (default: $DEFAULT_GITHUB_USERNAME)"
    echo "  -d, --domain DOMAIN        Production domain (default: $DEFAULT_DOMAIN)"
    echo "  -e, --email EMAIL          Email for SSL certificates (default: $DEFAULT_EMAIL)"
    echo "  -t, --token TOKEN          GitHub API token (optional)"
    echo "  -f, --force                Overwrite existing files"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 local                   # Create .env.local"
    echo "  $0 prod -d mysite.com -e admin@mysite.com  # Create .env.prod with custom domain and email"
    echo "  $0 all -u myuser -e admin@example.com -f   # Create all env files, overwrite existing"
    echo ""
}

create_env_local() {
    local file=".env.local"
    local username="$1"
    local email="$2"
    local token="$3"
    local force="$4"

    if [[ -f "$file" && "$force" != "true" ]]; then
        echo -e "${YELLOW}Warning: $file already exists. Use -f to overwrite.${NC}"
        return 1
    fi

    echo -e "${BLUE}Creating $file...${NC}"

    cat > "$file" << EOF
# Local Development Environment Configuration
APP_ENV=local
LOG_LEVEL=DEBUG

# Network Configuration
NGINX_CONFIG=app-dev.conf
HTTPS_PORT=443

# Application Settings
GITHUB_USERNAME=$username
GITHUB_TOKEN=$token
EMAIL=$email
CORS_ORIGINS=["*"]
ALLOWED_HOSTS=["*"]

# Development Mode - Volume mount source code for live reload
CODE_MOUNT=./app

# Redis settings removed
EOF

    echo -e "${GREEN}✓ Created $file${NC}"
}

create_env_dev() {
    local file=".env.dev"
    local username="$1"
    local email="$2"
    local token="$3"
    local force="$4"

    if [[ -f "$file" && "$force" != "true" ]]; then
        echo -e "${YELLOW}Warning: $file already exists. Use -f to overwrite.${NC}"
        return 1
    fi

    echo -e "${BLUE}Creating $file...${NC}"

    cat > "$file" << EOF
# Development Environment Configuration
APP_ENV=dev
LOG_LEVEL=DEBUG

# Network Configuration
NGINX_CONFIG=app-dev.conf
HTTPS_PORT=443

# Application Settings
GITHUB_USERNAME=$username
GITHUB_TOKEN=$token
EMAIL=$email
CORS_ORIGINS=["http://localhost","http://127.0.0.1"]
ALLOWED_HOSTS=["localhost","127.0.0.1"]

# Production Mode - No code mounting
CODE_MOUNT=/tmp/empty

# Redis settings removed
EOF

    echo -e "${GREEN}✓ Created $file${NC}"
}

create_env_prod() {
    local file=".env.prod"
    local username="$1"
    local domain="$2"
    local email="$3"
    local token="$4"
    local force="$5"

    if [[ -f "$file" && "$force" != "true" ]]; then
        echo -e "${YELLOW}Warning: $file already exists. Use -f to overwrite.${NC}"
        return 1
    fi

    echo -e "${BLUE}Creating $file...${NC}"

    cat > "$file" << EOF
# Production Environment Configuration
APP_ENV=prod
LOG_LEVEL=INFO

# Network Configuration
NGINX_CONFIG=app.conf
HTTPS_PORT=443

# Application Settings
GITHUB_USERNAME=$username
GITHUB_TOKEN=$token
EMAIL=$email
CORS_ORIGINS=["https://$domain"]
ALLOWED_HOSTS=["$domain","www.$domain"]

# Production Mode - No code mounting
CODE_MOUNT=/tmp/empty

# Redis settings removed
EOF

    echo -e "${GREEN}✓ Created $file${NC}"
}

# Parse arguments
GITHUB_USERNAME="$DEFAULT_GITHUB_USERNAME"
DOMAIN="$DEFAULT_DOMAIN"
EMAIL="$DEFAULT_EMAIL"
GITHUB_TOKEN=""
FORCE="false"
ENV_TYPE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            GITHUB_USERNAME="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -t|--token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -f|--force)
            FORCE="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        local|dev|prod|all)
            ENV_TYPE="$1"
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Validate input
if [[ -z "$ENV_TYPE" ]]; then
    echo -e "${RED}Error: Environment type required${NC}"
    show_help
    exit 1
fi

# Main logic
case "$ENV_TYPE" in
    local)
        create_env_local "$GITHUB_USERNAME" "$EMAIL" "$GITHUB_TOKEN" "$FORCE"
        ;;
    dev)
        create_env_dev "$GITHUB_USERNAME" "$EMAIL" "$GITHUB_TOKEN" "$FORCE"
        ;;
    prod)
        create_env_prod "$GITHUB_USERNAME" "$DOMAIN" "$EMAIL" "$GITHUB_TOKEN" "$FORCE"
        ;;
    all)
        echo -e "${BLUE}Creating all environment files...${NC}"
        echo ""
        create_env_local "$GITHUB_USERNAME" "$EMAIL" "$GITHUB_TOKEN" "$FORCE" || true
        create_env_dev "$GITHUB_USERNAME" "$EMAIL" "$GITHUB_TOKEN" "$FORCE" || true
        create_env_prod "$GITHUB_USERNAME" "$DOMAIN" "$EMAIL" "$GITHUB_TOKEN" "$FORCE" || true
        ;;
    *)
        echo -e "${RED}Error: Invalid environment type: $ENV_TYPE${NC}"
        show_help
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Environment configuration completed!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Review and customize the created .env files"
echo "  2. Add your GitHub token if needed: GITHUB_TOKEN=your_token_here"
echo "  3. Verify your SSL email is correct: EMAIL=your@email.com"
echo "  4. Start your environment: make start-${ENV_TYPE}"
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo "  make start-local    # Start local development"
echo "  make start-dev      # Start development environment"
echo "  make start-prod     # Start production environment"
