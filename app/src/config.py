"""Application configuration management.

Follows 12-factor app principles with environment-based configuration.
"""

import os


class Config:
    """Base configuration with sensible defaults."""

    # Flask
    SECRET_KEY = os.environ.get("SECRET_KEY") or "dev-secret-key-change-in-prod"
    FLASK_ENV = os.environ.get("FLASK_ENV", "production")

    # Application
    APP_NAME = "demo-app"
    APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
    ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")

    # AWS
    AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

    # Observability
    LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
    ENABLE_METRICS = os.environ.get("ENABLE_METRICS", "true").lower() == "true"
    ENABLE_CLOUDWATCH = os.environ.get("ENABLE_CLOUDWATCH", "false").lower() == "true"

    # Server
    PORT = int(os.environ.get("PORT", 8080))
    WORKERS = int(os.environ.get("WORKERS", 4))


class DevelopmentConfig(Config):
    """Development environment configuration."""

    DEBUG = True
    LOG_LEVEL = "DEBUG"
    FLASK_ENV = "development"


class StagingConfig(Config):
    """Staging environment configuration."""

    DEBUG = False
    LOG_LEVEL = "INFO"


class ProductionConfig(Config):
    """Production environment configuration."""

    DEBUG = False
    LOG_LEVEL = "INFO"

    # Override to ensure production security
    def __init__(self):
        """Initialize production config and validate required environment variables."""
        if not os.environ.get("SECRET_KEY"):
            raise ValueError("SECRET_KEY environment variable must be set in production")


# Configuration mapping
config_by_name = {
    "dev": DevelopmentConfig,
    "development": DevelopmentConfig,
    "staging": StagingConfig,
    "prod": ProductionConfig,
    "production": ProductionConfig,
}


def get_config(env_name=None):
    """Get configuration object based on environment name.

    Args:
        env_name: Environment name (dev, staging, prod). If None, uses ENVIRONMENT env var.

    Returns:
        Configuration object instance.
    """
    if env_name is None:
        env_name = os.environ.get("ENVIRONMENT", "dev")

    config_class = config_by_name.get(env_name, DevelopmentConfig)
    return config_class()
