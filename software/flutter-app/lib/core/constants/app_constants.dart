/// Application-wide constants
class AppConstants {
  AppConstants._();

  // App Metadata
  static const String appName = 'Voice Assistant';
  static const String appVersion = '2.1.0';
  static const String appBuild = '1';

  // Audio Settings
  static const int audioSampleRate = 16000;
  static const int audioChannels = 1;
  static const String audioFormat = 'wav';
  static const int maxRecordingDuration = 300; // 5 minutes in seconds
  static const int minRecordingDurationMs = 500; // minimum recording duration

  // File Paths
  static const String audioDirectory = 'audio_recordings';
  static const String tempDirectory = 'temp';
  static const String configAssetPath = 'assets/config.json';

  // Timeouts (in seconds)
  static const Duration apiTimeoutShort = Duration(seconds: 5);
  static const Duration apiTimeoutMedium = Duration(seconds: 10);
  static const Duration apiTimeoutLong = Duration(seconds: 30);
  static const Duration apiTimeoutXL = Duration(seconds: 60);
  static const Duration apiTimeoutXXL = Duration(seconds: 120);
  static const Duration recordingTimeout = Duration(minutes: 5);

  // Database
  static const String databaseName = 'voice_assistant.db';
  static const int databaseVersion = 1;

  // Pagination & Limits
  static const int itemsPerPage = 20;
  static const int maxChatHistory = 1000;
  static const int chatTitleMaxLength = 30;
  static const int previewTextMaxLength = 50;

  // Animation & UI Timing
  static const Duration textInputDebounce = Duration(milliseconds: 150);
  static const Duration recordingTimerInterval = Duration(milliseconds: 100);
  static const Duration snackbarDisplayDuration = Duration(seconds: 2);
  static const Duration shortSnackbarDuration = Duration(seconds: 1);
  static const Duration scrollAnimationDuration = Duration(milliseconds: 300);
  
  // TTS Settings
  static const double defaultTtsSpeechRate = 1.0;
  static const double defaultTtsPitch = 1.0;
  static const double defaultTtsVolume = 1.0;
  static const double minTtsSpeechRate = 0.5;
  static const double maxTtsSpeechRate = 2.0;
  static const double minTtsPitch = 0.5;
  static const double maxTtsPitch = 2.0;

  // Scroll Behavior
  static const double autoScrollThreshold = 100.0; // pixels from bottom
}
