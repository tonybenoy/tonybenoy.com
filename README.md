# tonybenoy.com

Personal website built with FastAPI and served via Docker with nginx reverse proxy. The application fetches and displays GitHub repository information with Redis caching.

## Architecture

- **Framework**: FastAPI with Jinja2 templating
- **Structure**: Modular routing in `src/routes/` with separate routers for home and apps
- **Static Files**: CSS, images, and files served from `src/static/`
- **Templates**: HTML templates in `src/templates/` using base template inheritance
- **Caching**: Redis for GitHub API response caching
- **Deployment**: Docker Compose with nginx, FastAPI app, Redis, and Let's Encrypt certbot
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
# or manually: cd src && uv sync
```

**Run development server:**
```bash
make dev
# or manually: cd src && uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Code quality:**
```bash
make lint format typecheck security
# or manually:
# cd src && uv run ruff check .
# cd src && uv run ruff format .
# cd src && uv run mypy . --ignore-missing-imports
# cd src && uv run bandit -r .
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
- **Local**: Volume mounts `./src` for instant code changes without rebuilds
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

## Key Files

**Application:**
- `src/main.py`: FastAPI application entry point with router registration
- `src/routes/home.py`: Home page routes (/, /about, /contact)
- `src/routes/apps.py`: GitHub repository display with Redis caching
- `src/utils.py`: GitHub API integration and template configuration
- `src/config.py`: Application settings and environment management

**Frontend:**
- `src/templates/`: Jinja2 templates with Solarized Dark terminal theme
  - `base.html`: Base template with navigation
  - `index.html`: Homepage with professional summary
  - `about.html`: Professional background and achievements
  - `contact.html`: Contact information and services
  - `apps.html`: GitHub projects showcase
- `src/static/css/style.css`: Solarized Dark theme with responsive design

**Deployment:**
- `docker-compose.yml`: Multi-environment deployment configuration
- `docker/Dockerfile`: Production-ready containerization
- `Makefile`: Development and deployment convenience commands
- `.env.example`: Environment configuration template
- `scripts/`: Deployment, monitoring, and maintenance scripts

**Documentation:**
- `README.md`: This file - setup and usage guide
