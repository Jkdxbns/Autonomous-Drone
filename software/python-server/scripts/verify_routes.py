"""Verify that routes have been updated correctly."""

import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def check_routes():
    """Check if routes are defined with new names."""
    
    print("=" * 80)
    print("ROUTE VERIFICATION")
    print("=" * 80)
    
    routes_to_check = [
        ("routes/assistant_routes.py", "/lm/query", "✓"),
        ("routes/lm_routes.py", "/lm/generate", "✓"),
        ("routes/lm_routes.py", "/stt/transcribe", "✓"),
        ("routes/lm_routes.py", "/ai/process", "✓"),
    ]
    
    all_good = True
    
    for file_path, route, status in routes_to_check:
        full_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), file_path)
        
        if not os.path.exists(full_path):
            print(f"❌ File not found: {file_path}")
            all_good = False
            continue
        
        with open(full_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if route in content:
            print(f"{status} {route:<25} found in {file_path}")
        else:
            print(f"❌ {route:<25} NOT found in {file_path}")
            all_good = False
    
    print("=" * 80)
    
    # Check Flutter app files
    print("\nFLUTTER APP VERIFICATION")
    print("=" * 80)
    
    flutter_files = [
        ("../../FlutterApp/mic_record_v10/lib/core/constants/api_endpoints.dart", 
         ["/lm/query", "/lm/generate", "/stt/transcribe", "/ai/process"]),
        ("../../FlutterApp/mic_record_v10/lib/services/api/assistant_api_service.dart",
         ["/lm/query"]),
        ("../../FlutterApp/mic_record_v10/lib/services/api/transcription_api_service.dart",
         ["/stt/transcribe"]),
    ]
    
    for file_rel_path, routes in flutter_files:
        full_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), file_rel_path)
        
        if not os.path.exists(full_path):
            print(f"⚠️  File not found: {file_rel_path}")
            continue
        
        with open(full_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        file_ok = True
        for route in routes:
            if route in content:
                print(f"✓ {route:<25} found in {os.path.basename(file_rel_path)}")
            else:
                print(f"❌ {route:<25} NOT found in {os.path.basename(file_rel_path)}")
                file_ok = False
                all_good = False
        
        if file_ok:
            print()
    
    print("=" * 80)
    
    if all_good:
        print("\n✅ ALL ROUTES VERIFIED SUCCESSFULLY!")
        print("\nNew API Routes:")
        print("  • /lm/query          - AI assistant with two-pass pipeline")
        print("  • /lm/generate       - Direct LM text generation")
        print("  • /stt/transcribe    - Audio transcription only")
        print("  • /ai/process        - Combined STT + LM processing")
    else:
        print("\n❌ SOME ROUTES NOT FOUND - Please check the files above")
    
    return all_good

if __name__ == "__main__":
    success = check_routes()
    sys.exit(0 if success else 1)
