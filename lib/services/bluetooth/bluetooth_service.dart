import 'dart:async';
import 'dart:typed_data';
import '../../models/bluetooth_device_config.dart';
import '../../utils/app_logger.dart';
import 'bluetooth_connection.dart';
import 'bluetooth_database_helper.dart';
import 'bluetooth_device_manager.dart';

/// Main Bluetooth service for managing multiple simultaneous connections
/// Inspired by SerialService.java from SimpleBluetoothTerminal
class BluetoothService {
  static final BluetoothService instance = BluetoothService._init();
  
  BluetoothService._init();

  final _dbHelper = BluetoothDatabaseHelper.instance;
  final _deviceManager = BluetoothDeviceManager.instance;
  
  // Map of device address to connection
  final Map<String, BluetoothDeviceConnection> _activeConnections = {};
  
  // Map of device address to connection info
  final Map<String, BluetoothConnectionInfo> _connectionInfo = {};
  
  // Stream controllers for broadcasting state changes
  final _connectionStateController = StreamController<Map<String, BluetoothConnectionInfo>>.broadcast();
  final _dataReceivedController = StreamController<DeviceDataEvent>.broadcast();
  
  // Message queue for devices that are disconnected
  final Map<String, List<QueuedMessage>> _messageQueues = {};

  bool _isInitialized = false;

  /// Initialize the Bluetooth service
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      AppLogger.info('Initializing Bluetooth service...');
      
      // Check Bluetooth availability
      final isAvailable = await _deviceManager.isBluetoothAvailable();
      if (!isAvailable) {
        throw Exception('Bluetooth is not available on this device');
      }

      // Initialize database
      await _dbHelper.database;
      
      _isInitialized = true;
      AppLogger.success('Bluetooth service initialized successfully');
    } catch (e) {
      AppLogger.error('Error initializing Bluetooth service: $e');
      rethrow;
    }
  }

  /// Connect to a device
  Future<bool> connectToDevice(BluetoothDeviceConfig config) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check if already connected
    if (_activeConnections.containsKey(config.address) &&
        _connectionInfo[config.address]?.isConnected == true) {
      AppLogger.warning('Already connected to ${config.displayName}');
      return true;
    }

    try {
      AppLogger.info('Connecting to ${config.displayName}...');

      // Create new connection
      final connection = BluetoothDeviceConnection(
        deviceConfig: config,
        onStateChanged: (state, error) => _handleConnectionStateChanged(config.address, state, error),
        onDataReceived: (data) => _handleDataReceived(config.address, data),
      );

      // Add to active connections
      _activeConnections[config.address] = connection;
      
      // Initialize connection info
      _connectionInfo[config.address] = BluetoothConnectionInfo(
        deviceAddress: config.address,
        state: BluetoothConnectionState.connecting,
      );
      _notifyConnectionStateChanged();

      // Attempt connection
      await connection.connect();

      // Update last connected timestamp
      await _dbHelper.updateLastConnected(config.address);

      // Process any queued messages
      await _processQueuedMessages(config.address);

      return true;
    } catch (e) {
      AppLogger.error('Error connecting to ${config.displayName}: $e');
      _activeConnections.remove(config.address);
      _connectionInfo[config.address] = BluetoothConnectionInfo(
        deviceAddress: config.address,
        state: BluetoothConnectionState.error,
        errorMessage: e.toString(),
      );
      _notifyConnectionStateChanged();
      return false;
    }
  }

  /// Disconnect from a device
  Future<void> disconnectDevice(String deviceAddress, {bool userInitiated = true}) async {
    final connection = _activeConnections[deviceAddress];
    if (connection == null) {
      AppLogger.warning('No active connection for device: $deviceAddress');
      return;
    }

    try {
      AppLogger.info('Disconnecting from device: $deviceAddress');
      await connection.disconnect(userInitiated: userInitiated);
      
      // Remove from active connections
      _activeConnections.remove(deviceAddress);
      
      // Update connection info
      _connectionInfo[deviceAddress] = BluetoothConnectionInfo(
        deviceAddress: deviceAddress,
        state: BluetoothConnectionState.disconnected,
      );
      _notifyConnectionStateChanged();
    } catch (e) {
      AppLogger.error('Error disconnecting from device: $e');
    }
  }

  /// Disconnect all devices
  Future<void> disconnectAll() async {
    AppLogger.info('Disconnecting all devices...');
    
    final addresses = List<String>.from(_activeConnections.keys);
    for (final address in addresses) {
      await disconnectDevice(address);
    }
    
    AppLogger.success('All devices disconnected');
  }

  /// Send string data to a specific device
  Future<bool> sendStringToDevice(String deviceAddress, String data) async {
    final connection = _activeConnections[deviceAddress];
    
    if (connection == null || !connection.isConnected) {
      AppLogger.warning('Device not connected: $deviceAddress. Queuing message...');
      await _queueMessage(deviceAddress, data, 'string');
      return false;
    }

    return await connection.writeString(data);
  }

  /// Send integer data to a specific device
  Future<bool> sendIntToDevice(String deviceAddress, int value) async {
    final connection = _activeConnections[deviceAddress];
    
    if (connection == null || !connection.isConnected) {
      AppLogger.warning('Device not connected: $deviceAddress. Queuing message...');
      await _queueMessage(deviceAddress, value.toString(), 'int');
      return false;
    }

    return await connection.writeInt(value);
  }

  /// Send data to multiple devices
  Future<Map<String, bool>> sendToMultipleDevices(List<String> deviceAddresses, String data) async {
    final results = <String, bool>{};
    
    for (final address in deviceAddresses) {
      results[address] = await sendStringToDevice(address, data);
    }
    
    return results;
  }

  /// Send data to all connected devices
  Future<Map<String, bool>> broadcastToAll(String data) async {
    final connectedAddresses = _activeConnections.keys
        .where((address) => _connectionInfo[address]?.isConnected == true)
        .toList();
    
    AppLogger.info('Broadcasting to ${connectedAddresses.length} devices');
    return await sendToMultipleDevices(connectedAddresses, data);
  }

  /// Get connection info for a device
  BluetoothConnectionInfo? getConnectionInfo(String deviceAddress) {
    return _connectionInfo[deviceAddress];
  }

  /// Get all connection info
  Map<String, BluetoothConnectionInfo> getAllConnectionInfo() {
    return Map.unmodifiable(_connectionInfo);
  }

  /// Get list of connected devices
  List<String> getConnectedDevices() {
    return _connectionInfo.entries
        .where((entry) => entry.value.isConnected)
        .map((entry) => entry.key)
        .toList();
  }

  /// Check if a device is connected
  bool isDeviceConnected(String deviceAddress) {
    return _connectionInfo[deviceAddress]?.isConnected ?? false;
  }

  /// Stream of connection state changes
  Stream<Map<String, BluetoothConnectionInfo>> get connectionStateStream => 
      _connectionStateController.stream;

  /// Stream of received data events
  Stream<DeviceDataEvent> get dataReceivedStream => 
      _dataReceivedController.stream;

  /// Handle connection state changes
  void _handleConnectionStateChanged(String deviceAddress, BluetoothConnectionState state, String? error) {
    final connection = _activeConnections[deviceAddress];
    
    AppLogger.info('Connection state changed for $deviceAddress: $state${error != null ? ' (error: $error)' : ''}');
    
    _connectionInfo[deviceAddress] = BluetoothConnectionInfo(
      deviceAddress: deviceAddress,
      state: state,
      connectedAt: state == BluetoothConnectionState.connected ? DateTime.now() : null,
      errorMessage: error,
      bytesSent: connection?.bytesSent ?? 0,
      bytesReceived: connection?.bytesReceived ?? 0,
    );

    AppLogger.info('Connection state changed for $deviceAddress: $state');
    _notifyConnectionStateChanged();

    // If connected, process queued messages
    if (state == BluetoothConnectionState.connected) {
      _processQueuedMessages(deviceAddress);
    }
  }

  /// Handle received data
  void _handleDataReceived(String deviceAddress, Uint8List data) {
    final event = DeviceDataEvent(
      deviceAddress: deviceAddress,
      data: data,
      timestamp: DateTime.now(),
    );

    _dataReceivedController.add(event);
    AppLogger.info('Data received from $deviceAddress: ${data.length} bytes');
  }

  /// Queue message for later sending
  Future<void> _queueMessage(String deviceAddress, String message, String type) async {
    await _dbHelper.queueMessage(
      deviceAddress: deviceAddress,
      message: message,
      messageType: type,
    );

    if (!_messageQueues.containsKey(deviceAddress)) {
      _messageQueues[deviceAddress] = [];
    }

    _messageQueues[deviceAddress]!.add(QueuedMessage(
      message: message,
      type: type,
      queuedAt: DateTime.now(),
    ));

    AppLogger.info('Message queued for $deviceAddress');
  }

  /// Process queued messages for a device
  Future<void> _processQueuedMessages(String deviceAddress) async {
    final queuedMessages = await _dbHelper.getPendingMessages(deviceAddress);
    
    if (queuedMessages.isEmpty) {
      return;
    }

    AppLogger.info('Processing ${queuedMessages.length} queued messages for $deviceAddress');

    for (final msg in queuedMessages) {
      final message = msg['message'] as String;
      final messageId = msg['id'] as int;
      
      bool success = false;
      if (msg['message_type'] == 'int') {
        success = await sendIntToDevice(deviceAddress, int.tryParse(message) ?? 0);
      } else {
        success = await sendStringToDevice(deviceAddress, message);
      }

      if (success) {
        await _dbHelper.markMessageSent(messageId);
      }
    }

    // Clear processed messages
    await _dbHelper.clearSentMessages(deviceAddress);
    _messageQueues.remove(deviceAddress);
  }

  /// Notify listeners of connection state changes
  void _notifyConnectionStateChanged() {
    _connectionStateController.add(getAllConnectionInfo());
  }

  /// Dispose the service
  Future<void> dispose() async {
    AppLogger.info('Disposing Bluetooth service...');
    
    await disconnectAll();
    await _connectionStateController.close();
    await _dataReceivedController.close();
    _deviceManager.dispose();
    
    _isInitialized = false;
    AppLogger.info('Bluetooth service disposed');
  }
}

/// Event for data received from a device
class DeviceDataEvent {
  final String deviceAddress;
  final Uint8List data;
  final DateTime timestamp;

  const DeviceDataEvent({
    required this.deviceAddress,
    required this.data,
    required this.timestamp,
  });
}

/// Queued message structure
class QueuedMessage {
  final String message;
  final String type;
  final DateTime queuedAt;

  const QueuedMessage({
    required this.message,
    required this.type,
    required this.queuedAt,
  });
}
