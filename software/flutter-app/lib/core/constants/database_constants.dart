/// Database table and column name constants
class DatabaseConstants {
  DatabaseConstants._();

  // Table Names
  static const String chatHistoryTable = 'chat_history';
  static const String conversationsTable = 'conversations';
  static const String transcriptionsTable = 'transcriptions';
  static const String audioRecordingsTable = 'audio_recordings';
  static const String settingsTable = 'settings';
  static const String messagesTable = 'messages';

  // Conversation Columns
  static const String conversationId = 'id';
  static const String conversationTitle = 'title';
  static const String conversationCreatedAt = 'created_at';
  static const String conversationLastModified = 'last_modified';

  // Message Columns
  static const String messageId = 'id';
  static const String messageConversationId = 'conversation_id';
  static const String messageRole = 'role';
  static const String messageContent = 'content';
  static const String messageTimestamp = 'timestamp';
  static const String messageSttModel = 'stt_model';
  static const String messageLmModel = 'lm_model';

  // Chat History Columns (legacy)
  static const String chatId = 'id';
  static const String chatMessage = 'message';
  static const String chatRole = 'role';
  static const String chatTimestamp = 'timestamp';
  static const String chatSessionId = 'session_id';
  static const String chatModel = 'model';

  // Transcription Columns
  static const String transcriptionId = 'id';
  static const String transcriptionText = 'text';
  static const String transcriptionAudioPath = 'audio_path';
  static const String transcriptionDuration = 'duration';
  static const String transcriptionTimestamp = 'timestamp';
  static const String transcriptionLanguage = 'language';

  // Audio Recording Columns
  static const String audioId = 'id';
  static const String audioPath = 'path';
  static const String audioSize = 'size';
  static const String audioFormat = 'format';
  static const String audioTimestamp = 'timestamp';
  static const String audioTranscribed = 'transcribed';

  // Settings Columns
  static const String settingKey = 'key';
  static const String settingValue = 'value';

  // Role Values
  static const String roleUser = 'user';
  static const String roleAssistant = 'assistant';
  static const String roleSystem = 'system';
}
