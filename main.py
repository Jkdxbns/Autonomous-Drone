"""
FlaskServer_v6 - Speech-to-Text and Language Model API Server

This server provides REST API endpoints for:
- Speech-to-text transcription (Whisper)
- Text generation (Gemini LM)
- Device tracking and management
- Model catalog access

Architecture:
- config/: Configuration and settings
- core/: Model loaders and utilities
- services/: Business logic layer
- routes/: HTTP endpoint handlers
- models/: Data models and persistence
"""

import time
import threading
from flask import Flask, request

# Import configuration
from config import DEVICE_REGISTRY_PATH

# Import models
from models.device_model import DeviceRegistry
import models.device_model as registry_module

# Import services
from services.catalog_service import CatalogService
from services.device_service import DeviceService

# Import route blueprints
from routes import health_routes, device_routes, lm_routes
from routes import assistant_routes, heartbeat_routes


app = Flask(__name__)

# Initialize device registry
print("[MAIN] Initializing device registry...")
registry_module.device_registry = DeviceRegistry(DEVICE_REGISTRY_PATH)
device_service = DeviceService(registry_module.device_registry)

# Initialize catalog service
catalog_service = CatalogService()


# Background thread to update device statuses
def status_monitor_thread():
    """Background thread to mark devices as offline when inactive."""
    while True:
        try:
            time.sleep(60)  # Check every minute
            device_service.update_statuses()
        except Exception as e:
            print(f"[MAIN] Status monitor error: {e}")


# Middleware to auto-register and track device activity
@app.before_request
def track_device_activity():
    """Auto-register device and update last_seen timestamp on each request.
    
    Uses MAC address as primary device identifier.
    """
    if request.endpoint and request.endpoint != 'static':
        mac_address = request.headers.get('X-Device-MAC')
        
        # If device already registered, update last_seen
        if mac_address and registry_module.device_registry.get_device(mac_address):
            device_service.update_activity(mac_address)
        else:
            # Try to auto-register from headers
            device_service.auto_register_from_headers(
                headers=dict(request.headers),
                ip_address=request.remote_addr
            )


# Register blueprints
app.register_blueprint(health_routes.bp)
app.register_blueprint(device_routes.bp)
app.register_blueprint(lm_routes.bp)
app.register_blueprint(assistant_routes.bp)
app.register_blueprint(heartbeat_routes.bp)


if __name__ == "__main__":
    # Update catalog from libraries before starting server
    print("[MAIN] Updating model catalog...")
    catalog_service.update_catalog()
    
    # Print device registry stats
    stats = device_service.get_stats()
    print(f"[MAIN] Loaded devices: {stats['total_devices']} total, "
          f"{stats['online_devices']} online, {stats['offline_devices']} offline")
    
    # Start background status monitor thread
    monitor = threading.Thread(target=status_monitor_thread, daemon=True)
    monitor.start()
    print("[MAIN] Status monitor thread started")
    
    # Start server
    print("\n" + "="*50)
    print("FlaskServer_v6 is running!")
    print("Endpoints: /health, /catalog, /device/*, /generate, /process")
    print("="*50 + "\n")
    app.run(host="0.0.0.0", port=5000, debug=True)
