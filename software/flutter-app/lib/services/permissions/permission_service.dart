import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/app_logger.dart';
import '../preferences_service.dart';

/// Centralized permission management service
/// Handles microphone permission with lifecycle monitoring
class PermissionService {
  static final PermissionService instance = PermissionService._();
  
  PermissionService._();

  /// Reactive permission state - UI can listen to this
  final ValueNotifier<bool> hasMicrophonePermission = ValueNotifier<bool>(false);

  /// Initialize permission service - call at app startup
  Future<void> initialize() async {
    try {
      final status = await Permission.microphone.status;
      hasMicrophonePermission.value = status.isGranted;
      
      AppLogger.info('Permission initialized: ${status.isGranted}');
    } catch (e) {
      AppLogger.error('Permission initialization error: $e');
      hasMicrophonePermission.value = false;
    }
  }

  /// Recheck permission status - call when app resumes from background
  Future<void> recheckPermission() async {
    try {
      final status = await Permission.microphone.status;
      hasMicrophonePermission.value = status.isGranted;
      
      AppLogger.info('Permission rechecked: ${status.isGranted}');
    } catch (e) {
      AppLogger.error('Permission recheck error: $e');
    }
  }

  /// Request microphone permission from system
  /// Returns true if granted, false otherwise
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      hasMicrophonePermission.value = status.isGranted;
      
      // Remember that we asked for permission
      if (!status.isGranted) {
        await PreferencesService.instance.setMicPermissionAsked(true);
      }
      
      AppLogger.info('Permission requested: ${status.isGranted}');
      return status.isGranted;
    } catch (e) {
      AppLogger.error('Permission request error: $e');
      return false;
    }
  }

  /// Open app settings for manual permission grant
  Future<void> openSettings() async {
    try {
      await openAppSettings();
      AppLogger.info('Opened app settings for permission');
    } catch (e) {
      AppLogger.error('Error opening settings: $e');
    }
  }

  /// Check if permission is permanently denied
  Future<bool> isPermanentlyDenied() async {
    try {
      final status = await Permission.microphone.status;
      return status.isPermanentlyDenied;
    } catch (e) {
      AppLogger.error('Error checking permanent denial: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    hasMicrophonePermission.dispose();
  }
}
