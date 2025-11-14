// Unified API service exports
export 'health_api_service.dart';
export 'chat_api_service.dart';
export 'transcription_api_service.dart';
export 'assistant_api_service.dart';

import 'dart:async';
import 'health_api_service.dart';
import 'chat_api_service.dart';
import 'transcription_api_service.dart';
import 'assistant_api_service.dart';
import '../../api/models/server_event.dart';
import '../../api/models/catalog_response.dart';

/// Unified API service that combines all API operations
/// Provides a single interface for all server communication
class ServerApiService {
  final String baseUrl;
  
  late final HealthApiService _healthApi;
  late final ChatApiService _chatApi;
  late final TranscriptionApiService _transcriptionApi;
  late final AssistantApiService _assistantApi;

  ServerApiService({required this.baseUrl}) {
    _healthApi = HealthApiService(baseUrl: baseUrl);
    _chatApi = ChatApiService(baseUrl: baseUrl);
    _transcriptionApi = TranscriptionApiService(baseUrl: baseUrl);
    _assistantApi = AssistantApiService(baseUrl: baseUrl);
  }

  // Health & Catalog
  Future<bool> checkHealth() => _healthApi.checkHealth();
  Future<CatalogResponse?> getCatalog() => _healthApi.getCatalog();
  Future<String?> echo(String text) => _healthApi.echo(text);

  // Chat & Text Generation
  Stream<ServerEvent> processText({
    required String text,
    required String lmModel,
  }) => _chatApi.processText(text: text, lmModel: lmModel);

  Stream<ServerEvent> generate({
    required String prompt,
    String? model,
  }) => _chatApi.generate(prompt: prompt, model: model);

  // Audio & Transcription
  Future<String> transcribeAudio({
    required String audioFilePath,
    required String sttModel,
  }) => _transcriptionApi.transcribeAudio(
    audioFilePath: audioFilePath,
    sttModel: sttModel,
  );

  Stream<ServerEvent> processAudio({
    required String audioFilePath,
    required String sttModel,
    required String lmModel,
  }) => _transcriptionApi.processAudio(
    audioFilePath: audioFilePath,
    sttModel: sttModel,
    lmModel: lmModel,
  );

  // Assistant API (Two-pass pipeline)
  Future<AssistantApiResult> handleAssistantRequest({
    required String userQuery,
    String? lmModel,
  }) => _assistantApi.handleRequest(
    userQuery: userQuery,
    lmModel: lmModel,
  );
}
