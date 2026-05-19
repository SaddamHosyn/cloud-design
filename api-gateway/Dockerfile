# Stage 1: Build stage
FROM python:3.9-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Stage 2: Final lightweight image
FROM python:3.9-slim

WORKDIR /app

# ✅ Install netcat and curl (must be root, before USER appuser)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY . .

# ✅ chmod entrypoint (must be root, before USER appuser)
RUN chmod +x entrypoint.sh

RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

# ✅ api-gateway port is 3000
EXPOSE 3000

# ✅ Use entrypoint script instead of python directly
ENTRYPOINT ["./entrypoint.sh"]