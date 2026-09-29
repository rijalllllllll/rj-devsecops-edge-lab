"""Edge telemetry ingestion service (DevSecOps lab).

A minimal, security-hardened HTTP service that receives sensor/edge telemetry
and exposes health + metrics. Represents the "device-to-cloud" data plane of an
IIoT deployment inside this DevSecOps reference repo.
"""
import os
import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

APP_NAME = "rj-edge-telemetry"
VERSION = "1.0.0"

app = FastAPI(title=APP_NAME, version=VERSION, docs_url="/docs", redoc_url=None)

# Minimal, defensive CORS (hardened baseline; tighten per deployment).
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

_START = time.time()


class Telemetry(BaseModel):
    device_id: str = Field(..., min_length=1, max_length=128)
    metric: str = Field(..., min_length=1, max_length=64)
    value: float
    ts: float | None = None


class TelemetryResponse(BaseModel):
    accepted: bool
    device_id: str
    metric: str


@app.get("/healthz", tags=["ops"])
def healthz() -> dict:
    """Liveness probe — the process is up."""
    return {"status": "ok", "service": APP_NAME, "version": VERSION, "uptime_s": int(time.time() - _START)}


@app.get("/readyz", tags=["ops"])
def readyz() -> dict:
    """Readiness probe — the service can take traffic."""
    return {"status": "ready", "version": VERSION}


@app.get("/metrics", tags=["ops"])
def metrics() -> dict:
    """Minimal operational metrics (log/summary oriented, extensible to /metrics)."""
    return {"service": APP_NAME, "uptime_s": int(time.time() - _START), "version": VERSION}


@app.post("/telemetry", response_model=TelemetryResponse, status_code=202, tags=["data"])
async def ingest(req: Request, item: Telemetry) -> TelemetryResponse:
    """Ingest a single telemetry sample (device-to-cloud)."""
    # Deterministic, non-sensitive acceptance; real impl persists to a queue/db.
    ts = item.ts or time.time()
    req.app.state.last = {"device_id": item.device_id, "metric": item.metric, "value": item.value, "ts": ts}
    return TelemetryResponse(accepted=True, device_id=item.device_id, metric=item.metric)


@app.exception_handler(Exception)
async def unhandled(_req: Request, exc: Exception) -> JSONResponse:
    # Never leak internals; keep a structured, opaque error to the client.
    return JSONResponse(status_code=500, content={"error": "internal_error"})


@app.on_event("startup")
def _startup() -> None:
    app.state.last = {}