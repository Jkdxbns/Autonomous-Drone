enum BleConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// Configuration for a BLE device
class BleDeviceConfig {
  final String deviceId; // UUID for BLE device
  final String? deviceName;
  final String? customAlias; // User-defined name
  
  // Connection settings
  final bool autoReconnect;
  final int connectionTimeout; // seconds
  final int mtu; // Maximum Transmission Unit (default 512)
  
  // Service & Characteristic UUIDs for HM-10 serial communication
  final String? serviceUuid; // Default: FFE0 for HM-10
  final String? rxCharacteristicUuid; // Default: FFE1 for HM-10 (write)
  final String? txCharacteristicUuid; // Default: FFE1 for HM-10 (notify)
  
  // Metadata
  final DateTime createdAt;
  final DateTime? lastConnectedAt;
  final int rssi; // Signal strength

  BleDeviceConfig({
    required this.deviceId,
    this.deviceName,
    this.customAlias,
    this.autoReconnect = false,
    this.connectionTimeout = 10,
    this.mtu = 512,
    this.serviceUuid,
    this.rxCharacteristicUuid,
    this.txCharacteristicUuid,
    required this.createdAt,
    this.lastConnectedAt,
    this.rssi = 0,
  });

  String get displayName => customAlias ?? deviceName ?? deviceId;

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'custom_alias': customAlias,
      'auto_reconnect': autoReconnect ? 1 : 0,
      'connection_timeout': connectionTimeout,
      'mtu': mtu,
      'service_uuid': serviceUuid,
      'rx_characteristic_uuid': rxCharacteristicUuid,
      'tx_characteristic_uuid': txCharacteristicUuid,
      'created_at': createdAt.toIso8601String(),
      'last_connected_at': lastConnectedAt?.toIso8601String(),
      'rssi': rssi,
    };
  }

  factory BleDeviceConfig.fromMap(Map<String, dynamic> map) {
    return BleDeviceConfig(
      deviceId: map['device_id'] as String,
      deviceName: map['device_name'] as String?,
      customAlias: map['custom_alias'] as String?,
      autoReconnect: (map['auto_reconnect'] as int) == 1,
      connectionTimeout: map['connection_timeout'] as int,
      mtu: map['mtu'] as int? ?? 512,
      serviceUuid: map['service_uuid'] as String?,
      rxCharacteristicUuid: map['rx_characteristic_uuid'] as String?,
      txCharacteristicUuid: map['tx_characteristic_uuid'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastConnectedAt: map['last_connected_at'] != null
          ? DateTime.parse(map['last_connected_at'] as String)
          : null,
      rssi: map['rssi'] as int? ?? 0,
    );
  }

  BleDeviceConfig copyWith({
    String? deviceId,
    String? deviceName,
    String? customAlias,
    bool? autoReconnect,
    int? connectionTimeout,
    int? mtu,
    String? serviceUuid,
    String? rxCharacteristicUuid,
    String? txCharacteristicUuid,
    DateTime? createdAt,
    DateTime? lastConnectedAt,
    int? rssi,
  }) {
    return BleDeviceConfig(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      customAlias: customAlias ?? this.customAlias,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      mtu: mtu ?? this.mtu,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      rxCharacteristicUuid: rxCharacteristicUuid ?? this.rxCharacteristicUuid,
      txCharacteristicUuid: txCharacteristicUuid ?? this.txCharacteristicUuid,
      createdAt: createdAt ?? this.createdAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      rssi: rssi ?? this.rssi,
    );
  }
}

/// Information about an active BLE connection
class BleConnectionInfo {
  final String deviceId;
  final BleConnectionState state;
  final DateTime? connectedAt;
  final int? currentMtu;
  final int bytesSent;
  final int bytesReceived;
  final String? errorMessage;

  BleConnectionInfo({
    required this.deviceId,
    required this.state,
    this.connectedAt,
    this.currentMtu,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.errorMessage,
  });

  BleConnectionInfo copyWith({
    String? deviceId,
    BleConnectionState? state,
    DateTime? connectedAt,
    int? currentMtu,
    int? bytesSent,
    int? bytesReceived,
    String? errorMessage,
  }) {
    return BleConnectionInfo(
      deviceId: deviceId ?? this.deviceId,
      state: state ?? this.state,
      connectedAt: connectedAt ?? this.connectedAt,
      currentMtu: currentMtu ?? this.currentMtu,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Event for data received from a BLE device
class BleDeviceDataEvent {
  final String deviceId;
  final List<int> data;
  final DateTime timestamp;

  BleDeviceDataEvent({
    required this.deviceId,
    required this.data,
    required this.timestamp,
  });

  String get dataAsString => String.fromCharCodes(data);
}

/// Common UUIDs for HM-10 module
class HM10Uuids {
  // HM-10 default service and characteristic UUIDs
  static const String serviceUuid = 'FFE0';
  static const String characteristicUuid = 'FFE1'; // Used for both RX and TX
  
  // Alternative UUIDs (some HM-10 clones use different UUIDs)
  static const String altServiceUuid = '0000FFE0-0000-1000-8000-00805F9B34FB';
  static const String altCharacteristicUuid = '0000FFE1-0000-1000-8000-00805F9B34FB';
}
