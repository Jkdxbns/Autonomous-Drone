import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/preferences_service.dart';
import '../../utils/app_logger.dart';
import '../../ui/dialogs/microphone_permission_dialog.dart';
import '../../ui/dialogs/wifi_permission_dialog.dart';

/// Manages permission requests with professional dialogs
class PermissionManager {
  static final PermissionManager instance = PermissionManager._();
  PermissionManager._();

  /// Request microphone permission with dialog
  Future<bool> requestMicrophonePermission(BuildContext context, {bool forceShow = false}) async {
    final prefs = PreferencesService.instance;
    final status = await Permission.microphone.status;
    
    // If already granted and not forcing, skip dialog
    if (status.isGranted && !forceShow) {
      return true;
    }
    
    // If already asked and denied/permanently denied, check if we should show settings
    if (prefs.micPermissionAsked && !forceShow) {
      if (status.isPermanentlyDenied) {
        // ignore: use_build_context_synchronously
        if (context.mounted) {
          await _showOpenSettingsDialog(
            context,
            'Microphone Access Required',
            'Please enable microphone permission in app settings to use voice recording features.',
          );
        }
      }
      return status.isGranted;
    }

    // Show professional dialog
    if (!context.mounted) return false;
    final userConsent = await showMicrophonePermissionDialog(context);
    
    if (!userConsent) {
      await prefs.setMicPermissionAsked(true);
      AppLogger.error('User denied microphone permission in dialog');
      return false;
    }

    // Request actual system permission
    final newStatus = await Permission.microphone.request();
    await prefs.setMicPermissionAsked(true);

    if (newStatus.isGranted) {
      AppLogger.success('Microphone permission granted');
      return true;
    } else if (newStatus.isPermanentlyDenied) {
      AppLogger.error('Microphone permission permanently denied');
      // Show settings dialog
      // ignore: use_build_context_synchronously
      if (context.mounted) {
        await _showOpenSettingsDialog(
          context,
          'Microphone Access Required',
          'Please enable microphone permission in app settings to use voice recording features.',
        );
      }
    } else {
      AppLogger.error('Microphone permission denied');
    }

    return false;
  }

  /// Request Wi-Fi permission with dialog (for device identification)
  Future<bool> requestWiFiPermission(BuildContext context, {bool forceShow = false}) async {
    final prefs = PreferencesService.instance;
    
    // If already asked and not forcing, skip
    if (prefs.wifiPermissionAsked && !forceShow) {
      return true;
    }

    // Show professional dialog for user awareness
    if (!context.mounted) return false;
    final userConsent = await showWiFiPermissionDialog(context);
    await prefs.setWifiPermissionAsked(true);

    if (userConsent) {
      AppLogger.success('User consented to network information access');
      return true;
    } else {
      AppLogger.info('User skipped network information access (will use device ID only)');
      return false;
    }
  }

  /// Request both permissions on app startup (first time only)
  Future<void> requestStartupPermissions(BuildContext context) async {
    if (!context.mounted) return;
    
    final prefs = PreferencesService.instance;
    
    AppLogger.info('═══════════════════════════════════════════════════════');
    AppLogger.info('[STARTUP PERMISSIONS] Checking permission status');
    AppLogger.info('═══════════════════════════════════════════════════════');
    
    // Check if this is the first time the app is launched
    final micAsked = prefs.micPermissionAsked;
    final wifiAsked = prefs.wifiPermissionAsked;
    final isFirstLaunch = !micAsked && !wifiAsked;
    
    AppLogger.info('Permission flags:');
    AppLogger.info('  micPermissionAsked: $micAsked');
    AppLogger.info('  wifiPermissionAsked: $wifiAsked');
    AppLogger.info('  isFirstLaunch: $isFirstLaunch');
    
    if (isFirstLaunch) {
      AppLogger.info('First launch detected - requesting ALL permissions');
    } else {
      AppLogger.info('Not first launch - checking individual permission needs');
    }
    
    // Request Wi-Fi first (less intrusive)
    if (!prefs.wifiPermissionAsked) {
      AppLogger.info('Requesting WiFi permission...');
      await requestWiFiPermission(context);
    } else {
      AppLogger.info('Skipping WiFi permission (already asked)');
    }
    
    // Add small delay between dialogs for better UX
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Then request microphone
    if (context.mounted && !prefs.micPermissionAsked) {
      AppLogger.info('Requesting microphone permission...');
      await requestMicrophonePermission(context);
    } else {
      AppLogger.info('Skipping microphone permission (already asked)');
    }
    
    // Add small delay before notification permission
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Request notification permission
    if (context.mounted) {
      AppLogger.info('Requesting notification permission...');
      await requestNotificationPermission(context);
    }
    
    // Add delay before Bluetooth permissions
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Request Bluetooth permissions (ALWAYS - no flag to skip)
    if (context.mounted) {
      AppLogger.info('Requesting Bluetooth permissions...');
      final btGranted = await requestBluetoothPermissions(context);
      if (btGranted) {
        AppLogger.success('✅ Bluetooth permissions granted on startup');
      } else {
        AppLogger.warning('⚠️ Bluetooth permissions not granted on startup');
      }
    }
    
    AppLogger.info('═══════════════════════════════════════════════════════');
    AppLogger.info('[STARTUP PERMISSIONS] Permission request flow completed');
    AppLogger.info('═══════════════════════════════════════════════════════');
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission(BuildContext context, {bool forceShow = false}) async {
    final status = await Permission.notification.status;
    
    // If already granted and not forcing, skip
    if (status.isGranted && !forceShow) {
      return true;
    }

    // If permanently denied, show settings dialog
    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await _showOpenSettingsDialog(
          context,
          'Notification Permission',
          'Please enable notification permission in app settings to receive connection alerts and messages.',
        );
      }
      return false;
    }

    // Show consent dialog
    if (!context.mounted) return false;
    final userConsent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('Enable Notifications?'),
          ],
        ),
        content: const Text(
          'Allow notifications to:\n\n'
          '• Get alerts when devices connect/disconnect\n'
          '• Receive new message notifications\n'
          '• Stay informed about Bluetooth status\n\n'
          'You can change this later in settings.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check),
            label: const Text('Allow'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (userConsent != true) {
      AppLogger.info('User declined notification permission');
      return false;
    }

    // Request system permission
    final newStatus = await Permission.notification.request();

    if (newStatus.isGranted) {
      AppLogger.success('Notification permission granted');
      return true;
    } else if (newStatus.isPermanentlyDenied) {
      AppLogger.error('Notification permission permanently denied');
      if (context.mounted) {
        await _showOpenSettingsDialog(
          context,
          'Notification Permission',
          'Please enable notification permission in app settings.',
        );
      }
    } else {
      AppLogger.error('Notification permission denied');
    }

    return false;
  }

  /// Check if notification permission is granted
  Future<bool> isNotificationGranted() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }
  
  /// Check if all required permissions have been requested
  Future<bool> hasRequestedAllPermissions() async {
    final prefs = PreferencesService.instance;
    return prefs.micPermissionAsked && prefs.wifiPermissionAsked;
  }

  /// Show dialog to open app settings
  Future<void> _showOpenSettingsDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    if (!context.mounted) return;
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Check if microphone permission is granted
  Future<bool> isMicrophoneGranted() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }
  
  /// Request Bluetooth permissions (Location + BT Scan + BT Connect + BT Advertise)
  /// Called on app startup to prevent crash when opening scanner
  Future<bool> requestBluetoothPermissions(BuildContext context) async {
    AppLogger.info('───────────────────────────────────────────────────────');
    AppLogger.info('[BLUETOOTH PERMISSIONS] Starting permission request flow');
    AppLogger.info('───────────────────────────────────────────────────────');
    
    try {
      // Check if all are already granted
      final locationStatus = await Permission.location.status;
      final btScanStatus = await Permission.bluetoothScan.status;
      final btConnectStatus = await Permission.bluetoothConnect.status;
      
      AppLogger.info('Current permission statuses:');
      AppLogger.info('  Location: ${locationStatus}');
      AppLogger.info('  Bluetooth Scan: ${btScanStatus}');
      AppLogger.info('  Bluetooth Connect: ${btConnectStatus}');
      
      if (locationStatus.isGranted && btScanStatus.isGranted && btConnectStatus.isGranted) {
        AppLogger.success('✅ All Bluetooth permissions already granted');
        return true;
      }
      
      AppLogger.info('Some permissions missing - showing explanation dialog');
      
      // Show explanation dialog first
      if (!context.mounted) {
        AppLogger.warning('Context not mounted - cannot show dialog');
        return false;
      }
      
      final userConsent = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bluetooth, color: Colors.blue, size: 28),
              SizedBox(width: 12),
              Text('Enable Bluetooth?'),
            ],
          ),
          content: const Text(
            'This app uses Bluetooth to:\n\n'
            '• Connect to Bluetooth devices (HC-05, HM-10)\n'
            '• Send and receive data wirelessly\n'
            '• Scan for nearby Bluetooth devices\n\n'
            'Location permission is also required by Android for Bluetooth scanning.\n\n'
            'You can manage these permissions later in app settings.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                AppLogger.info('User clicked "Not Now" on Bluetooth dialog');
                Navigator.of(context).pop(false);
              },
              child: const Text('Not Now'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                AppLogger.info('User clicked "Allow" on Bluetooth dialog');
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.check),
              label: const Text('Allow'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      
      if (userConsent != true) {
        AppLogger.warning('User declined Bluetooth permissions in dialog');
        return false;
      }
      
      AppLogger.info('User consented - requesting system permissions...');
      
      // Request location first (needed for BT scanning)
      if (locationStatus.isDenied) {
        AppLogger.info('Requesting location permission...');
        final result = await Permission.location.request();
        AppLogger.info('  Result: $result');
        if (!result.isGranted) {
          AppLogger.warning('Location permission denied');
          if (context.mounted) {
            _showLocationDeniedMessage(context);
          }
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // Request Bluetooth scan
      if (context.mounted && btScanStatus.isDenied) {
        AppLogger.info('Requesting Bluetooth scan permission...');
        final result = await Permission.bluetoothScan.request();
        AppLogger.info('  Result: $result');
        if (!result.isGranted) {
          AppLogger.warning('Bluetooth scan permission denied');
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // Request Bluetooth connect
      if (context.mounted && btConnectStatus.isDenied) {
        AppLogger.info('Requesting Bluetooth connect permission...');
        final result = await Permission.bluetoothConnect.request();
        AppLogger.info('  Result: $result');
        if (!result.isGranted) {
          AppLogger.warning('Bluetooth connect permission denied');
          return false;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      // Request Bluetooth advertise (optional, Android 13+)
      try {
        final btAdvertiseStatus = await Permission.bluetoothAdvertise.status;
        if (btAdvertiseStatus.isDenied) {
          AppLogger.info('Requesting Bluetooth advertise permission...');
          final result = await Permission.bluetoothAdvertise.request();
          AppLogger.info('  Result: $result');
        }
      } catch (e) {
        AppLogger.info('Bluetooth advertise permission not available: $e');
      }
      
      AppLogger.success('✅ All Bluetooth permissions granted successfully');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error requesting Bluetooth permissions: $e');
      return false;
    } finally {
      AppLogger.info('───────────────────────────────────────────────────────');
    }
  }
  
  /// Show message explaining why location is needed
  void _showLocationDeniedMessage(BuildContext context) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text(
          'Android requires location permission for Bluetooth scanning.\n\n'
          'This is an Android system requirement and your location data is NOT collected or used by this app.\n\n'
          'Please grant location permission to use Bluetooth features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  /// Reset permission flags (for testing or user request)
  Future<void> resetPermissionFlags() async {
    final prefs = PreferencesService.instance;
    await prefs.setMicPermissionAsked(false);
    await prefs.setWifiPermissionAsked(false);
    AppLogger.info('Permission flags reset');
  }
  
  /// Manually request permissions again (useful for settings screen)
  Future<void> requestPermissionsManually(BuildContext context) async {
    if (!context.mounted) return;
    
    // Request both permissions with forceShow flag
    await requestWiFiPermission(context, forceShow: true);
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    // ignore: use_build_context_synchronously
    if (context.mounted) {
      await requestMicrophonePermission(context, forceShow: true);
    }
  }
}
