import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/app_logger.dart';
import '../../api/models/device_info_data.dart';
import 'api_headers.dart';

/// Service for device registration with server
class DeviceRegistrationApiService {
  final String baseUrl;

  DeviceRegistrationApiService({required this.baseUrl});

  /// Register device with server
  /// Sends device name, model, UUID, and MAC address (if available)
  Future<bool> registerDevice(DeviceInfoData deviceInfo) async {
    try {
      final url = Uri.parse('$baseUrl${ApiEndpoints.registerDevice}');
      
      // Get headers with device info
      final headers = await ApiHeaders.getJsonHeaders();
      
      final requestBody = jsonEncode(deviceInfo.toJson());
      
      // DEBUG: Log what we're sending
      AppLogger.info('═══════════════════════════════════════════════════════');
      AppLogger.info('[REGISTRATION] Registering device with server');
      AppLogger.info('═══════════════════════════════════════════════════════');
      AppLogger.info('URL: $url');
      AppLogger.info('Device Info:');
      AppLogger.info('  device_id: ${deviceInfo.deviceId}');
      AppLogger.info('  device_name: ${deviceInfo.deviceName}');
      AppLogger.info('  model_name: ${deviceInfo.modelName}');
      AppLogger.info('  mac_address: ${deviceInfo.macAddress ?? "NULL"}');
      AppLogger.info('  ip_address: ${deviceInfo.ipAddress ?? "NULL"}');
      AppLogger.info('Request Headers:');
      headers.forEach((key, value) {
        AppLogger.info('  $key: $value');
      });
      AppLogger.info('Request Body (JSON):');
      AppLogger.info('  $requestBody');
      AppLogger.info('───────────────────────────────────────────────────────');
      
      final response = await http
          .post(
            url,
            headers: headers,
            body: requestBody,
          )
          .timeout(AppConstants.apiTimeoutMedium);

      AppLogger.info('[REGISTRATION] Server Response:');
      AppLogger.info('  Status Code: ${response.statusCode}');
      AppLogger.info('  Body: ${response.body}');
      AppLogger.info('═══════════════════════════════════════════════════════');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        
        if (status == 'success') {
          AppLogger.success('✅ Device registered successfully: ${deviceInfo.deviceName}');
          return true;
        }
      }

      AppLogger.error('❌ Device registration failed: ${response.statusCode}');
      return false;
    } catch (e) {
      AppLogger.error('❌ Cannot register device: $e');
      return false;
    }
  }

  /// Get list of all registered devices (for admin/debugging)
  Future<List<Map<String, dynamic>>?> getDeviceList() async {
    try {
      final url = Uri.parse('$baseUrl${ApiEndpoints.deviceList}');
      
      // Add device tracking headers even for GET requests
      final headers = await ApiHeaders.getHeaders();
      
      final response = await http.get(url, headers: headers).timeout(
        AppConstants.apiTimeoutMedium,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final devices = json['devices'] as List<dynamic>?;
        
        if (devices != null) {
          final deviceList = devices.map((d) => d as Map<String, dynamic>).toList();
          
          AppLogger.success('Fetched ${deviceList.length} devices from server');
          return deviceList;
        }
      }

      AppLogger.error('Failed to fetch device list: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.error('Cannot fetch device list: $e');
      return null;
    }
  }

  /// Update custom name for a device
  Future<bool> updateDeviceName(String identifier, String customName) async {
    try {
      // URL encode the identifier (important for MAC addresses with colons)
      final encodedIdentifier = Uri.encodeComponent(identifier);
      final url = Uri.parse('$baseUrl/device/$encodedIdentifier/name');
      
      AppLogger.info('Updating device name:');
      AppLogger.info('  URL: $url');
      AppLogger.info('  Identifier: $identifier');
      AppLogger.info('  Encoded: $encodedIdentifier');
      AppLogger.info('  Custom name: $customName');
      
      // Get headers with device info (for tracking who made the change)
      final headers = await ApiHeaders.getJsonHeaders();
      
      final requestBody = jsonEncode({
        'custom_name': customName,
      });
      
      AppLogger.info('  Request body: $requestBody');
      AppLogger.info('  Headers: ${headers.keys.join(", ")}');
      
      final response = await http
          .put(
            url,
            headers: headers,
            body: requestBody,
          )
          .timeout(AppConstants.apiTimeoutMedium);

      AppLogger.info('Update response:');
      AppLogger.info('  Status: ${response.statusCode}');
      AppLogger.info('  Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        
        if (status == 'success') {
          AppLogger.success('✓ Device name updated successfully');
          return true;
        } else {
          AppLogger.error('Server returned success code but status != "success"');
          AppLogger.error('Response data: $data');
          return false;
        }
      } else if (response.statusCode == 404) {
        AppLogger.error('✗ Device not found on server (identifier: $identifier)');
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          AppLogger.error('Error details: ${errorData['error']}');
        } catch (_) {
          AppLogger.error('Error response: ${response.body}');
        }
        return false;
      } else if (response.statusCode == 400) {
        AppLogger.error('✗ Bad request - missing required fields');
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          AppLogger.error('Error details: ${errorData['error']}');
        } catch (_) {
          AppLogger.error('Error response: ${response.body}');
        }
        return false;
      }

      AppLogger.error('✗ Unexpected response: ${response.statusCode}');
      AppLogger.error('Response body: ${response.body}');
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('✗ Exception updating device name: $e');
      AppLogger.error('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Clear custom name for a device (revert to auto-detected)
  Future<bool> clearDeviceName(String identifier) async {
    try {
      // URL encode the identifier (important for MAC addresses with colons)
      final encodedIdentifier = Uri.encodeComponent(identifier);
      final url = Uri.parse('$baseUrl/device/$encodedIdentifier/name');
      
      AppLogger.info('Clearing device name at: $url');
      
      // Get headers with device info
      final headers = await ApiHeaders.getHeaders();
      
      final response = await http
          .delete(url, headers: headers)
          .timeout(AppConstants.apiTimeoutMedium);

      AppLogger.info('Clear response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        
        if (status == 'success') {
          AppLogger.success('Device name cleared (reverted to auto)');
          return true;
        }
      }

      AppLogger.error('Device name clear failed: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      AppLogger.error('Cannot clear device name: $e');
      return false;
    }
  }
}
