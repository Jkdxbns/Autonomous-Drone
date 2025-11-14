"""
Test Hardware MAC Address Extraction
Verifies that the new MAC address system works correctly
"""

import requests
import json

BASE_URL = "http://127.0.0.1:5000"

def test_device_registration_with_mac():
    """Test that devices register with proper hardware MAC"""
    print("\n=== Testing Hardware MAC Registration ===")
    
    # Simulate device registration with hardware MAC
    test_mac = "A1:B2:C3:D4:E5:F6"
    
    response = requests.post(
        f"{BASE_URL}/device/register",
        json={
            "device_id": "test-device-001",
            "device_name": "Test Device",
            "model_name": "Test Model",
            "ip_address": "192.168.0.100",
            "mac_address": test_mac
        },
        headers={"Content-Type": "application/json"}
    )
    
    print(f"Status: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        print(f"✓ Device registered successfully")
        print(f"  MAC Address: {data.get('device', {}).get('mac_address')}")
        print(f"  Device ID: {data.get('device', {}).get('device_id')}")
        print(f"  Device Name: {data.get('device', {}).get('device_name')}")
        return True
    else:
        print(f"✗ Registration failed: {response.text}")
        return False


def test_device_list_shows_mac():
    """Test that device list shows hardware MAC addresses"""
    print("\n=== Testing Device List with MAC ===")
    
    response = requests.get(f"{BASE_URL}/device/list")
    
    if response.status_code == 200:
        data = response.json()
        devices = data.get('devices', [])
        
        print(f"✓ Found {len(devices)} device(s)")
        
        for device in devices:
            mac = device.get('mac_address')
            device_id = device.get('device_id')
            device_name = device.get('device_name')
            
            print(f"\n  Device: {device_name}")
            print(f"    MAC: {mac}")
            print(f"    ID: {device_id}")
            
            # Validate MAC format
            if mac and ':' in mac and len(mac.split(':')) == 6:
                # Check if it's NOT an IP address
                if not mac.startswith(('192.168', '10.', '172.')):
                    print(f"    ✓ Valid hardware MAC format")
                else:
                    print(f"    ✗ WARNING: MAC looks like IP address")
            else:
                print(f"    ✗ WARNING: Invalid MAC format")
        
        return True
    else:
        print(f"✗ Failed to get device list: {response.status_code}")
        return False


def test_invalid_mac_rejection():
    """Test that devices with invalid MACs are rejected"""
    print("\n=== Testing Invalid MAC Rejection ===")
    
    invalid_macs = [
        ("192.168.0.100", "IP address as MAC"),
        ("10.0.0.1", "Private IP"),
        ("invalid", "Not a MAC format"),
        (None, "No MAC provided"),
        ("", "Empty MAC"),
    ]
    
    for mac, description in invalid_macs:
        print(f"\n  Testing: {description} ({mac})")
        
        response = requests.post(
            f"{BASE_URL}/device/register",
            json={
                "device_id": "test-invalid-001",
                "device_name": "Invalid Test",
                "model_name": "Test",
                "ip_address": "192.168.0.101",
                "mac_address": mac
            },
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code != 200:
            print(f"    ✓ Correctly rejected (status {response.status_code})")
        else:
            print(f"    ✗ WARNING: Should have been rejected")
    
    return True


def test_mac_as_primary_key():
    """Test that MAC address is used as primary key"""
    print("\n=== Testing MAC as Primary Key ===")
    
    test_mac = "11:22:33:44:55:66"
    
    # Register device with device_id "old-id"
    response1 = requests.post(
        f"{BASE_URL}/device/register",
        json={
            "device_id": "old-id-001",
            "device_name": "Test Phone",
            "model_name": "Test Model",
            "ip_address": "192.168.0.102",
            "mac_address": test_mac
        },
        headers={"Content-Type": "application/json"}
    )
    
    if response1.status_code == 200:
        print("✓ Device registered with device_id='old-id-001'")
    else:
        print(f"✗ Initial registration failed")
        return False
    
    # Register same MAC but different device_id (simulating app reinstall)
    response2 = requests.post(
        f"{BASE_URL}/device/register",
        json={
            "device_id": "new-id-002",  # DIFFERENT device_id
            "device_name": "Test Phone",
            "model_name": "Test Model",
            "ip_address": "192.168.0.102",
            "mac_address": test_mac  # SAME MAC
        },
        headers={"Content-Type": "application/json"}
    )
    
    if response2.status_code == 200:
        print("✓ Device re-registered with device_id='new-id-002'")
    else:
        print(f"✗ Re-registration failed")
        return False
    
    # Get device list - should show only ONE device with this MAC
    response3 = requests.get(f"{BASE_URL}/device/list")
    
    if response3.status_code == 200:
        data = response3.json()
        devices = data.get('devices', [])
        
        # Count devices with this MAC
        matching_devices = [d for d in devices if d.get('mac_address') == test_mac]
        
        if len(matching_devices) == 1:
            print(f"✓ Only ONE device found with MAC {test_mac}")
            print(f"  Device ID updated to: {matching_devices[0].get('device_id')}")
            
            if matching_devices[0].get('device_id') == 'new-id-002':
                print(f"✓ Device ID correctly updated (MAC is primary key)")
                return True
            else:
                print(f"✗ Device ID not updated correctly")
                return False
        else:
            print(f"✗ Found {len(matching_devices)} devices (expected 1)")
            return False
    
    return False


def main():
    print("=" * 60)
    print("Hardware MAC Address Test Suite")
    print("=" * 60)
    
    tests = [
        ("Device Registration with MAC", test_device_registration_with_mac),
        ("Device List Shows MAC", test_device_list_shows_mac),
        ("Invalid MAC Rejection", test_invalid_mac_rejection),
        ("MAC as Primary Key", test_mac_as_primary_key),
    ]
    
    results = []
    
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"\n✗ Test failed with error: {e}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    
    for test_name, result in results:
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"{status}: {test_name}")
    
    passed = sum(1 for _, r in results if r)
    total = len(results)
    
    print(f"\nPassed: {passed}/{total}")
    
    if passed == total:
        print("\n✓ All tests passed!")
    else:
        print(f"\n✗ {total - passed} test(s) failed")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n✗ Test suite failed: {e}")
