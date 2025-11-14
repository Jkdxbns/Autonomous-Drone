import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background initialization service that runs heavy startup tasks off the main thread
class BackgroundInitializer {
  /// Initialize app configuration and preferences in a background isolate
  static Future<InitializationResult> initialize() async {
    // Run heavy initialization work off the main thread using compute
    return await compute(_initializeInBackground, null);
  }
}

/// Top-level function for background initialization (required for compute)
Future<InitializationResult> _initializeInBackground(_) async {
  try {
    // Load config from assets (this involves JSON parsing)
    final configString = await rootBundle.loadString('assets/config.json');
    
    // Initialize SharedPreferences (this can be slow on first run)
    final prefs = await SharedPreferences.getInstance();
    
    // Get theme preference
    final isDarkMode = prefs.getBool('theme_mode') ?? false;
    
    return InitializationResult(
      success: true,
      configJson: configString,
      isDarkMode: isDarkMode,
    );
  } catch (e) {
    return InitializationResult(
      success: false,
      error: e.toString(),
    );
  }
}

/// Result object for initialization (must be serializable for isolate communication)
class InitializationResult {
  final bool success;
  final String? configJson;
  final bool isDarkMode;
  final String? error;

  InitializationResult({
    required this.success,
    this.configJson,
    this.isDarkMode = false,
    this.error,
  });
}
