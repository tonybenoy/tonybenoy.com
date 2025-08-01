# Multi-stage build for smaller, more secure image
FROM python:3.11-slim AS builder

# Install system dependencies and uv
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && curl -LsSf https://astral.sh/uv/install.sh | sh

# Add uv to PATH
ENV PATH="/root/.local/bin:$PATH"

# Set working directory
WORKDIR /app

# Copy project configuration
COPY src/pyproject.toml src/uv.lock ./

# Install dependencies
RUN uv sync --frozen --no-dev

# Production stage
FROM python:3.11-slim AS production

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /app/.venv /app/.venv

# Copy application code
COPY src/ /app/src/

# Create necessary directories and set permissions
RUN mkdir -p /app/logs && chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Set environment variables
ENV PATH="/app/.venv/bin:$PATH"
ENV PYTHONPATH="/app"
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Add health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD /usr/local/bin/python3 -c "import sys; sys.path.insert(0, '/app/.venv/lib/python3.11/site-packages'); import httpx; httpx.get('http://localhost:8000/test', timeout=10)" || exit 1

# Expose port
EXPOSE 8000

# Run the application  
CMD ["/usr/local/bin/python3", "-c", "import sys; sys.path.insert(0, '/app/.venv/lib/python3.11/site-packages'); from gunicorn.app.wsgiapp import run; sys.argv=['gunicorn', '-b', '0.0.0.0:8000', 'src.main:app', '-w', '2', '-k', 'uvicorn.workers.UvicornWorker', '--preload', '--access-logfile', '-', '--error-logfile', '-']; run()"]
