import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/bluetooth_device_config.dart';
import '../../utils/app_logger.dart';
import 'bluetooth_database_helper.dart';

/// Manages Bluetooth device discovery, pairing, and device list
/// Similar to DevicesFragment.java from SimpleBluetoothTerminal
class BluetoothDeviceManager {
  static final BluetoothDeviceManager instance = BluetoothDeviceManager._init();
  
  BluetoothDeviceManager._init();

  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  final _dbHelper = BluetoothDatabaseHelper.instance;

  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;
  final List<BluetoothDiscoveryResult> _discoveredDevices = [];
  
  bool _isScanning = false;
  bool _isBluetoothEnabled = false;

  /// Check if Bluetooth is available on device
  Future<bool> isBluetoothAvailable() async {
    try {
      final isAvailable = await _bluetooth.isAvailable ?? false;
      AppLogger.info('Bluetooth available: $isAvailable');
      return isAvailable;
    } catch (e) {
      AppLogger.error('Error checking Bluetooth availability: $e');
      return false;
    }
  }

  /// Check if Bluetooth is currently enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      _isBluetoothEnabled = await _bluetooth.isEnabled ?? false;
      AppLogger.info('Bluetooth enabled: $_isBluetoothEnabled');
      return _isBluetoothEnabled;
    } catch (e) {
      AppLogger.error('Error checking Bluetooth state: $e');
      return false;
    }
  }

  /// Request to enable Bluetooth
  Future<bool> requestEnableBluetooth() async {
    try {
      AppLogger.info('Requesting to enable Bluetooth...');
      final result = await _bluetooth.requestEnable();
      _isBluetoothEnabled = result ?? false;
      
      if (_isBluetoothEnabled) {
        AppLogger.success('Bluetooth enabled successfully');
      } else {
        AppLogger.error('Failed to enable Bluetooth');
      }
      
      return _isBluetoothEnabled;
    } catch (e) {
      AppLogger.error('Error requesting Bluetooth enable: $e');
      return false;
    }
  }

  /// Open Bluetooth settings
  Future<void> openBluetoothSettings() async {
    try {
      await _bluetooth.openSettings();
    } catch (e) {
      AppLogger.error('Error opening Bluetooth settings: $e');
    }
  }

  /// Get list of bonded (paired) devices
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      final bondedDevices = await _bluetooth.getBondedDevices();
      AppLogger.info('Found ${bondedDevices.length} bonded devices');
      return bondedDevices;
    } catch (e) {
      AppLogger.error('Error getting bonded devices: $e');
      return [];
    }
  }

  /// Get bonded devices with their configurations from database
  Future<List<BluetoothDeviceConfig>> getBondedDevicesWithConfig() async {
    try {
      final bondedDevices = await getBondedDevices();
      final savedConfigs = await _dbHelper.getAllDevices();
      
      final devicesWithConfig = <BluetoothDeviceConfig>[];
      
      for (final device in bondedDevices) {
        // Check if device has saved configuration
        final savedConfig = savedConfigs.firstWhere(
          (config) => config.address == device.address,
          orElse: () => BluetoothDeviceConfig(
            address: device.address,
            name: device.name ?? 'Unknown Device',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        devicesWithConfig.add(savedConfig);
      }
      
      return devicesWithConfig;
    } catch (e) {
      AppLogger.error('Error getting bonded devices with config: $e');
      return [];
    }
  }

  /// Check if all required Bluetooth permissions are granted
  Future<bool> _checkBluetoothPermissions() async {
    try {
      // Check Bluetooth scan permission (Android 12+)
      final bluetoothScanStatus = await Permission.bluetoothScan.status;
      if (!bluetoothScanStatus.isGranted) {
        AppLogger.error('BLUETOOTH_SCAN permission not granted');
        return false;
      }

      // Check Bluetooth connect permission (Android 12+)
      final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
      if (!bluetoothConnectStatus.isGranted) {
        AppLogger.error('BLUETOOTH_CONNECT permission not granted');
        return false;
      }

      // Check location permission (required for Bluetooth on all Android versions)
      final locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        AppLogger.error('LOCATION permission not granted (required for Bluetooth)');
        return false;
      }

      AppLogger.success('All Bluetooth permissions are granted');
      return true;
    } catch (e) {
      AppLogger.error('Error checking Bluetooth permissions: $e');
      return false;
    }
  }

  /// Request required Bluetooth permissions
  Future<bool> requestBluetoothPermissions() async {
    try {
      AppLogger.info('Requesting Bluetooth permissions...');

      // Request permissions one at a time to avoid conflicts
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      if (!bluetoothScanStatus.isGranted) {
        AppLogger.error('BLUETOOTH_SCAN permission denied');
        return false;
      }

      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      if (!bluetoothConnectStatus.isGranted) {
        AppLogger.error('BLUETOOTH_CONNECT permission denied');
        return false;
      }

      final locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        AppLogger.error('LOCATION permission denied');
        return false;
      }

      AppLogger.success('All Bluetooth permissions granted');
      return true;
    } catch (e) {
      AppLogger.error('Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  /// Start device discovery (scanning)
  Future<void> startDiscovery({
    required Function(BluetoothDiscoveryResult result) onDeviceFound,
    required Function() onFinished,
  }) async {
    if (_isScanning) {
      AppLogger.warning('Already scanning for devices');
      return;
    }

    try {
      // Check if permissions are granted (they should be from startup)
      AppLogger.info('Verifying Bluetooth permissions before scan...');
      final permissionsGranted = await _checkBluetoothPermissions();

      if (!permissionsGranted) {
        AppLogger.error('Bluetooth permissions not granted. Please restart the app or grant permissions in Settings.');
        throw Exception('Bluetooth permissions required. Please grant permissions in app Settings.');
      }

      // Check if Bluetooth is enabled
      if (!await isBluetoothEnabled()) {
        AppLogger.warning('Bluetooth is not enabled');
        throw Exception('Bluetooth is not enabled');
      }

      _isScanning = true;
      _discoveredDevices.clear();
      AppLogger.info('Starting Bluetooth device discovery...');

      _discoveryStreamSubscription = _bluetooth.startDiscovery().listen(
        (result) {
          // Add to discovered devices list if not already there
          if (!_discoveredDevices.any((r) => r.device.address == result.device.address)) {
            _discoveredDevices.add(result);
            AppLogger.info('Discovered device: ${result.device.name ?? "Unknown"} (${result.device.address})');
            onDeviceFound(result);
          }
        },
        onDone: () {
          _isScanning = false;
          AppLogger.success('Device discovery finished. Found ${_discoveredDevices.length} devices');
          onFinished();
        },
        onError: (error) {
          _isScanning = false;
          AppLogger.error('Error during device discovery: $error');
          
          // Check if it's a permission error
          if (error.toString().contains('BLUETOOTH_SCAN') || 
              error.toString().contains('SecurityException')) {
            AppLogger.error('Permission error - please grant Bluetooth permissions and try again');
            AppLogger.showToast('Bluetooth permission required. Please try again.', isError: true);
          }
          
          onFinished();
        },
      );
    } catch (e) {
      _isScanning = false;
      AppLogger.error('Error starting device discovery: $e');
      
      // User-friendly error message
      if (e.toString().contains('BLUETOOTH_SCAN') || 
          e.toString().contains('SecurityException')) {
        AppLogger.showToast('Bluetooth permission required. Please restart the app.', isError: true);
      }
      
      rethrow;
    }
  }

  /// Stop device discovery
  Future<void> stopDiscovery() async {
    if (!_isScanning) {
      return;
    }

    try {
      AppLogger.info('Stopping device discovery...');
      await _discoveryStreamSubscription?.cancel();
      _discoveryStreamSubscription = null;
      _isScanning = false;
      AppLogger.success('Device discovery stopped');
    } catch (e) {
      AppLogger.error('Error stopping device discovery: $e');
    }
  }

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Get list of discovered devices
  List<BluetoothDiscoveryResult> get discoveredDevices => List.unmodifiable(_discoveredDevices);

  /// Bond (pair) with a device
  Future<bool> bondWithDevice(BluetoothDevice device) async {
    try {
      AppLogger.info('Attempting to bond with device: ${device.name ?? device.address}');
      
      final isBonded = await _bluetooth.bondDeviceAtAddress(device.address);
      
      if (isBonded == true) {
        AppLogger.success('Successfully bonded with ${device.name ?? device.address}');
        
        // Save device configuration to database
        final config = BluetoothDeviceConfig(
          address: device.address,
          name: device.name ?? 'Unknown Device',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _dbHelper.upsertDevice(config);
        
        return true;
      } else {
        AppLogger.error('Failed to bond with ${device.name ?? device.address}');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error bonding with device: $e');
      return false;
    }
  }

  /// Remove bond (unpair) from a device
  Future<bool> removeBond(String deviceAddress) async {
    try {
      AppLogger.info('Removing bond for device: $deviceAddress');
      
      final result = await _bluetooth.removeDeviceBondWithAddress(deviceAddress);
      
      if (result == true) {
        AppLogger.success('Successfully removed bond for $deviceAddress');
        
        // Optionally remove from database or keep configuration
        // await _dbHelper.deleteDevice(deviceAddress);
        
        return true;
      } else {
        AppLogger.error('Failed to remove bond for $deviceAddress');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error removing bond: $e');
      return false;
    }
  }

  /// Listen to Bluetooth state changes
  Stream<BluetoothState> get stateStream => _bluetooth.onStateChanged();

  /// Dispose resources
  void dispose() {
    _discoveryStreamSubscription?.cancel();
  }
}
