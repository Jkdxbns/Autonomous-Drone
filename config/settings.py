"""Server configuration and constants."""

import os
from pathlib import Path

# Base directory - FlaskServer_v6 root
BASE_DIR = Path(__file__).resolve().parent.parent

# Model cache directory (renamed from __models__)
WHISPER_CACHE = BASE_DIR / "models" / "__models__" / "faster-whisper"
WHISPER_CACHE.mkdir(parents=True, exist_ok=True)

# Set environment variables for HuggingFace cache
os.environ["HF_HOME"] = str(WHISPER_CACHE)
os.environ["HF_HUB_CACHE"] = str(WHISPER_CACHE / "hub")
os.environ["HUGGINGFACE_HUB_CACHE"] = str(WHISPER_CACHE / "hub")

# Data file paths
MODEL_CATALOG_PATH = BASE_DIR / "models" / "model_catalog.json"
DEVICE_REGISTRY_PATH = BASE_DIR / "device_registry.json"

# API configuration
APIS_JSON = BASE_DIR / "secrets" / "apis.json"
ALT_APIS_JSON = BASE_DIR / "secrets" / "APIs.json"

print(f"[CONFIG] Whisper cache: {WHISPER_CACHE}")
print(f"[CONFIG] Base directory: {BASE_DIR}")
