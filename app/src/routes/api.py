"""Main API endpoints.

Simple demonstration API with hello-world functionality.
"""

from datetime import datetime
from flask import Blueprint, jsonify, request, current_app
import socket


bp = Blueprint("api", __name__, url_prefix="/api")


@bp.route("/hello", methods=["GET"])
def hello():
    """Hello world endpoint.

    Returns:
        JSON response with greeting and metadata.
    """
    name = request.args.get("name", "World")

    return (
        jsonify(
            {
                "message": f"Hello, {name}!",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "service": current_app.config.get("APP_NAME", "demo-app"),
                "version": current_app.config.get("APP_VERSION", "unknown"),
                "environment": current_app.config.get("ENVIRONMENT", "unknown"),
                "hostname": socket.gethostname(),
            }
        ),
        200,
    )


@bp.route("/info", methods=["GET"])
def info():
    """Service information endpoint.

    Returns:
        JSON response with service metadata and configuration.
    """
    return (
        jsonify(
            {
                "service": {
                    "name": current_app.config.get("APP_NAME", "demo-app"),
                    "version": current_app.config.get("APP_VERSION", "unknown"),
                    "environment": current_app.config.get("ENVIRONMENT", "unknown"),
                },
                "platform": {
                    "hostname": socket.gethostname(),
                    "region": current_app.config.get("AWS_REGION", "unknown"),
                },
                "features": {
                    "metrics_enabled": current_app.config.get("ENABLE_METRICS", False),
                    "cloudwatch_enabled": current_app.config.get("ENABLE_CLOUDWATCH", False),
                },
                "timestamp": datetime.utcnow().isoformat() + "Z",
            }
        ),
        200,
    )


@bp.route("/echo", methods=["POST"])
def echo():
    """Echo endpoint that returns the posted JSON data.

    Returns:
        JSON response echoing the request payload.
    """
    data = request.get_json() or {}

    return (
        jsonify(
            {
                "echo": data,
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "content_type": request.content_type,
            }
        ),
        200,
    )
