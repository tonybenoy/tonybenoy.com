# Makefile for TonyBenoy.com
# Provides convenient shortcuts for common development and deployment tasks

.PHONY: help install dev test lint format typecheck security build clean
.PHONY: start-local start-dev start-prod stop-local stop-dev stop-prod
.PHONY: deploy-local deploy-dev deploy-prod monitor-local monitor-dev monitor-prod
.PHONY: logs-local logs-dev logs-prod backup restore

# Default environment
ENV ?= local

# Colors for help output
BLUE = \033[0;34m
GREEN = \033[0;32m
YELLOW = \033[1;33m
NC = \033[0m

help: ## Show this help message
	@echo "$(BLUE)TonyBenoy.com Development & Deployment Commands$(NC)\n"
	@echo "$(GREEN)Development:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / && /Development/ {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "\n$(GREEN)Environment Management:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / && /Environment/ {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "\n$(GREEN)Deployment:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / && /Deployment/ {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "\n$(GREEN)Monitoring:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / && /Monitoring/ {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "\n$(GREEN)Examples:$(NC)"
	@echo "  make dev          # Start development server"
	@echo "  make start-prod   # Start production environment"
	@echo "  make deploy-prod  # Full production deployment"
	@echo "  make logs ENV=dev # View development logs"

# Development Commands
install: ## Development: Install dependencies
	cd src && uv sync

dev: ## Development: Run development server
	cd src && uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000

test: ## Development: Run tests
	cd src && uv run pytest

lint: ## Development: Run linting
	cd src && uv run ruff check .

format: ## Development: Format code
	cd src && uv run ruff format .

typecheck: ## Development: Run type checking
	cd src && uv run mypy . --ignore-missing-imports

security: ## Development: Run security check
	cd src && uv run bandit -r .

build: ## Development: Build Docker image
	docker build -f docker/Dockerfile -t tonybenoy-com:latest .

clean: ## Development: Clean up Docker resources
	docker system prune -f
	docker image prune -f

# Environment Management
start-local: ## Environment: Start local environment (HTTP, debug)
	./scripts/start.sh local

start-dev: ## Environment: Start development environment (HTTP)
	./scripts/start.sh dev

start-prod: ## Environment: Start production environment (HTTPS, SSL)
	./scripts/start.sh prod

stop-local: ## Environment: Stop local environment
	./scripts/stop.sh local

stop-dev: ## Environment: Stop development environment
	./scripts/stop.sh dev

stop-prod: ## Environment: Stop production environment
	./scripts/stop.sh prod

restart: ## Environment: Restart current environment
	./scripts/stop.sh $(ENV)
	./scripts/start.sh $(ENV)

# Deployment Commands
deploy-local: ## Deployment: Deploy to local with health checks
	./scripts/deploy-env.sh local

deploy-dev: ## Deployment: Deploy to development with health checks
	./scripts/deploy-env.sh dev

deploy-prod: ## Deployment: Deploy to production with health checks
	./scripts/deploy-env.sh prod

deploy: ## Deployment: Deploy to specified environment (ENV=local|dev|prod)
	./scripts/deploy-env.sh $(ENV)

# Monitoring Commands
monitor-local: ## Monitoring: Monitor local environment
	./scripts/monitor.sh local

monitor-dev: ## Monitoring: Monitor development environment
	./scripts/monitor.sh dev

monitor-prod: ## Monitoring: Monitor production environment
	./scripts/monitor.sh prod

monitor: ## Monitoring: Monitor specified environment (ENV=local|dev|prod)
	./scripts/monitor.sh $(ENV)

logs-local: ## Monitoring: View local logs
	docker-compose --env-file .env.local logs -f

logs-dev: ## Monitoring: View development logs
	docker-compose --env-file .env.dev logs -f

logs-prod: ## Monitoring: View production logs
	docker-compose --env-file .env.prod logs -f

logs: ## Monitoring: View logs for specified environment (ENV=local|dev|prod)
	docker-compose --env-file .env.$(ENV) logs -f

status: ## Monitoring: Show service status for environment (ENV=local|dev|prod)
	docker-compose --env-file .env.$(ENV) ps

# Backup & Recovery
backup: ## Backup: Create backup
	./scripts/backup.sh full

restore: ## Backup: Restore from backup (requires BACKUP_DATE)
ifndef BACKUP_DATE
	@echo "Error: BACKUP_DATE required. Usage: make restore BACKUP_DATE=20231201-120000"
	@exit 1
endif
	./scripts/restore.sh $(BACKUP_DATE)

# Utility Commands
health: ## Utility: Check health for environment (ENV=local|dev|prod)
	./scripts/deploy-env.sh health $(ENV)

shell: ## Utility: Open shell in app container for environment (ENV=local|dev|prod)
	docker-compose --env-file .env.$(ENV) exec fastapi /bin/bash

redis-cli: ## Utility: Open Redis CLI
	docker-compose --env-file .env.$(ENV) exec redis_db redis-cli

nginx-reload: ## Utility: Reload nginx configuration
	docker-compose --env-file .env.$(ENV) exec nginx nginx -s reload

ssl-renew: ## Utility: Renew SSL certificates (production only)
	docker-compose --env-file .env.prod exec certbot certbot renew --dry-run