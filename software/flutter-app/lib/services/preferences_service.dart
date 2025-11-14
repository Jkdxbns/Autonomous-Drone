import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

/// Service for managing user preferences and settings
/// All app settings are persisted to device storage using SharedPreferences
class PreferencesService {
  static PreferencesService? _instance;
  static SharedPreferences? _prefs;

  // ValueNotifiers for reactive model selection
  final ValueNotifier<String> defaultSttModelNotifier = ValueNotifier<String>('small');
  final ValueNotifier<String> defaultLmModelNotifier = ValueNotifier<String>('gemini-2.5-flash');

  // Private constructor
  PreferencesService._();

  /// Get singleton instance
  static PreferencesService get instance {
    _instance ??= PreferencesService._();
    return _instance!;
  }

  /// Initialize the preferences service
  /// Must be called before using any other methods
  static Future<void> init() async {
    if (_prefs != null) {
      // Already initialized, just reload values
      final sttModel = _prefs!.getString(_keyDefaultSttModel) ?? 'small';
      final lmModel = _prefs!.getString(_keyDefaultLmModel) ?? 'gemini-2.5-flash';
      instance.defaultSttModelNotifier.value = sttModel;
      instance.defaultLmModelNotifier.value = lmModel;
      return;
    }
    
    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();
    
    // Migrate old model names to new format
    _migrateModelNames();
    
    // Load model preferences into notifiers
    final sttModel = _prefs?.getString(_keyDefaultSttModel) ?? 'small';
    final lmModel = _prefs?.getString(_keyDefaultLmModel) ?? 'gemini-2.5-flash';
    
    instance.defaultSttModelNotifier.value = sttModel;
    instance.defaultLmModelNotifier.value = lmModel;
  }

  /// Migrate old model names (whisper-small → small)
  static void _migrateModelNames() {
    if (_prefs == null) return;
    
    // Migrate STT model name
    final oldSttModel = _prefs!.getString(_keyDefaultSttModel);
    if (oldSttModel != null && oldSttModel.startsWith('whisper-')) {
      // Convert "whisper-small" → "small"
      final newSttModel = oldSttModel.replaceFirst('whisper-', '');
      _prefs!.setString(_keyDefaultSttModel, newSttModel);
      // Migration complete - no need to print in production
    }
    
    // LM models don't need migration (already use correct format)
  }

  // Preference Keys
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyAllowCellular = 'allow_cellular_download';
  static const String _keyMicPermissionAsked = 'mic_permission_asked';
  static const String _keyWifiPermissionAsked = 'wifi_permission_asked';
  static const String _keyDeviceId = 'device_id';
  static const String _keyTtsEnabled = 'tts_enabled';
  static const String _keyTtsSpeed = 'tts_speed';
  static const String _keyTtsPitch = 'tts_pitch';
  static const String _keyTtsVolume = 'tts_volume';
  static const String _keyServerHost = 'server_host';
  static const String _keyServerPort = 'server_port';
  static const String _keyDefaultSttModel = 'default_stt_model';
  static const String _keyDefaultLmModel = 'default_lm_model';

  // Theme Settings
  bool get isDarkMode => _prefs?.getBool(_keyThemeMode) ?? false;
  Future<void> setDarkMode(bool value) async {
    await _prefs?.setBool(_keyThemeMode, value);
  }

  // Download Settings
  bool get allowCellularDownload => _prefs?.getBool(_keyAllowCellular) ?? false;
  Future<void> setAllowCellularDownload(bool value) async {
    await _prefs?.setBool(_keyAllowCellular, value);
  }

  // Permission Settings
  bool get micPermissionAsked => _prefs?.getBool(_keyMicPermissionAsked) ?? false;
  Future<void> setMicPermissionAsked(bool value) async {
    await _prefs?.setBool(_keyMicPermissionAsked, value);
  }

  bool get wifiPermissionAsked => _prefs?.getBool(_keyWifiPermissionAsked) ?? false;
  Future<void> setWifiPermissionAsked(bool value) async {
    await _prefs?.setBool(_keyWifiPermissionAsked, value);
  }

  // Device ID
  String? get deviceId => _prefs?.getString(_keyDeviceId);
  Future<void> setDeviceId(String value) async {
    await _prefs?.setString(_keyDeviceId, value);
  }

  // TTS Settings
  bool get ttsEnabled => _prefs?.getBool(_keyTtsEnabled) ?? true;
  Future<void> setTtsEnabled(bool value) async {
    await _prefs?.setBool(_keyTtsEnabled, value);
  }

  double get ttsSpeed => _prefs?.getDouble(_keyTtsSpeed) ?? 0.5;
  Future<void> setTtsSpeed(double value) async {
    await _prefs?.setDouble(_keyTtsSpeed, value);
  }

  double get ttsPitch => _prefs?.getDouble(_keyTtsPitch) ?? 1.0;
  Future<void> setTtsPitch(double value) async {
    await _prefs?.setDouble(_keyTtsPitch, value);
  }

  double get ttsVolume => _prefs?.getDouble(_keyTtsVolume) ?? 0.8;
  Future<void> setTtsVolume(double value) async {
    await _prefs?.setDouble(_keyTtsVolume, value);
  }

  // Server Configuration
  String get serverHost => _prefs?.getString(_keyServerHost) ?? '192.168.1.168';
  Future<void> setServerHost(String value) async {
    await _prefs?.setString(_keyServerHost, value);
  }

  int get serverPort => _prefs?.getInt(_keyServerPort) ?? 5000;
  Future<void> setServerPort(int value) async {
    await _prefs?.setInt(_keyServerPort, value);
  }

  // Model Selection - Server Models Only
  String get defaultSttModel => defaultSttModelNotifier.value;
  Future<void> setDefaultSttModel(String value) async {
    AppLogger.info('Saving STT model: $value');
    await _prefs?.setString(_keyDefaultSttModel, value);
    defaultSttModelNotifier.value = value;
    AppLogger.success('STT model saved: $value');
  }

  String get defaultLmModel => defaultLmModelNotifier.value;
  Future<void> setDefaultLmModel(String value) async {
    AppLogger.info('Saving LM model: $value');
    await _prefs?.setString(_keyDefaultLmModel, value);
    defaultLmModelNotifier.value = value;
    AppLogger.success('LM model saved: $value');
  }

  /// Clear all preferences (useful for reset/logout)
  Future<void> clearAll() async {
    await _prefs?.clear();
  }

  /// Check if preferences have been initialized
  static bool get isInitialized => _prefs != null;
}
