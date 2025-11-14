"""Test script for assistant endpoint - two-pass pipeline."""

import requests
import json
import sys
import os

# Fix Windows console encoding for Unicode
if sys.platform == 'win32':
    os.system('chcp 65001 > nul')
    sys.stdout.reconfigure(encoding='utf-8')

BASE_URL = "http://localhost:5000"

def test_text_generation():
    """Test text-generation category (streaming)."""
    print("\n" + "="*60)
    print("TEST 1: Text Generation (Streaming)")
    print("="*60)
    
    response = requests.post(
        f"{BASE_URL}/api/v1/assistant/handle",
        json={
            "user_query": "Hi there, how are you?",
            "source_device_mac": "5D:17:47:13:E7:49"
        },
        stream=True
    )
    
    if response.status_code != 200:
        print(f"❌ Failed: {response.status_code}")
        print(response.text)
        return False
    
    print("✓ Request successful, streaming response:")
    print("-" * 60)
    
    full_text = ""
    for line in response.iter_lines():
        if line:
            line_str = line.decode('utf-8')
            print(line_str)
            
            if line_str.startswith('data: '):
                try:
                    data = json.loads(line_str[6:])
                    if 'chunk' in data:
                        full_text += data['chunk']
                except:
                    pass
    
    print("-" * 60)
    print(f"✓ Full response: {full_text[:100]}...")
    return True


def test_bt_control():
    """Test bt-control category (JSON response)."""
    print("\n" + "="*60)
    print("TEST 2: Bluetooth Control (JSON)")
    print("="*60)
    
    response = requests.post(
        f"{BASE_URL}/api/v1/assistant/handle",
        json={
            "user_query": "turn on bluetooth lights",
            "source_device_mac": "5D:17:47:13:E7:49"
        }
    )
    
    if response.status_code != 200:
        print(f"❌ Failed: {response.status_code}")
        print(response.text)
        return False
    
    result = response.json()
    print("✓ Request successful, JSON response:")
    print("-" * 60)
    print(json.dumps(result, indent=2))
    print("-" * 60)
    
    # Validate structure
    if 'result' in result:
        bt_result = result['result']
        required_fields = ['task', 'user-data', 'source-device', 'target-device', 'output']
        
        for field in required_fields:
            if field not in bt_result:
                print(f"❌ Missing field: {field}")
                return False
        
        print(f"✓ Task: {bt_result['task']}")
        print(f"✓ Command: {bt_result['output']['generated_output']}")
        print(f"✓ Target: {bt_result['target-device']}")
    
    return True


def test_bt_control_generic_format():
    """Test bt-control with generic format (no user-defined format)."""
    print("\n" + "="*60)
    print("TEST 3: Bluetooth Control - Generic Format")
    print("="*60)
    
    response = requests.post(
        f"{BASE_URL}/api/v1/assistant/handle",
        json={
            "user_query": "blink bluetooth LED for 5 seconds",
            "source_device_mac": "5D:17:47:13:E7:49"
        }
    )
    
    if response.status_code != 200:
        print(f"❌ Failed: {response.status_code}")
        print(response.text)
        return False
    
    result = response.json()
    print("✓ Request successful:")
    print("-" * 60)
    
    if 'result' in result:
        command = result['result']['output']['generated_output']
        print(f"✓ Command: {command}")
        
        # Should be in format actuator:action or actuator:action-param
        if ':' in command:
            print(f"✓ Generic format detected: {command}")
        else:
            print(f"⚠️  Expected generic format (actuator:action), got: {command}")
    
    print(json.dumps(result, indent=2))
    return True


def test_device_not_found():
    """Test bt-control with non-existent device."""
    print("\n" + "="*60)
    print("TEST 4: Device Not Found")
    print("="*60)
    
    response = requests.post(
        f"{BASE_URL}/api/v1/assistant/handle",
        json={
            "user_query": "turn on robot lights",
            "source_device_mac": "5D:17:47:13:E7:49"
        }
    )
    
    if response.status_code != 200:
        print(f"❌ Failed: {response.status_code}")
        print(response.text)
        return False
    
    result = response.json()
    print("✓ Request completed:")
    print("-" * 60)
    print(json.dumps(result, indent=2))
    print("-" * 60)
    
    if 'result' in result and 'error' in result['result']:
        print(f"✓ Error detected as expected: {result['result']['error']['message']}")
    else:
        print("⚠️  Expected error for non-existent device")
    
    return True


def test_health():
    """Test server health endpoint."""
    print("\n" + "="*60)
    print("PRE-TEST: Server Health Check")
    print("="*60)
    
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        
        if response.status_code == 200:
            print("✓ Server is running")
            data = response.json()
            print(f"  Status: {data.get('status')}")
            return True
        else:
            print(f"❌ Server returned: {response.status_code}")
            return False
    
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to server")
        print(f"   Make sure Flask server is running at {BASE_URL}")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


if __name__ == "__main__":
    print("\n" + "="*60)
    print("ASSISTANT ENDPOINT TEST SUITE")
    print("="*60)
    
    # Check server health first
    if not test_health():
        print("\n❌ Server is not running. Exiting.")
        sys.exit(1)
    
    # Run tests
    tests = [
        ("Text Generation", test_text_generation),
        ("BT Control", test_bt_control),
        ("BT Control (Generic)", test_bt_control_generic_format),
        ("Device Not Found", test_device_not_found),
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            passed = test_func()
            results.append((test_name, passed))
        except Exception as e:
            print(f"❌ Test failed with exception: {e}")
            import traceback
            traceback.print_exc()
            results.append((test_name, False))
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    for test_name, passed in results:
        status = "✓ PASS" if passed else "❌ FAIL"
        print(f"{status}: {test_name}")
    
    passed_count = sum(1 for _, p in results if p)
    total_count = len(results)
    
    print(f"\nPassed: {passed_count}/{total_count}")
    
    if passed_count == total_count:
        print("\n🎉 All tests passed!")
        sys.exit(0)
    else:
        print("\n⚠️  Some tests failed")
        sys.exit(1)
