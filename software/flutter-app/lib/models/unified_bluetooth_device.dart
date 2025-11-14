import 'bluetooth_device_config.dart';
import 'ble_device_config.dart';

/// Device type enum
enum BluetoothDeviceType {
  classic, // Bluetooth Classic (HC-05, HC-06)
  ble, // Bluetooth Low Energy (HM-10, Nordic, etc.)
}

/// Unified connection state
enum UnifiedConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// Unified Bluetooth Device - represents both Classic and BLE devices
class UnifiedBluetoothDevice {
  final String id; // MAC address (Classic) or UUID (BLE)
  final String name;
  final String? customAlias;
  final BluetoothDeviceType type;
  final int rssi; // Signal strength in dBm
  final bool isPaired; // Only meaningful for Classic

  // Type-specific configurations (only one will be non-null)
  final BluetoothDeviceConfig? classicConfig;
  final BleDeviceConfig? bleConfig;

  // Connection state
  final UnifiedConnectionState connectionState;
  final DateTime? lastConnected;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UnifiedBluetoothDevice({
    required this.id,
    required this.name,
    this.customAlias,
    required this.type,
    this.rssi = 0,
    this.isPaired = false,
    this.classicConfig,
    this.bleConfig,
    this.connectionState = UnifiedConnectionState.disconnected,
    this.lastConnected,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display name (alias > name > id)
  String get displayName => customAlias?.isNotEmpty == true
      ? customAlias!
      : (name.isNotEmpty ? name : id);

  /// Check if device is Classic
  bool get isClassic => type == BluetoothDeviceType.classic;

  /// Check if device is BLE
  bool get isBle => type == BluetoothDeviceType.ble;

  /// Check if connected
  bool get isConnected => connectionState == UnifiedConnectionState.connected;

  /// Check if connecting
  bool get isConnecting => connectionState == UnifiedConnectionState.connecting;

  /// Get device type badge emoji
  String get typeBadge => isClassic ? '🔵' : '🟢';

  /// Get device type label
  String get typeLabel => isClassic ? 'Classic' : 'BLE';

  /// Create from Classic device
  factory UnifiedBluetoothDevice.fromClassic(
    BluetoothDeviceConfig config, {
    bool isPaired = false,
    int rssi = 0,
    UnifiedConnectionState? connectionState,
  }) {
    return UnifiedBluetoothDevice(
      id: config.address,
      name: config.name,
      customAlias: config.customAlias,
      type: BluetoothDeviceType.classic,
      rssi: rssi,
      isPaired: isPaired,
      classicConfig: config,
      connectionState: connectionState ?? UnifiedConnectionState.disconnected,
      lastConnected: config.lastConnected,
      createdAt: config.createdAt,
      updatedAt: config.updatedAt,
    );
  }

  /// Create from BLE device
  factory UnifiedBluetoothDevice.fromBle(
    BleDeviceConfig config, {
    UnifiedConnectionState? connectionState,
  }) {
    return UnifiedBluetoothDevice(
      id: config.deviceId,
      name: config.deviceName ?? 'Unknown',
      customAlias: config.customAlias,
      type: BluetoothDeviceType.ble,
      rssi: config.rssi,
      isPaired: false, // BLE doesn't use pairing
      bleConfig: config,
      connectionState: connectionState ?? UnifiedConnectionState.disconnected,
      lastConnected: config.lastConnectedAt,
      createdAt: config.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Convert to map for database
  Map<String, dynamic> toMap() {
    return {
      'device_id': id,
      'device_type': type == BluetoothDeviceType.classic ? 'classic' : 'ble',
      'name': name,
      'custom_alias': customAlias,
      'rssi': rssi,
      'is_paired': isPaired ? 1 : 0,
      // Classic fields
      'baud_rate': classicConfig?.baudRate,
      'data_bits': classicConfig?.dataBits,
      'stop_bits': classicConfig?.stopBits,
      'parity': classicConfig?.parity == true ? 1 : 0,
      'buffer_size': classicConfig?.bufferSize,
      // BLE fields
      'service_uuid': bleConfig?.serviceUuid,
      'rx_characteristic_uuid': bleConfig?.rxCharacteristicUuid,
      'tx_characteristic_uuid': bleConfig?.txCharacteristicUuid,
      'mtu': bleConfig?.mtu,
      // Common fields
      'auto_reconnect': (classicConfig?.autoReconnect ?? bleConfig?.autoReconnect ?? false) ? 1 : 0,
      'connection_timeout': classicConfig?.connectionTimeout ?? bleConfig?.connectionTimeout,
      'last_connected': lastConnected?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from map (database)
  factory UnifiedBluetoothDevice.fromMap(Map<String, dynamic> map) {
    final typeStr = map['device_type'] as String;
    final type = typeStr == 'classic'
        ? BluetoothDeviceType.classic
        : BluetoothDeviceType.ble;

    BluetoothDeviceConfig? classicConfig;
    BleDeviceConfig? bleConfig;

    if (type == BluetoothDeviceType.classic) {
      classicConfig = BluetoothDeviceConfig(
        address: map['device_id'] as String,
        name: map['name'] as String,
        customAlias: map['custom_alias'] as String?,
        baudRate: map['baud_rate'] as int? ?? 9600,
        dataBits: map['data_bits'] as int? ?? 8,
        stopBits: map['stop_bits'] as int? ?? 1,
        parity: (map['parity'] as int?) == 1,
        autoReconnect: (map['auto_reconnect'] as int?) == 1,
        bufferSize: map['buffer_size'] as int? ?? 1024,
        connectionTimeout: map['connection_timeout'] as int? ?? 10,
        lastConnected: map['last_connected'] != null
            ? DateTime.parse(map['last_connected'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
    } else {
      bleConfig = BleDeviceConfig(
        deviceId: map['device_id'] as String,
        deviceName: map['name'] as String,
        customAlias: map['custom_alias'] as String?,
        autoReconnect: (map['auto_reconnect'] as int?) == 1,
        connectionTimeout: map['connection_timeout'] as int? ?? 10,
        mtu: map['mtu'] as int? ?? 512,
        serviceUuid: map['service_uuid'] as String?,
        rxCharacteristicUuid: map['rx_characteristic_uuid'] as String?,
        txCharacteristicUuid: map['tx_characteristic_uuid'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        lastConnectedAt: map['last_connected'] != null
            ? DateTime.parse(map['last_connected'] as String)
            : null,
        rssi: map['rssi'] as int? ?? 0,
      );
    }

    return UnifiedBluetoothDevice(
      id: map['device_id'] as String,
      name: map['name'] as String,
      customAlias: map['custom_alias'] as String?,
      type: type,
      rssi: map['rssi'] as int? ?? 0,
      isPaired: (map['is_paired'] as int?) == 1,
      classicConfig: classicConfig,
      bleConfig: bleConfig,
      connectionState: UnifiedConnectionState.disconnected,
      lastConnected: map['last_connected'] != null
          ? DateTime.parse(map['last_connected'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Copy with method
  UnifiedBluetoothDevice copyWith({
    String? id,
    String? name,
    String? customAlias,
    BluetoothDeviceType? type,
    int? rssi,
    bool? isPaired,
    BluetoothDeviceConfig? classicConfig,
    BleDeviceConfig? bleConfig,
    UnifiedConnectionState? connectionState,
    DateTime? lastConnected,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UnifiedBluetoothDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      customAlias: customAlias ?? this.customAlias,
      type: type ?? this.type,
      rssi: rssi ?? this.rssi,
      isPaired: isPaired ?? this.isPaired,
      classicConfig: classicConfig ?? this.classicConfig,
      bleConfig: bleConfig ?? this.bleConfig,
      connectionState: connectionState ?? this.connectionState,
      lastConnected: lastConnected ?? this.lastConnected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedBluetoothDevice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UnifiedBluetoothDevice(id: $id, name: $name, type: $typeLabel, connected: $isConnected)';
  }
}

/// Unified connection info
class UnifiedConnectionInfo {
  final String deviceId;
  final BluetoothDeviceType deviceType;
  final UnifiedConnectionState state;
  final DateTime? connectedAt;
  final int bytesSent;
  final int bytesReceived;
  final String? errorMessage;

  const UnifiedConnectionInfo({
    required this.deviceId,
    required this.deviceType,
    required this.state,
    this.connectedAt,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.errorMessage,
  });

  bool get isConnected => state == UnifiedConnectionState.connected;
  bool get isConnecting => state == UnifiedConnectionState.connecting;
  bool get hasError => state == UnifiedConnectionState.error;

  String get typeBadge => deviceType == BluetoothDeviceType.classic ? '🔵' : '🟢';
  String get typeLabel => deviceType == BluetoothDeviceType.classic ? 'Classic' : 'BLE';

  UnifiedConnectionInfo copyWith({
    String? deviceId,
    BluetoothDeviceType? deviceType,
    UnifiedConnectionState? state,
    DateTime? connectedAt,
    int? bytesSent,
    int? bytesReceived,
    String? errorMessage,
  }) {
    return UnifiedConnectionInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceType: deviceType ?? this.deviceType,
      state: state ?? this.state,
      connectedAt: connectedAt ?? this.connectedAt,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Unified data event for received data
class UnifiedDataEvent {
  final String deviceId;
  final BluetoothDeviceType deviceType;
  final String data;
  final DateTime timestamp;

  const UnifiedDataEvent({
    required this.deviceId,
    required this.deviceType,
    required this.data,
    required this.timestamp,
  });

  bool get isClassic => deviceType == BluetoothDeviceType.classic;
  bool get isBle => deviceType == BluetoothDeviceType.ble;
  String get typeBadge => deviceType == BluetoothDeviceType.classic ? '🔵' : '🟢';
  String get typeLabel => deviceType == BluetoothDeviceType.classic ? 'Classic' : 'BLE';
}
