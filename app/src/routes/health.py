"""Health check endpoints.

Implements Kubernetes-style health probes:
- /health - Basic health check
- /health/ready - Readiness probe (checks dependencies)
- /health/live - Liveness probe (checks if app is alive)
"""

from datetime import datetime
from flask import Blueprint, jsonify, current_app


bp = Blueprint("health", __name__)


@bp.route("/health", methods=["GET"])
def health():
    """Basic health check endpoint.

    Returns:
        JSON response with health status and metadata.
    """
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "service": current_app.config.get("APP_NAME", "demo-app"),
        "version": current_app.config.get("APP_VERSION", "unknown"),
        "environment": current_app.config.get("ENVIRONMENT", "unknown"),
    }), 200


@bp.route("/health/ready", methods=["GET"])
def ready():
    """Readiness probe endpoint.

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

    return jsonify({
        "status": "ready" if all_ready else "not_ready",
        "checks": checks,
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }), status_code


@bp.route("/health/live", methods=["GET"])
def live():
    """Liveness probe endpoint.

    Indicates if the application is alive and running.
    This should only fail if the application is completely unresponsive.

    Returns:
        JSON response with liveness status.
    """
    return jsonify({
        "status": "alive",
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }), 200
