import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/ble_device_config.dart';
import '../../utils/app_logger.dart';

class BleDeviceManager {
  static final BleDeviceManager instance = BleDeviceManager._init();
  
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<BleStatus>? _statusSubscription;
  
  final _discoveredDevicesController = StreamController<DiscoveredDevice>.broadcast();
  final _scanningStateController = StreamController<bool>.broadcast();
  
  bool _isScanning = false;
  BleStatus _bleStatus = BleStatus.unknown;

  BleDeviceManager._init() {
    _initializeStatusListener();
  }

  // Getters
  Stream<DiscoveredDevice> get discoveredDevices => _discoveredDevicesController.stream;
  Stream<bool> get scanningState => _scanningStateController.stream;
  bool get isScanning => _isScanning;
  BleStatus get bleStatus => _bleStatus;
  bool get isBluetoothOn => _bleStatus == BleStatus.ready;

  void _initializeStatusListener() {
    _statusSubscription = _ble.statusStream.listen((status) {
      _bleStatus = status;
      AppLogger.info('BLE status changed: $status');
    });
  }

  /// Check and request necessary permissions
  /// FIXED: Request permissions ONE AT A TIME with proper delays to avoid crashes
  Future<bool> checkPermissions() async {
    AppLogger.info('Checking BLE permissions');

    try {
      // Check if all required permissions are already granted
      final bluetoothScanStatus = await Permission.bluetoothScan.status;
      final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
      final locationStatus = await Permission.location.status;

      // If all are already granted, return immediately
      if (bluetoothScanStatus.isGranted && 
          bluetoothConnectStatus.isGranted && 
          locationStatus.isGranted) {
        AppLogger.info('All BLE permissions already granted');
        return true;
      }

      // Request permissions ONE AT A TIME with delays to prevent crashes
      if (bluetoothScanStatus.isDenied) {
        AppLogger.info('Requesting Bluetooth scan permission...');
        final status = await Permission.bluetoothScan.request();
        if (!status.isGranted) {
          AppLogger.warning('Bluetooth scan permission denied');
          return false;
        }
        // Critical: Wait 500ms before next permission request
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (bluetoothConnectStatus.isDenied) {
        AppLogger.info('Requesting Bluetooth connect permission...');
        final status = await Permission.bluetoothConnect.request();
        if (!status.isGranted) {
          AppLogger.warning('Bluetooth connect permission denied');
          return false;
        }
        // Critical: Wait 500ms before next permission request
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Location permission for Android 11 and below
      if (locationStatus.isDenied) {
        AppLogger.info('Requesting location permission...');
        final status = await Permission.location.request();
        if (!status.isGranted) {
          AppLogger.warning('Location permission denied');
          return false;
        }
      }

      AppLogger.info('All BLE permissions granted');
      return true;
    } catch (e) {
      AppLogger.error('Error checking BLE permissions: $e');
      return false;
    }
  }

  /// Start scanning for BLE devices
  Future<void> startScan({
    List<Uuid>? serviceUuids,
    Duration timeout = const Duration(seconds: 10),
    ScanMode scanMode = ScanMode.balanced,
  }) async {
    if (_isScanning) {
      AppLogger.warning('Scan already in progress');
      return;
    }

    if (!await checkPermissions()) {
      AppLogger.error('Required permissions not granted for BLE scan');
      throw Exception('Required permissions not granted');
    }

    // CRITICAL: Check if Bluetooth is enabled before scanning
    if (_bleStatus != BleStatus.ready) {
      AppLogger.warning('Bluetooth is not ready. Status: $_bleStatus');
      
      if (_bleStatus == BleStatus.poweredOff || _bleStatus == BleStatus.unknown) {
        AppLogger.showToast('Please enable Bluetooth to scan for devices');
        throw Exception('Bluetooth is not enabled. Please turn on Bluetooth and try again.');
      }
      
      throw Exception('Bluetooth is not ready. Status: $_bleStatus');
    }

    AppLogger.info('Starting BLE scan with timeout: ${timeout.inSeconds}s');
    _isScanning = true;
    _scanningStateController.add(true);

    try {
      _scanSubscription = _ble.scanForDevices(
        withServices: serviceUuids ?? [],
        scanMode: scanMode,
      ).listen(
        (device) {
          // Filter out devices without names (optional)
          if (device.name.isNotEmpty) {
            AppLogger.debug('Found BLE device: ${device.name} (${device.id})');
            _discoveredDevicesController.add(device);
          }
        },
        onError: (error) {
          AppLogger.error('Scan error: $error');
        },
      );

      // Auto-stop after timeout
      Future.delayed(timeout, () {
        if (_isScanning) {
          stopScan();
        }
      });
    } catch (e) {
      AppLogger.error('Failed to start scan: $e');
      _isScanning = false;
      _scanningStateController.add(false);
      rethrow;
    }
  }

  /// Stop scanning
  void stopScan() {
    if (!_isScanning) return;

    AppLogger.info('Stopping BLE scan');
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    _scanningStateController.add(false);
  }

  /// Scan specifically for HM-10 devices
  Future<void> scanForHM10({Duration timeout = const Duration(seconds: 10)}) async {
    // HM-10 service UUID
    final hm10ServiceUuid = Uuid.parse(HM10Uuids.serviceUuid);
    
    await startScan(
      serviceUuids: [hm10ServiceUuid],
      timeout: timeout,
    );
  }

  /// Convert discovered device to BleDeviceConfig
  BleDeviceConfig deviceToBleConfig(DiscoveredDevice device) {
    return BleDeviceConfig(
      deviceId: device.id,
      deviceName: device.name.isNotEmpty ? device.name : null,
      rssi: device.rssi,
      createdAt: DateTime.now(),
      serviceUuid: device.serviceUuids.isNotEmpty 
          ? device.serviceUuids.first.toString() 
          : HM10Uuids.serviceUuid,
      rxCharacteristicUuid: HM10Uuids.characteristicUuid,
      txCharacteristicUuid: HM10Uuids.characteristicUuid,
    );
  }

  /// Check if BLE is available on this device
  Future<bool> isBleAvailable() async {
    // Check if BLE is supported
    try {
      await for (final status in _ble.statusStream.take(1)) {
        return status != BleStatus.unsupported;
      }
    } catch (e) {
      AppLogger.error('Error checking BLE availability: $e');
    }
    return false;
  }

  /// Get known services for a device
  Future<List<Service>> discoverServices(String deviceId) async {
    try {
      AppLogger.info('Discovering services for device: $deviceId');
      
      // First trigger service discovery
      await _ble.discoverAllServices(deviceId);
      // Then get the discovered services
      final services = await _ble.getDiscoveredServices(deviceId);
      
      for (var service in services) {
        AppLogger.info('Service: ${service.id}');
        for (var characteristic in service.characteristics) {
          AppLogger.info('  Characteristic: ${characteristic.id}');
          AppLogger.info('    Properties: ${characteristic.isReadable ? "R" : ""}${characteristic.isWritableWithResponse ? "W" : ""}${characteristic.isNotifiable ? "N" : ""}');
        }
      }
      
      return services;
    } catch (e) {
      AppLogger.error('Failed to discover services: $e');
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    stopScan();
    _statusSubscription?.cancel();
    _discoveredDevicesController.close();
    _scanningStateController.close();
  }
}
