/// Response model for /catalog endpoint
class CatalogResponse {
  final String status;
  final CatalogData data;

  CatalogResponse({
    required this.status,
    required this.data,
  });

  factory CatalogResponse.fromJson(Map<String, dynamic> json) {
    return CatalogResponse(
      status: json['status'] as String,
      data: CatalogData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }
}

class CatalogData {
  final List<ModelInfo> sttModels;
  final List<ModelInfo> lmModels;

  CatalogData({
    required this.sttModels,
    required this.lmModels,
  });

  factory CatalogData.fromJson(Map<String, dynamic> json) {
    return CatalogData(
      sttModels: (json['stt_models'] as List<dynamic>?)
          ?.map((m) => ModelInfo.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      lmModels: (json['lm_models'] as List<dynamic>?)
          ?.map((m) => ModelInfo.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class ModelInfo {
  final String displayName;
  final bool enabled;
  final String type; // 'stt' or 'lm'

  ModelInfo({
    required this.displayName,
    required this.enabled,
    required this.type,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      displayName: json['display_name'] as String,
      enabled: json['enabled'] as bool? ?? true,
      type: json['type'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'enabled': enabled,
      'type': type,
    };
  }

  @override
  String toString() => 'ModelInfo(displayName: $displayName, type: $type)';
}
