import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';
import 'server/server_config_service.dart';
import 'api/api_headers.dart';
import 'bluetooth/unified_bluetooth_service.dart';

/// Service that maintains device online status via periodic heartbeat
class HeartbeatService {
  static final HeartbeatService instance = HeartbeatService._();
  HeartbeatService._();

  Timer? _heartbeatTimer;
  bool _isRunning = false;
  
  /// Heartbeat interval (60 seconds)
  static const Duration _heartbeatInterval = Duration(seconds: 60);

  /// Start the heartbeat service
  void start() {
    if (_isRunning) {
      AppLogger.info('Heartbeat service already running');
      return;
    }

    AppLogger.info('Starting heartbeat service (interval: ${_heartbeatInterval.inSeconds}s)');
    _isRunning = true;
    
    // Send initial heartbeat immediately
    _sendHeartbeat();
    
    // Then send periodic heartbeats
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat();
    });
  }

  /// Stop the heartbeat service
  void stop() {
    if (!_isRunning) {
      return;
    }

    AppLogger.info('Stopping heartbeat service');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isRunning = false;
  }

  /// Send heartbeat to server
  Future<void> _sendHeartbeat() async {
    try {
      final baseUrl = ServerConfigService.instance.baseUrl;
      final url = Uri.parse('$baseUrl/device/heartbeat');
      
      // Get connected Bluetooth device IDs
      final connectedDevices = await _getConnectedBluetoothDevices();
      
      // Get headers with device identification
      final headers = await ApiHeaders.getJsonHeaders();
      
      // Build request body with connected BT devices
      final body = jsonEncode({
        'connected_devices': connectedDevices,
      });
      
      // Send heartbeat request
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        AppLogger.info('Heartbeat sent successfully (${connectedDevices.length} BT devices connected)');
      } else {
        AppLogger.warning('Heartbeat failed: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Heartbeat error: $e');
      // Don't stop service on error - will retry next interval
    }
  }

  /// Get list of connected Bluetooth device MAC addresses
  Future<List<String>> _getConnectedBluetoothDevices() async {
    try {
      final connectedDevices = <String>[];
      
      // Get all connected devices from unified service
      final devices = UnifiedBluetoothService.instance.getConnectedDevices();
      for (var device in devices) {
        if (device.id.isNotEmpty) {
          connectedDevices.add(device.id);
        }
      }
      
      return connectedDevices;
    } catch (e) {
      AppLogger.error('Error getting connected Bluetooth devices: $e');
      return [];
    }
  }

  /// Report connection event to server (called when BT device connects)
  Future<void> reportConnection(String deviceId) async {
    try {
      final baseUrl = ServerConfigService.instance.baseUrl;
      final url = Uri.parse('$baseUrl/device/connection-status');
      
      final headers = await ApiHeaders.getJsonHeaders();
      
      final body = jsonEncode({
        'connected': [deviceId],
        'disconnected': [],
      });
      
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        AppLogger.info('Reported device connection: $deviceId');
      } else {
        AppLogger.warning('Failed to report connection: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Error reporting connection: $e');
    }
  }

  /// Report disconnection event to server (called when BT device disconnects)
  Future<void> reportDisconnection(String deviceId) async {
    try {
      final baseUrl = ServerConfigService.instance.baseUrl;
      final url = Uri.parse('$baseUrl/device/connection-status');
      
      final headers = await ApiHeaders.getJsonHeaders();
      
      final body = jsonEncode({
        'connected': [],
        'disconnected': [deviceId],
      });
      
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        AppLogger.info('Reported device disconnection: $deviceId');
      } else {
        AppLogger.warning('Failed to report disconnection: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Error reporting disconnection: $e');
    }
  }

  /// Check if service is running
  bool get isRunning => _isRunning;
}
