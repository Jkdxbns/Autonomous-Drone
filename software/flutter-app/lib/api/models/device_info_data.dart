/// Model for device information
class DeviceInfoData {
  final String deviceId; // Unique UUID
  final String deviceName; // e.g., "Samsung Galaxy S21"
  final String modelName; // e.g., "SM-G991B"
  final String? macAddress; // Wi-Fi MAC (optional, may be null)
  final String? ipAddress; // IP address or parent device info (optional)

  DeviceInfoData({
    required this.deviceId,
    required this.deviceName,
    required this.modelName,
    this.macAddress,
    this.ipAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'model_name': modelName,
      if (macAddress != null) 'mac_address': macAddress,
      if (ipAddress != null) 'ip_address': ipAddress,
    };
  }

  @override
  String toString() {
    return 'DeviceInfo(id: $deviceId, name: $deviceName, model: $modelName, mac: ${macAddress ?? "N/A"}, ip: ${ipAddress ?? "N/A"})';
  }
}
