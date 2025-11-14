import 'dart:convert';
import 'package:flutter/material.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/ai_assistant_screen.dart';
import 'ui/screens/chat_history_screen.dart';
import 'ui/screens/models/model_selection_screen.dart';
import 'ui/screens/settings/server_settings_screen.dart';
import 'ui/screens/settings/device_lookup_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/bluetooth/unified_scanner_screen.dart';
import 'ui/screens/bluetooth/unified_terminal_screen.dart';
import 'ui/screens/bluetooth/bluetooth_settings_screen.dart';
import 'ui/screens/bluetooth/bluetooth_controller_screen.dart';
import 'config/ui_config.dart';
import 'config/app_config.dart';
import 'services/preferences_service.dart';
import 'services/tts_service.dart';
import 'services/background_initializer.dart';
import 'services/permissions/permission_service.dart';
import 'services/permissions/permission_manager.dart';
import 'services/server/server_config_service.dart';
import 'services/device/device_info_service.dart';
import 'services/api/device_registration_api_service.dart';
import 'services/ble/ble_service.dart';
import 'services/heartbeat_service.dart';
import 'utils/app_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _themeMode = ThemeMode.light;
    // All heavy work (config loading, SharedPreferences) runs in background isolate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Run initialization in background isolate using compute
      final result = await BackgroundInitializer.initialize();
      
      if (!mounted) return;
      
      if (result.success && result.configJson != null) {
        // Parse and set AppConfig on main thread (lightweight operation)
        final configJson = jsonDecode(result.configJson!) as Map<String, dynamic>;
        AppConfig.initializeFromJson(configJson);
        
        // Initialize PreferencesService (already initialized in background)
        await PreferencesService.init();
        
        // Initialize permission service
        await PermissionService.instance.initialize();
        
        // Initialize server config service
        await ServerConfigService.instance.init();
        
        // Initialize TTS service
        await TtsService.instance.initialize();
        
        AppLogger.info('Requesting startup permissions...');
        
        // Request permissions with professional dialogs
        if (mounted) {
          await PermissionManager.instance.requestStartupPermissions(context);
          AppLogger.success('Permission request flow completed');
        }
        
        // Initialize device info service
        await DeviceInfoService.instance.initialize();
        
        // Initialize BLE service and restore existing connections
        AppLogger.info('Initializing BLE service...');
        await BleService.instance.initialize();
        AppLogger.success('BLE service initialized');
        
        // Register device with server
        if (mounted) {
          await _registerDevice();
        }
        
        // Start heartbeat service to maintain online status
        if (mounted) {
          AppLogger.info('Starting heartbeat service...');
          HeartbeatService.instance.start();
          AppLogger.success('Heartbeat service started');
        }
        
        if (mounted) {
          setState(() {
            _themeMode = result.isDarkMode ? ThemeMode.dark : ThemeMode.light;
            _isInitialized = true;
          });
        }
      } else {
        // Handle initialization error
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      AppLogger.error('Initialization error: $e');
      // Handle initialization error
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  /// Register device with server
  Future<void> _registerDevice() async {
    try {
      AppLogger.info('═══════════════════════════════════════════════════════');
      AppLogger.info('[DEVICE REGISTRATION] Getting device info...');
      
      final deviceInfo = await DeviceInfoService.instance.getDeviceInfo();
      
      AppLogger.info('[DEVICE REGISTRATION] Device Info:');
      AppLogger.info('  device_id: ${deviceInfo.deviceId}');
      AppLogger.info('  device_name: ${deviceInfo.deviceName}');
      AppLogger.info('  model_name: ${deviceInfo.modelName}');
      AppLogger.info('  mac_address: ${deviceInfo.macAddress ?? "NULL"}');
      
      // Check if MAC address is available
      if (deviceInfo.macAddress == null || deviceInfo.macAddress!.isEmpty) {
        AppLogger.error('⚠️ No MAC address available - device may not persist in registry');
        AppLogger.error('Device will use UUID fallback: ${deviceInfo.deviceId}');
      } else {
        AppLogger.success('✅ MAC address available: ${deviceInfo.macAddress}');
      }
      
      final registrationService = DeviceRegistrationApiService(
        baseUrl: ServerConfigService.instance.baseUrl,
      );
      
      // Try registration with retry logic
      bool success = false;
      int attempts = 0;
      const maxAttempts = 3;
      
      while (!success && attempts < maxAttempts) {
        attempts++;
        success = await registrationService.registerDevice(deviceInfo);
        
        if (!success && attempts < maxAttempts) {
          AppLogger.warning('Device registration attempt $attempts failed, retrying...');
          await Future.delayed(Duration(seconds: 2 * attempts)); // Exponential backoff
        }
      }
      
      if (success) {
        AppLogger.success('✓ Device registered: ${deviceInfo.deviceName}');
        if (deviceInfo.macAddress != null) {
          AppLogger.success('  └─ MAC: ${deviceInfo.macAddress}');
        }
      } else {
        AppLogger.error('✗ Device registration failed after $maxAttempts attempts');
        AppLogger.error('  └─ Device: ${deviceInfo.deviceName}');
        AppLogger.error('  └─ Server may be offline, or check DeviceInfoService.getMacAddress()');
        AppLogger.showToast('Device registration failed - check server connection', isError: true);
      }
    } catch (e) {
      AppLogger.error('Device registration error: $e');
      // Non-critical error - app can continue without registration
      // The heartbeat service will retry registration automatically
    }
  }

  void _changeTheme(bool useDarkMode) {
    setState(() {
      _themeMode = useDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
    PreferencesService.instance.setDarkMode(useDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: AppLogger.scaffoldMessengerKey,
      title: 'Audio Recorder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF1565C0),
          secondary: const Color(0xFF0D47A1),
          surface: const Color(0xFF0A1929),
          primaryContainer: const Color(0xFF1E3A5F),
          secondaryContainer: const Color(0xFF0D2844),
          surfaceContainerHighest: const Color(0xFF1E3A5F),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A1929),
        cardColor: const Color(0xFF1E3A5F),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: _isInitialized 
        ? const MainScreen() 
        : const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Default to Home
  int? _currentConversationId;
  final GlobalKey<ChatHistoryScreenState> _chatHistoryKey = GlobalKey<ChatHistoryScreenState>();
  final GlobalKey<State<UnifiedTerminalScreen>> _terminalKey = GlobalKey<State<UnifiedTerminalScreen>>();
  
  // Keep screen instances alive
  late final List<Widget> _screens;
  Widget? _aiAssistantScreen;

  @override
  void initState() {
    super.initState();
    _initializeScreens();
  }

  void _initializeScreens() {
    _aiAssistantScreen = AIAssistantScreen(
      key: ValueKey(_currentConversationId),
      conversationId: _currentConversationId,
      onCreateConversation: _onCreateConversation,
    );
    
    _screens = [
      HomeScreen(onNavigate: (index) {
        setState(() {
          _selectedIndex = index;
        });
      }),
      _aiAssistantScreen!, // AI Assistant (kept alive)
      ChatHistoryScreen(
        key: _chatHistoryKey,
        onChatSelected: _onChatSelected,
      ),
      const ModelSelectionScreen(),
      const ServerSettingsScreen(),
      const DeviceLookupScreen(),
      SettingsScreen(
        onThemeChanged: (useDarkMode) {
          final myAppState = context.findAncestorStateOfType<_MyAppState>();
          myAppState?._changeTheme(useDarkMode);
        },
      ),
      const UnifiedScannerScreen(),        // Index 7: Unified Bluetooth Scanner
      UnifiedTerminalScreen(key: _terminalKey),       // Index 8: Unified Bluetooth Terminal
      const BluetoothSettingsScreen(),     // Index 9: Bluetooth Settings
      const BluetoothControllerScreen(),   // Index 10: Bluetooth Controller
    ];
  }

  void _onDrawerItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.of(context).pop();
  }

  void _onChatSelected(int conversationId) {
    setState(() {
      _selectedIndex = 1; // Switch to AI Assistant
      _currentConversationId = conversationId;
      // Recreate AI Assistant screen with new conversation
      _aiAssistantScreen = AIAssistantScreen(
        key: ValueKey(conversationId),
        conversationId: conversationId,
        onCreateConversation: _onCreateConversation,
      );
      _screens[1] = _aiAssistantScreen!;
    });
    Navigator.of(context).pop();
  }

  void _onCreateConversation(String title) {
    _chatHistoryKey.currentState?.addConversation(title);
  }

  void _clearAllChats() {
    _chatHistoryKey.currentState?.clearAllChats();
  }

  void _createNewChat() {
    setState(() {
      _currentConversationId = null;
      // Create new AI Assistant screen for new chat
      _aiAssistantScreen = AIAssistantScreen(
        key: const ValueKey(null),
        conversationId: null,
        onCreateConversation: _onCreateConversation,
      );
      _screens[1] = _aiAssistantScreen!;
    });
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 1:
        return UIConfig.textAiAssistant;
      case 2:
        return UIConfig.textChatHistory;
      case 3:
        return UIConfig.textModelSelection;
      case 4:
        return 'Server Configuration';
      case 5:
        return 'Device Lookup';
      case 6:
        return 'App Settings';
      case 7:
        return 'Bluetooth Scanner';
      case 8:
        return 'Bluetooth Terminal';
      case 9:
        return 'Bluetooth Settings';
      case 10:
        return 'Bluetooth Controller';
      default:
        return UIConfig.textHome;
    }
  }

  List<Widget>? _buildAppBarActions() {
    switch (_selectedIndex) {
      case 1:
        return [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: _createNewChat,
              icon: const Icon(Icons.add, size: 18),
              label: Text(UIConfig.textNewChatButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ];
      case 2:
        return [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: UIConfig.textClearAllChats,
              onPressed: _clearAllChats,
            ),
          ),
        ];
      case 3:
        // Model Selection screen - No action button needed
        return null;
      case 4:
        // Server Settings screen - No action button needed
        return null;
      case 8:
        // Bluetooth Terminal screen - Refresh and Clear actions
        return [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh devices',
            onPressed: () {
              final terminalState = _terminalKey.currentState as dynamic;
              terminalState?.refreshDevices();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear messages',
            onPressed: () {
              final terminalState = _terminalKey.currentState as dynamic;
              terminalState?.clearMessages();
            },
          ),
        ];
      case 10:
        // Bluetooth Controller screen - Save action (pressable; implementation later)
        return [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement save behavior for Controller screen
              },
              icon: const Icon(UIConfig.iconSave, size: 18),
              label: const Text(UIConfig.textSave),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ];
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_getTitle()),
        actions: _buildAppBarActions(),
      ),
      drawer: Drawer(
        width: UIConfig.drawerWidth,
        child: ListView(
          primary: false,
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(UIConfig.iconApp, size: UIConfig.iconSizeLarge, color: UIConfig.colorWhite),
                  SizedBox(height: UIConfig.spacingSmall),
                  Text(
                    UIConfig.textVoiceAssistant,
                    style: UIConfig.textStyleHeader,
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(UIConfig.iconHome),
              title: Text(UIConfig.textHome),
              selected: _selectedIndex == 0,
              onTap: () => _onDrawerItemTapped(0),
            ),
            ExpansionTile(
              leading: Icon(UIConfig.iconAI),
              title: const Text('AI'),
              children: [
                ListTile(
                  dense: true,
                  visualDensity: UIConfig.drawerNestedDensity,
                  contentPadding: UIConfig.paddingDrawerNested,
                  title: Row(
                    children: [
                      Icon(UIConfig.iconAI, size: UIConfig.iconSizeSmall),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text(UIConfig.textAiAssistant, style: TextStyle(fontSize: UIConfig.fontSizeMedium)),
                    ],
                  ),
                  selected: _selectedIndex == 1,
                  onTap: () => _onDrawerItemTapped(1),
                ),
                ListTile(
                  dense: true,
                  visualDensity: UIConfig.drawerNestedDensity,
                  contentPadding: UIConfig.paddingDrawerNested,
                  title: Row(
                    children: [
                      Icon(UIConfig.iconChatHistory, size: UIConfig.iconSizeSmall),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text(UIConfig.textChatHistory, style: TextStyle(fontSize: UIConfig.fontSizeMedium)),
                    ],
                  ),
                  selected: _selectedIndex == 2,
                  onTap: () => _onDrawerItemTapped(2),
                ),
                ListTile(
                  dense: true,
                  visualDensity: UIConfig.drawerNestedDensity,
                  contentPadding: UIConfig.paddingDrawerNested,
                  title: Row(
                    children: [
                      Icon(UIConfig.iconModel, size: UIConfig.iconSizeSmall),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text(UIConfig.textModelSelection, style: TextStyle(fontSize: UIConfig.fontSizeMedium)),
                    ],
                  ),
                  selected: _selectedIndex == 3,
                  onTap: () => _onDrawerItemTapped(3),
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.bluetooth),
              title: const Text('Bluetooth'),
              subtitle: const Text('Classic + BLE devices', style: TextStyle(fontSize: 11)),
              children: [
                ListTile(
                  dense: true,
                  visualDensity: UIConfig.drawerNestedDensity,
                  contentPadding: UIConfig.paddingDrawerNested,
                  title: Row(
                    children: [
                      Icon(Icons.bluetooth_searching, size: UIConfig.iconSizeSmall),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text('Scanner', style: TextStyle(fontSize: UIConfig.fontSizeMedium)),
                    ],
                  ),
                  selected: _selectedIndex == 7,
                  onTap: () => _onDrawerItemTapped(7),
                ),
                ListTile(
                  dense: true,
                  visualDensity: UIConfig.drawerNestedDensity,
                  contentPadding: UIConfig.paddingDrawerNested,
                  title: Row(
                    children: [
                      Icon(Icons.terminal, size: UIConfig.iconSizeSmall),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text('Terminal', style: TextStyle(fontSize: UIConfig.fontSizeMedium)),
                    ],
                  ),
                  selected: _selectedIndex == 8,
                  onTap: () => _onDrawerItemTapped(8),
                ),
                ListTile(
                  dense: true,
                  visualDensity: UIConfig.drawerNestedDensity,
                  contentPadding: UIConfig.paddingDrawerNested,
                  title: Row(
                    children: [
                      Icon(Icons.settings, size: UIConfig.iconSizeSmall),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text('Settings', style: TextStyle(fontSize: UIConfig.fontSizeMedium)),
                    ],
                  ),
                  selected: _selectedIndex == 9,
                  onTap: () => _onDrawerItemTapped(9),
                ),
                ListTile(
                  dense: true,
                  visualDensity: UIConfig.drawerNestedDensity,
                  contentPadding: UIConfig.paddingDrawerNested,
                  title: Row(
                    children: [
                      Icon(Icons.gamepad, size: UIConfig.iconSizeSmall),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text('Controller', style: TextStyle(fontSize: UIConfig.fontSizeMedium)),
                    ],
                  ),
                  selected: _selectedIndex == 10,
                  onTap: () => _onDrawerItemTapped(10),
                ),
              ],
            ),
            ExpansionTile(
              leading: Icon(UIConfig.iconSettings),
              title: Text(UIConfig.textSettings),
              children: [
                ListTile(
                  dense: true,
                  visualDensity: UIConfig.drawerNestedDensity,
                  contentPadding: UIConfig.paddingDrawerNested,
                  title: Row(
                    children: [
                      Icon(Icons.dns, size: UIConfig.iconSizeSmall),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text('Server Configuration', style: TextStyle(fontSize: UIConfig.fontSizeMedium)),
                    ],
                  ),
                  selected: _selectedIndex == 4,
                  onTap: () => _onDrawerItemTapped(4),
                ),
                ListTile(
                  dense: true,
                  visualDensity: UIConfig.drawerNestedDensity,
                  contentPadding: UIConfig.paddingDrawerNested,
                  title: Row(
                    children: [
                      Icon(Icons.devices, size: UIConfig.iconSizeSmall),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text('Device Lookup', style: TextStyle(fontSize: UIConfig.fontSizeMedium)),
                    ],
                  ),
                  selected: _selectedIndex == 5,
                  onTap: () => _onDrawerItemTapped(5),
                ),
                ListTile(
                  dense: true,
                  visualDensity: UIConfig.drawerNestedDensity,
                  contentPadding: UIConfig.paddingDrawerNested,
                  title: Row(
                    children: [
                      Icon(Icons.tune, size: UIConfig.iconSizeSmall),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text('App Settings', style: TextStyle(fontSize: UIConfig.fontSizeMedium)),
                    ],
                  ),
                  selected: _selectedIndex == 6,
                  onTap: () => _onDrawerItemTapped(6),
                ),
              ],
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
    );
  }
}
