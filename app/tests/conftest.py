"""Pytest configuration and shared fixtures."""

import pytest
from src.app import create_app


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


@pytest.fixture
def runner(app):
    """Create CLI test runner.

    Args:
        app: Flask application fixture.

    Returns:
        Flask CLI test runner.
    """
    return app.test_cli_runner()
