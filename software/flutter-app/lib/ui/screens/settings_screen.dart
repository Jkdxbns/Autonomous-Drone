import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/ui_config.dart';
import '../../services/preferences_service.dart';
import '../../services/tts_service.dart';
import '../../services/permissions/permission_manager.dart';
import '../../utils/app_logger.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  // late bool _allowCellularDownload; // Commented out - feature removed
  late bool _useDarkMode;
  late bool _ttsEnabled;
  late double _ttsSpeed;
  late double _ttsPitch;
  late double _ttsVolume;
  bool _micPermissionGranted = false;
  bool _loadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkPermissions();
  }

  void _loadPreferences() {
    final prefs = PreferencesService.instance;
    setState(() {
      // _allowCellularDownload = prefs.allowCellularDownload; // Commented out - feature removed
      _useDarkMode = prefs.isDarkMode;
      _ttsEnabled = prefs.ttsEnabled;
      _ttsSpeed = prefs.ttsSpeed;
      _ttsPitch = prefs.ttsPitch;
      _ttsVolume = prefs.ttsVolume;
    });
  }

  Future<void> _saveThemePreference() async {
    final prefs = PreferencesService.instance;
    await prefs.setDarkMode(_useDarkMode);
    widget.onThemeChanged(_useDarkMode);
  }
  
  Future<void> _checkPermissions() async {
    final micStatus = await Permission.microphone.status;
    setState(() {
      _micPermissionGranted = micStatus.isGranted;
      _loadingPermissions = false;
    });
  }
  
  Future<void> _requestPermissions() async {
    await PermissionManager.instance.requestPermissionsManually(context);
    // Recheck permissions after request
    await _checkPermissions();
  }
  
  Future<void> _resetPermissionDialogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Permission Dialogs'),
        content: const Text(
          'This will reset the permission dialog flags so you can see them again on next app restart. '
          'Current granted permissions will not be revoked.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await PermissionManager.instance.resetPermissionFlags();
      // ignore: use_build_context_synchronously
      AppLogger.success('Permission dialogs will show on next app launch');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        primary: false,
        children: [
          // Theme Settings
          _buildSectionHeader(UIConfig.textTheme),
          SwitchListTile(
            title: Text(UIConfig.textUseDarkMode),
            subtitle: Text(UIConfig.textEnableDarkTheme),
            value: _useDarkMode,
            onChanged: (value) {
              setState(() {
                _useDarkMode = value;
              });
              _saveThemePreference();
            },
          ),
          const Divider(),
          
          // Download Settings - COMMENTED OUT
          // _buildSectionHeader(UIConfig.textDownloadSettings),
          // SwitchListTile(
          //   title: Text(UIConfig.textAllowCellular),
          //   subtitle: Text(UIConfig.textDownloadOverMobile),
          //   value: _allowCellularDownload,
          //   onChanged: (value) {
          //     setState(() {
          //       _allowCellularDownload = value;
          //     });
          //   },
          // ),
          // const Divider(),

          // Permissions Section
          _buildSectionHeader('Permissions'),
          ListTile(
            leading: Icon(
              _micPermissionGranted ? Icons.check_circle : Icons.cancel,
              color: _micPermissionGranted ? Colors.green : Colors.red,
            ),
            title: const Text('Microphone Permission'),
            subtitle: Text(
              _loadingPermissions
                  ? 'Checking...'
                  : _micPermissionGranted
                      ? 'Granted - Voice recording enabled'
                      : 'Not granted - Required for voice recording',
            ),
            trailing: _micPermissionGranted
                ? null
                : ElevatedButton(
                    onPressed: _requestPermissions,
                    child: const Text('Grant'),
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Request Permissions Again'),
            subtitle: const Text('Show permission dialogs again'),
            onTap: _requestPermissions,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Reset Permission Dialogs'),
            subtitle: const Text('Allow dialogs to show on next app launch'),
            onTap: _resetPermissionDialogs,
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('App Settings'),
            subtitle: const Text('Open system app settings'),
            onTap: () async {
              await openAppSettings();
            },
          ),
          const Divider(),

          // TTS Settings
          _buildSectionHeader(UIConfig.textTtsSettings),
          SwitchListTile(
            title: const Text('Enable Text-to-Speech'),
            subtitle: const Text('Speak AI responses aloud'),
            value: _ttsEnabled,
            onChanged: (value) async {
              setState(() {
                _ttsEnabled = value;
              });
              await PreferencesService.instance.setTtsEnabled(value);
              if (!value) {
                // Stop any ongoing speech
                TtsService.instance.stop();
              }
            },
          ),
          ListTile(
            title: Text(UIConfig.textSpeechSpeed),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: ${_ttsSpeed.toStringAsFixed(2)}x',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Slider(
                  value: _ttsSpeed,
                  min: 0.1,
                  max: 2.0,
                  divisions: 19,
                  label: '${_ttsSpeed.toStringAsFixed(2)}x',
                  onChanged: (value) {
                    setState(() {
                      _ttsSpeed = value;
                    });
                  },
                  onChangeEnd: (value) async {
                    // Save to preferences when user finishes dragging slider
                    await TtsService.instance.updateSpeed(value);
                  },
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(UIConfig.textSpeechPitch),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: ${_ttsPitch.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Slider(
                  value: _ttsPitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: _ttsPitch.toStringAsFixed(2),
                  onChanged: (value) {
                    setState(() {
                      _ttsPitch = value;
                    });
                  },
                  onChangeEnd: (value) async {
                    // Save to preferences when user finishes dragging slider
                    await TtsService.instance.updatePitch(value);
                  },
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(UIConfig.textSpeechVolume),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: ${(_ttsVolume * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Slider(
                  value: _ttsVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(_ttsVolume * 100).toStringAsFixed(0)}%',
                  onChanged: (value) {
                    setState(() {
                      _ttsVolume = value;
                    });
                  },
                  onChangeEnd: (value) async {
                    // Save to preferences when user finishes dragging slider
                    await TtsService.instance.updateVolume(value);
                  },
                ),
              ],
            ),
          ),
          const Divider(),

          // App Info - COMMENTED OUT
          // _buildSectionHeader(UIConfig.textAbout),
          // ListTile(
          //   title: Text(UIConfig.textAppVersion),
          //   subtitle: Text(UIConfig.appVersion),
          // ),
          // ListTile(
          //   title: Text(UIConfig.textBuild),
          //   subtitle: Text(UIConfig.appBuild),
          // ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        UIConfig.spacingLarge, 
        UIConfig.spacingLarge * 1.5, 
        UIConfig.spacingLarge, 
        UIConfig.spacingSmall
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: UIConfig.fontSizeMedium,
          fontWeight: UIConfig.fontWeightBold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
