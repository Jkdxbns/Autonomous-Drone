"""Device management service - business logic for device tracking."""

from datetime import datetime, timedelta
from typing import Dict, List, Optional
from models.device_model import DeviceRegistry


class DeviceService:
    """Handles device registration, tracking, and status management."""
    
    def __init__(self, registry: DeviceRegistry):
        """Initialize device service with registry.
        
        Args:
            registry: DeviceRegistry instance for data persistence.
        """
        self.registry = registry
        print("[DEVICE_SERVICE] Initialized")
    
    def register_device(
        self,
        device_id: str,
        device_name: str,
        model_name: str,
        ip_address: str,
        mac_address: Optional[str] = None,
    ) -> dict:
        """Register or update a device.
        
        Args:
            device_id: Device UUID
            device_name: Human-readable device name
            model_name: Device model identifier
            ip_address: Client IP address
            mac_address: Hardware MAC address (required)
        
        Returns:
            Device record dictionary.
        
        Raises:
            ValueError: If MAC address is invalid or missing.
        """
        return self.registry.register_device(
            device_id=device_id,
            device_name=device_name,
            model_name=model_name,
            ip_address=ip_address,
            mac_address=mac_address
        )
    
    def auto_register_from_headers(self, headers: dict, ip_address: str) -> Optional[dict]:
        """Auto-register device from HTTP request headers.
        
        Args:
            headers: Request headers dictionary
            ip_address: Client IP address
        
        Returns:
            Device record if registered, None otherwise.
        """
        return self.registry.auto_register_from_headers(headers, ip_address)
    
    def update_activity(self, mac_address: str) -> None:
        """Update device last_seen timestamp.
        
        Args:
            mac_address: Device MAC address
        """
        self.registry.update_last_seen(mac_address)
    
    def update_statuses(self) -> None:
        """Update device statuses (mark offline if inactive)."""
        self.registry.update_device_statuses()
    
    def get_all_devices(self) -> List[dict]:
        """Get all registered devices.
        
        Returns:
            List of device records sorted by last_seen.
        """
        return self.registry.get_all_devices()
    
    def get_device(self, identifier: str) -> Optional[dict]:
        """Get device by MAC address or device_id.
        
        Args:
            identifier: MAC address or device_id
        
        Returns:
            Device record or None if not found.
        """
        return self.registry.get_device(identifier)
    
    def update_custom_name(
        self,
        identifier: str,
        custom_name: str,
        updated_by_device_id: str
    ) -> Optional[dict]:
        """Update device custom name.
        
        Args:
            identifier: MAC address or device_id
            custom_name: New custom name
            updated_by_device_id: Device ID that initiated the change
        
        Returns:
            Updated device record or None if not found.
        """
        return self.registry.update_device_custom_name(
            identifier=identifier,
            custom_name=custom_name,
            updated_by_device_id=updated_by_device_id
        )
    
    def clear_custom_name(self, identifier: str) -> Optional[dict]:
        """Clear device custom name.
        
        Args:
            identifier: MAC address or device_id
        
        Returns:
            Updated device record or None if not found.
        """
        return self.registry.clear_device_custom_name(identifier)
    
    def get_stats(self) -> dict:
        """Get device registry statistics.
        
        Returns:
            Dictionary with total, online, and offline device counts.
        """
        return self.registry.get_stats()
    
    def get_device_by_mac(self, mac_address: str) -> Optional[dict]:
        """Get device by MAC address specifically.
        
        Args:
            mac_address: Device MAC address
        
        Returns:
            Device record or None if not found.
        """
        return self.registry.get_device(mac_address)
