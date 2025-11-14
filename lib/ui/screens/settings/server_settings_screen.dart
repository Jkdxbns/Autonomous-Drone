import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api/server_api_service.dart';
import '../../../services/server/server_config_service.dart';
import '../../../utils/app_logger.dart';
import '../../../config/ui_config.dart';

/// Server settings screen
/// Allows users to configure server host and port
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  
  bool _isTesting = false;
  bool? _connectionStatus; // null = not tested, true = success, false = failed
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final config = ServerConfigService.instance;
    _hostController.text = config.host.value;
    _portController.text = config.port.value.toString();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _connectionStatus = null;
      _statusMessage = 'Testing connection...';
    });

    try {
      final host = _hostController.text.trim();
      final port = int.tryParse(_portController.text.trim());

      if (host.isEmpty) {
        setState(() {
          _isTesting = false;
          _connectionStatus = false;
          _statusMessage = 'Host cannot be empty';
        });
        return;
      }

      if (port == null || port <= 0 || port > 65535) {
        setState(() {
          _isTesting = false;
          _connectionStatus = false;
          _statusMessage = 'Invalid port number (1-65535)';
        });
        return;
      }

      final testUrl = 'http://$host:$port';
      final apiService = ServerApiService(baseUrl: testUrl);
      
      final isHealthy = await apiService.checkHealth();

      setState(() {
        _isTesting = false;
        _connectionStatus = isHealthy;
        _statusMessage = isHealthy
            ? 'Connection successful!'
            : 'Server is reachable but not healthy';
      });

      AppLogger.info('Connection test: ${_connectionStatus! ? 'SUCCESS' : 'FAILED'}');
    } catch (e) {
      setState(() {
        _isTesting = false;
        _connectionStatus = false;
        _statusMessage = 'Connection failed: ${e.toString()}';
      });
      AppLogger.error('Connection test error: $e');
    }
  }

  Future<void> _saveConfiguration() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (host.isEmpty) {
      _showSnackBar('Host cannot be empty', UIConfig.colorError);
      return;
    }

    if (port == null || port <= 0 || port > 65535) {
      _showSnackBar('Invalid port number', UIConfig.colorError);
      return;
    }

    final success = await ServerConfigService.instance.updateServer(host, port);

    if (success) {
      _showSnackBar('Server configuration saved', UIConfig.colorSuccess);
      AppLogger.success('Server config updated: $host:$port');
    } else {
      _showSnackBar('Failed to save configuration', UIConfig.colorError);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will reset the server configuration to default values:\n\n'
          'Host: 192.168.0.168\n'
          'Port: 5000',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ServerConfigService.instance.resetToDefaults();
      _loadCurrentConfig();
      _showSnackBar('Reset to default configuration', UIConfig.colorInfo);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        primary: false,
        padding: UIConfig.paddingAllLarge,
        children: [
          // Header
          Text(
            'Server Settings',
            style: UIConfig.textStyleHeader,
          ),
          SizedBox(height: UIConfig.spacingSmall),
          Text(
            'Configure the Flask server connection',
            style: UIConfig.textStyleBody.copyWith(
              color: UIConfig.colorGrey600,
            ),
          ),
          SizedBox(height: UIConfig.spacingXLarge),

          // Configuration Card
          Card(
            elevation: 2,
            child: Padding(
              padding: UIConfig.paddingAllLarge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Host field
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Server Host',
                      hintText: 'e.g., 192.168.0.168 or localhost',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  SizedBox(height: UIConfig.spacingLarge),

                  // Port field
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Server Port',
                      hintText: 'e.g., 5000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.network_check),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  SizedBox(height: UIConfig.spacingLarge),

                  // Current URL display
                  Container(
                    padding: UIConfig.paddingAllMedium,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: UIConfig.radiusMedium,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.link,
                          size: UIConfig.iconSizeSmall,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: UIConfig.spacingSmall),
                        Expanded(
                          child: Text(
                            'http://${_hostController.text.isEmpty ? "host" : _hostController.text}'
                            ':${_portController.text.isEmpty ? "port" : _portController.text}',
                            style: TextStyle(
                              fontSize: UIConfig.fontSizeSmall,
                              fontFamily: 'monospace',
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: UIConfig.spacingLarge),

                  // Test Connection Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? SizedBox(
                              width: UIConfig.iconSizeSmall,
                              height: UIConfig.iconSizeSmall,
                              child: const CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_ping),
                      label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                      style: ElevatedButton.styleFrom(
                        padding: UIConfig.paddingAllMedium,
                      ),
                    ),
                  ),

                  // Connection status
                  if (_statusMessage != null) ...[
                    SizedBox(height: UIConfig.spacingMedium),
                    Container(
                      padding: UIConfig.paddingAllMedium,
                      decoration: BoxDecoration(
                        color: _connectionStatus == null
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : _connectionStatus!
                                ? UIConfig.colorSuccess.withValues(alpha: 0.1)
                                : UIConfig.colorError.withValues(alpha: 0.1),
                        borderRadius: UIConfig.radiusMedium,
                        border: Border.all(
                          color: _connectionStatus == null
                              ? Theme.of(context).colorScheme.outline
                              : _connectionStatus!
                                  ? UIConfig.colorSuccess
                                  : UIConfig.colorError,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _connectionStatus == null
                                ? Icons.info_outline
                                : _connectionStatus!
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                            color: _connectionStatus == null
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : _connectionStatus!
                                    ? UIConfig.colorSuccess
                                    : UIConfig.colorError,
                          ),
                          SizedBox(width: UIConfig.spacingSmall),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: TextStyle(
                                color: _connectionStatus == null
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : _connectionStatus!
                                        ? UIConfig.colorSuccess
                                        : UIConfig.colorError,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: UIConfig.spacingLarge),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset'),
                  style: OutlinedButton.styleFrom(
                    padding: UIConfig.paddingAllMedium,
                  ),
                ),
              ),
              SizedBox(width: UIConfig.spacingMedium),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _saveConfiguration,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Configuration'),
                  style: ElevatedButton.styleFrom(
                    padding: UIConfig.paddingAllMedium,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: UIConfig.spacingXLarge),

          // Info section
          Card(
            child: Padding(
              padding: UIConfig.paddingAllLarge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: UIConfig.spacingSmall),
                      Text(
                        'Connection Tips',
                        style: UIConfig.textStyleSubtitle.copyWith(
                          fontWeight: UIConfig.fontWeightBold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: UIConfig.spacingMedium),
                  Text(
                    '• Make sure your Flask server is running\n'
                    '• Use localhost or 127.0.0.1 if server is on the same device\n'
                    '• Use your computer\'s local IP (e.g., 192.168.x.x) for same network\n'
                    '• Default Flask port is 5000\n'
                    '• Test connection before saving',
                    style: UIConfig.textStyleBody.copyWith(
                      color: UIConfig.colorGrey600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
