"""Health check endpoints.

Implements Kubernetes-style health probes:
- /health - Basic health check
- /health/ready - Readiness probe (checks dependencies)
- /health/live - Liveness probe (checks if app is alive)
"""

from datetime import datetime, timezone
from flask import Blueprint, jsonify, current_app


bp = Blueprint("health", __name__)


@bp.route("/health", methods=["GET"])
def health():
    """Return basic health check information.

    Returns:
        JSON response with health status and metadata.
    """
    return (
        jsonify(
            {
                "status": "healthy",
                "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
                "service": current_app.config.get("APP_NAME", "demo-app"),
                "version": current_app.config.get("APP_VERSION", "unknown"),
                "environment": current_app.config.get("ENVIRONMENT", "unknown"),
            }
        ),
        200,
    )


@bp.route("/health/ready", methods=["GET"])
def ready():
    """Check if the application is ready to serve traffic.

    Checks if the application is ready to serve traffic.
    In a real application, this would check:
    - Database connectivity
    - Cache availability
    - External service dependencies

    Returns:
        JSON response with readiness status and dependency checks.
    """
    checks = {}
    all_ready = True

    # Example dependency checks (simulated for demo)
    # In production, replace with actual dependency health checks
    checks["database"] = "ok"  # Replace with actual DB check
    checks["cache"] = "ok"  # Replace with actual cache check

    # Determine overall status
    all_ready = all(status == "ok" for status in checks.values())
    status_code = 200 if all_ready else 503

    return (
        jsonify(
            {
                "status": "ready" if all_ready else "not_ready",
                "checks": checks,
                "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            }
        ),
        status_code,
    )


@bp.route("/health/live", methods=["GET"])
def live():
    """Indicate whether the application is alive.

    Indicates if the application is alive and running.
    This should only fail if the application is completely unresponsive.

    Returns:
        JSON response with liveness status.
    """
    return (
        jsonify(
            {
                "status": "alive",
                "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            }
        ),
        200,
    )
