# syntax=docker/dockerfile:1
# ---- Build stage ----
FROM python:3.12-slim-bookworm AS builder
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /build
COPY app/requirements.txt .
# Pin trust: install as root in build stage; final stage will drop privileges.
RUN python -m venv /opt/venv && /opt/venv/bin/pip install -r requirements.txt

# ---- Runtime stage: minimal + non-root ----
FROM python:3.12-slim-bookworm AS runtime
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
# Create non-root user with no login shell, no home dir.
RUN useradd --system --no-create-home --uid 10001 appuser
COPY --from=builder /opt/venv /opt/venv
WORKDIR /app
COPY app/main.py .
# Run as unprivileged user.
USER 10001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["/opt/venv/bin/python", "-c", "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8000/healthz')"]
CMD ["/opt/venv/bin/uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]