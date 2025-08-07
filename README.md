# tonybenoy.com

[![CI](https://github.com/tonybenoy/tonybenoy.com/workflows/CI/badge.svg)](https://github.com/tonybenoy/tonybenoy.com/actions)
[![codecov](https://codecov.io/gh/tonybenoy/tonybenoy.com/branch/master/graph/badge.svg)](https://codecov.io/gh/tonybenoy/tonybenoy.com)
[![Python](https://img.shields.io/badge/python-3.11%2B-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110%2B-009688.svg)](https://fastapi.tiangolo.com/)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?logo=docker&logoColor=white)](https://www.docker.com/)
[![License](https://img.shields.io/badge/license-AGPL--v3-green)](LICENSE)
[![Code style: Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)

Personal website built with FastAPI and served via Docker with nginx reverse proxy. The application fetches and displays GitHub repository information with in-memory caching.

## Architecture

- **Framework**: FastAPI with Jinja2 templating
- **Structure**: Modular routing in `app/routes/` with separate routers for home and apps
- **Static Files**: CSS, images, and files served from `app/static/`
- **Templates**: HTML templates in `app/templates/` using base template inheritance
- **Caching**: Simple in-memory cache for GitHub API response caching
- **Deployment**: Docker Compose with nginx, FastAPI app, and Let's Encrypt certbot
- **Package Management**: uv for fast Python dependency management

## Quick Start

**Prerequisites:**
- Docker and Docker Compose
- Make (optional, for convenience commands)

**Environment Setup:**
```bash
# Copy environment template and customize
cp .env.example .env.local
# Edit .env.local with your settings
```

**Development with live reload (recommended):**
```bash
make start-local     # Uses volume mounting for instant code changes
```

**Development environment:**
```bash
make start-dev       # Full containerized environment
```

**Production deployment:**
```bash
make start-prod      # Production with SSL and security
```

## Development

### Local Development (Manual)

**Install dependencies:**
```bash
make install
# or manually: uv sync
```

**Run development server:**
```bash
make dev
# or manually: uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Testing:**
```bash
make test         # Run tests
make test-cov     # Run tests with coverage report
# or manually:
# uv run pytest
# uv run pytest --cov=app --cov-report=term-missing --cov-report=html
```

**Code quality:**
```bash
make lint format typecheck security
# or manually:
# uv run ruff check .
# uv run ruff format .
# uv run mypy . --ignore-missing-imports
# uv run bandit -r app/
```

### Docker Development

**Quick commands:**
```bash
make start-local    # Local dev with volume mounting (live reload)
make start-dev      # Development environment
make start-prod     # Production environment
make stop-local     # Stop local environment
make logs ENV=local # View logs
make build          # Build Docker image
```

**Environment-specific deployment:**
```bash
# Full deployment with health checks
make deploy-local   # Local deployment
make deploy-dev     # Development deployment
make deploy-prod    # Production deployment

# Monitoring
make monitor-local  # Monitor local environment
make monitor-dev    # Monitor development
make monitor-prod   # Monitor production
```

## Environment Configuration

The application supports three environments with different configurations:

| Environment | Purpose                      | Code Mounting    | SSL           | CORS       |
| ----------- | ---------------------------- | ---------------- | ------------- | ---------- |
| **local**   | Development with live reload | ✅ Volume mounted | ❌ HTTP only   | Wide open  |
| **dev**     | Testing environment          | ❌ Built-in       | ❌ HTTP only   | Restricted |
| **prod**    | Production                   | ❌ Built-in       | ✅ HTTPS + SSL | Strict     |

**Environment files:**
- `.env.local` - Local development with volume mounting
- `.env.dev` - Development environment
- `.env.prod` - Production environment
- `.env.example` - Template with all options

**Key differences:**
- **Local**: Volume mounts `./app` for instant code changes without rebuilds
- **Dev/Prod**: Uses code built into Docker image, requires rebuild for changes

## Monitoring & Maintenance

**Health checks:**
```bash
./scripts/monitor.sh
```

**Service logs:**
```bash
docker-compose logs -f [service_name]
```

**Service status:**
```bash
docker-compose ps
```

## Backup & Recovery

**Create backup:**
```bash
# Full backup (default)
./scripts/backup.sh full

# Data only backup
./scripts/backup.sh data

# Configuration only backup
./scripts/backup.sh config
```

**List backups:**
```bash
./scripts/backup.sh list
```

**Restore from backup:**
```bash
./scripts/restore.sh <backup_date> [full|data|config]
```

## Log Management

**Manual log rotation:**
```bash
./scripts/log-rotate.sh rotate
```

**Check log status:**
```bash
./scripts/log-rotate.sh status
```

**Setup automated maintenance:**
```bash
# Install cron jobs for automated backups and log rotation
sudo ./scripts/setup-cron.sh setup
```

## SSL Configuration

For production deployment with HTTPS, the application includes automated SSL certificate management using Let's Encrypt.

### SSL Setup

**Prerequisites:**
- Domain name pointing to your server
- Ports 80 and 443 open on your server
- Email address for certificate registration

**Automated SSL initialization (recommended):**
```bash
# Initialize SSL certificates with interactive prompts
make ssl-init

# With email specified
make ssl-init EMAIL=admin@yourdomain.com

# With custom domain (if different from .env.prod)
make ssl-init EMAIL=admin@yourdomain.com DOMAIN=yourdomain.com

# Skip staging test (for advanced users)
make ssl-init EMAIL=admin@yourdomain.com SKIP_STAGING=true

# Force renewal of existing certificates
make ssl-init EMAIL=admin@yourdomain.com FORCE=true
```

**Manual SSL script usage:**
```bash
# Direct script usage with more options
./scripts/init-ssl.sh --email admin@yourdomain.com
./scripts/init-ssl.sh --email admin@yourdomain.com --skip-staging
./scripts/init-ssl.sh --email admin@yourdomain.com --force
```

**SSL certificate management:**
```bash
# Renew certificates (automated via certbot container)
make ssl-renew

# Production deployment with SSL
make deploy-prod
```

**The SSL initialization process:**
1. Validates domain and email
2. Checks DNS resolution  
3. Tests with Let's Encrypt staging environment
4. Issues production certificates if staging succeeds
5. Switches nginx to HTTPS configuration
6. Verifies HTTPS functionality

## Key Files

**Application:**
- `app/main.py`: FastAPI application entry point with router registration
- `app/routes/home.py`: Home page routes including test endpoints and utilities
- `app/routes/apps.py`: GitHub repository display with in-memory caching
- `app/utils.py`: GitHub API integration and template configuration
- `app/config.py`: Application settings and environment management

**Frontend:**
- `app/templates/`: Jinja2 templates with base template inheritance
  - `base.html`: Base template with navigation
  - `index.html`: Homepage
  - `apps.html`: GitHub projects showcase
- `app/static/css/style.css`: Application styling with responsive design

**Deployment:**
- `docker-compose.yml`: Multi-environment deployment configuration
- `docker/Dockerfile`: Production-ready containerization
- `Makefile`: Development and deployment convenience commands
- `.env.example`: Environment configuration template
- `scripts/`: Deployment, monitoring, and maintenance scripts
  - `init-ssl.sh`: Automated SSL certificate initialization with Let's Encrypt

**Documentation:**
- `README.md`: This file - setup and usage guide
