"""Download all Whisper STT models listed in `models/model_catalog.json`.

This script downloads each model under the STT section into:
  models/__models__/whisper/<model_name>/

Usage (from project root):
  python scripts\download_whisper_models.py

If you hit HF rate limits or private repo errors, set your token:
  set HUGGINGFACE_HUB_TOKEN=<token>
"""

import json
import os
import sys
from pathlib import Path

try:
    from huggingface_hub import snapshot_download
except Exception as exc:
    print("ERROR: huggingface-hub is not installed. Install with: pip install huggingface-hub")
    raise


ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = ROOT / "models" / "model_catalog.json"
DEST_ROOT = ROOT / "models" / "__models__" / "whisper"


def repo_id_from_url(url: str) -> str:
    """Extract HF repo_id from a URL or return the string unchanged if already a repo id."""
    if not isinstance(url, str):
        raise ValueError("Invalid repo URL")
    if "huggingface.co/" in url:
        return url.split("huggingface.co/")[-1].rstrip("/")
    return url


def is_downloaded(dest: Path) -> bool:
    """Basic check whether model appears downloaded (some files exist)."""
    if not dest.exists():
        return False
    # heuristics: any file inside dest
    for _ in dest.rglob("*"):
        return True
    return False


def main():
    if not CATALOG_PATH.exists():
        print(f"Model catalog not found at: {CATALOG_PATH}")
        sys.exit(2)

    with CATALOG_PATH.open("r", encoding="utf-8") as f:
        catalog = json.load(f)

    stt = catalog.get("STT") or {}
    if not stt:
        print("No STT models found in catalog.")
        return

    DEST_ROOT.mkdir(parents=True, exist_ok=True)

    for model_name, repo_url in stt.items():
        try:
            repo_id = repo_id_from_url(repo_url)
            dest = DEST_ROOT / model_name
            if is_downloaded(dest):
                print(f"Skipping {model_name} — already downloaded at {dest}")
                continue

            print(f"Downloading {model_name} from {repo_id} → {dest} ...")
            snapshot_download(
                repo_id=repo_id,
                local_dir=str(dest),
                local_dir_use_symlinks=False,
                resume_download=True,
            )
            print(f"OK: {model_name} downloaded to {dest}\n")

        except KeyboardInterrupt:
            print("Interrupted by user")
            return
        except Exception as e:
            print(f"ERROR downloading {model_name}: {e}\n")


if __name__ == "__main__":
    main()
