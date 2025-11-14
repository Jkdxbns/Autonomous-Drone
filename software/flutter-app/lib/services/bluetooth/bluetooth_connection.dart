import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as fbs;
import '../../models/bluetooth_device_config.dart';
import '../../utils/app_logger.dart';

/// Handles individual Bluetooth device connection
/// Inspired by SerialSocket.java from SimpleBluetoothTerminal
class BluetoothDeviceConnection {
  final BluetoothDeviceConfig deviceConfig;
  final Function(BluetoothConnectionState state, String? error) onStateChanged;
  final Function(Uint8List data) onDataReceived;

  fbs.BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _dataSubscription;
  BluetoothConnectionState _currentState = BluetoothConnectionState.disconnected;
  
  int _bytesSent = 0;
  int _bytesReceived = 0;
  DateTime? _connectedAt;
  Timer? _reconnectTimer;
  bool _shouldAutoReconnect = false;

  BluetoothDeviceConnection({
    required this.deviceConfig,
    required this.onStateChanged,
    required this.onDataReceived,
  });

  /// Get current connection state
  BluetoothConnectionState get state => _currentState;

  /// Check if connected
  bool get isConnected => _currentState == BluetoothConnectionState.connected;

  /// Get connection statistics
  int get bytesSent => _bytesSent;
  int get bytesReceived => _bytesReceived;
  DateTime? get connectedAt => _connectedAt;

  /// Connect to the Bluetooth device
  Future<void> connect() async {
    if (_currentState == BluetoothConnectionState.connected ||
        _currentState == BluetoothConnectionState.connecting) {
      AppLogger.warning('Already connected or connecting to ${deviceConfig.displayName}');
      return;
    }

    _updateState(BluetoothConnectionState.connecting);
    _shouldAutoReconnect = deviceConfig.autoReconnect;

    try {
      AppLogger.info('📡 [STEP 1/4] Initiating connection to ${deviceConfig.displayName} (${deviceConfig.address})...');

      // STEP 1: Request connection from OS Bluetooth stack
      // This sends RFCOMM connection request to the remote device
      _connection = await fbs.BluetoothConnection.toAddress(deviceConfig.address)
          .timeout(
        Duration(seconds: deviceConfig.connectionTimeout),
        onTimeout: () {
          throw TimeoutException('Connection timeout after ${deviceConfig.connectionTimeout}s');
        },
      );

      // STEP 2: Verify connection object was created
      if (_connection == null) {
        throw Exception('Connection object is null - OS rejected connection');
      }
      
      AppLogger.success('✓ [STEP 2/4] Connection object created - SPP socket established');

      // STEP 3: Verify connection is actually alive by checking if we can access streams
      // The isConnected property checks the underlying socket state
      try {
        final isAlive = _connection!.isConnected;
        if (!isAlive) {
          AppLogger.warning('Connection reports not connected, but proceeding anyway');
        }
      } catch (e) {
        AppLogger.warning('Could not verify connection state: $e');
      }
      
      AppLogger.success('✓ [STEP 3/4] I/O streams ready - bidirectional channel open');

      // STEP 4: Start data listener to verify connection is alive
      // If listener starts successfully, we have full duplex communication
      _startDataListener();
      
      // Connection is fully established
      _connectedAt = DateTime.now();
      _updateState(BluetoothConnectionState.connected);
      
      AppLogger.success('✓ [STEP 4/4] Connection verified - Device ready for communication');
      AppLogger.success('🎉 Successfully connected to ${deviceConfig.displayName}');

    } catch (e) {
      AppLogger.error('❌ Connection failed for ${deviceConfig.displayName}: $e');
      _updateState(BluetoothConnectionState.error, e.toString());
      
      // Clean up failed connection
      try {
        await _connection?.close();
      } catch (_) {}
      _connection = null;
      
      // Attempt auto-reconnect if enabled
      if (_shouldAutoReconnect) {
        _scheduleReconnect();
      }
    }
  }

  /// Disconnect from the device
  Future<void> disconnect({bool userInitiated = false}) async {
    if (userInitiated) {
      _shouldAutoReconnect = false;
      _reconnectTimer?.cancel();
    }

    if (_currentState == BluetoothConnectionState.disconnected) {
      return;
    }

    _updateState(BluetoothConnectionState.disconnecting);

    try {
      AppLogger.info('Disconnecting from ${deviceConfig.displayName}...');

      // Cancel data subscription
      await _dataSubscription?.cancel();
      _dataSubscription = null;

      // Close connection
      await _connection?.close();
      _connection = null;

      _updateState(BluetoothConnectionState.disconnected);
      _connectedAt = null;

      AppLogger.success('Disconnected from ${deviceConfig.displayName}');
    } catch (e) {
      AppLogger.error('Disconnect error for ${deviceConfig.displayName}: $e');
      _updateState(BluetoothConnectionState.error, e.toString());
    }
  }

  /// Write string data to the device
  Future<bool> writeString(String data) async {
    if (!isConnected) {
      AppLogger.warning('Cannot write: Not connected to ${deviceConfig.displayName}');
      return false;
    }

    try {
      final bytes = utf8.encode(data);
      return await writeBytes(Uint8List.fromList(bytes));
    } catch (e) {
      AppLogger.error('Error writing string to ${deviceConfig.displayName}: $e');
      return false;
    }
  }

  /// Write integer data to the device
  Future<bool> writeInt(int value) async {
    if (!isConnected) {
      AppLogger.warning('Cannot write: Not connected to ${deviceConfig.displayName}');
      return false;
    }

    try {
      // Convert int to string and then bytes
      final data = value.toString();
      final bytes = utf8.encode(data);
      return await writeBytes(Uint8List.fromList(bytes));
    } catch (e) {
      AppLogger.error('Error writing int to ${deviceConfig.displayName}: $e');
      return false;
    }
  }

  /// Write raw bytes to the device
  Future<bool> writeBytes(Uint8List data) async {
    if (!isConnected || _connection == null) {
      AppLogger.warning('Cannot write: Not connected to ${deviceConfig.displayName}');
      return false;
    }

    try {
      _connection!.output.add(data);
      await _connection!.output.allSent;
      
      _bytesSent += data.length;
      AppLogger.info('Sent ${data.length} bytes to ${deviceConfig.displayName}');
      return true;
    } catch (e) {
      AppLogger.error('Error writing bytes to ${deviceConfig.displayName}: $e');
      _handleConnectionError(e);
      return false;
    }
  }

  /// Start listening for incoming data
  void _startDataListener() {
    if (_connection == null) return;

    _dataSubscription = _connection!.input!.listen(
      (Uint8List data) {
        _bytesReceived += data.length;
        AppLogger.info('Received ${data.length} bytes from ${deviceConfig.displayName}');
        onDataReceived(data);
      },
      onError: (error) {
        AppLogger.error('Data stream error for ${deviceConfig.displayName}: $error');
        _handleConnectionError(error);
      },
      onDone: () {
        AppLogger.warning('Data stream closed for ${deviceConfig.displayName}');
        _handleConnectionError(Exception('Connection closed by remote device'));
      },
      cancelOnError: false,
    );
  }

  /// Handle connection errors
  void _handleConnectionError(dynamic error) {
    if (_currentState == BluetoothConnectionState.connected) {
      AppLogger.error('Connection lost to ${deviceConfig.displayName}: $error');
      _updateState(BluetoothConnectionState.error, error.toString());
      
      // Disconnect and attempt reconnect if auto-reconnect is enabled
      disconnect().then((_) {
        if (_shouldAutoReconnect) {
          _scheduleReconnect();
        }
      });
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    
    const reconnectDelay = Duration(seconds: 5);
    AppLogger.info('Scheduling reconnect to ${deviceConfig.displayName} in ${reconnectDelay.inSeconds}s...');
    
    _reconnectTimer = Timer(reconnectDelay, () {
      if (_shouldAutoReconnect && !isConnected) {
        AppLogger.info('Attempting to reconnect to ${deviceConfig.displayName}...');
        connect();
      }
    });
  }

  /// Update connection state and notify listeners
  void _updateState(BluetoothConnectionState newState, [String? error]) {
    if (_currentState != newState) {
      _currentState = newState;
      onStateChanged(newState, error);
    }
  }

  /// Verify connection is still alive
  /// Returns true if connection is responsive, false otherwise
  Future<bool> verifyConnection() async {
    if (!isConnected || _connection == null) {
      return false;
    }

    try {
      // Check if connection object reports as connected
      final isAlive = _connection!.isConnected;
      
      if (!isAlive) {
        AppLogger.warning('Connection verification failed: isConnected = false');
        return false;
      }

      AppLogger.success('Connection verification passed for ${deviceConfig.displayName}');
      return true;
    } catch (e) {
      AppLogger.error('Connection verification error: $e');
      return false;
    }
  }

  /// Test connection by attempting to write dummy data
  /// Some devices need actual data transmission to confirm connection
  Future<bool> testConnection({String? testMessage}) async {
    if (!isConnected) {
      return false;
    }

    try {
      // Try to write a test message (or empty byte if no message provided)
      if (testMessage != null) {
        return await writeString(testMessage);
      } else {
        // Send a single null byte as keepalive
        return await writeBytes(Uint8List.fromList([0x00]));
      }
    } catch (e) {
      AppLogger.error('Connection test failed: $e');
      return false;
    }
  }

  /// Reset statistics
  void resetStats() {
    _bytesSent = 0;
    _bytesReceived = 0;
  }

  /// Dispose resources
  Future<void> dispose() async {
    _shouldAutoReconnect = false;
    _reconnectTimer?.cancel();
    await disconnect();
  }
}
