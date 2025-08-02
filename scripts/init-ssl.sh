#!/bin/bash

# SSL Certificate Initialization Script for TonyBenoy.com
# This script automates Let's Encrypt SSL certificate setup using your existing infrastructure
# It tests with staging first, then issues production certificates

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env.prod"

# Default values
STAGING=true
FORCE_RENEWAL=false
SKIP_STAGING=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Automated SSL certificate initialization for TonyBenoy.com using Let's Encrypt.

OPTIONS:
    -e, --email EMAIL       Email address for Let's Encrypt (required)
    -d, --domain DOMAIN     Domain name (default: from .env.prod)
    --skip-staging          Skip staging test and go directly to production
    --force                 Force certificate renewal even if valid certificates exist
    -h, --help              Show this help message

EXAMPLES:
    $0 --email admin@tonybenoy.com
    $0 --email admin@tonybenoy.com --domain tonybenoy.com
    $0 --email admin@tonybenoy.com --skip-staging
    $0 --email admin@tonybenoy.com --force

The script will:
1. Validate the domain and email
2. Start containers with HTTP-only nginx config
3. Test with Let's Encrypt staging (unless --skip-staging)
4. If staging succeeds, get production certificates
5. Switch to HTTPS nginx config and restart

EOF
}

# Function to extract domain from .env.prod
get_domain_from_env() {
    if [[ -f "$ENV_FILE" ]]; then
        # Extract primary domain from ALLOWED_HOSTS
        DOMAIN=$(grep "ALLOWED_HOSTS" "$ENV_FILE" | sed 's/.*\["//' | sed 's/",.*//' | sed 's/".*//')
        if [[ -n "$DOMAIN" && "$DOMAIN" != "*" ]]; then
            echo "$DOMAIN"
            return 0
        fi
    fi
    return 1
}

# Function to validate email
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        print_error "Invalid email format: $email"
        return 1
    fi
    return 0
}

# Function to validate domain
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
        print_error "Invalid domain format: $domain"
        return 1
    fi
    return 0
}

# Function to check if domain points to this server
check_domain_dns() {
    local domain="$1"
    print_status "Checking DNS resolution for $domain..."
    
    # Get domain's IP
    DOMAIN_IP=$(getnet +short "$domain" | tail -n1)
    
    if [[ -z "$DOMAIN_IP" ]]; then
        print_warning "Could not resolve domain $domain. Please ensure DNS is configured correctly."
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Aborting due to DNS issues"
            exit 1
        fi
        return 1
    fi
    
    print_success "Domain $domain resolves to $DOMAIN_IP"
    return 0
}

# Function to check if certificates already exist
check_existing_certificates() {
    local domain="$1"
    
    if docker-compose --env-file "$ENV_FILE" exec -T certbot test -f "/etc/letsencrypt/live/$domain/fullchain.pem" 2>/dev/null; then
        print_warning "Certificates already exist for $domain"
        
        if [[ "$FORCE_RENEWAL" == "false" ]]; then
            read -p "Renew existing certificates? [y/N]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Using existing certificates"
                return 1
            fi
        fi
        
        print_status "Will renew existing certificates"
    fi
    return 0
}

# Function to create temporary HTTP-only nginx config
create_temp_nginx_config() {
    local domain="$1"
    
    print_status "Creating temporary HTTP-only nginx configuration..."
    
    cat > "$PROJECT_DIR/nginx/app-temp-ssl.conf" << EOF
# Temporary configuration for SSL certificate initialization
server {
    listen 80;
    server_name $domain www.$domain;
    
    # Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
    }
    
    # Temporary response for other requests during setup
    location / {
        return 200 'SSL Certificate Setup In Progress...';
        add_header Content-Type text/plain;
    }
}
EOF
    
    print_success "Temporary nginx config created"
}

# Function to start containers with temporary config
start_temp_containers() {
    print_status "Starting containers with temporary HTTP-only configuration..."
    
    # Stop any running containers
    docker-compose --env-file "$ENV_FILE" down 2>/dev/null || true
    
    # Start with temporary nginx config
    NGINX_CONFIG=app-temp-ssl.conf docker-compose --env-file "$ENV_FILE" up -d nginx certbot
    
    # Wait for nginx to be ready
    print_status "Waiting for nginx to be ready..."
    for i in {1..30}; do
        if curl -sf http://localhost/.well-known/acme-challenge/test 2>/dev/null; then
            break
        fi
        sleep 2
    done
    
    print_success "Containers started successfully"
}

# Function to obtain SSL certificate
obtain_certificate() {
    local domain="$1"
    local email="$2"
    local staging="$3"
    
    local staging_flag=""
    local cert_type="PRODUCTION"
    
    if [[ "$staging" == "true" ]]; then
        staging_flag="--staging"
        cert_type="STAGING"
    fi
    
    print_status "Obtaining $cert_type SSL certificate for $domain..."
    
    # Run certbot to obtain certificate
    if docker-compose --env-file "$ENV_FILE" exec -T certbot certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$email" \
        --agree-tos \
        --no-eff-email \
        $staging_flag \
        --force-renewal \
        -d "$domain" \
        -d "www.$domain"; then
        
        print_success "$cert_type certificate obtained successfully!"
        return 0
    else
        print_error "Failed to obtain $cert_type certificate"
        return 1
    fi
}

# Function to switch to production nginx config
switch_to_production_config() {
    print_status "Switching to production HTTPS nginx configuration..."
    
    # Stop containers
    docker-compose --env-file "$ENV_FILE" down
    
    # Start all services with production config
    docker-compose --env-file "$ENV_FILE" up -d
    
    # Wait for services to be ready
    print_status "Waiting for services to start..."
    sleep 10
    
    # Test HTTPS
    local domain="$1"
    for i in {1..30}; do
        if curl -sf "https://$domain/test" 2>/dev/null; then
            print_success "HTTPS is working correctly!"
            return 0
        fi
        sleep 2
    done
    
    print_warning "HTTPS test failed, but certificates may still be working"
    return 0
}

# Function to cleanup temporary files
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f "$PROJECT_DIR/nginx/app-temp-ssl.conf"
}

# Function to show final status
show_final_status() {
    local domain="$1"
    
    echo
    print_success "SSL Certificate initialization completed!"
    echo
    echo "🎉 Your website is now secured with Let's Encrypt SSL!"
    echo
    echo "📝 Summary:"
    echo "   - Domain: $domain"
    echo "   - Certificate: Let's Encrypt"
    echo "   - HTTPS URL: https://$domain"
    echo "   - Auto-renewal: Enabled (via certbot container)"
    echo
    echo "🔧 Next steps:"
    echo "   - Test your site: https://$domain"
    echo "   - Monitor logs: make logs-prod"
    echo "   - Check renewal: make ssl-renew"
    echo
}

# Main execution function
main() {
    local email=""
    local domain=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--email)
                email="$2"
                shift 2
                ;;
            -d|--domain)
                domain="$2"
                shift 2
                ;;
            --skip-staging)
                SKIP_STAGING=true
                shift
                ;;
            --force)
                FORCE_RENEWAL=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Check if email is provided
    if [[ -z "$email" ]]; then
        echo
        print_error "Email address is required for Let's Encrypt registration"
        echo
        read -p "Enter your email address: " email
        echo
    fi
    
    # Validate email
    if ! validate_email "$email"; then
        exit 1
    fi
    
    # Get domain from .env.prod if not provided
    if [[ -z "$domain" ]]; then
        if ! domain=$(get_domain_from_env); then
            print_error "Could not extract domain from $ENV_FILE"
            echo
            read -p "Enter your domain name: " domain
            echo
        fi
    fi
    
    # Validate domain
    if ! validate_domain "$domain"; then
        exit 1
    fi
    
    # Check if .env.prod exists
    if [[ ! -f "$ENV_FILE" ]]; then
        print_error "Production environment file not found: $ENV_FILE"
        print_status "Run 'make create-env-prod DOMAIN=$domain' first"
        exit 1
    fi
    
    print_status "Starting SSL certificate initialization for $domain"
    print_status "Email: $email"
    echo
    
    # Check DNS
    check_domain_dns "$domain"
    
    # Check existing certificates
    if ! check_existing_certificates "$domain"; then
        print_success "Using existing certificates, switching to production config..."
        switch_to_production_config "$domain"
        show_final_status "$domain"
        return 0
    fi
    
    # Create temporary nginx config
    create_temp_nginx_config "$domain"
    
    # Set up error handling for cleanup
    trap cleanup EXIT
    
    # Start containers with temporary config
    start_temp_containers
    
    # Test with staging first (unless skipped)
    if [[ "$SKIP_STAGING" == "false" ]]; then
        print_status "Testing with Let's Encrypt staging environment..."
        
        if obtain_certificate "$domain" "$email" "true"; then
            print_success "Staging test completed successfully!"
            echo
            print_status "Proceeding with production certificate..."
        else
            print_error "Staging test failed!"
            print_error "Please check your domain configuration and try again"
            exit 1
        fi
    else
        print_warning "Skipping staging test as requested"
    fi
    
    # Obtain production certificate
    if obtain_certificate "$domain" "$email" "false"; then
        print_success "Production certificate obtained!"
    else
        print_error "Failed to obtain production certificate"
        exit 1
    fi
    
    # Switch to production configuration
    switch_to_production_config "$domain"
    
    # Show final status
    show_final_status "$domain"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi