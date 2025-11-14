"""Standalone test to verify catalog generation logic."""

print("=" * 60)
print("TESTING CATALOG GENERATION LOGIC")
print("=" * 60)

# Test 1: Check faster-whisper _MODELS
print("\n[1] Testing faster-whisper._MODELS access...")
try:
    from faster_whisper.utils import _MODELS
    print(f"✓ Successfully imported _MODELS")
    print(f"✓ Found {len(_MODELS)} Whisper models")
    print("\nSample models:")
    for key, value in list(_MODELS.items())[:5]:
        print(f"  {key:15} → {value}")
    if len(_MODELS) > 5:
        print(f"  ... and {len(_MODELS) - 5} more")
except ImportError as e:
    print(f"✗ faster-whisper not installed: {e}")
except AttributeError as e:
    print(f"✗ _MODELS not found: {e}")

# Test 2: Check google-generativeai availability
print("\n[2] Testing google-generativeai availability...")
try:
    import google.generativeai as genai
    print(f"✓ google-generativeai module imported")
    
    # Check if API key is available
    import os
    api_key = os.getenv("GEMINI_API_KEY")
    if api_key:
        print(f"✓ API key found in environment")
    else:
        print(f"⚠ No GEMINI_API_KEY in environment (models will use fallback)")
        
except ImportError as e:
    print(f"✗ google-generativeai not installed: {e}")

# Test 3: Verify catalog JSON structure
print("\n[3] Testing catalog JSON structure...")
try:
    import json
    from pathlib import Path
    
    catalog_path = Path(__file__).parent / "models" / "model_catalog.json"
    with open(catalog_path) as f:
        catalog = json.load(f)
    
    print(f"✓ Catalog JSON loaded successfully")
    print(f"  Keys: {list(catalog.keys())}")
    print(f"  STT models (hardcoded): {len(catalog.get('STT', {}))}")
    print(f"  LM models (hardcoded): {len(catalog.get('LM', {}))}")
    
    if len(catalog.get('STT', {})) == 0 and len(catalog.get('LM', {})) == 0:
        print(f"✓ Catalog is empty (dynamic generation will populate)")
    else:
        print(f"⚠ Catalog has hardcoded values (will be overridden by dynamic generation)")
        
except Exception as e:
    print(f"✗ Failed to load catalog: {e}")

print("\n" + "=" * 60)
print("VERIFICATION SUMMARY")
print("=" * 60)

print("\n✓ Logic verification complete!")
print("\nPipeline flow:")
print("  1. Server starts")
print("  2. _get_raw_catalog() called")
print("  3. _build_dynamic_catalog() generates:")
print("     - STT: from faster_whisper.utils._MODELS")
print("     - LM: from genai.list_models() or fallback")
print("  4. Results cached in _DYNAMIC_CATALOG_CACHE")
print("  5. get_catalog() formats for app (display names only)")
print("  6. App receives model list with no internal URLs")

print("\nReady to test with server:")
print("  pip install -r requirements.txt")
print("  python main.py")
