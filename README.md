# tonybenoy.com

Personal website built with FastAPI and served via Docker with nginx reverse proxy. The application fetches and displays GitHub repository information with Redis caching.

## Architecture

- **Framework**: FastAPI with Jinja2 templating
- **Structure**: Modular routing in `src/routes/` with separate routers for home and apps
- **Static Files**: CSS, images, and files served from `src/static/`
- **Templates**: HTML templates in `src/templates/` using base template inheritance
- **Caching**: Redis for GitHub API response caching
- **Deployment**: Docker Compose with nginx, FastAPI app, Redis, and Let's Encrypt certbot

## Development

**Install dependencies:**
```bash
cd src && uv sync
```

**Run development server:**
```bash
cd src && uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Linting and formatting:**
```bash
cd src && uv run ruff check .
cd src && uv run ruff format .
```

**Type checking:**
```bash
cd src && uv run mypy . --ignore-missing-imports
```

**Security scanning:**
```bash
cd src && uv run bandit -r .
```

## Docker

**Development:**
```bash
docker build -f docker/Dockerfile -t website .
docker run --net=host -p 8000:8000 -it website
```

**Production deployment:**
```bash
docker-compose up -d
```

## Key Files

- `src/main.py`: FastAPI application entry point with router registration
- `src/routes/home.py`: Home page routes including test endpoints and utilities
- `src/routes/apps.py`: GitHub repository display with Redis caching
- `src/utils.py`: GitHub API integration and template configuration
- `docker-compose.yml`: Production deployment with nginx, Redis, and SSL
