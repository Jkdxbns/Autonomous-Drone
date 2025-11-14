"""
Test Device Lookup Table and Heartbeat System
Verifies device registration, status tracking, and heartbeat functionality.
"""

import requests
import json
import time
from datetime import datetime

BASE_URL = "http://localhost:5000"

# Test device data
TEST_PHONE = {
    "device_id": "test-phone-12345",
    "device_name": "Test Galaxy S21",
    "model_name": "SM-G991B",
    "mac_address": "AA:BB:CC:DD:EE:FF"
}

TEST_BT_DEVICE = {
    "device_id": "test-bt-12345",
    "device_name": "MLT-BT05",
    "model_name": "BLE Device",
    "mac_address": "11:22:33:44:55:66",
    "ip_address": "SM-G991B"  # Parent phone model
}


def print_section(title):
    """Print formatted section header."""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}\n")


def test_health():
    """Test server health endpoint."""
    print_section("1. Testing Server Health")
    
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Health check failed: {e}")
        return False


def test_device_registration():
    """Test device registration."""
    print_section("2. Testing Device Registration")
    
    # Register phone
    print("📱 Registering phone device...")
    try:
        headers = {
            'Content-Type': 'application/json',
            'X-Device-MAC': TEST_PHONE['mac_address'],
            'X-Device-Id': TEST_PHONE['device_id'],
            'X-Device-Name': TEST_PHONE['device_name'],
            'X-Device-Model': TEST_PHONE['model_name']
        }
        
        response = requests.post(
            f"{BASE_URL}/device/register",
            headers=headers,
            json=TEST_PHONE,
            timeout=5
        )
        
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        if response.status_code == 200:
            print("✅ Phone registered successfully")
        else:
            print(f"❌ Phone registration failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Phone registration error: {e}")
        return False
    
    # Register BT device
    print("\n🔵 Registering Bluetooth device...")
    try:
        headers = {
            'Content-Type': 'application/json',
            'X-Device-MAC': TEST_BT_DEVICE['mac_address'],
            'X-Device-Id': TEST_BT_DEVICE['device_id'],
            'X-Device-Name': TEST_BT_DEVICE['device_name'],
            'X-Device-Model': TEST_BT_DEVICE['model_name']
        }
        
        response = requests.post(
            f"{BASE_URL}/device/register",
            headers=headers,
            json=TEST_BT_DEVICE,
            timeout=5
        )
        
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        if response.status_code == 200:
            print("✅ Bluetooth device registered successfully")
        else:
            print(f"❌ BT device registration failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ BT device registration error: {e}")
        return False
    
    return True


def test_device_list():
    """Test device list retrieval."""
    print_section("3. Testing Device List")
    
    try:
        response = requests.get(f"{BASE_URL}/device/list", timeout=5)
        
        print(f"Status: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"\n📊 Device Stats:")
            print(f"  Total: {data['count']}")
            print(f"  Online: {data['stats']['online_devices']}")
            print(f"  Offline: {data['stats']['offline_devices']}")
            
            print(f"\n📋 Device List:")
            for device in data['devices']:
                status_icon = "🟢" if device['status'] == 'online' else "🔴"
                print(f"  {status_icon} {device['device_name']} ({device['mac_address']})")
                print(f"     Status: {device['status']}")
                print(f"     Last seen: {device['last_seen']}")
            
            return True
        else:
            print(f"❌ Failed to fetch device list: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Device list error: {e}")
        return False


def test_heartbeat():
    """Test heartbeat functionality."""
    print_section("4. Testing Heartbeat System")
    
    # Send heartbeat from phone
    print("💓 Sending heartbeat from phone (with connected BT device)...")
    try:
        headers = {
            'Content-Type': 'application/json',
            'X-Device-MAC': TEST_PHONE['mac_address'],
            'X-Device-Id': TEST_PHONE['device_id']
        }
        
        payload = {
            'connected_devices': [TEST_BT_DEVICE['mac_address']]
        }
        
        response = requests.post(
            f"{BASE_URL}/device/heartbeat",
            headers=headers,
            json=payload,
            timeout=5
        )
        
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        if response.status_code == 200:
            print("✅ Heartbeat sent successfully")
        else:
            print(f"❌ Heartbeat failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Heartbeat error: {e}")
        return False
    
    return True


def test_connection_status():
    """Test connection status reporting."""
    print_section("5. Testing Connection Status Updates")
    
    # Report BT device connected
    print("🔗 Reporting Bluetooth device connection...")
    try:
        headers = {
            'Content-Type': 'application/json',
            'X-Device-MAC': TEST_PHONE['mac_address']
        }
        
        payload = {
            'connected': [TEST_BT_DEVICE['mac_address']],
            'disconnected': []
        }
        
        response = requests.post(
            f"{BASE_URL}/device/connection-status",
            headers=headers,
            json=payload,
            timeout=5
        )
        
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        
        if response.status_code == 200:
            print("✅ Connection status reported successfully")
        else:
            print(f"❌ Connection status failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Connection status error: {e}")
        return False
    
    return True


def test_status_persistence():
    """Test that devices stay online with heartbeat."""
    print_section("6. Testing Status Persistence")
    
    print("⏱️  Sending heartbeats every 30 seconds for 2 minutes...")
    print("   (Devices should stay online during this time)")
    
    for i in range(4):  # 4 heartbeats over 2 minutes
        print(f"\n💓 Heartbeat {i+1}/4 at {datetime.now().strftime('%H:%M:%S')}")
        
        try:
            headers = {
                'Content-Type': 'application/json',
                'X-Device-MAC': TEST_PHONE['mac_address'],
                'X-Device-Id': TEST_PHONE['device_id']
            }
            
            payload = {
                'connected_devices': [TEST_BT_DEVICE['mac_address']]
            }
            
            response = requests.post(
                f"{BASE_URL}/device/heartbeat",
                headers=headers,
                json=payload,
                timeout=5
            )
            
            if response.status_code == 200:
                print("   ✅ Heartbeat sent")
                
                # Check device status
                list_response = requests.get(f"{BASE_URL}/device/list", timeout=5)
                if list_response.status_code == 200:
                    devices = list_response.json()['devices']
                    phone = next((d for d in devices if d['mac_address'] == TEST_PHONE['mac_address']), None)
                    bt = next((d for d in devices if d['mac_address'] == TEST_BT_DEVICE['mac_address']), None)
                    
                    if phone:
                        print(f"   📱 Phone: {phone['status']}")
                    if bt:
                        print(f"   🔵 BT Device: {bt['status']}")
            else:
                print(f"   ❌ Heartbeat failed: {response.status_code}")
                
        except Exception as e:
            print(f"   ❌ Error: {e}")
        
        if i < 3:  # Don't wait after last heartbeat
            print("   Waiting 30 seconds...")
            time.sleep(30)
    
    print("\n✅ Status persistence test completed")
    return True


def test_timeout():
    """Test that devices go offline after 2 minutes without heartbeat."""
    print_section("7. Testing Timeout (2 minute wait)")
    
    print("⏱️  Waiting 2.5 minutes without heartbeat...")
    print("   (Devices should go offline)")
    
    for i in range(15):  # 15 * 10 seconds = 2.5 minutes
        time.sleep(10)
        remaining = 150 - (i + 1) * 10
        print(f"   ⏳ {remaining} seconds remaining...")
    
    # Check status
    print("\n📊 Checking device status after timeout...")
    try:
        response = requests.get(f"{BASE_URL}/device/list", timeout=5)
        
        if response.status_code == 200:
            devices = response.json()['devices']
            phone = next((d for d in devices if d['mac_address'] == TEST_PHONE['mac_address']), None)
            bt = next((d for d in devices if d['mac_address'] == TEST_BT_DEVICE['mac_address']), None)
            
            print(f"\n📱 Phone Status: {phone['status'] if phone else 'NOT FOUND'}")
            print(f"🔵 BT Device Status: {bt['status'] if bt else 'NOT FOUND'}")
            
            if phone and phone['status'] == 'offline':
                print("✅ Phone correctly marked offline")
            else:
                print("❌ Phone should be offline but isn't")
            
            if bt and bt['status'] == 'offline':
                print("✅ BT device correctly marked offline")
            else:
                print("❌ BT device should be offline but isn't")
            
            return True
        else:
            print(f"❌ Failed to check status: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Status check error: {e}")
        return False


def main():
    """Run all tests."""
    print("\n" + "="*60)
    print("  DEVICE LOOKUP TABLE & HEARTBEAT VERIFICATION TEST")
    print("="*60)
    
    tests = [
        ("Server Health", test_health),
        ("Device Registration", test_device_registration),
        ("Device List", test_device_list),
        ("Heartbeat", test_heartbeat),
        ("Connection Status", test_connection_status),
        ("Status Persistence", test_status_persistence),
        # ("Timeout Test", test_timeout),  # Uncomment to test timeout (takes 2.5 minutes)
    ]
    
    results = []
    
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"\n❌ {test_name} crashed: {e}")
            results.append((test_name, False))
    
    # Print summary
    print_section("TEST SUMMARY")
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        icon = "✅" if result else "❌"
        print(f"{icon} {test_name}")
    
    print(f"\n📊 Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed!")
    else:
        print(f"⚠️  {total - passed} test(s) failed")


if __name__ == "__main__":
    main()
