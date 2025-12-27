"""API key management for external services."""

import os
import json
from .settings import APIS_JSON, ALT_APIS_JSON


def _load_json(path):
    """Load JSON file from disk."""
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    except Exception:
        return {}


def get_api_key() -> str:
    """Get Gemini API key from secrets file or environment variable.
    
    Returns:
        API key string, or empty string if not found.
    """
    data = _load_json(APIS_JSON) or _load_json(ALT_APIS_JSON)
    gem = data.get("gemini") if isinstance(data, dict) else None
    api_key = None
    if isinstance(gem, dict):
        api_key = gem.get("api_key") or gem.get("apiKey") or gem.get("api_key_env_var")
    return api_key or os.getenv("GEMINI_API_KEY", "")
