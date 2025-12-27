/// Represents AI model metadata (LLM or STT)
class ModelInfo {
  // Common fields
  final String name;
  final String displayName;
  final String provider;
  final String description;
  final bool enabled;
  final String modelType; // 'llm' or 'stt'
  
  // LLM-specific fields
  final int? contextWindow;
  final bool? supportsStreaming;
  final double? costPer1kTokens;
  final int? maxOutputTokens;
  final double? defaultTemperature;
  
  // STT-specific fields
  final String? sttModelType; // 'api' or 'local'
  final String? apiKeyEnv;
  final String? modelPath;
  final List<String>? supportedLanguages;
  final int? maxAudioLength;
  final double? costPerMinute;
  
  // Legacy fields (for backward compatibility)
  final String? modelSize;
  final int? totalSize;
  final double? totalSizeMb;
  final bool? downloaded;

  ModelInfo({
    required this.name,
    required this.displayName,
    required this.provider,
    this.description = '',
    this.enabled = false,
    this.modelType = 'stt',
    // LLM fields
    this.contextWindow,
    this.supportsStreaming,
    this.costPer1kTokens,
    this.maxOutputTokens,
    this.defaultTemperature,
    // STT fields
    this.sttModelType,
    this.apiKeyEnv,
    this.modelPath,
    this.supportedLanguages,
    this.maxAudioLength,
    this.costPerMinute,
    // Legacy fields
    this.modelSize,
    this.totalSize,
    this.totalSizeMb,
    this.downloaded,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    // Detect model type from JSON structure
    final hasContextWindow = json.containsKey('context_window');
    
    String modelType = 'stt';
    if (hasContextWindow) {
      modelType = 'llm';
    }
    
    return ModelInfo(
      name: json['name'] as String? ?? json['model_name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['name'] as String? ?? '',
      provider: json['provider'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      modelType: modelType,
      // LLM fields
      contextWindow: json['context_window'] as int?,
      supportsStreaming: json['supports_streaming'] as bool?,
      costPer1kTokens: (json['cost_per_1k_tokens'] as num?)?.toDouble(),
      maxOutputTokens: json['max_output_tokens'] as int?,
      defaultTemperature: (json['default_temperature'] as num?)?.toDouble(),
      // STT fields
      sttModelType: json['model_type'] as String?,
      apiKeyEnv: json['api_key_env'] as String?,
      modelPath: json['model_path'] as String?,
      supportedLanguages: (json['supported_languages'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      maxAudioLength: json['max_audio_length'] as int?,
      costPerMinute: (json['cost_per_minute'] as num?)?.toDouble(),
      // Legacy fields
      modelSize: json['model_size'] as String?,
      totalSize: json['total_size'] as int?,
      totalSizeMb: (json['total_size_mb'] as num?)?.toDouble(),
      downloaded: json['downloaded'] as bool? ?? json['is_downloaded'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'name': name,
      'display_name': displayName,
      'provider': provider,
      'description': description,
      'enabled': enabled,
      'model_type': modelType,
    };
    
    // Add LLM fields if present
    if (contextWindow != null) map['context_window'] = contextWindow;
    if (supportsStreaming != null) map['supports_streaming'] = supportsStreaming;
    if (costPer1kTokens != null) map['cost_per_1k_tokens'] = costPer1kTokens;
    if (maxOutputTokens != null) map['max_output_tokens'] = maxOutputTokens;
    if (defaultTemperature != null) map['default_temperature'] = defaultTemperature;
    
    // Add STT fields if present
    if (sttModelType != null) map['stt_model_type'] = sttModelType;
    if (apiKeyEnv != null) map['api_key_env'] = apiKeyEnv;
    if (modelPath != null) map['model_path'] = modelPath;
    if (supportedLanguages != null) map['supported_languages'] = supportedLanguages;
    if (maxAudioLength != null) map['max_audio_length'] = maxAudioLength;
    if (costPerMinute != null) map['cost_per_minute'] = costPerMinute;
    
    // Add legacy fields if present
    if (modelSize != null) map['model_size'] = modelSize;
    if (totalSize != null) map['total_size'] = totalSize;
    if (totalSizeMb != null) map['total_size_mb'] = totalSizeMb;
    if (downloaded != null) map['downloaded'] = downloaded;
    
    return map;
  }

  ModelInfo copyWith({
    bool? enabled,
    bool? downloaded,
    String? description,
  }) {
    return ModelInfo(
      name: name,
      displayName: displayName,
      provider: provider,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      modelType: modelType,
      contextWindow: contextWindow,
      supportsStreaming: supportsStreaming,
      costPer1kTokens: costPer1kTokens,
      maxOutputTokens: maxOutputTokens,
      defaultTemperature: defaultTemperature,
      sttModelType: sttModelType,
      apiKeyEnv: apiKeyEnv,
      modelPath: modelPath,
      supportedLanguages: supportedLanguages,
      maxAudioLength: maxAudioLength,
      costPerMinute: costPerMinute,
      modelSize: modelSize,
      totalSize: totalSize,
      totalSizeMb: totalSizeMb,
      downloaded: downloaded ?? this.downloaded,
    );
  }
  
  // Helper getters
  bool get isLLM => modelType == 'llm';
  bool get isSTT => modelType == 'stt';
  bool get isLocalModel => sttModelType == 'local';
  bool get isAPIModel => sttModelType == 'api';
  bool get isFree => (costPer1kTokens ?? costPerMinute ?? 0.0) == 0.0;
  
  String get costDisplay {
    if (isLLM && costPer1kTokens != null) {
      return '\$${costPer1kTokens!.toStringAsFixed(4)}/1K tokens';
    } else if (isSTT && costPerMinute != null) {
      if (costPerMinute == 0.0) return 'Free';
      return '\$${costPerMinute!.toStringAsFixed(3)}/min';
    }
    return 'Free';
  }
}

class ModelFile {
  final String name;
  final int size;
  final double sizeMb;

  ModelFile({
    required this.name,
    required this.size,
    required this.sizeMb,
  });

  factory ModelFile.fromJson(Map<String, dynamic> json) {
    return ModelFile(
      name: json['name'] as String,
      size: json['size'] as int? ?? 0,
      sizeMb: (json['size_mb'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'size': size,
      'size_mb': sizeMb,
    };
  }
}

