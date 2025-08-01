FROM python:3.11-slim

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

# Copy project files
COPY src/pyproject.toml src/uv.lock /app/
COPY src/ /app/

# Install dependencies with uv
RUN uv sync --frozen --no-dev

# Expose port
EXPOSE 8000

# Run the application
CMD ["uv", "run", "gunicorn", "-b", "0.0.0.0:8000", "main:app", "-w", "1", "-k", "uvicorn.workers.UvicornWorker", "--preload"]
