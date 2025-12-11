"""Structured logging middleware.

Configures JSON-formatted logging for CloudWatch Logs integration.
Adds request context to all log messages.
"""

import logging
import json
import uuid
from datetime import datetime, timezone
from flask import request, g
from werkzeug.exceptions import HTTPException
import sys


class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging."""

    def format(self, record):
        """Format log record as JSON.

        Args:
            record: Log record to format.

        Returns:
            JSON-formatted log string.
        """
        log_data = {
            "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }

        # Add request context if available (only works during active request)
        try:
            if hasattr(g, "request_id"):
                log_data["request_id"] = g.request_id

            if request:
                log_data["request"] = {
                    "method": request.method,
                    "path": request.path,
                    "remote_addr": request.remote_addr,
                }
        except RuntimeError:
            # Outside application context (e.g., during app startup)
            pass

        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        # Add any extra fields
        if hasattr(record, "extra_fields"):
            log_data.update(record.extra_fields)

        return json.dumps(log_data)


def setup_logging(app):
    """Configure application logging.

    Args:
        app: Flask application instance.
    """
    # Get log level from config
    log_level = app.config.get("LOG_LEVEL", "INFO")

    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)

    # Remove existing handlers
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)

    # Create console handler with JSON formatter
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)
    console_handler.setFormatter(JSONFormatter())
    root_logger.addHandler(console_handler)

    # Configure Flask app logger
    app.logger.setLevel(log_level)

    # Add request ID to all requests
    @app.before_request
    def add_request_id():
        """Generate unique request ID for tracing."""
        g.request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))

    # Log all requests
    @app.after_request
    def log_request(response):
        """Log request details after processing.

        Args:
            response: Flask response object.

        Returns:
            Unmodified response object.
        """
        # Skip health check logging in production to reduce noise
        if request.path.startswith("/health"):
            return response

        app.logger.info(
            f"{request.method} {request.path} {response.status_code}",
            extra={
                "extra_fields": {
                    "request_id": g.get("request_id"),
                    "method": request.method,
                    "path": request.path,
                    "status_code": response.status_code,
                    "user_agent": request.headers.get("User-Agent"),
                    "content_length": response.content_length,
                }
            },
        )
        return response

    # Log unhandled exceptions (but not HTTP exceptions like 404)
    @app.errorhandler(Exception)
    def handle_exception(error):
        """Log unhandled exceptions.

        Args:
            error: Exception that was raised.

        Returns:
            JSON error response for 500 errors, or re-raises HTTP exceptions.
        """
        # Don't catch HTTP exceptions (404, 403, etc.) - let Flask handle them
        if isinstance(error, HTTPException):
            return error

        # Log actual server errors
        app.logger.error(
            f"Unhandled exception: {error!s}",
            exc_info=True,
            extra={
                "extra_fields": {
                    "request_id": g.get("request_id"),
                    "error_type": type(error).__name__,
                }
            },
        )

        return {
            "error": "Internal server error",
            "request_id": g.get("request_id"),
        }, 500

    app.logger.info(
        "Logging configured",
        extra={
            "extra_fields": {
                "log_level": log_level,
                "environment": app.config.get("ENVIRONMENT"),
            }
        },
    )
