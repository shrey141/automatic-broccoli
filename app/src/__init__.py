"""Platform Engineering Demo Application."""

try:
    from importlib.metadata import version
    __version__ = version("demo-app")
except Exception:
    __version__ = "unknown"
