"""Flask application factory.

Creates and configures the Flask application with all middleware and routes.
"""

import logging
import os
from flask import Flask
from flask_cors import CORS

from src.config import get_config
from src.middleware.logging import setup_logging
from src.middleware.metrics import setup_metrics
from src.routes import health, api

logger = logging.getLogger(__name__)


def create_app(config_name=None):
    """Application factory pattern for Flask.

    Args:
        config_name: Configuration environment name (dev, staging, prod).
                    If None, uses ENVIRONMENT env var.

    Returns:
        Configured Flask application instance.
    """
    app = Flask(__name__)

    # Load configuration
    config = get_config(config_name)
    app.config.from_object(config)

    # Setup middleware (order matters!)
    setup_logging(app)  # Logging first so other middleware can log
    setup_metrics(app)  # Metrics to track all requests

    # Enable CORS for development/testing
    CORS(app)
    # Enable CORS with environment-specific restrictions
    if app.config.get("ENVIRONMENT") in ["dev", "development"]:
        CORS(app)  # Allow all origins in development
    else:
        # Restrict origins in staging/production
        allowed_origins = os.environ.get("CORS_ORIGINS", "").split(",")
        if allowed_origins:
            CORS(app, origins=allowed_origins)

    # Register blueprints
    app.register_blueprint(health.bp)
    app.register_blueprint(api.bp)

    # Root endpoint
    @app.route("/")
    def index():
        """Root endpoint with service information."""
        return {
            "service": app.config.get("APP_NAME", "demo-app"),
            "version": app.config.get("APP_VERSION", "unknown"),
            "environment": app.config.get("ENVIRONMENT", "unknown"),
            "status": "running",
            "endpoints": {
                "health": "/health",
                "ready": "/health/ready",
                "live": "/health/live",
                "metrics": "/metrics",
                "api": "/api",
            },
        }, 200

    # Log application startup
    logger.info(
        "Application created",
        extra={
            "extra_fields": {
                "app_name": app.config.get("APP_NAME"),
                "version": app.config.get("APP_VERSION"),
                "environment": app.config.get("ENVIRONMENT"),
                "debug": app.debug,
            }
        },
    )

    return app


# Create application instance for running directly
if __name__ == "__main__":
    app = create_app()
    # Bind to 0.0.0.0 for Docker container - this is required for the app
    # to be accessible from outside the container. The security boundary
    # is at the ALB/ingress level, not at the container network interface.
    app.run(
        host="0.0.0.0",  # nosec B104
        port=app.config.get("PORT", 8080),
        debug=app.config.get("DEBUG", False),
    )
