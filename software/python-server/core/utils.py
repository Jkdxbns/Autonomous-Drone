"""Shared utility functions."""

import json
from pathlib import Path


def load_json(path: Path) -> dict:
    """Load JSON file from disk.
    
    Args:
        path: Path to JSON file.
        
    Returns:
        Dictionary with file contents, or empty dict if file not found.
    """
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    except Exception as e:
        raise RuntimeError(f"Failed to read {path}: {e}")


def save_json(path: Path, data: dict) -> None:
    """Save dictionary to JSON file.
    
    Args:
        path: Path to JSON file.
        data: Dictionary to save.
    """
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        raise RuntimeError(f"Failed to write {path}: {e}")
