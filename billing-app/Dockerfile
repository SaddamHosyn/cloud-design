# Stage 1: Build stage
FROM python:3.9-slim AS builder

WORKDIR /app

# Install build dependencies (needed if some packages require compilation)
RUN apt-get update && apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

# Create a virtual environment and install dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Final lightweight image
FROM python:3.9-slim

WORKDIR /app

# Copy the virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy the application code
COPY . .

# Create a non-root user for security
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

# Note: For api-gateway EXPOSE 3000, for inventory/billing EXPOSE 8080.
# Change the exposed port based on which app this is placed in.
EXPOSE 8080

ENTRYPOINT ["python", "server.py"]