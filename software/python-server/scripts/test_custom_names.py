"""
Test script for custom device name functionality
Tests PUT /device/<id>/name and DELETE /device/<id>/name endpoints
"""

import requests
import json
import sys

BASE_URL = "http://127.0.0.1:5000"

def test_device_list():
    """Get current device list"""
    print("\n=== Getting Device List ===")
    response = requests.get(f"{BASE_URL}/device/list")
    
    if response.status_code == 200:
        data = response.json()
        devices = data.get('devices', [])
        print(f"✓ Found {len(devices)} device(s)")
        
        for device in devices:
            device_id = device.get('device_id')
            device_name = device.get('device_name')
            custom_name = device.get('custom_name')
            has_custom = device.get('has_custom_name', False)
            
            display_name = custom_name if has_custom else device_name
            print(f"  - ID: {device_id}")
            print(f"    Name: {display_name}")
            print(f"    Custom: {has_custom}")
            print(f"    MAC: {device.get('mac_address')}")
        
        return devices
    else:
        print(f"✗ Failed: {response.status_code}")
        return []


def test_update_name(device_id, custom_name, updated_by="test-script"):
    """Test updating device custom name"""
    print(f"\n=== Updating Device Name ===")
    print(f"Device ID: {device_id}")
    print(f"Custom Name: {custom_name}")
    
    response = requests.put(
        f"{BASE_URL}/device/{device_id}/name",
        json={
            "custom_name": custom_name,
            "updated_by_device_id": updated_by
        },
        headers={"Content-Type": "application/json"}
    )
    
    if response.status_code == 200:
        data = response.json()
        print(f"✓ Success: {data.get('message')}")
        device = data.get('device', {})
        print(f"  Updated name: {device.get('custom_name')}")
        print(f"  Has custom: {device.get('has_custom_name')}")
        print(f"  Updated at: {device.get('custom_name_updated_at')}")
        print(f"  Updated by: {device.get('custom_name_updated_by')}")
        return True
    else:
        print(f"✗ Failed: {response.status_code}")
        print(f"  Error: {response.text}")
        return False


def test_clear_name(device_id):
    """Test clearing device custom name"""
    print(f"\n=== Clearing Device Name ===")
    print(f"Device ID: {device_id}")
    
    response = requests.delete(
        f"{BASE_URL}/device/{device_id}/name"
    )
    
    if response.status_code == 200:
        data = response.json()
        print(f"✓ Success: {data.get('message')}")
        device = data.get('device', {})
        print(f"  Auto name: {device.get('device_name')}")
        print(f"  Custom name: {device.get('custom_name')}")
        print(f"  Has custom: {device.get('has_custom_name')}")
        return True
    else:
        print(f"✗ Failed: {response.status_code}")
        print(f"  Error: {response.text}")
        return False


def main():
    print("=" * 50)
    print("Custom Device Name Test")
    print("=" * 50)
    
    # Get device list
    devices = test_device_list()
    
    if not devices:
        print("\n⚠ No devices found. Please register a device first.")
        print("  Tip: Launch the Flutter app and it will auto-register")
        return
    
    # Use first device for testing
    device_id = devices[0].get('device_id')
    original_name = devices[0].get('device_name')
    
    print(f"\nUsing device: {device_id}")
    print(f"Original name: {original_name}")
    
    # Test 1: Update to custom name
    if test_update_name(device_id, "My Awesome Phone", "test-device-1"):
        print("\n✓ Test 1 passed: Custom name set")
    else:
        print("\n✗ Test 1 failed")
        sys.exit(1)
    
    # Verify change
    devices = test_device_list()
    if devices[0].get('custom_name') == "My Awesome Phone":
        print("✓ Custom name verified in list")
    else:
        print("✗ Custom name not found in list")
        sys.exit(1)
    
    # Test 2: Update from different device (simulating multi-device)
    if test_update_name(device_id, "Living Room Phone", "test-device-2"):
        print("\n✓ Test 2 passed: Name updated from different device")
    else:
        print("\n✗ Test 2 failed")
        sys.exit(1)
    
    # Verify change
    devices = test_device_list()
    if devices[0].get('custom_name') == "Living Room Phone":
        print("✓ Updated name verified (latest wins)")
    else:
        print("✗ Name not updated correctly")
        sys.exit(1)
    
    # Test 3: Clear custom name
    if test_clear_name(device_id):
        print("\n✓ Test 3 passed: Custom name cleared")
    else:
        print("\n✗ Test 3 failed")
        sys.exit(1)
    
    # Verify cleared
    devices = test_device_list()
    if not devices[0].get('has_custom_name') and devices[0].get('device_name') == original_name:
        print("✓ Reverted to auto-detected name")
    else:
        print("✗ Name not reverted correctly")
        sys.exit(1)
    
    print("\n" + "=" * 50)
    print("✓ All tests passed!")
    print("=" * 50)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n✗ Test failed with error: {e}")
        sys.exit(1)
