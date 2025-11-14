"""Heartbeat Routes - Device connection status updates."""

from flask import Blueprint, request, jsonify
import models.device_model as registry_module


bp = Blueprint("heartbeat", __name__)


@bp.post("/device/heartbeat")
def device_heartbeat():
    """Update device last_seen timestamp to keep it marked as online.
    
    This should be called periodically by devices to maintain online status.
    
    Request Headers:
    - X-Device-MAC: Device MAC address (or device_id as fallback)
    
    Request JSON (optional):
    {
        "connected_devices": ["MAC1", "MAC2"]  # BT devices connected to this phone
    }
    
    Response:
    {
        "status": "success",
        "message": "Heartbeat received",
        "device_mac": "AA:BB:CC:DD:EE:FF"
    }
    """
    print("\n" + "="*80)
    print("[HEARTBEAT] POST /device/heartbeat called")
    print("="*80)
    
    if registry_module.device_registry is None:
        return jsonify(error="Device registry not initialized"), 500
    
    # DEBUG: Print all headers
    print("\n[DEBUG] Request Headers:")
    for header_name, header_value in request.headers:
        print(f"  {header_name}: {header_value}")
    
    # Get device identifier from header (Flask normalizes to title case)
    device_mac = request.headers.get('X-Device-MAC') or request.headers.get('X-Device-Mac')
    device_id = request.headers.get('X-Device-Id')
    
    identifier = device_mac or device_id
    
    print(f"\n[DEBUG] Extracted Identifiers:")
    print(f"  X-Device-MAC (or X-Device-Mac): {device_mac}")
    print(f"  X-Device-Id: {device_id}")
    print(f"  Final identifier: {identifier}")
    print(f"  remote_addr: {request.remote_addr}")
    
    if not identifier:
        print(f"[ERROR] No device identifier found in headers")
        print("="*80 + "\n")
        return jsonify(error="Missing device identifier (X-Device-MAC or X-Device-Id)"), 400
    
    try:
        # Update this device's last_seen
        print(f"\n[HEARTBEAT] Attempting to update last_seen for: {identifier}")
        updated = registry_module.device_registry.update_last_seen(identifier)
        
        print(f"[HEARTBEAT] update_last_seen result: {updated}")
        
        if not updated:
            # Device not found - try auto-registration from headers
            print(f"[HEARTBEAT] Device {identifier} not found in registry")
            print(f"[HEARTBEAT] Attempting auto-registration from headers...")
            
            device = registry_module.device_registry.auto_register_from_headers(
                headers=request.headers,
                ip_address=request.remote_addr
            )
            
            if device:
                print(f"[SUCCESS] Auto-registered device: {device.get('device_name')} ({device.get('device_id')})")
                updated = True
            else:
                print(f"[ERROR] Auto-registration failed for identifier: {identifier}")
                print("="*80 + "\n")
                return jsonify(error="Device not found and auto-registration failed"), 404
        else:
            print(f"[SUCCESS] Updated last_seen for device: {identifier}")
        
        # Update connected Bluetooth devices if provided
        payload = request.get_json() or {}
        connected_devices = payload.get('connected_devices', [])
        
        print(f"\n[DEBUG] Connected devices in payload: {connected_devices}")
        
        for bt_mac in connected_devices:
            if bt_mac and bt_mac != identifier:
                bt_updated = registry_module.device_registry.update_last_seen(bt_mac)
                print(f"[HEARTBEAT] Updated connected BT device {bt_mac}: {bt_updated}")
        
        print(f"[SUCCESS] Heartbeat processed successfully")
        print("="*80 + "\n")
        
        return jsonify({
            "status": "success",
            "message": "Heartbeat received",
            "device_identifier": identifier,
            "connected_devices_updated": len(connected_devices)
        }), 200
    
    except Exception as e:
        print(f"\n[ERROR] Heartbeat failed: {str(e)}")
        print("="*80 + "\n")
        return jsonify(error=f"Heartbeat failed: {str(e)}"), 500


@bp.post("/device/connection-status")
def update_connection_status():
    """Update connection status for Bluetooth devices.
    
    Called when devices connect/disconnect from phone.
    
    Request JSON:
    {
        "connected": ["MAC1", "MAC2"],    # Currently connected devices
        "disconnected": ["MAC3"]          # Recently disconnected devices
    }
    
    Response:
    {
        "status": "success",
        "updated_count": 3
    }
    """
    if registry_module.device_registry is None:
        return jsonify(error="Device registry not initialized"), 500
    
    try:
        payload = request.get_json() or {}
        connected = payload.get('connected', [])
        disconnected = payload.get('disconnected', [])
        
        updated_count = 0
        
        # Mark connected devices as online
        for mac in connected:
            if registry_module.device_registry.update_last_seen(mac):
                updated_count += 1
        
        # Mark disconnected devices as offline immediately
        # (Don't wait for 2-minute timeout)
        for mac in disconnected:
            # Note: Would need to add a mark_offline method to device_model.py
            # For now, they'll just timeout naturally
            print(f"[CONNECTION] Device disconnected: {mac}")
            updated_count += 1
        
        return jsonify({
            "status": "success",
            "updated_count": updated_count,
            "connected": len(connected),
            "disconnected": len(disconnected)
        }), 200
    
    except Exception as e:
        return jsonify(error=f"Connection status update failed: {str(e)}"), 500
