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
import 'constants/constants.dart';
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
      // ALWAYS initialize PreferencesService first (critical for app settings)
      // This must happen before anything else that might use preferences
      final prefsInitialized = await PreferencesService.init();
      if (!prefsInitialized) {
        AppLogger.error('Failed to initialize PreferencesService');
      }

      // Run config loading in background isolate using compute
      final result = await BackgroundInitializer.initialize();

      if (!mounted) return;

      if (result.success && result.configJson != null) {
        // Parse and set AppConfig on main thread (lightweight operation)
        final configJson =
            jsonDecode(result.configJson!) as Map<String, dynamic>;
        AppConfig.initializeFromJson(configJson);

        // Reload preferences to pick up any config-based defaults
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
          // Get theme from PreferencesService (now properly initialized on main thread)
          final isDarkMode = PreferencesService.instance.isDarkMode;
          setState(() {
            _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
            _isInitialized = true;
          });
        }
      } else {
        // Handle initialization error - preferences already initialized above
        AppLogger.warning('Background initialization failed, using defaults');

        // Still initialize server config to load saved host/port
        await ServerConfigService.instance.init();

        if (mounted) {
          final isDarkMode = PreferencesService.instance.isDarkMode;
          setState(() {
            _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      AppLogger.error('Initialization error: $e');
      // Handle initialization error - preferences should still work
      // Still try to initialize server config
      try {
        await ServerConfigService.instance.init();
      } catch (_) {
        // Ignore - will use defaults
      }

      if (mounted) {
        final isDarkMode = PreferencesService.isInitialized
            ? PreferencesService.instance.isDarkMode
            : false;
        setState(() {
          _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
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
        AppLogger.error(
          'No MAC address available - device may not persist in registry',
        );
        AppLogger.error(
          'Device will use UUID fallback: ${deviceInfo.deviceId}',
        );
      } else {
        AppLogger.success('MAC address available: ${deviceInfo.macAddress}');
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
          AppLogger.warning(
            'Device registration attempt $attempts failed, retrying...',
          );
          await Future.delayed(
            Duration(seconds: 2 * attempts),
          ); // Exponential backoff
        }
      }

      if (success) {
        AppLogger.success('✓ Device registered: ${deviceInfo.deviceName}');
        if (deviceInfo.macAddress != null) {
          AppLogger.success('  └─ MAC: ${deviceInfo.macAddress}');
        }
      } else {
        AppLogger.error(
          '✗ Device registration failed after $maxAttempts attempts',
        );
        AppLogger.error('  └─ Device: ${deviceInfo.deviceName}');
        AppLogger.error(
          '  └─ Server may be offline, or check DeviceInfoService.getMacAddress()',
        );
        AppLogger.showToast(
          'Device registration failed - check server connection',
          isError: true,
        );
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
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: _isInitialized
          ? const MainScreen()
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
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
  final GlobalKey<ChatHistoryScreenState> _chatHistoryKey =
      GlobalKey<ChatHistoryScreenState>();
  final GlobalKey<State<UnifiedTerminalScreen>> _terminalKey =
      GlobalKey<State<UnifiedTerminalScreen>>();
  final GlobalKey<State<DeviceLookupScreen>> _deviceLookupKey =
      GlobalKey<State<DeviceLookupScreen>>();
  final GlobalKey<BluetoothControllerScreenState> _controllerKey =
      GlobalKey<BluetoothControllerScreenState>();

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
      HomeScreen(
        onNavigate: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      _aiAssistantScreen!, // AI Assistant (kept alive)
      ChatHistoryScreen(key: _chatHistoryKey, onChatSelected: _onChatSelected),
      const ModelSelectionScreen(),
      const ServerSettingsScreen(),
      DeviceLookupScreen(key: _deviceLookupKey),
      SettingsScreen(
        onThemeChanged: (useDarkMode) {
          final myAppState = context.findAncestorStateOfType<_MyAppState>();
          myAppState?._changeTheme(useDarkMode);
        },
      ),
      const UnifiedScannerScreen(), // Index 7: Unified Bluetooth Scanner
      UnifiedTerminalScreen(
        key: _terminalKey,
      ), // Index 8: Unified Bluetooth Terminal
      const BluetoothSettingsScreen(), // Index 9: Bluetooth Settings
      BluetoothControllerScreen(
        key: _controllerKey,
      ), // Index 10: Bluetooth Controller
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
    // Only pop if the drawer is open (check if we can pop safely)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
        return AppStrings.navAiAssistant;
      case 2:
        return AppStrings.navChatHistory;
      case 3:
        return AppStrings.navModelSelection;
      case 4:
        return AppStrings.navServerConfig;
      case 5:
        return AppStrings.navDeviceLookup;
      case 6:
        return AppStrings.navAppSettings;
      case 7:
        return AppStrings.navScanner;
      case 8:
        return AppStrings.navTerminal;
      case 9:
        return 'Bluetooth Settings';
      case 10:
        return AppStrings.navController;
      default:
        return AppStrings.navHome;
    }
  }

  List<Widget>? _buildAppBarActions() {
    switch (_selectedIndex) {
      case 1:
        return [
          Padding(
            padding: EdgeInsets.only(right: Spacing.small),
            child: ElevatedButton.icon(
              onPressed: _createNewChat,
              icon: Icon(AppIcons.add, size: IconSize.small),
              label: Text(AppStrings.actionNewChat),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.large,
                  vertical: Spacing.medium,
                ),
              ),
            ),
          ),
        ];
      case 2:
        return [
          Padding(
            padding: EdgeInsets.only(right: Spacing.small),
            child: IconButton(
              icon: Icon(AppIcons.deleteSweep),
              tooltip: AppStrings.actionClearAll,
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
      case 5:
        // Device Lookup screen - Refresh action
        return [
          IconButton(
            icon: Icon(AppIcons.refresh),
            tooltip: AppStrings.actionRefresh,
            onPressed: () {
              final deviceLookupState =
                  _deviceLookupKey.currentState as dynamic;
              deviceLookupState?.loadDevices();
            },
          ),
        ];
      case 8:
        // Bluetooth Terminal screen - Refresh and Clear actions
        return [
          IconButton(
            icon: Icon(AppIcons.refresh),
            tooltip: 'Refresh devices',
            onPressed: () {
              final terminalState = _terminalKey.currentState as dynamic;
              terminalState?.refreshDevices();
            },
          ),
          IconButton(
            icon: Icon(AppIcons.deleteSweep),
            tooltip: 'Clear messages',
            onPressed: () {
              final terminalState = _terminalKey.currentState as dynamic;
              terminalState?.clearMessages();
            },
          ),
        ];
      case 10:
        // Bluetooth Controller screen - Load and Save As actions
        return [
          // Load button
          Padding(
            padding: EdgeInsets.only(right: Spacing.small),
            child: ElevatedButton.icon(
              onPressed: () {
                _controllerKey.currentState?.showLoadDialog();
              },
              icon: Icon(Icons.folder_open, size: IconSize.small),
              label: const Text('Load'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onSecondaryContainer,
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.medium,
                  vertical: Spacing.medium,
                ),
              ),
            ),
          ),
          // Save As button
          Padding(
            padding: EdgeInsets.only(right: Spacing.small),
            child: ElevatedButton.icon(
              onPressed: () {
                _controllerKey.currentState?.showSaveAsDialog();
              },
              icon: Icon(AppIcons.save, size: IconSize.small),
              label: const Text('Save As'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.medium,
                  vertical: Spacing.medium,
                ),
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
        toolbarHeight: context.dimensions.appBarHeight,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(_getTitle()),
        actions: _buildAppBarActions(),
      ),
      drawer: Drawer(
        width: context.dimensions.drawerWidth,
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
                  Icon(
                    AppIcons.app,
                    size: IconSize.xxlarge,
                    color: AppColors.white,
                  ),
                  SizedBox(height: Spacing.small),
                  Text(
                    AppStrings.aiTitle,
                    style: AppTextStyle.headingLarge.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(AppIcons.home),
              title: Text(AppStrings.navHome),
              selected: _selectedIndex == 0,
              onTap: () => _onDrawerItemTapped(0),
            ),
            ExpansionTile(
              leading: Icon(AppIcons.ai),
              title: const Text('AI'),
              children: [
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: EdgeInsets.only(
                    left: Spacing.xxxlarge,
                    right: Spacing.large,
                  ),
                  title: Row(
                    children: [
                      Icon(AppIcons.ai, size: IconSize.small),
                      SizedBox(width: Spacing.small),
                      Text(
                        AppStrings.navAiAssistant,
                        style: TextStyle(fontSize: FontSize.medium),
                      ),
                    ],
                  ),
                  selected: _selectedIndex == 1,
                  onTap: () => _onDrawerItemTapped(1),
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: EdgeInsets.only(
                    left: Spacing.xxxlarge,
                    right: Spacing.large,
                  ),
                  title: Row(
                    children: [
                      Icon(AppIcons.history, size: IconSize.small),
                      SizedBox(width: Spacing.small),
                      Text(
                        AppStrings.navChatHistory,
                        style: TextStyle(fontSize: FontSize.medium),
                      ),
                    ],
                  ),
                  selected: _selectedIndex == 2,
                  onTap: () => _onDrawerItemTapped(2),
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: EdgeInsets.only(
                    left: Spacing.xxxlarge,
                    right: Spacing.large,
                  ),
                  title: Row(
                    children: [
                      Icon(AppIcons.model, size: IconSize.small),
                      SizedBox(width: Spacing.small),
                      Text(
                        AppStrings.navModelSelection,
                        style: TextStyle(fontSize: FontSize.medium),
                      ),
                    ],
                  ),
                  selected: _selectedIndex == 3,
                  onTap: () => _onDrawerItemTapped(3),
                ),
              ],
            ),
            ExpansionTile(
              leading: Icon(AppIcons.bluetooth),
              title: const Text('Bluetooth'),
              subtitle: Text(
                AppStrings.bluetoothClassicPlusBle,
                style: TextStyle(fontSize: FontSize.xsmall),
              ),
              children: [
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: EdgeInsets.only(
                    left: Spacing.xxxlarge,
                    right: Spacing.large,
                  ),
                  title: Row(
                    children: [
                      Icon(AppIcons.bluetoothSearching, size: IconSize.small),
                      SizedBox(width: Spacing.small),
                      Text(
                        AppStrings.navScanner,
                        style: TextStyle(fontSize: FontSize.medium),
                      ),
                    ],
                  ),
                  selected: _selectedIndex == 7,
                  onTap: () => _onDrawerItemTapped(7),
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: EdgeInsets.only(
                    left: Spacing.xxxlarge,
                    right: Spacing.large,
                  ),
                  title: Row(
                    children: [
                      Icon(AppIcons.terminal, size: IconSize.small),
                      SizedBox(width: Spacing.small),
                      Text(
                        AppStrings.navTerminal,
                        style: TextStyle(fontSize: FontSize.medium),
                      ),
                    ],
                  ),
                  selected: _selectedIndex == 8,
                  onTap: () => _onDrawerItemTapped(8),
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: EdgeInsets.only(
                    left: Spacing.xxxlarge,
                    right: Spacing.large,
                  ),
                  title: Row(
                    children: [
                      Icon(AppIcons.settings, size: IconSize.small),
                      SizedBox(width: Spacing.small),
                      Text(
                        AppStrings.navSettings,
                        style: TextStyle(fontSize: FontSize.medium),
                      ),
                    ],
                  ),
                  selected: _selectedIndex == 9,
                  onTap: () => _onDrawerItemTapped(9),
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: EdgeInsets.only(
                    left: Spacing.xxxlarge,
                    right: Spacing.large,
                  ),
                  title: Row(
                    children: [
                      Icon(Icons.gamepad, size: IconSize.small),
                      SizedBox(width: Spacing.small),
                      Text(
                        AppStrings.navController,
                        style: TextStyle(fontSize: FontSize.medium),
                      ),
                    ],
                  ),
                  selected: _selectedIndex == 10,
                  onTap: () => _onDrawerItemTapped(10),
                ),
              ],
            ),
            ExpansionTile(
              leading: Icon(AppIcons.settings),
              title: Text(AppStrings.navSettings),
              children: [
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: EdgeInsets.only(
                    left: Spacing.xxxlarge,
                    right: Spacing.large,
                  ),
                  title: Row(
                    children: [
                      Icon(AppIcons.server, size: IconSize.small),
                      SizedBox(width: Spacing.small),
                      Text(
                        AppStrings.navServerConfig,
                        style: TextStyle(fontSize: FontSize.medium),
                      ),
                    ],
                  ),
                  selected: _selectedIndex == 4,
                  onTap: () => _onDrawerItemTapped(4),
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: EdgeInsets.only(
                    left: Spacing.xxxlarge,
                    right: Spacing.large,
                  ),
                  title: Row(
                    children: [
                      Icon(AppIcons.device, size: IconSize.small),
                      SizedBox(width: Spacing.small),
                      Text(
                        AppStrings.navDeviceLookup,
                        style: TextStyle(fontSize: FontSize.medium),
                      ),
                    ],
                  ),
                  selected: _selectedIndex == 5,
                  onTap: () => _onDrawerItemTapped(5),
                ),
                ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -1),
                  contentPadding: EdgeInsets.only(
                    left: Spacing.xxxlarge,
                    right: Spacing.large,
                  ),
                  title: Row(
                    children: [
                      Icon(AppIcons.tune, size: IconSize.small),
                      SizedBox(width: Spacing.small),
                      Text(
                        AppStrings.navAppSettings,
                        style: TextStyle(fontSize: FontSize.medium),
                      ),
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
      body: IndexedStack(index: _selectedIndex, children: _screens),
    );
  }
}
