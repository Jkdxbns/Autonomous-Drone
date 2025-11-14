/// Line ending options for messages
enum LineEnding {
  none('None', ''),
  lf('\\n (LF)', '\n'),
  cr('\\r (CR)', '\r'),
  crlf('\\r\\n (CRLF)', '\r\n'),
  nul('\\0 (NULL)', '\x00');

  final String label;
  final String value;
  const LineEnding(this.label, this.value);
}

/// Text encoding options
enum TextEncoding {
  utf8('UTF-8'),
  ascii('ASCII'),
  latin1('Latin-1');

  final String label;
  const TextEncoding(this.label);
}

/// Display format for received data
enum DisplayFormat {
  text('Text'),
  hex('Hex'),
  decimal('Decimal'),
  binary('Binary');

  final String label;
  const DisplayFormat(this.label);
}

/// Timestamp display format
enum TimestampFormat {
  none('None'),
  timeOnly('Time Only'),
  dateTime('Date & Time'),
  relative('Relative');

  final String label;
  const TimestampFormat(this.label);
}

/// Connection priority for BLE
enum BleConnectionPriority {
  lowPower('Low Power'),
  balanced('Balanced'),
  highPerformance('High Performance');

  final String label;
  const BleConnectionPriority(this.label);
}

/// Parity options for Classic Bluetooth
enum ParityType {
  none('None'),
  even('Even'),
  odd('Odd');

  final String label;
  const ParityType(this.label);
}

/// Flow control options
enum FlowControlType {
  none('None'),
  hardware('Hardware (RTS/CTS)'),
  software('Software (XON/XOFF)');

  final String label;
  const FlowControlType(this.label);
}

/// Global Bluetooth Settings
class BluetoothSettings {
  // Connection Settings
  final bool autoReconnect;
  final int connectionTimeout; // seconds
  final int reconnectAttempts;
  final int reconnectDelay; // seconds
  final int keepAliveInterval; // seconds, 0 = off

  // Classic Bluetooth Settings
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final ParityType parity;
  final int bufferSize; // bytes
  final FlowControlType flowControl;

  // BLE Settings
  final int mtuSize; // bytes
  final String serviceUuid;
  final String rxCharacteristicUuid;
  final String txCharacteristicUuid;
  final BleConnectionPriority bleConnectionPriority;
  final int notificationDelay; // milliseconds

  // Message Formatting
  final LineEnding lineEnding;
  final String autoPrefix;
  final String autoSuffix;
  final TextEncoding encoding;
  final bool trimWhitespace;

  // Display & Logging
  final DisplayFormat displayFormat;
  final TimestampFormat timestampFormat;
  final int maxMessageHistory;
  final bool autoScroll;
  final bool localEcho;
  final bool enableLogging;

  // Advanced Settings
  final bool packetChunking;
  final int chunkSize; // bytes
  final int chunkDelay; // milliseconds
  final bool discardInvalidUtf8;
  final int scanDuration; // seconds

  // Notifications & Alerts
  final bool connectionSound;
  final bool messageSound;
  final bool vibrateOnMessage;
  final bool showToastNotifications;

  const BluetoothSettings({
    // Connection defaults
    this.autoReconnect = true,
    this.connectionTimeout = 10,
    this.reconnectAttempts = 3,
    this.reconnectDelay = 2,
    this.keepAliveInterval = 30,
    
    // Classic Bluetooth defaults
    this.baudRate = 9600,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = ParityType.none,
    this.bufferSize = 1024,
    this.flowControl = FlowControlType.none,
    
    // BLE defaults
    this.mtuSize = 512,
    this.serviceUuid = 'FFE0',
    this.rxCharacteristicUuid = 'FFE1',
    this.txCharacteristicUuid = 'FFE1',
    this.bleConnectionPriority = BleConnectionPriority.balanced,
    this.notificationDelay = 0,
    
    // Message formatting defaults
    this.lineEnding = LineEnding.none,
    this.autoPrefix = '',
    this.autoSuffix = '',
    this.encoding = TextEncoding.utf8,
    this.trimWhitespace = false,
    
    // Display defaults
    this.displayFormat = DisplayFormat.text,
    this.timestampFormat = TimestampFormat.relative,
    this.maxMessageHistory = 200,
    this.autoScroll = true,
    this.localEcho = false,
    this.enableLogging = false,
    
    // Advanced defaults
    this.packetChunking = true,
    this.chunkSize = 20,
    this.chunkDelay = 50,
    this.discardInvalidUtf8 = false,
    this.scanDuration = 15,
    
    // Notifications defaults
    this.connectionSound = true,
    this.messageSound = false,
    this.vibrateOnMessage = false,
    this.showToastNotifications = true,
  });

  /// HM-10 BLE preset
  factory BluetoothSettings.hm10Preset() {
    return const BluetoothSettings(
      mtuSize: 512,
      serviceUuid: 'FFE0',
      rxCharacteristicUuid: 'FFE1',
      txCharacteristicUuid: 'FFE1',
      lineEnding: LineEnding.crlf,
      chunkSize: 20,
      chunkDelay: 50,
    );
  }

  /// Arduino Nano preset
  factory BluetoothSettings.arduinoNanoPreset() {
    return const BluetoothSettings(
      baudRate: 9600,
      dataBits: 8,
      stopBits: 1,
      parity: ParityType.none,
      lineEnding: LineEnding.lf,
      bufferSize: 1024,
    );
  }

  BluetoothSettings copyWith({
    bool? autoReconnect,
    int? connectionTimeout,
    int? reconnectAttempts,
    int? reconnectDelay,
    int? keepAliveInterval,
    int? baudRate,
    int? dataBits,
    int? stopBits,
    ParityType? parity,
    int? bufferSize,
    FlowControlType? flowControl,
    int? mtuSize,
    String? serviceUuid,
    String? rxCharacteristicUuid,
    String? txCharacteristicUuid,
    BleConnectionPriority? bleConnectionPriority,
    int? notificationDelay,
    LineEnding? lineEnding,
    String? autoPrefix,
    String? autoSuffix,
    TextEncoding? encoding,
    bool? trimWhitespace,
    DisplayFormat? displayFormat,
    TimestampFormat? timestampFormat,
    int? maxMessageHistory,
    bool? autoScroll,
    bool? localEcho,
    bool? enableLogging,
    bool? packetChunking,
    int? chunkSize,
    int? chunkDelay,
    bool? discardInvalidUtf8,
    int? scanDuration,
    bool? connectionSound,
    bool? messageSound,
    bool? vibrateOnMessage,
    bool? showToastNotifications,
  }) {
    return BluetoothSettings(
      autoReconnect: autoReconnect ?? this.autoReconnect,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      keepAliveInterval: keepAliveInterval ?? this.keepAliveInterval,
      baudRate: baudRate ?? this.baudRate,
      dataBits: dataBits ?? this.dataBits,
      stopBits: stopBits ?? this.stopBits,
      parity: parity ?? this.parity,
      bufferSize: bufferSize ?? this.bufferSize,
      flowControl: flowControl ?? this.flowControl,
      mtuSize: mtuSize ?? this.mtuSize,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      rxCharacteristicUuid: rxCharacteristicUuid ?? this.rxCharacteristicUuid,
      txCharacteristicUuid: txCharacteristicUuid ?? this.txCharacteristicUuid,
      bleConnectionPriority: bleConnectionPriority ?? this.bleConnectionPriority,
      notificationDelay: notificationDelay ?? this.notificationDelay,
      lineEnding: lineEnding ?? this.lineEnding,
      autoPrefix: autoPrefix ?? this.autoPrefix,
      autoSuffix: autoSuffix ?? this.autoSuffix,
      encoding: encoding ?? this.encoding,
      trimWhitespace: trimWhitespace ?? this.trimWhitespace,
      displayFormat: displayFormat ?? this.displayFormat,
      timestampFormat: timestampFormat ?? this.timestampFormat,
      maxMessageHistory: maxMessageHistory ?? this.maxMessageHistory,
      autoScroll: autoScroll ?? this.autoScroll,
      localEcho: localEcho ?? this.localEcho,
      enableLogging: enableLogging ?? this.enableLogging,
      packetChunking: packetChunking ?? this.packetChunking,
      chunkSize: chunkSize ?? this.chunkSize,
      chunkDelay: chunkDelay ?? this.chunkDelay,
      discardInvalidUtf8: discardInvalidUtf8 ?? this.discardInvalidUtf8,
      scanDuration: scanDuration ?? this.scanDuration,
      connectionSound: connectionSound ?? this.connectionSound,
      messageSound: messageSound ?? this.messageSound,
      vibrateOnMessage: vibrateOnMessage ?? this.vibrateOnMessage,
      showToastNotifications: showToastNotifications ?? this.showToastNotifications,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'auto_reconnect': autoReconnect ? 1 : 0,
      'connection_timeout': connectionTimeout,
      'reconnect_attempts': reconnectAttempts,
      'reconnect_delay': reconnectDelay,
      'keep_alive_interval': keepAliveInterval,
      'baud_rate': baudRate,
      'data_bits': dataBits,
      'stop_bits': stopBits,
      'parity': parity.name,
      'buffer_size': bufferSize,
      'flow_control': flowControl.name,
      'mtu_size': mtuSize,
      'service_uuid': serviceUuid,
      'rx_characteristic_uuid': rxCharacteristicUuid,
      'tx_characteristic_uuid': txCharacteristicUuid,
      'ble_connection_priority': bleConnectionPriority.name,
      'notification_delay': notificationDelay,
      'line_ending': lineEnding.name,
      'auto_prefix': autoPrefix,
      'auto_suffix': autoSuffix,
      'encoding': encoding.name,
      'trim_whitespace': trimWhitespace ? 1 : 0,
      'display_format': displayFormat.name,
      'timestamp_format': timestampFormat.name,
      'max_message_history': maxMessageHistory,
      'auto_scroll': autoScroll ? 1 : 0,
      'local_echo': localEcho ? 1 : 0,
      'enable_logging': enableLogging ? 1 : 0,
      'packet_chunking': packetChunking ? 1 : 0,
      'chunk_size': chunkSize,
      'chunk_delay': chunkDelay,
      'discard_invalid_utf8': discardInvalidUtf8 ? 1 : 0,
      'scan_duration': scanDuration,
      'connection_sound': connectionSound ? 1 : 0,
      'message_sound': messageSound ? 1 : 0,
      'vibrate_on_message': vibrateOnMessage ? 1 : 0,
      'show_toast_notifications': showToastNotifications ? 1 : 0,
    };
  }

  factory BluetoothSettings.fromMap(Map<String, dynamic> map) {
    return BluetoothSettings(
      autoReconnect: (map['auto_reconnect'] as int?) == 1,
      connectionTimeout: map['connection_timeout'] as int? ?? 10,
      reconnectAttempts: map['reconnect_attempts'] as int? ?? 3,
      reconnectDelay: map['reconnect_delay'] as int? ?? 2,
      keepAliveInterval: map['keep_alive_interval'] as int? ?? 30,
      baudRate: map['baud_rate'] as int? ?? 9600,
      dataBits: map['data_bits'] as int? ?? 8,
      stopBits: map['stop_bits'] as int? ?? 1,
      parity: ParityType.values.firstWhere(
        (e) => e.name == map['parity'],
        orElse: () => ParityType.none,
      ),
      bufferSize: map['buffer_size'] as int? ?? 1024,
      flowControl: FlowControlType.values.firstWhere(
        (e) => e.name == map['flow_control'],
        orElse: () => FlowControlType.none,
      ),
      mtuSize: map['mtu_size'] as int? ?? 512,
      serviceUuid: map['service_uuid'] as String? ?? 'FFE0',
      rxCharacteristicUuid: map['rx_characteristic_uuid'] as String? ?? 'FFE1',
      txCharacteristicUuid: map['tx_characteristic_uuid'] as String? ?? 'FFE1',
      bleConnectionPriority: BleConnectionPriority.values.firstWhere(
        (e) => e.name == map['ble_connection_priority'],
        orElse: () => BleConnectionPriority.balanced,
      ),
      notificationDelay: map['notification_delay'] as int? ?? 0,
      lineEnding: LineEnding.values.firstWhere(
        (e) => e.name == map['line_ending'],
        orElse: () => LineEnding.none,
      ),
      autoPrefix: map['auto_prefix'] as String? ?? '',
      autoSuffix: map['auto_suffix'] as String? ?? '',
      encoding: TextEncoding.values.firstWhere(
        (e) => e.name == map['encoding'],
        orElse: () => TextEncoding.utf8,
      ),
      trimWhitespace: (map['trim_whitespace'] as int?) == 1,
      displayFormat: DisplayFormat.values.firstWhere(
        (e) => e.name == map['display_format'],
        orElse: () => DisplayFormat.text,
      ),
      timestampFormat: TimestampFormat.values.firstWhere(
        (e) => e.name == map['timestamp_format'],
        orElse: () => TimestampFormat.relative,
      ),
      maxMessageHistory: map['max_message_history'] as int? ?? 200,
      autoScroll: (map['auto_scroll'] as int?) == 1,
      localEcho: (map['local_echo'] as int?) == 1,
      enableLogging: (map['enable_logging'] as int?) == 1,
      packetChunking: (map['packet_chunking'] as int?) == 1,
      chunkSize: map['chunk_size'] as int? ?? 20,
      chunkDelay: map['chunk_delay'] as int? ?? 50,
      discardInvalidUtf8: (map['discard_invalid_utf8'] as int?) == 1,
      scanDuration: map['scan_duration'] as int? ?? 15,
      connectionSound: (map['connection_sound'] as int?) == 1,
      messageSound: (map['message_sound'] as int?) == 1,
      vibrateOnMessage: (map['vibrate_on_message'] as int?) == 1,
      showToastNotifications: (map['show_toast_notifications'] as int?) == 1,
    );
  }
}

/// Device-specific settings override
class DeviceBluetoothSettings {
  final String deviceId; // MAC address or UUID
  final BluetoothSettings? overrides; // null = use global settings

  const DeviceBluetoothSettings({
    required this.deviceId,
    this.overrides,
  });

  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      ...?overrides?.toMap(),
    };
  }

  factory DeviceBluetoothSettings.fromMap(Map<String, dynamic> map) {
    return DeviceBluetoothSettings(
      deviceId: map['device_id'] as String,
      overrides: map.containsKey('auto_reconnect') 
          ? BluetoothSettings.fromMap(map)
          : null,
    );
  }
}
