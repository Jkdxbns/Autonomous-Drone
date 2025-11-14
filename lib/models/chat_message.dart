/// Dummy ChatMessage model for UI display (no database logic)
class ChatMessage {
  final int? id;
  final int conversationId;
  final String role;
  final String content;
  final DateTime timestamp;
  final String? sttModel; // STT model used for transcription
  final String? lmModel;  // LM model used for generation

  ChatMessage({
    this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.sttModel,
    this.lmModel,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatMessage copyWith({
    int? id,
    int? conversationId,
    String? role,
    String? content,
    DateTime? timestamp,
    String? sttModel,
    String? lmModel,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sttModel: sttModel ?? this.sttModel,
      lmModel: lmModel ?? this.lmModel,
    );
  }

  // Database mapping
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      conversationId: map['conversation_id'] as int,
      role: map['role'] as String,
      content: map['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      sttModel: map['stt_model'] as String?,
      lmModel: map['lm_model'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'stt_model': sttModel,
      'lm_model': lmModel,
    };
  }
}