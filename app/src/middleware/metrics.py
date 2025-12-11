"""Metrics middleware for observability.

Integrates Prometheus metrics export and CloudWatch custom metrics.
"""

import os
import logging
from prometheus_flask_exporter import PrometheusMetrics
from flask import request, g

logger = logging.getLogger(__name__)


def setup_metrics(app):
    """Configure Prometheus metrics and CloudWatch integration.

    Args:
        app: Flask application instance.

    Returns:
        PrometheusMetrics instance.
    """
    if not app.config.get("ENABLE_METRICS", True):
        logger.info("Metrics disabled by configuration")
        return None

    # Initialize Prometheus metrics
    metrics = PrometheusMetrics(app)

    # Add application info metric
    metrics.info(
        "app_info",
        "Application information",
        version=app.config.get("APP_VERSION", "unknown"),
        environment=app.config.get("ENVIRONMENT", "unknown"),
    )

    # CloudWatch integration (optional, enabled via config)
    if app.config.get("ENABLE_CLOUDWATCH", False):
        try:
            import boto3
            from botocore.exceptions import ClientError

            cloudwatch = boto3.client(
                "cloudwatch", region_name=app.config.get("AWS_REGION", "us-east-1")
            )

            @app.after_request
            def send_metrics_to_cloudwatch(response):
                """Send custom metrics to CloudWatch after each request.

                Args:
                    response: Flask response object.

                Returns:
                    Unmodified response object.
                """
                # Skip metrics for health checks to reduce noise and costs
                if request.path.startswith("/health") or request.path == "/metrics":
                    return response

                try:
                    # Prepare metric data
                    metric_data = [
                        {
                            "MetricName": "RequestCount",
                            "Value": 1,
                            "Unit": "Count",
                            "Dimensions": [
                                {
                                    "Name": "Environment",
                                    "Value": app.config.get("ENVIRONMENT", "unknown"),
                                },
                                {
                                    "Name": "StatusCode",
                                    "Value": str(response.status_code),
                                },
                                {
                                    "Name": "Method",
                                    "Value": request.method,
                                },
                                {
                                    "Name": "Endpoint",
                                    "Value": request.endpoint or "unknown",
                                },
                            ],
                        }
                    ]

                    # Send metrics to CloudWatch (async would be better in production)
                    cloudwatch.put_metric_data(
                        Namespace=f"DemoApp/{app.config.get('ENVIRONMENT', 'dev')}",
                        MetricData=metric_data,
                    )

                except ClientError as e:
                    # Log error but don't fail the request
                    logger.warning(
                        f"Failed to send metrics to CloudWatch: {e}",
                        extra={"extra_fields": {"error": str(e)}},
                    )
                except Exception as e:
                    logger.error(
                        f"Unexpected error sending CloudWatch metrics: {e}",
                        extra={"extra_fields": {"error": str(e)}},
                    )

                return response

            logger.info("CloudWatch metrics integration enabled")

        except ImportError:
            logger.warning(
                "boto3 not available, CloudWatch metrics disabled. "
                "Install boto3 to enable CloudWatch integration."
            )
        except Exception as e:
            logger.error(
                f"Failed to initialize CloudWatch metrics: {e}",
                extra={"extra_fields": {"error": str(e)}},
            )

    logger.info(
        "Metrics configured",
        extra={
            "extra_fields": {
                "prometheus_enabled": True,
                "cloudwatch_enabled": app.config.get("ENABLE_CLOUDWATCH", False),
            }
        },
    )

    return metrics
