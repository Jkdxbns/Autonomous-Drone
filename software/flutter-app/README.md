# COFFIN v6 - Voice AI Assistant with Bluetooth Integration

A comprehensive Flutter mobile application that combines voice-based AI interaction with Bluetooth device management. This app provides real-time speech-to-text transcription, AI-powered conversations, and unified Bluetooth connectivity for both Classic (SPP) and Low Energy (BLE) devices.

## 🚀 Features

### AI & Voice Interaction
- **Voice Recording & Transcription**: Real-time audio recording with server-side speech-to-text processing
- **AI Assistant**: Interactive chat interface with streaming responses from language models
- **Conversation Management**: Create, save, and manage multiple chat sessions with full history
- **Text-to-Speech**: Optional voice responses from the AI assistant
- **Model Selection**: Choose from available language models on the server

### Bluetooth Connectivity
- **Unified Bluetooth Scanner**: Discover and connect to both Bluetooth Classic (SPP) and BLE devices
  - HC-05/HC-06 Bluetooth Classic modules
  - HM-10 BLE modules
  - Automatic device type detection
- **Bluetooth Terminal**: Send and receive data from connected devices in real-time
- **Bluetooth Controller**: Gamepad-style interface for controlling connected devices
- **Device Management**: Save custom names, auto-reconnect, and manage multiple devices
- **Connection Persistence**: Automatically restores connections on app restart

### Device & Server Management
- **Server Configuration**: Configure custom server endpoints for all API services
- **Device Registration**: Automatic device registration with server using hardware MAC address
- **Device Lookup**: View and manage registered devices on the server
- **Heartbeat Service**: Maintains device online status with automatic server sync
- **Health Monitoring**: Real-time server health and connectivity status

### User Interface
- **Material Design 3**: Modern, responsive UI with dark/light theme support
- **Navigation Drawer**: Easy access to all features and settings
- **Permission Management**: Professional permission request dialogs with rationale
- **Error Handling**: Comprehensive error messages and user feedback
- **Offline Support**: Local database for chat history and device settings

## 📋 Prerequisites

### Development Environment
- **Flutter SDK**: Version 3.9.2 or higher
- **Dart SDK**: Version 3.9.2 or higher
- **Android Studio** or **VS Code** with Flutter extensions
- **Android SDK**: API level 21+ (Android 5.0+)
  - Target SDK: API 36 (Android 14+)

### Backend Server
This app requires a running backend server that provides:
- Speech-to-Text API endpoint (`/api/stt/transcribe`)
- Language Model Chat API (`/api/lm/chat` and `/api/lm/chat/stream`)
- Device Registration API (`/api/devices/register`)
- Conversation Management API
- Audio Upload/Download endpoints

**Note**: Server implementation is not included in this repository. Configure your server URL in the app settings or `assets/config.json`.

## 🛠️ Installation & Setup

### 1. Prerequisites
- **Flutter SDK**: Version 3.9.2 or higher ([Install Flutter](https://flutter.dev/docs/get-started/install))
- **Dart SDK**: Version 3.9.2 or higher (comes with Flutter)
- **Android Studio** or **VS Code** with Flutter extensions
- **Android SDK**: API level 21+ (Android 5.0+)

### 2. Create Flutter Project
```bash
# Create a new Flutter project
flutter create your_project_name
cd your_project_name
```

### 3. Copy Project Files
Copy/replace the following files and folders from this repository:

**Required Files:**
- `lib/` → Replace entire folder with all source code
- `assets/` → Copy entire folder (contains config.json)
- `packages/` → Copy entire folder (contains patched bluetooth package)
- `pubspec.yaml` → Replace file (contains all dependencies)

**Android Configuration:**
- `android/app/build.gradle.kts` → Replace file (SDK 36 config)
- `android/app/src/main/AndroidManifest.xml` → Replace file (all permissions included)

**Optional:**
- `test/` → Copy folder if you want the test files

### 4. Install Dependencies
```bash
flutter pub get
```

### 5. Update App Package Name (Optional)
If you want to use a different package name:

Edit `android/app/build.gradle.kts`:
```kotlin
android {
    namespace = "com.yourcompany.yourapp"  // Change this
    
    defaultConfig {
        applicationId = "com.yourcompany.yourapp"  // Change this too
    }
}
```

Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:label="Your App Name"  <!-- Change this -->
```

### 6. Android Permissions (Already Configured)
✅ The provided `AndroidManifest.xml` already includes:
- Microphone, Internet, Network permissions
- Bluetooth Classic & BLE permissions (all Android versions)
- Location permissions (required for Bluetooth scanning)
- Storage permissions (optional)
- Foreground service permissions
- Impeller disabled (fixes rendering issues)

✅ The provided `build.gradle.kts` already includes:
- SDK 36 (Android 15) configuration
- Minimum SDK 21 (Android 5.0)
- ProGuard configuration for release builds
- Java 11 compatibility

### 7. Configure Server Connection
Edit `assets/config.json` to point to your server:
```json
{
  "baseUrl": "http://your-server-ip:8000",
  ...
}
```

Or configure it later in the app via **Settings > Server Configuration**.

### 8. Build & Run

#### Debug Build
```bash
flutter run
```

#### Production APK
```bash
flutter build apk --release
```

The APK will be generated at: `build/app/outputs/flutter-apk/app-release.apk`

#### Production App Bundle (for Google Play)
```bash
flutter build appbundle --release
```

## 📱 Usage Guide

### First Launch
1. **Grant Permissions**: The app will request necessary permissions on first launch
2. **Configure Server**: Navigate to Settings > Server Configuration and enter your server URL
3. **Device Registration**: The app automatically registers your device with the server

### Voice Recording & AI Chat
1. Open **AI Assistant** from the drawer
2. Tap and hold the microphone button to record
3. Release to send the recording for transcription and AI response
4. View conversation history in **Chat History**
5. Create new conversations with the "New Chat" button

### Bluetooth Connection
1. Open **Bluetooth > Scanner** from the drawer
2. Toggle between "Classic" and "BLE" tabs
3. Tap **Scan** to discover devices
4. Tap on a device to connect
5. Use **Bluetooth > Terminal** to send/receive data
6. Use **Bluetooth > Controller** for gamepad-style control

### Managing Devices
- **Custom Names**: Long-press a device in the terminal to set a custom name
- **Auto-Reconnect**: Enable in Bluetooth Settings to automatically reconnect on app start
- **Device Info**: View MAC addresses and connection details in Device Lookup

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point & navigation
├── api/                      # API service implementations
├── config/                   # App & UI configuration
├── models/                   # Data models
├── services/                 # Business logic services
│   ├── ble/                  # Bluetooth Low Energy services
│   ├── bluetooth/            # Bluetooth Classic services
│   ├── device/               # Device info & registration
│   ├── permissions/          # Permission management
│   └── server/               # Server API services
├── ui/                       # User interface screens & widgets
│   ├── screens/              # App screens
│   │   ├── bluetooth/        # Bluetooth-related screens
│   │   ├── models/           # Model selection
│   │   └── settings/         # Settings screens
│   └── widgets/              # Reusable UI components
└── utils/                    # Utility functions & helpers

assets/
└── config.json               # Server endpoints & configuration

android/                      # Android-specific code
packages/                     # Local package modifications
└── flutter_bluetooth_serial/ # Patched for Android SDK 36
```

## 🔧 Key Technologies

- **Flutter**: Android mobile framework (as of now)
- **SQLite**: Local database for conversation history
- **Shared Preferences**: App settings persistence (most settings not persistent)
- **HTTP**: API based communication
- **flutter_bluetooth_serial**: Bluetooth Classic (SPP) connectivity
- **flutter_reactive_ble**: Bluetooth Low Energy connectivity
- **record**: Audio recording
- **flutter_tts**: Text-to-speech synthesis
- **permission_handler**: Runtime permission management

## 🔒 Permissions Required

| Permission | Purpose |
|------------|---------|
| Microphone | Voice recording for transcription |
| Internet | API communication with server |
| Bluetooth | Connect to Bluetooth devices |
| Location | Required for Bluetooth scanning on Android |
| Storage | Optional: Export/import audio files |
| Foreground Service | Maintain Bluetooth connections in background |

## 🐛 Troubleshooting

### Bluetooth Connection Issues
- Ensure Bluetooth is enabled on your device
- Grant all required permissions (Bluetooth + Location)
- For Android 12+, both BLUETOOTH_SCAN and BLUETOOTH_CONNECT are required
- Try unpairing and re-pairing devices in Android Bluetooth settings

### Server Connection Errors
- Verify server URL in Settings > Server Configuration
- Check server is running and accessible from your device
- Ensure firewall allows connections on the server port
- For local development, use your computer's local network IP (not localhost)

### Permission Denied
- Go to Android Settings > Apps > COFFIN v6 > Permissions
- Manually enable all required permissions
- Restart the app after changing permissions

### Build Errors
- Run `flutter clean` and `flutter pub get`
- Ensure Flutter SDK is up to date: `flutter upgrade`
- Check Android SDK is properly installed
- For Gradle errors, check `android/gradle.properties`

---

**Built with Flutter** ❤️ | **Version**: 9.0.0
