#!/bin/bash

# SSL Certificate Verification Script for Let's Encrypt
# This script automates SSL certificate verification and troubleshooting

set -euo pipefail

# Configuration
DOMAIN="tonybenoy.com"
WWW_DOMAIN="www.tonybenoy.com"
DOCKER_COMPOSE_FILE="docker-compose.yml"
NGINX_CONTAINER="tonybenoy-nginx"
CERTBOT_CONTAINER="tonybenoy-certbot"
CERT_PATH="/etc/letsencrypt/live/${DOMAIN}"

# Load email from environment file if available
load_email_from_env() {
    local env_file="${1:-}"
    if [ -n "${env_file}" ] && [ -f "${env_file}" ]; then
        # Extract EMAIL from env file, handle different formats
        local email_line
        email_line=$(grep -E "^EMAIL=" "${env_file}" 2>/dev/null | head -1)
        if [ -n "${email_line}" ]; then
            # Remove EMAIL= prefix and any quotes
            echo "${email_line#EMAIL=}" | sed 's/^["'\'']*//;s/["'\'']*$//'
        fi
    fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if containers are running
check_containers() {
    print_status "Checking container status..."
    
    if ! docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "${NGINX_CONTAINER}"; then
        print_error "Nginx container (${NGINX_CONTAINER}) is not running"
        return 1
    fi
    
    if ! docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "${CERTBOT_CONTAINER}"; then
        print_warning "Certbot container (${CERTBOT_CONTAINER}) is not running"
    fi
    
    print_success "Required containers are running"
}

# Function to check certificate files
check_cert_files() {
    print_status "Checking SSL certificate files..."
    
    # Check if certificates exist in the certbot container
    if docker exec "${CERTBOT_CONTAINER}" test -f "${CERT_PATH}/fullchain.pem" && \
       docker exec "${CERTBOT_CONTAINER}" test -f "${CERT_PATH}/privkey.pem"; then
        print_success "Certificate files exist"
        
        # Check certificate expiration
        local expiry_date
        expiry_date=$(docker exec "${CERTBOT_CONTAINER}" openssl x509 -in "${CERT_PATH}/fullchain.pem" -noout -enddate | cut -d= -f2)
        local expiry_epoch
        expiry_epoch=$(date -d "${expiry_date}" +%s)
        local current_epoch
        current_epoch=$(date +%s)
        local days_until_expiry
        days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        echo "Certificate expires on: ${expiry_date}"
        echo "Days until expiry: ${days_until_expiry}"
        
        if [ "${days_until_expiry}" -lt 30 ]; then
            print_warning "Certificate expires in less than 30 days!"
        else
            print_success "Certificate is valid for ${days_until_expiry} more days"
        fi
    else
        print_error "Certificate files not found. Need to obtain certificates first."
        return 1
    fi
}

# Function to verify ACME challenge accessibility
test_acme_challenge() {
    print_status "Testing ACME challenge accessibility..."
    
    # Create a test file
    local test_file="acme-test-$(date +%s).txt"
    local test_content="ACME challenge test"
    
    # Create test file in certbot www directory
    docker exec "${CERTBOT_CONTAINER}" sh -c "echo '${test_content}' > /var/www/certbot/${test_file}"
    
    # Test accessibility via HTTP
    local test_url="http://${DOMAIN}/.well-known/acme-challenge/${test_file}"
    
    if curl -s -f "${test_url}" | grep -q "${test_content}"; then
        print_success "ACME challenge path is accessible"
        # Clean up test file
        docker exec "${CERTBOT_CONTAINER}" rm -f "/var/www/certbot/${test_file}"
        return 0
    else
        print_error "ACME challenge path is not accessible at ${test_url}"
        # Clean up test file
        docker exec "${CERTBOT_CONTAINER}" rm -f "/var/www/certbot/${test_file}" 2>/dev/null || true
        return 1
    fi
}

# Function to test SSL connectivity
test_ssl_connection() {
    print_status "Testing SSL connection..."
    
    local ssl_test_result
    if ssl_test_result=$(echo | openssl s_client -connect "${DOMAIN}:443" -servername "${DOMAIN}" 2>/dev/null | openssl x509 -noout -subject -dates 2>/dev/null); then
        print_success "SSL connection successful"
        echo "${ssl_test_result}"
        return 0
    else
        print_error "SSL connection failed"
        return 1
    fi
}

# Function to verify nginx SSL configuration
verify_nginx_config() {
    print_status "Verifying nginx SSL configuration..."
    
    if docker exec "${NGINX_CONTAINER}" nginx -t; then
        print_success "Nginx configuration is valid"
    else
        print_error "Nginx configuration has errors"
        return 1
    fi
}

# Function to check DNS resolution
check_dns() {
    print_status "Checking DNS resolution..."
    
    for domain in "${DOMAIN}" "${WWW_DOMAIN}"; do
        local ip
        if ip=$(getent hosts "${domain}" | awk '{print $1}' | head -1); then
            if [ -n "${ip}" ]; then
                print_success "DNS resolves ${domain} to ${ip}"
            else
                print_error "DNS resolution failed for ${domain}"
                return 1
            fi
        else
            print_error "DNS lookup failed for ${domain}"
            return 1
        fi
    done
}

# Function to obtain new certificates
obtain_certificates() {
    local email="${1:-}"
    
    # Try to load email from environment file if not provided
    if [ -z "${email}" ]; then
        # Try production first, then dev, then local
        for env_file in ".env.prod" ".env.dev" ".env.local"; do
            if [ -f "${env_file}" ]; then
                email=$(load_email_from_env "${env_file}")
                if [ -n "${email}" ]; then
                    print_status "Using email from ${env_file}: ${email}"
                    break
                fi
            fi
        done
    fi
    
    if [ -z "${email}" ]; then
        print_error "Email address required for certificate registration"
        echo "Usage: $0 obtain <email@example.com>"
        echo "Or set EMAIL=your@email.com in your .env file"
        return 1
    fi
    
    print_status "Obtaining new SSL certificates for ${DOMAIN} and ${WWW_DOMAIN}..."
    print_status "Using email: ${email}"
    
    # Check if we're in production environment (HTTPS setup)
    local env_file=".env.prod"
    if [ -f "${env_file}" ]; then
        source "${env_file}"
        if [ "${NGINX_CONFIG}" != "app.conf" ]; then
            print_warning "Not in production environment. Consider using 'first-time' command instead."
        fi
    fi
    
    # Use webroot mode with nginx running
    print_status "Using webroot mode with nginx running..."
    
    # Run certbot to obtain certificates
    print_status "Running certbot to obtain certificates..."
    if docker-compose run --rm --entrypoint "" certbot certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "${email}" \
        --agree-tos \
        --no-eff-email \
        -d "${DOMAIN}" \
        -d "${WWW_DOMAIN}"; then
        print_success "Certificates obtained successfully"
    else
        print_error "Failed to obtain certificates"
        docker-compose up -d
        return 1
    fi
    
    # Services are already running - no need to restart
    print_status "Certificates obtained with services running"
    
    # Wait for nginx to be ready
    sleep 10
    
    print_success "Certificate obtainment complete"
}

# Function for first-time SSL setup (starts with HTTP, then gets SSL)
first_time_setup() {
    local email="${1:-}"
    
    # Try to load email from environment file if not provided
    if [ -z "${email}" ]; then
        # Try production first, then dev, then local
        for env_file in ".env.prod" ".env.dev" ".env.local"; do
            if [ -f "${env_file}" ]; then
                email=$(load_email_from_env "${env_file}")
                if [ -n "${email}" ]; then
                    print_status "Using email from ${env_file}: ${email}"
                    break
                fi
            fi
        done
    fi
    
    if [ -z "${email}" ]; then
        print_error "Email address required for certificate registration"
        echo "Usage: $0 first-time <email@example.com>"
        echo "Or set EMAIL=your@email.com in your .env file"
        return 1
    fi
    
    print_status "Starting first-time SSL setup..."
    print_status "This will:"
    print_status "1. Start with HTTP-only configuration"
    print_status "2. Obtain SSL certificates"
    print_status "3. Switch to HTTPS configuration"
    print_status "4. Restart with SSL enabled"
    
    # Ensure we start with development (HTTP) configuration
    print_status "Step 1: Starting with HTTP-only configuration..."
    
    # Stop any running containers
    docker-compose down 2>/dev/null || true
    
    # Start with development environment (HTTP only)
    if [ -f ".env.dev" ]; then
        docker-compose --env-file .env.dev up -d
    else
        print_error ".env.dev file not found. Creating basic development environment..."
        cat > .env.dev << EOF
APP_ENV=dev
NGINX_CONFIG=app-dev.conf
HTTPS_PORT=443
LOG_LEVEL=DEBUG
GITHUB_USERNAME=tonybenoy
GITHUB_TOKEN=
CORS_ORIGINS=["*"]
ALLOWED_HOSTS=["*"]
CODE_MOUNT=/tmp/empty
EOF
        docker-compose --env-file .env.dev up -d
    fi
    
    # Wait for services to be ready
    print_status "Waiting for services to start..."
    sleep 15
    
    # Skip ACME challenge test for webroot mode - certbot will handle its own verification
    print_status "Step 2: Skipping ACME challenge test (using webroot mode)..."
    
    # Step 3: Create dummy certificate to allow nginx to start with SSL config
    print_status "Step 3: Creating dummy certificate for ${DOMAIN}..."
    docker-compose run --rm --entrypoint "/bin/sh" certbot -c "\
      mkdir -p /etc/letsencrypt/live/${DOMAIN} && \
      openssl req -x509 -nodes -newkey rsa:4096 -days 1 \
        -keyout '/etc/letsencrypt/live/${DOMAIN}/privkey.pem' \
        -out '/etc/letsencrypt/live/${DOMAIN}/fullchain.pem' \
        -subj '/CN=localhost'"
    
    # Step 4: Switch to production (HTTPS) configuration with dummy certs
    print_status "Step 4: Switching to HTTPS configuration with dummy certificates..."
    docker-compose down
    if [ -f ".env.prod" ]; then
        docker-compose --env-file .env.prod up -d
    else
        print_error ".env.prod file not found"
        return 1
    fi
    
    # Wait for nginx to start with dummy certs
    sleep 10
    
    # Step 5: Delete dummy certificate
    print_status "Step 5: Deleting dummy certificate..."
    docker-compose run --rm --entrypoint "/bin/sh" certbot -c "\
      rm -Rf /etc/letsencrypt/live/${DOMAIN} && \
      rm -Rf /etc/letsencrypt/archive/${DOMAIN} && \
      rm -Rf /etc/letsencrypt/renewal/${DOMAIN}.conf"
    
    # Step 6: Get real certificates via webroot (nginx running)
    print_status "Step 6a: Testing with staging certificates first..."
    if docker-compose run --rm --entrypoint "" certbot certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --staging \
        --email "${email}" \
        --agree-tos \
        --no-eff-email \
        -d "${DOMAIN}" \
        -d "${WWW_DOMAIN}"; then
        print_success "Staging certificates obtained successfully!"
        
        # Remove staging certificates
        print_status "Step 6b: Removing staging certificates..."
        docker-compose run --rm --entrypoint "/bin/sh" certbot -c "\
          rm -Rf /etc/letsencrypt/live/${DOMAIN} && \
          rm -Rf /etc/letsencrypt/archive/${DOMAIN} && \
          rm -Rf /etc/letsencrypt/renewal/${DOMAIN}.conf"
        
        # Now get production certificates
        print_status "Step 6c: Obtaining production SSL certificates..."
        if docker-compose run --rm --entrypoint "" certbot certbot certonly \
            --webroot \
            --webroot-path=/var/www/certbot \
            --email "${email}" \
            --agree-tos \
            --no-eff-email \
            -d "${DOMAIN}" \
            -d "${WWW_DOMAIN}"; then
            print_success "Production SSL certificates obtained successfully"
            
            # Reload nginx to use new certificates
            print_status "Step 7: Reloading nginx with real certificates..."
            docker-compose exec nginx nginx -s reload
        else
            print_error "Failed to obtain production SSL certificates"
            # Restart with HTTP configuration
            docker-compose down
            docker-compose --env-file .env.dev up -d
            return 1
        fi
    else
        print_error "Failed to obtain staging SSL certificates - setup validation failed"
        # Restart with HTTP configuration
        docker-compose down
        docker-compose --env-file .env.dev up -d
        return 1
    fi
    
    # Wait for nginx reload
    print_status "Waiting for nginx to reload with SSL certificates..."
    sleep 10
    
    # Verify SSL is working
    print_status "Step 8: Verifying SSL configuration..."
    if test_ssl_connection; then
        print_success "✅ First-time SSL setup completed successfully!"
        print_success "Your website is now accessible at:"
        print_success "  - https://${DOMAIN}"
        print_success "  - https://${WWW_DOMAIN}"
        show_cert_info
    else
        print_error "SSL verification failed. Check logs with: docker-compose logs nginx"
        return 1
    fi
}

# Function to renew certificates
renew_certificates() {
    print_status "Renewing SSL certificates..."
    
    if docker exec "${CERTBOT_CONTAINER}" certbot renew --dry-run; then
        print_success "Certificate renewal test passed"
        
        # Perform actual renewal
        if docker exec "${CERTBOT_CONTAINER}" certbot renew; then
            print_success "Certificates renewed successfully"
            
            # Reload nginx to use new certificates
            docker exec "${NGINX_CONTAINER}" nginx -s reload
            print_success "Nginx reloaded with new certificates"
        else
            print_error "Certificate renewal failed"
            return 1
        fi
    else
        print_error "Certificate renewal dry-run failed"
        return 1
    fi
}

# Function to show certificate information
show_cert_info() {
    print_status "Certificate Information:"
    
    if docker exec "${CERTBOT_CONTAINER}" test -f "${CERT_PATH}/fullchain.pem"; then
        echo "=========================================="
        docker exec "${CERTBOT_CONTAINER}" openssl x509 -in "${CERT_PATH}/fullchain.pem" -noout -text | grep -A 2 "Validity"
        echo "=========================================="
        docker exec "${CERTBOT_CONTAINER}" openssl x509 -in "${CERT_PATH}/fullchain.pem" -noout -text | grep -A 10 "Subject Alternative Name"
        echo "=========================================="
    else
        print_error "No certificate found to display"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  first-time [email]  - Complete first-time SSL setup (HTTP → HTTPS)"
    echo "  check               - Run all verification checks"
    echo "  obtain [email]      - Obtain new SSL certificates"
    echo "  renew               - Renew existing certificates"
    echo "  test                - Test SSL connection and ACME challenge"
    echo "  info                - Show certificate information"
    echo "  help                - Show this help message"
    echo ""
    echo "Email Configuration:"
    echo "  Email can be provided as command argument or set in .env files"
    echo "  Set EMAIL=your@email.com in .env.prod, .env.dev, or .env.local"
    echo ""
    echo "Examples:"
    echo "  $0 first-time admin@tonybenoy.com    # First-time setup with email"
    echo "  $0 first-time                       # Uses email from .env file"
    echo "  $0 check                             # Verify current setup"
    echo "  $0 renew                             # Renew certificates"
    echo ""
    echo "If no command is provided, 'check' will be run by default."
}

# Main function
main() {
    local command="${1:-check}"
    
    case "${command}" in
        check)
            echo "=== SSL Certificate Verification ==="
            check_containers
            check_dns
            check_cert_files
            verify_nginx_config
            test_acme_challenge
            test_ssl_connection
            show_cert_info
            print_success "All SSL verification checks completed"
            ;;
        first-time)
            echo "=== First-Time SSL Setup ==="
            check_dns
            first_time_setup "${2:-}"
            ;;
        obtain)
            echo "=== Obtaining SSL Certificates ==="
            check_containers
            check_dns
            test_acme_challenge
            obtain_certificates "${2:-}"
            ;;
        renew)
            echo "=== Renewing SSL Certificates ==="
            check_containers
            renew_certificates
            ;;
        test)
            echo "=== Testing SSL and ACME ==="
            check_containers
            test_acme_challenge
            test_ssl_connection
            ;;
        info)
            echo "=== Certificate Information ==="
            show_cert_info
            ;;
        help)
            show_usage
            ;;
        *)
            print_error "Unknown command: ${command}"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"