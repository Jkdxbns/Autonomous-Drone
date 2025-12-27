"""Quick test of new API routes."""

import requests
import json

BASE_URL = "http://localhost:5000"

def test_route(method, endpoint, data=None, files=None, stream=False):
    """Test a single route."""
    url = f"{BASE_URL}{endpoint}"
    print(f"\n{'='*60}")
    print(f"Testing: {method} {endpoint}")
    print('='*60)
    
    try:
        if method == "GET":
            r = requests.get(url)
        elif method == "POST":
            if files:
                r = requests.post(url, data=data, files=files, stream=stream)
            else:
                r = requests.post(url, json=data, stream=stream)
        
        print(f"✓ Status: {r.status_code}")
        
        if stream:
            print("✓ Streaming response received")
            lines = []
            for line in r.iter_lines():
                if line:
                    lines.append(line.decode('utf-8'))
                    if len(lines) <= 5:  # Show first 5 lines
                        print(f"  {line.decode('utf-8')}")
            print(f"  ... ({len(lines)} total lines)")
        else:
            result = r.json()
            print(f"✓ Response: {json.dumps(result, indent=2)[:200]}...")
        
        return True
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    print("\n" + "="*60)
    print("API ROUTE VERIFICATION TESTS")
    print("="*60)
    
    results = {}
    
    # Test health
    results['/health'] = test_route('GET', '/health')
    
    # Test catalog
    results['/catalog'] = test_route('GET', '/catalog')
    
    # Test /lm/generate
    results['/lm/generate'] = test_route(
        'POST', 
        '/lm/generate',
        data={'prompt': 'Say hi in 2 words', 'stream': False}
    )
    
    # Test /lm/query (text generation)
    results['/lm/query (text)'] = test_route(
        'POST',
        '/lm/query',
        data={
            'user_query': 'What is 2+2?',
            'source_device_mac': 'TEST:MAC:ADDRESS'
        },
        stream=True
    )
    
    # Test /lm/query (bt-control)
    results['/lm/query (bt)'] = test_route(
        'POST',
        '/lm/query',
        data={
            'user_query': 'turn on lights',
            'source_device_mac': 'TEST:MAC:ADDRESS'
        }
    )
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    for route, success in results.items():
        status = "✓ PASS" if success else "❌ FAIL"
        print(f"{status:8} {route}")
    
    total = len(results)
    passed = sum(results.values())
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n✅ ALL ROUTES WORKING!")
    else:
        print(f"\n⚠️  {total - passed} test(s) failed")

if __name__ == "__main__":
    main()
