import 'dart:convert';
import 'package:flutter/services.dart';

/// App configuration loaded from config.json
class AppConfig {
  final String baseUrl;
  final Map<String, String> endpoints;

  AppConfig({
    required this.baseUrl,
    required this.endpoints,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      baseUrl: json['baseUrl'] as String,
      endpoints: Map<String, String>.from(json['endpoints'] as Map),
    );
  }

  static AppConfig? _instance;

  static AppConfig get instance {
    if (_instance == null) {
      throw StateError('AppConfig not initialized. Call AppConfig.load() first.');
    }
    return _instance!;
  }

  /// Initialize from a pre-parsed JSON object (used for background initialization)
  static void initializeFromJson(Map<String, dynamic> json) {
    _instance = AppConfig.fromJson(json);
  }

  /// Load configuration from assets/config.json
  static Future<void> load() async {
    final configString = await rootBundle.loadString('assets/config.json');
    final configJson = jsonDecode(configString) as Map<String, dynamic>;
    _instance = AppConfig.fromJson(configJson);
  }

  /// Get full URL for an endpoint
  String getUrl(String endpointKey) {
    final endpoint = endpoints[endpointKey];
    if (endpoint == null) {
      throw ArgumentError('Endpoint "$endpointKey" not found in config');
    }
    return '$baseUrl$endpoint';
  }
}
