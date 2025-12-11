"""Unit tests for health check endpoints."""

import pytest
import json


class TestHealthEndpoint:
    """Test suite for /health endpoint."""

    def test_health_endpoint_returns_200(self, client):
        """Test that health endpoint returns 200 OK."""
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_endpoint_returns_json(self, client):
        """Test that health endpoint returns JSON."""
        response = client.get("/health")
        assert response.content_type == "application/json"

    def test_health_endpoint_contains_status(self, client):
        """Test that health response contains status field."""
        response = client.get("/health")
        data = response.get_json()
        assert "status" in data
        assert data["status"] == "healthy"

    def test_health_endpoint_contains_metadata(self, client):
        """Test that health response contains required metadata."""
        response = client.get("/health")
        data = response.get_json()
        assert "timestamp" in data
        assert "service" in data
        assert "version" in data
        assert "environment" in data


class TestReadyEndpoint:
    """Test suite for /health/ready endpoint."""

    def test_ready_endpoint_returns_200(self, client):
        """Test that ready endpoint returns 200 OK when all checks pass."""
        response = client.get("/health/ready")
        assert response.status_code == 200

    def test_ready_endpoint_returns_json(self, client):
        """Test that ready endpoint returns JSON."""
        response = client.get("/health/ready")
        assert response.content_type == "application/json"

    def test_ready_endpoint_contains_checks(self, client):
        """Test that ready response contains dependency checks."""
        response = client.get("/health/ready")
        data = response.get_json()
        assert "checks" in data
        assert isinstance(data["checks"], dict)

    def test_ready_endpoint_status_field(self, client):
        """Test that ready response contains status field."""
        response = client.get("/health/ready")
        data = response.get_json()
        assert "status" in data
        assert data["status"] in ["ready", "not_ready"]


class TestLiveEndpoint:
    """Test suite for /health/live endpoint."""

    def test_live_endpoint_returns_200(self, client):
        """Test that live endpoint returns 200 OK."""
        response = client.get("/health/live")
        assert response.status_code == 200

    def test_live_endpoint_returns_json(self, client):
        """Test that live endpoint returns JSON."""
        response = client.get("/health/live")
        assert response.content_type == "application/json"

    def test_live_endpoint_contains_status(self, client):
        """Test that live response contains status field."""
        response = client.get("/health/live")
        data = response.get_json()
        assert "status" in data
        assert data["status"] == "alive"


class TestAPIEndpoints:
    """Test suite for API endpoints."""

    def test_root_endpoint(self, client):
        """Test root endpoint returns service information."""
        response = client.get("/")
        assert response.status_code == 200
        data = response.get_json()
        assert "service" in data
        assert "endpoints" in data

    def test_hello_endpoint(self, client):
        """Test /api/hello endpoint."""
        response = client.get("/api/hello")
        assert response.status_code == 200
        data = response.get_json()
        assert "message" in data
        assert "Hello, World!" in data["message"]

    def test_hello_endpoint_with_name(self, client):
        """Test /api/hello endpoint with name parameter."""
        response = client.get("/api/hello?name=Alice")
        assert response.status_code == 200
        data = response.get_json()
        assert "Hello, Alice!" in data["message"]

    def test_info_endpoint(self, client):
        """Test /api/info endpoint."""
        response = client.get("/api/info")
        assert response.status_code == 200
        data = response.get_json()
        assert "service" in data
        assert "platform" in data
        assert "features" in data

    def test_echo_endpoint(self, client):
        """Test /api/echo endpoint."""
        payload = {"test": "data", "number": 42}
        response = client.post(
            "/api/echo",
            data=json.dumps(payload),
            content_type="application/json"
        )
        assert response.status_code == 200
        data = response.get_json()
        assert "echo" in data
        assert data["echo"] == payload

    def test_metrics_endpoint_exists(self, client):
        """Test that /metrics endpoint exists (Prometheus)."""
        response = client.get("/metrics")
        assert response.status_code == 200
