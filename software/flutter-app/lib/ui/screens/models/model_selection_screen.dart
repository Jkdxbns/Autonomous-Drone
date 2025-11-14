import 'package:flutter/material.dart';
import '../../../services/api/server_api_service.dart';
import '../../../api/models/catalog_response.dart';
import '../../../services/server/server_config_service.dart';
import '../../../services/preferences_service.dart';
import '../../../utils/app_logger.dart';
import '../../../config/ui_config.dart';

/// Model selection screen - Server models only
/// Shows 2 dropdowns: STT models and LM models
/// Users can select and set defaults for each type
class ModelSelectionScreen extends StatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  State<ModelSelectionScreen> createState() => ModelSelectionScreenState();
}

class ModelSelectionScreenState extends State<ModelSelectionScreen> {
  // API service
  late ServerApiService _apiService;

  // Model lists
  List<ModelInfo> _sttModels = [];
  List<ModelInfo> _lmModels = [];

  // Selected models
  String? _selectedSttModel;
  String? _selectedLmModel;

  // Default models (from preferences)
  String _defaultSttModel = 'whisper-small';
  String _defaultLmModel = 'gemini-2.5-flash';

  // Loading state
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadDefaults();
    _loadCatalog();
  }

  void _initializeService() {
    final serverConfig = ServerConfigService.instance;
    _apiService = ServerApiService(baseUrl: serverConfig.baseUrl);

    // Listen to server config changes
    serverConfig.host.addListener(_onServerConfigChanged);
    serverConfig.port.addListener(_onServerConfigChanged);
  }

  void _onServerConfigChanged() {
    // Recreate API service with new URL
    final serverConfig = ServerConfigService.instance;
    _apiService = ServerApiService(baseUrl: serverConfig.baseUrl);
    
    // Reload catalog
    _loadCatalog();
  }

  Future<void> _loadDefaults() async {
    final prefs = PreferencesService.instance;
    setState(() {
      _defaultSttModel = prefs.defaultSttModel;
      _defaultLmModel = prefs.defaultLmModel;
      _selectedSttModel = _defaultSttModel;
      _selectedLmModel = _defaultLmModel;
    });
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final catalog = await _apiService.getCatalog();

      if (catalog == null) {
        setState(() {
          _errorMessage = UIConfig.errorServerUnavailable;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _sttModels = catalog.data.sttModels;
        _lmModels = catalog.data.lmModels;
        _isLoading = false;

        // Set selected to defaults if not already set
        _selectedSttModel ??= _defaultSttModel;
        _selectedLmModel ??= _defaultLmModel;
      });

      AppLogger.success('Models loaded: ${_sttModels.length} STT, ${_lmModels.length} LM');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load models: $e';
        _isLoading = false;
      });
      AppLogger.error('Failed to load catalog: $e');
    }
  }

  Future<void> _setDefaultSttModel() async {
    if (_selectedSttModel == null) return;

    try {
      await PreferencesService.instance.setDefaultSttModel(_selectedSttModel!);
      setState(() {
        _defaultSttModel = _selectedSttModel!;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Default STT model set to: $_selectedSttModel'),
            backgroundColor: UIConfig.colorSuccess,
          ),
        );
      }

      AppLogger.success('Default STT model: $_selectedSttModel');
    } catch (e) {
      AppLogger.error('Failed to save default STT model: $e');
    }
  }

  Future<void> _setDefaultLmModel() async {
    if (_selectedLmModel == null) return;

    try {
      await PreferencesService.instance.setDefaultLmModel(_selectedLmModel!);
      setState(() {
        _defaultLmModel = _selectedLmModel!;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Default LM model set to: $_selectedLmModel'),
            backgroundColor: UIConfig.colorSuccess,
          ),
        );
      }

      AppLogger.success('Default LM model: $_selectedLmModel');
    } catch (e) {
      AppLogger.error('Failed to save default LM model: $e');
    }
  }

  @override
  void dispose() {
    final serverConfig = ServerConfigService.instance;
    serverConfig.host.removeListener(_onServerConfigChanged);
    serverConfig.port.removeListener(_onServerConfigChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: UIConfig.iconSizeLarge,
            color: UIConfig.colorError,
          ),
          SizedBox(height: UIConfig.spacingLarge),
          Text(
            _errorMessage!,
            style: UIConfig.textStyleSubtitle.copyWith(
              color: UIConfig.colorError,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: UIConfig.spacingLarge),
          ElevatedButton.icon(
            onPressed: _loadCatalog,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadCatalog,
      child: ListView(
        primary: false,
        padding: UIConfig.paddingAllLarge,
        children: [
          // Header
          Text(
            UIConfig.textModelSelection,
            style: UIConfig.textStyleHeader,
          ),
          SizedBox(height: UIConfig.spacingSmall),
          Text(
            'Select default models for speech recognition and text generation',
            style: UIConfig.textStyleBody.copyWith(
              color: UIConfig.colorGrey600,
            ),
          ),
          SizedBox(height: UIConfig.spacingXLarge),

          // STT Models Section
          _buildSttModelSection(),

          SizedBox(height: UIConfig.spacingXLarge),

          // LM Models Section
          _buildLmModelSection(),
        ],
      ),
    );
  }

  Widget _buildSttModelSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: UIConfig.paddingAllLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mic,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: UIConfig.spacingSmall),
                Text(
                  'Speech-to-Text Models',
                  style: UIConfig.textStyleSubtitle.copyWith(
                    fontWeight: UIConfig.fontWeightBold,
                  ),
                ),
              ],
            ),
            SizedBox(height: UIConfig.spacingMedium),

            // Current default
            Container(
              padding: UIConfig.paddingAllMedium,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: UIConfig.radiusMedium,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    size: UIConfig.iconSizeSmall,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  SizedBox(width: UIConfig.spacingSmall),
                  Text(
                    'Current Default: $_defaultSttModel',
                    style: TextStyle(
                      fontSize: UIConfig.fontSizeMedium,
                      fontWeight: UIConfig.fontWeightMedium,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: UIConfig.spacingMedium),

            // Dropdown
            if (_sttModels.isEmpty)
              const Text('No STT models available')
            else
              DropdownButtonFormField<String>(
                isExpanded: true,  // Allow dropdown to expand to full width
                initialValue: _selectedSttModel,
                decoration: const InputDecoration(
                  labelText: 'Select STT Model',
                  border: OutlineInputBorder(),
                ),
                items: _sttModels.map((model) {
                  final isDefault = model.displayName == _defaultSttModel;
                  return DropdownMenuItem<String>(
                    value: model.displayName,
                    child: Text(
                      '${model.displayName}${isDefault ? ' (default)' : ''}',
                      overflow: TextOverflow.ellipsis,  // Handle long text
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSttModel = value;
                  });
                },
              ),

            SizedBox(height: UIConfig.spacingMedium),

            // Set Default Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedSttModel != null &&
                        _selectedSttModel != _defaultSttModel
                    ? _setDefaultSttModel
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Set as Default'),
                style: ElevatedButton.styleFrom(
                  padding: UIConfig.paddingAllMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLmModelSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: UIConfig.paddingAllLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: UIConfig.spacingSmall),
                Text(
                  'Language Models',
                  style: UIConfig.textStyleSubtitle.copyWith(
                    fontWeight: UIConfig.fontWeightBold,
                  ),
                ),
              ],
            ),
            SizedBox(height: UIConfig.spacingMedium),

            // Current default
            Container(
              padding: UIConfig.paddingAllMedium,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: UIConfig.radiusMedium,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    size: UIConfig.iconSizeSmall,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  SizedBox(width: UIConfig.spacingSmall),
                  Text(
                    'Current Default: $_defaultLmModel',
                    style: TextStyle(
                      fontSize: UIConfig.fontSizeMedium,
                      fontWeight: UIConfig.fontWeightMedium,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: UIConfig.spacingMedium),

            // Dropdown
            if (_lmModels.isEmpty)
              const Text('No LM models available')
            else
              DropdownButtonFormField<String>(
                isExpanded: true,  // Allow dropdown to expand to full width
                initialValue: _selectedLmModel,
                decoration: const InputDecoration(
                  labelText: 'Select Language Model',
                  border: OutlineInputBorder(),
                ),
                items: _lmModels.map((model) {
                  final isDefault = model.displayName == _defaultLmModel;
                  return DropdownMenuItem<String>(
                    value: model.displayName,
                    child: Text(
                      '${model.displayName}${isDefault ? ' (default)' : ''}',
                      overflow: TextOverflow.ellipsis,  // Handle long text
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLmModel = value;
                  });
                },
              ),

            SizedBox(height: UIConfig.spacingMedium),

            // Set Default Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedLmModel != null &&
                        _selectedLmModel != _defaultLmModel
                    ? _setDefaultLmModel
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Set as Default'),
                style: ElevatedButton.styleFrom(
                  padding: UIConfig.paddingAllMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
