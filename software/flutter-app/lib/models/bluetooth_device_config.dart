enum BluetoothConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// Data format enum for serial communication
enum DataFormat {
  ascii,
  hex,
  decimal,
  binary,
}

/// Bluetooth device configuration model
class BluetoothDeviceConfig {
  final int? id; // Database ID
  final String address; // MAC address (unique identifier)
  final String name; // Device name
  final String? customAlias; // User-defined alias
  
  // Connection parameters
  final int baudRate; // Baud rate (e.g., 9600, 115200)
  final int dataBits; // Data bits (7 or 8)
  final int stopBits; // Stop bits (1 or 2)
  final bool parity; // Parity enabled
  final bool autoReconnect; // Auto-reconnect on disconnect
  final int bufferSize; // Buffer size in bytes
  final int connectionTimeout; // Connection timeout in seconds
  
  // Metadata
  final DateTime? lastConnected;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BluetoothDeviceConfig({
    this.id,
    required this.address,
    required this.name,
    this.customAlias,
    this.baudRate = 9600,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = false,
    this.autoReconnect = true,
    this.bufferSize = 1024,
    this.connectionTimeout = 10,
    this.lastConnected,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get display name (alias if available, otherwise device name)
  String get displayName => customAlias?.isNotEmpty == true ? customAlias! : name;

  /// Copy with method
  BluetoothDeviceConfig copyWith({
    int? id,
    String? address,
    String? name,
    String? customAlias,
    int? baudRate,
    int? dataBits,
    int? stopBits,
    bool? parity,
    bool? autoReconnect,
    int? bufferSize,
    int? connectionTimeout,
    DateTime? lastConnected,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BluetoothDeviceConfig(
      id: id ?? this.id,
      address: address ?? this.address,
      name: name ?? this.name,
      customAlias: customAlias ?? this.customAlias,
      baudRate: baudRate ?? this.baudRate,
      dataBits: dataBits ?? this.dataBits,
      stopBits: stopBits ?? this.stopBits,
      parity: parity ?? this.parity,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      bufferSize: bufferSize ?? this.bufferSize,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      lastConnected: lastConnected ?? this.lastConnected,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert to map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'address': address,
      'name': name,
      'custom_alias': customAlias,
      'baud_rate': baudRate,
      'data_bits': dataBits,
      'stop_bits': stopBits,
      'parity': parity ? 1 : 0,
      'auto_reconnect': autoReconnect ? 1 : 0,
      'buffer_size': bufferSize,
      'connection_timeout': connectionTimeout,
      'last_connected': lastConnected?.toIso8601String(),
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create from map (from database)
  factory BluetoothDeviceConfig.fromMap(Map<String, dynamic> map) {
    return BluetoothDeviceConfig(
      id: map['id'] as int?,
      address: map['address'] as String,
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
      isFavorite: (map['is_favorite'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() {
    return 'BluetoothDeviceConfig(address: $address, name: $name, alias: $customAlias)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BluetoothDeviceConfig && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;
}

/// Connection info for active connections
class BluetoothConnectionInfo {
  final String deviceAddress;
  final BluetoothConnectionState state;
  final DateTime? connectedAt;
  final String? errorMessage;
  final int bytesSent;
  final int bytesReceived;

  const BluetoothConnectionInfo({
    required this.deviceAddress,
    required this.state,
    this.connectedAt,
    this.errorMessage,
    this.bytesSent = 0,
    this.bytesReceived = 0,
  });

  BluetoothConnectionInfo copyWith({
    String? deviceAddress,
    BluetoothConnectionState? state,
    DateTime? connectedAt,
    String? errorMessage,
    int? bytesSent,
    int? bytesReceived,
  }) {
    return BluetoothConnectionInfo(
      deviceAddress: deviceAddress ?? this.deviceAddress,
      state: state ?? this.state,
      connectedAt: connectedAt ?? this.connectedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
    );
  }

  bool get isConnected => state == BluetoothConnectionState.connected;
  bool get isConnecting => state == BluetoothConnectionState.connecting;
  bool get isDisconnected => state == BluetoothConnectionState.disconnected;
  bool get hasError => state == BluetoothConnectionState.error;
}
