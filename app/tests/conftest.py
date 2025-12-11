"""Pytest configuration and shared fixtures."""

import pytest
from prometheus_client import REGISTRY
from src.app import create_app


@pytest.fixture(autouse=True)
def clear_prometheus_registry():
    """Clear Prometheus registry before each test to avoid duplicate metric errors."""
    # Get all collectors and unregister them
    collectors = list(REGISTRY._collector_to_names.keys())
    for collector in collectors:
        try:
            REGISTRY.unregister(collector)
        except Exception:
            pass  # Ignore errors for default collectors
    yield
    # Clean up after test
    collectors = list(REGISTRY._collector_to_names.keys())
    for collector in collectors:
        try:
            REGISTRY.unregister(collector)
        except Exception:
            pass


@pytest.fixture
def app():
    """Create application instance for testing.

    Returns:
        Flask application configured for testing.
    """
    app = create_app("dev")
    app.config.update(
        {
            "TESTING": True,
            "ENABLE_CLOUDWATCH": False,  # Disable CloudWatch in tests
        }
    )
    return app


@pytest.fixture
def client(app):
    """Create test client.

    Args:
        app: Flask application fixture.

    Returns:
        Flask test client.
    """
    return app.test_client()
