"""Tests for the edge telemetry service."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # app/ dir

import pytest
from fastapi.testclient import TestClient

from main import app


@pytest.fixture(scope="module")
def client():
    return TestClient(app)


def test_healthz(client):
    r = client.get("/healthz")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["service"] == "rj-edge-telemetry"


def test_readyz(client):
    r = client.get("/readyz")
    assert r.status_code == 200
    assert r.json()["status"] == "ready"


def test_metrics(client):
    r = client.get("/metrics")
    assert r.status_code == 200
    assert r.json()["service"] == "rj-edge-telemetry"
    assert "uptime_s" in r.json()


def test_ingest_valid(client):
    r = client.post("/telemetry", json={"device_id": "edge-01", "metric": "bearing_temp_c", "value": 48.5})
    assert r.status_code == 202
    body = r.json()
    assert body["accepted"] is True
    assert body["device_id"] == "edge-01"


def test_ingest_validation_error(client):
    # Empty device_id violates min_length -> 422, never credit a bad sample.
    r = client.post("/telemetry", json={"device_id": "", "metric": "x", "value": 1.0})
    assert r.status_code == 422


def test_unknown_route_404(client):
    assert client.get("/nope").status_code == 404