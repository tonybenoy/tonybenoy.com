FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY ./src/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy source code
COPY src/ /app/src/

# Expose port
EXPOSE 8000

# Run the application
CMD ["gunicorn", "-b", "0.0.0.0:8000", "src.main:app", "-w", "1", "-k", "uvicorn.workers.UvicornWorker", "--preload"]
