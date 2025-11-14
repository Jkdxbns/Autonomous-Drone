import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/conversation.dart';
import '../../models/chat_message.dart';
import '../../utils/app_logger.dart';
import '../bluetooth/bluetooth_settings_database.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static DatabaseHelper get instance => _instance;
  
  DatabaseHelper._internal();
  
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ai_assistant.db');
    
    AppLogger.info('Initializing database at: $path');
    
    return await openDatabase(
      path,
      version: 3, // Increment version for Bluetooth settings tables
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Create conversations table
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_modified INTEGER NOT NULL
      )
    ''');
    
    // Create messages table with model tracking
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        stt_model TEXT,
        lm_model TEXT,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
      )
    ''');
    
    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_messages_conversation_id ON messages (conversation_id)
    ''');
    
    // Create Bluetooth settings tables
    await BluetoothSettingsDatabase.createTables(db);
    await BluetoothSettingsDatabase.initializeGlobalSettings(db);
    
    AppLogger.success('Database tables created successfully');
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add model tracking columns to existing messages table
      await db.execute('ALTER TABLE messages ADD COLUMN stt_model TEXT');
      await db.execute('ALTER TABLE messages ADD COLUMN lm_model TEXT');
      AppLogger.info('Database upgraded to version 2: Added model tracking');
    }
    
    if (oldVersion < 3) {
      // Add Bluetooth settings tables
      await BluetoothSettingsDatabase.createTables(db);
      await BluetoothSettingsDatabase.initializeGlobalSettings(db);
      AppLogger.info('Database upgraded to version 3: Added Bluetooth settings tables');
    }
  }
  
  // ==================== CONVERSATIONS ====================
  
  Future<int> createConversation(Conversation conversation) async {
    final db = await database;
    final id = await db.insert('conversations', {
      'title': conversation.title,
      'created_at': conversation.createdAt.millisecondsSinceEpoch,
      'last_modified': conversation.lastModified.millisecondsSinceEpoch,
    });
    AppLogger.info('Created conversation with ID: $id');
    return id;
  }
  
  Future<Conversation?> getConversation(int id) async {
    final db = await database;
    final maps = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    
    return Conversation.fromMap(maps.first);
  }
  
  Future<List<Conversation>> getAllConversations() async {
    final db = await database;
    final maps = await db.query(
      'conversations',
      orderBy: 'last_modified DESC',
    );
    
    return maps.map((map) => Conversation.fromMap(map)).toList();
  }
  
  Future<void> updateConversation(Conversation conversation) async {
    final db = await database;
    await db.update(
      'conversations',
      {
        'title': conversation.title,
        'last_modified': conversation.lastModified.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [conversation.id],
    );
    AppLogger.info('Updated conversation ID: ${conversation.id}');
  }
  
  Future<void> deleteConversation(int id) async {
    final db = await database;
    await db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
    AppLogger.info('Deleted conversation ID: $id');
  }
  
  Future<void> deleteAllConversations() async {
    final db = await database;
    await db.delete('conversations');
    AppLogger.info('Deleted all conversations');
  }
  
  // ==================== MESSAGES ====================
  
  Future<int> createMessage(ChatMessage message) async {
    final db = await database;
    final id = await db.insert('messages', {
      'conversation_id': message.conversationId,
      'role': message.role,
      'content': message.content,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'stt_model': message.sttModel,
      'lm_model': message.lmModel,
    });
    
    // Note: Conversation last_modified now updated separately at end of conversation
    // This reduces database writes during streaming
    
    return id;
  }
  
  Future<List<ChatMessage>> getMessagesForConversation(int conversationId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );
    
    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }
  
  Future<void> deleteMessage(int id) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> deleteMessagesForConversation(int conversationId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }
  
  // ==================== UTILITY ====================
  
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('conversations');
    AppLogger.info('Cleared all database data');
  }
  
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
