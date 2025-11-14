"""Configuration package for FlaskServer."""

from .settings import BASE_DIR, WHISPER_CACHE, MODEL_CATALOG_PATH, DEVICE_REGISTRY_PATH
from .secrets import get_api_key

__all__ = [
    "BASE_DIR",
    "WHISPER_CACHE",
    "MODEL_CATALOG_PATH",
    "DEVICE_REGISTRY_PATH",
    "get_api_key",
]
