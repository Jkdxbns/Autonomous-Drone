import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/ble_device_config.dart';
import '../../utils/app_logger.dart';

class BleDatabaseHelper {
  static final BleDatabaseHelper instance = BleDatabaseHelper._init();
  static Database? _database;

  BleDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ble_devices.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    AppLogger.info('Initializing BLE database at: $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    AppLogger.info('Creating BLE database tables');

    // Table for BLE device configurations
    await db.execute('''
      CREATE TABLE ble_devices (
        device_id TEXT PRIMARY KEY,
        device_name TEXT,
        custom_alias TEXT,
        auto_reconnect INTEGER DEFAULT 0,
        connection_timeout INTEGER DEFAULT 10,
        mtu INTEGER DEFAULT 512,
        service_uuid TEXT,
        rx_characteristic_uuid TEXT,
        tx_characteristic_uuid TEXT,
        created_at TEXT NOT NULL,
        last_connected_at TEXT,
        rssi INTEGER DEFAULT 0
      )
    ''');

    // Table for connection history
    await db.execute('''
      CREATE TABLE ble_connection_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        connected_at TEXT NOT NULL,
        disconnected_at TEXT,
        duration_seconds INTEGER,
        bytes_sent INTEGER DEFAULT 0,
        bytes_received INTEGER DEFAULT 0,
        disconnect_reason TEXT,
        FOREIGN KEY (device_id) REFERENCES ble_devices (device_id)
      )
    ''');

    // Table for message queue (for auto-reconnect scenarios)
    await db.execute('''
      CREATE TABLE ble_message_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        message_data BLOB NOT NULL,
        created_at TEXT NOT NULL,
        sent INTEGER DEFAULT 0,
        sent_at TEXT,
        FOREIGN KEY (device_id) REFERENCES ble_devices (device_id)
      )
    ''');

    // Table for discovered services and characteristics
    await db.execute('''
      CREATE TABLE ble_discovered_services (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        service_uuid TEXT NOT NULL,
        characteristic_uuid TEXT NOT NULL,
        properties TEXT NOT NULL,
        discovered_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES ble_devices (device_id),
        UNIQUE(device_id, service_uuid, characteristic_uuid)
      )
    ''');

    AppLogger.info('BLE database tables created successfully');
  }

  // ==================== BLE Device CRUD ====================

  Future<int> insertDevice(BleDeviceConfig device) async {
    final db = await database;
    AppLogger.info('Inserting BLE device: ${device.deviceId}');
    
    return await db.insert(
      'ble_devices',
      device.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<BleDeviceConfig?> getDevice(String deviceId) async {
    final db = await database;
    final maps = await db.query(
      'ble_devices',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );

    if (maps.isEmpty) return null;
    return BleDeviceConfig.fromMap(maps.first);
  }

  Future<List<BleDeviceConfig>> getAllDevices() async {
    final db = await database;
    final maps = await db.query('ble_devices', orderBy: 'last_connected_at DESC');
    return maps.map((map) => BleDeviceConfig.fromMap(map)).toList();
  }

  Future<int> updateDevice(BleDeviceConfig device) async {
    final db = await database;
    AppLogger.info('Updating BLE device: ${device.deviceId}');
    
    return await db.update(
      'ble_devices',
      device.toMap(),
      where: 'device_id = ?',
      whereArgs: [device.deviceId],
    );
  }

  Future<int> deleteDevice(String deviceId) async {
    final db = await database;
    AppLogger.info('Deleting BLE device: $deviceId');
    
    // Delete related records first
    await db.delete('ble_connection_history', where: 'device_id = ?', whereArgs: [deviceId]);
    await db.delete('ble_message_queue', where: 'device_id = ?', whereArgs: [deviceId]);
    await db.delete('ble_discovered_services', where: 'device_id = ?', whereArgs: [deviceId]);
    
    return await db.delete(
      'ble_devices',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<void> updateLastConnected(String deviceId) async {
    final db = await database;
    await db.update(
      'ble_devices',
      {'last_connected_at': DateTime.now().toIso8601String()},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  // ==================== Connection History ====================

  Future<int> insertConnectionHistory({
    required String deviceId,
    required DateTime connectedAt,
  }) async {
    final db = await database;
    return await db.insert('ble_connection_history', {
      'device_id': deviceId,
      'connected_at': connectedAt.toIso8601String(),
      'bytes_sent': 0,
      'bytes_received': 0,
    });
  }

  Future<void> updateConnectionHistory({
    required int historyId,
    required DateTime disconnectedAt,
    required int bytesSent,
    required int bytesReceived,
    String? disconnectReason,
  }) async {
    final db = await database;
    final duration = disconnectedAt.difference(
      DateTime.parse((await db.query('ble_connection_history',
          where: 'id = ?', whereArgs: [historyId])).first['connected_at'] as String),
    ).inSeconds;

    await db.update(
      'ble_connection_history',
      {
        'disconnected_at': disconnectedAt.toIso8601String(),
        'duration_seconds': duration,
        'bytes_sent': bytesSent,
        'bytes_received': bytesReceived,
        'disconnect_reason': disconnectReason,
      },
      where: 'id = ?',
      whereArgs: [historyId],
    );
  }

  Future<List<Map<String, dynamic>>> getConnectionHistory(String deviceId, {int limit = 10}) async {
    final db = await database;
    return await db.query(
      'ble_connection_history',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'connected_at DESC',
      limit: limit,
    );
  }

  // ==================== Message Queue ====================

  Future<int> queueMessage(String deviceId, List<int> data) async {
    final db = await database;
    return await db.insert('ble_message_queue', {
      'device_id': deviceId,
      'message_data': data,
      'created_at': DateTime.now().toIso8601String(),
      'sent': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingMessages(String deviceId) async {
    final db = await database;
    return await db.query(
      'ble_message_queue',
      where: 'device_id = ? AND sent = 0',
      whereArgs: [deviceId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markMessageSent(int messageId) async {
    final db = await database;
    await db.update(
      'ble_message_queue',
      {
        'sent': 1,
        'sent_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> clearOldMessages(String deviceId, {int daysOld = 7}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    await db.delete(
      'ble_message_queue',
      where: 'device_id = ? AND sent = 1 AND sent_at < ?',
      whereArgs: [deviceId, cutoffDate.toIso8601String()],
    );
  }

  // ==================== Discovered Services ====================

  Future<void> saveDiscoveredService({
    required String deviceId,
    required String serviceUuid,
    required String characteristicUuid,
    required String properties,
  }) async {
    final db = await database;
    await db.insert(
      'ble_discovered_services',
      {
        'device_id': deviceId,
        'service_uuid': serviceUuid,
        'characteristic_uuid': characteristicUuid,
        'properties': properties,
        'discovered_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getDiscoveredServices(String deviceId) async {
    final db = await database;
    return await db.query(
      'ble_discovered_services',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'service_uuid ASC',
    );
  }

  // ==================== Utility ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
    AppLogger.info('BLE database closed');
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ble_devices.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
    AppLogger.info('BLE database deleted');
  }
}
