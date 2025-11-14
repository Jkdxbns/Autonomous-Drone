import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../../models/ble_device_config.dart';
import '../../utils/app_logger.dart';

class BleDeviceConnection {
  final FlutterReactiveBle _ble;
  final BleDeviceConfig config;
  
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;
  
  final _dataController = StreamController<List<int>>.broadcast();
  final _stateController = StreamController<BleConnectionState>.broadcast();
  
  BleConnectionState _currentState = BleConnectionState.disconnected;
  DateTime? _connectedAt;
  int _bytesSent = 0;
  int _bytesReceived = 0;
  int? _currentMtu;
  
  QualifiedCharacteristic? _rxCharacteristic; // For writing
  QualifiedCharacteristic? _txCharacteristic; // For reading/notify
  
  // Cached UUIDs (converted once)
  Uuid? _serviceUuid;
  Uuid? _characteristicUuid;
  
  // Completer to wait for connection
  Completer<bool>? _connectionCompleter;
  
  // Flag to prevent duplicate service discovery
  bool _isDiscovering = false;
  bool _servicesReady = false;
  
  // Prevent rapid connect/disconnect
  DateTime? _lastConnectionAttempt;
  static const _connectionDebounceMs = 500;

  BleDeviceConnection({
    required FlutterReactiveBle ble,
    required this.config,
  }) : _ble = ble;

  // Getters
  Stream<List<int>> get dataStream => _dataController.stream;
  Stream<BleConnectionState> get stateStream => _stateController.stream;
  BleConnectionState get currentState => _currentState;
  DateTime? get connectedAt => _connectedAt;
  int get bytesSent => _bytesSent;
  int get bytesReceived => _bytesReceived;
  int? get currentMtu => _currentMtu;

  /// Connect to the BLE device
  Future<bool> connect() async {
    // Debounce rapid connection attempts
    final now = DateTime.now();
    if (_lastConnectionAttempt != null) {
      final elapsed = now.difference(_lastConnectionAttempt!).inMilliseconds;
      if (elapsed < _connectionDebounceMs) {
        AppLogger.warning('Connection attempt too soon after previous attempt (${elapsed}ms ago)');
        await Future.delayed(Duration(milliseconds: _connectionDebounceMs - elapsed));
      }
    }
    _lastConnectionAttempt = now;
    
    if (_currentState == BleConnectionState.connected || 
        _currentState == BleConnectionState.connecting) {
      AppLogger.warning('Already connected or connecting to ${config.deviceId}');
      return _currentState == BleConnectionState.connected;
    }

    AppLogger.info('Connecting to BLE device: ${config.deviceId}');
    _updateState(BleConnectionState.connecting);

    // Create completer to wait for connection result
    _connectionCompleter = Completer<bool>();

    try {
      // Start connection stream - this will automatically detect if already connected
      _connectionSubscription = _ble
          .connectToDevice(
            id: config.deviceId,
            connectionTimeout: Duration(seconds: config.connectionTimeout),
          )
          .listen(
            _handleConnectionUpdate,
            onError: _handleConnectionError,
          );
      
      // Wait for connection to complete (or timeout)
      // Add 3 seconds: 800ms delay + 500ms subscription + buffer
      final connected = await _connectionCompleter!.future.timeout(
        Duration(seconds: config.connectionTimeout + 3),
        onTimeout: () {
          AppLogger.error('BLE connection timeout for ${config.deviceId}');
          _updateState(BleConnectionState.error);
          return false;
        },
      );
      
      return connected;
    } catch (e) {
      AppLogger.error('Failed to connect to ${config.deviceId}: $e');
      _updateState(BleConnectionState.error);
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete(false);
      }
      return false;
    }
  }

  void _handleConnectionUpdate(ConnectionStateUpdate update) async {
    AppLogger.info('Connection state update for ${config.deviceId}: ${update.connectionState}');

    switch (update.connectionState) {
      case DeviceConnectionState.connecting:
        _updateState(BleConnectionState.connecting);
        break;
        
      case DeviceConnectionState.connected:
        _connectedAt = DateTime.now();
        _updateState(BleConnectionState.connected);
        
        // Only discover services once, even if we get multiple connected events
        if (!_isDiscovering && !_servicesReady) {
          _isDiscovering = true;
          
          try {
            // Wait for service discovery and characteristic subscription
            await _discoverAndSubscribe();
            _servicesReady = true;
            
            // Complete the connection completer with success AFTER services are ready
            if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
              _connectionCompleter!.complete(true);
            }
          } catch (e) {
            AppLogger.error('Service discovery failed: $e');
            
            // Complete with failure
            if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
              _connectionCompleter!.complete(false);
            }
          } finally {
            _isDiscovering = false;
          }
        } else if (_servicesReady) {
          AppLogger.info('Services already ready, skipping discovery');
        }
        break;
        
      case DeviceConnectionState.disconnecting:
        _updateState(BleConnectionState.disconnecting);
        break;
        
      case DeviceConnectionState.disconnected:
        _connectedAt = null;
        _servicesReady = false; // Reset flags on disconnect
        _isDiscovering = false;
        _updateState(BleConnectionState.disconnected);
        await _cleanup();
        
        // Complete the connection completer with failure if still waiting
        if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
          _connectionCompleter!.complete(false);
        }
        
        // Auto-reconnect if enabled and not in error state
        // Only reconnect if the disconnect wasn't intentional (manual disconnect sets state to disconnecting first)
        if (config.autoReconnect && 
            _currentState == BleConnectionState.disconnected &&
            _connectionCompleter == null) { // No active manual connection attempt
          AppLogger.info('Auto-reconnecting to ${config.deviceId} in 5 seconds');
          Future.delayed(const Duration(seconds: 5), () {
            // Double-check state hasn't changed
            if (_currentState == BleConnectionState.disconnected && _connectionCompleter == null) {
              connect();
            }
          });
        }
        break;
    }

    if (update.failure != null) {
      AppLogger.error('Connection failure: ${update.failure}');
      _updateState(BleConnectionState.error);
      
      // Complete the connection completer with failure
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete(false);
      }
    }
  }

  void _handleConnectionError(dynamic error) {
    AppLogger.error('Connection error for ${config.deviceId}: $error');
    _updateState(BleConnectionState.error);
    
    // Complete the connection completer with failure
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(false);
    }
  }

  /// Discover services and subscribe to TX characteristic
  Future<void> _discoverAndSubscribe() async {
    try {
      // Convert UUIDs once and cache them
      if (_serviceUuid == null || _characteristicUuid == null) {
        final shortServiceUuid = config.serviceUuid ?? HM10Uuids.serviceUuid;
        final shortCharUuid = config.txCharacteristicUuid ?? HM10Uuids.characteristicUuid;
        
        // Ensure we have full 128-bit UUIDs
        final fullServiceUuid = shortServiceUuid.length == 4 
            ? '0000${shortServiceUuid.toUpperCase()}-0000-1000-8000-00805F9B34FB'
            : shortServiceUuid;
        final fullCharUuid = shortCharUuid.length == 4
            ? '0000${shortCharUuid.toUpperCase()}-0000-1000-8000-00805F9B34FB'
            : shortCharUuid;
        
        _serviceUuid = Uuid.parse(fullServiceUuid);
        _characteristicUuid = Uuid.parse(fullCharUuid);
        
        AppLogger.info('Service UUID: $fullServiceUuid');
        AppLogger.info('Characteristic UUID: $fullCharUuid');
      }

      // Create qualified characteristics (use cached UUIDs)
      _rxCharacteristic = QualifiedCharacteristic(
        serviceId: _serviceUuid!,
        characteristicId: _characteristicUuid!,
        deviceId: config.deviceId,
      );
      
      _txCharacteristic = _rxCharacteristic; // HM-10 uses same characteristic for RX/TX

      AppLogger.info('Setting up BLE services for ${config.deviceId}');
      
      // Add a moderate delay to let GATT services stabilize
      // Not too long (causes timeout) or too short (services not ready)
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Check if still connected after delay
      if (_currentState != BleConnectionState.connected) {
        AppLogger.warning('Connection lost during service discovery');
        throw Exception('Connection lost');
      }
      
      // Request MTU if needed
      if (config.mtu > 23) {
        try {
          _currentMtu = await _ble.requestMtu(
            deviceId: config.deviceId,
            mtu: config.mtu,
          );
          AppLogger.info('MTU set to $_currentMtu for ${config.deviceId}');
        } catch (e) {
          AppLogger.warning('Failed to set MTU: $e');
          _currentMtu = 23; // Default MTU
        }
      }

      // Subscribe to notifications with retry logic
      bool subscribed = false;
      int retryCount = 0;
      const maxRetries = 2;
      
      while (!subscribed && retryCount < maxRetries) {
        try {
          // Check if still connected before attempting subscription
          if (_currentState != BleConnectionState.connected) {
            throw Exception('Connection lost before subscription');
          }
          
          AppLogger.info('Attempting to subscribe to characteristic (attempt ${retryCount + 1}/$maxRetries)');
          
          _characteristicSubscription = _ble
              .subscribeToCharacteristic(_txCharacteristic!)
              .listen(
                _handleIncomingData,
                onError: (error) {
                  AppLogger.error('Characteristic subscription error: $error');
                },
                cancelOnError: false, // Keep subscription alive even if errors occur
              );
          
          // Wait a bit to ensure subscription is established
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Check if still connected after subscription
          if (_currentState != BleConnectionState.connected) {
            throw Exception('Connection lost after subscription attempt');
          }
          
          subscribed = true;
          AppLogger.success('✓ BLE services ready for ${config.deviceId}');
          
          // After successful subscription, log discovered services for debugging
          _logDiscoveredServices();
          
        } catch (e) {
          retryCount++;
          AppLogger.warning('Subscribe attempt $retryCount failed: $e');
          
          // Cancel any partial subscription
          await _characteristicSubscription?.cancel();
          _characteristicSubscription = null;
          
          if (retryCount < maxRetries) {
            // Wait before retrying, with exponential backoff
            await Future.delayed(Duration(milliseconds: 300 * retryCount));
            
            // Check if still connected before retry
            if (_currentState != BleConnectionState.connected) {
              AppLogger.error('Connection lost, aborting subscription attempts');
              throw Exception('Connection lost during retry');
            }
          } else {
            AppLogger.error('Failed to subscribe after $maxRetries attempts: $e');
            // Rethrow to fail the connection
            throw Exception('Failed to setup BLE services: $e');
          }
        }
      }
      
    } catch (e) {
      AppLogger.error('Failed to discover/subscribe: $e');
      // Rethrow to fail the connection properly
      rethrow;
    }
  }

  /// Log discovered services for debugging (called after connection is stable)
  Future<void> _logDiscoveredServices() async {
    try {
      final services = await _ble.getDiscoveredServices(config.deviceId);
      AppLogger.info('Found ${services.length} services on ${config.deviceId}');
      
      // Log all discovered services and their characteristics
      AppLogger.info('=== Discovered Services ===');
      for (final service in services) {
        AppLogger.info('Service: ${service.id}');
        for (final characteristic in service.characteristics) {
          AppLogger.info('  └─ Characteristic: ${characteristic.id} (${characteristic.isReadable ? "R" : ""}${characteristic.isWritableWithResponse ? "W" : ""}${characteristic.isWritableWithoutResponse ? "w" : ""}${characteristic.isNotifiable ? "N" : ""})');
        }
      }
      AppLogger.info('=========================');
    } catch (e) {
      AppLogger.warning('Could not log discovered services: $e');
    }
  }

  void _handleIncomingData(List<int> data) {
    if (data.isEmpty) return;

    _bytesReceived += data.length;
    AppLogger.debug('Received ${data.length} bytes from ${config.deviceId}');
    _dataController.add(data);
  }

  /// Write data to the device
  Future<void> writeData(List<int> data) async {
    if (_currentState != BleConnectionState.connected) {
      throw Exception('Device not connected');
    }

    if (_rxCharacteristic == null) {
      throw Exception('RX characteristic not available');
    }

    try {
      // Split data into chunks if larger than MTU
      final chunkSize = (_currentMtu ?? 23) - 3; // 3 bytes overhead
      for (int i = 0; i < data.length; i += chunkSize) {
        final chunk = data.sublist(
          i,
          i + chunkSize > data.length ? data.length : i + chunkSize,
        );

        await _ble.writeCharacteristicWithResponse(_rxCharacteristic!, value: chunk);
        _bytesSent += chunk.length;
        
        // Small delay between chunks
        if (i + chunkSize < data.length) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      AppLogger.debug('Sent ${data.length} bytes to ${config.deviceId}');
    } catch (e) {
      AppLogger.error('Failed to write data: $e');
      rethrow;
    }
  }

  /// Write string data
  Future<void> writeString(String text) async {
    await writeData(text.codeUnits);
  }

  /// Disconnect from the device
  Future<void> disconnect() async {
    if (_currentState == BleConnectionState.disconnected) {
      return;
    }

    AppLogger.info('Disconnecting from ${config.deviceId}');
    _updateState(BleConnectionState.disconnecting);
    
    await _cleanup();
    _updateState(BleConnectionState.disconnected);
  }

  Future<void> _cleanup() async {
    await _characteristicSubscription?.cancel();
    _characteristicSubscription = null;
    
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    _rxCharacteristic = null;
    _txCharacteristic = null;
  }

  void _updateState(BleConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }

  /// Get connection info
  BleConnectionInfo getConnectionInfo() {
    return BleConnectionInfo(
      deviceId: config.deviceId,
      state: _currentState,
      connectedAt: _connectedAt,
      currentMtu: _currentMtu,
      bytesSent: _bytesSent,
      bytesReceived: _bytesReceived,
    );
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _cleanup();
    await _dataController.close();
    await _stateController.close();
    
    // Clear cached data
    _serviceUuid = null;
    _characteristicUuid = null;
    _connectionCompleter = null;
  }
}
