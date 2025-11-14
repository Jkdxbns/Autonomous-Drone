import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_logger.dart';

/// Manages server configuration with persistence
/// Allows users to change server host/port in app
class ServerConfigService {
  static final ServerConfigService instance = ServerConfigService._();
  
  ServerConfigService._();

  // Reactive server configuration
  final ValueNotifier<String> host = ValueNotifier<String>('192.168.0.168');
  final ValueNotifier<int> port = ValueNotifier<int>(5000);

  // Keys for SharedPreferences
  static const String _keyHost = 'server_host';
  static const String _keyPort = 'server_port';

  // Default values
  static const String defaultHost = '192.168.0.168';
  static const int defaultPort = 5000;

  /// Get full server URL
  String get baseUrl => 'http://${host.value}:${port.value}';

  /// Initialize from saved preferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load saved values or use defaults
      host.value = prefs.getString(_keyHost) ?? defaultHost;
      port.value = prefs.getInt(_keyPort) ?? defaultPort;
      
      AppLogger.info('Server config loaded: $baseUrl');
    } catch (e) {
      AppLogger.error('Failed to load server config: $e');
      // Use defaults on error
      host.value = defaultHost;
      port.value = defaultPort;
    }
  }

  /// Update server configuration and persist
  Future<bool> updateServer(String newHost, int newPort) async {
    try {
      // Validate inputs
      if (newHost.isEmpty) {
        AppLogger.error('Invalid host: empty string');
        return false;
      }
      
      if (newPort <= 0 || newPort > 65535) {
        AppLogger.error('Invalid port: $newPort');
        return false;
      }

      AppLogger.info('Updating server config: $newHost:$newPort');

      final prefs = await SharedPreferences.getInstance();
      
      // Save to preferences
      final hostSaved = await prefs.setString(_keyHost, newHost);
      final portSaved = await prefs.setInt(_keyPort, newPort);
      
      if (!hostSaved || !portSaved) {
        AppLogger.error('Failed to save server config to SharedPreferences');
        return false;
      }
      
      // Update reactive values
      host.value = newHost;
      port.value = newPort;
      
      AppLogger.success('Server config updated and saved: $baseUrl');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update server config: $e');
      return false;
    }
  }

  /// Reset to default configuration
  Future<void> resetToDefaults() async {
    await updateServer(defaultHost, defaultPort);
  }

  /// Dispose resources
  void dispose() {
    host.dispose();
    port.dispose();
  }
}
