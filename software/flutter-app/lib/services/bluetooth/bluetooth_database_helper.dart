import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/bluetooth_device_config.dart';
import '../../utils/app_logger.dart';

/// Database helper for Bluetooth device configurations
/// Separate database for Bluetooth communication data
class BluetoothDatabaseHelper {
  static final BluetoothDatabaseHelper instance = BluetoothDatabaseHelper._init();
  static Database? _database;

  BluetoothDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bluetooth_devices.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    AppLogger.info('Initializing Bluetooth database at: $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    AppLogger.info('Creating Bluetooth database tables...');

    // Bluetooth devices configuration table
    await db.execute('''
      CREATE TABLE bluetooth_devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        address TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        custom_alias TEXT,
        baud_rate INTEGER NOT NULL DEFAULT 9600,
        data_bits INTEGER NOT NULL DEFAULT 8,
        stop_bits INTEGER NOT NULL DEFAULT 1,
        parity INTEGER NOT NULL DEFAULT 0,
        auto_reconnect INTEGER NOT NULL DEFAULT 1,
        buffer_size INTEGER NOT NULL DEFAULT 1024,
        connection_timeout INTEGER NOT NULL DEFAULT 10,
        last_connected TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Connection history table (optional, for analytics)
    await db.execute('''
      CREATE TABLE connection_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_address TEXT NOT NULL,
        connected_at TEXT NOT NULL,
        disconnected_at TEXT,
        bytes_sent INTEGER NOT NULL DEFAULT 0,
        bytes_received INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        FOREIGN KEY (device_address) REFERENCES bluetooth_devices (address) ON DELETE CASCADE
      )
    ''');

    // Message queue table (for queued messages when device disconnected)
    await db.execute('''
      CREATE TABLE message_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_address TEXT NOT NULL,
        message TEXT NOT NULL,
        message_type TEXT NOT NULL,
        queued_at TEXT NOT NULL,
        sent_at TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (device_address) REFERENCES bluetooth_devices (address) ON DELETE CASCADE
      )
    ''');

    AppLogger.success('Bluetooth database tables created successfully');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    AppLogger.info('Upgrading Bluetooth database from v$oldVersion to v$newVersion');
    // Add migration logic here if needed in future versions
  }

  // ========== CRUD Operations for Bluetooth Devices ==========

  /// Insert or update device configuration
  Future<int> upsertDevice(BluetoothDeviceConfig config) async {
    try {
      final db = await database;
      final now = DateTime.now();
      
      // Check if device exists
      final existing = await getDeviceByAddress(config.address);
      
      if (existing != null) {
        // Update existing device
        final updatedConfig = config.copyWith(
          id: existing.id,
          updatedAt: now,
        );
        
        await db.update(
          'bluetooth_devices',
          updatedConfig.toMap(),
          where: 'address = ?',
          whereArgs: [config.address],
        );
        
        AppLogger.info('Updated Bluetooth device: ${config.address}');
        return existing.id!;
      } else {
        // Insert new device
        final newConfig = config.copyWith(
          createdAt: now,
          updatedAt: now,
        );
        
        final id = await db.insert(
          'bluetooth_devices',
          newConfig.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        AppLogger.success('Inserted new Bluetooth device: ${config.address}');
        return id;
      }
    } catch (e) {
      AppLogger.error('Error upserting Bluetooth device: $e');
      rethrow;
    }
  }

  /// Get device configuration by address
  Future<BluetoothDeviceConfig?> getDeviceByAddress(String address) async {
    try {
      final db = await database;
      final maps = await db.query(
        'bluetooth_devices',
        where: 'address = ?',
        whereArgs: [address],
      );

      if (maps.isNotEmpty) {
        return BluetoothDeviceConfig.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error getting device by address: $e');
      return null;
    }
  }

  /// Get all saved devices
  Future<List<BluetoothDeviceConfig>> getAllDevices() async {
    try {
      final db = await database;
      final maps = await db.query(
        'bluetooth_devices',
        orderBy: 'is_favorite DESC, last_connected DESC, name ASC',
      );

      return maps.map((map) => BluetoothDeviceConfig.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error getting all devices: $e');
      return [];
    }
  }

  /// Get favorite devices
  Future<List<BluetoothDeviceConfig>> getFavoriteDevices() async {
    try {
      final db = await database;
      final maps = await db.query(
        'bluetooth_devices',
        where: 'is_favorite = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );

      return maps.map((map) => BluetoothDeviceConfig.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Error getting favorite devices: $e');
      return [];
    }
  }

  /// Update last connected timestamp
  Future<void> updateLastConnected(String address) async {
    try {
      final db = await database;
      await db.update(
        'bluetooth_devices',
        {
          'last_connected': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'address = ?',
        whereArgs: [address],
      );
    } catch (e) {
      AppLogger.error('Error updating last connected: $e');
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String address) async {
    try {
      final db = await database;
      final device = await getDeviceByAddress(address);
      
      if (device != null) {
        await db.update(
          'bluetooth_devices',
          {
            'is_favorite': device.isFavorite ? 0 : 1,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'address = ?',
          whereArgs: [address],
        );
      }
    } catch (e) {
      AppLogger.error('Error toggling favorite: $e');
    }
  }

  /// Delete device configuration
  Future<void> deleteDevice(String address) async {
    try {
      final db = await database;
      await db.delete(
        'bluetooth_devices',
        where: 'address = ?',
        whereArgs: [address],
      );
      AppLogger.info('Deleted Bluetooth device: $address');
    } catch (e) {
      AppLogger.error('Error deleting device: $e');
    }
  }

  /// Delete all devices
  Future<void> deleteAllDevices() async {
    try {
      final db = await database;
      await db.delete('bluetooth_devices');
      AppLogger.info('Deleted all Bluetooth devices');
    } catch (e) {
      AppLogger.error('Error deleting all devices: $e');
    }
  }

  // ========== Connection History Operations ==========

  /// Add connection history entry
  Future<void> addConnectionHistory({
    required String deviceAddress,
    required DateTime connectedAt,
    DateTime? disconnectedAt,
    int bytesSent = 0,
    int bytesReceived = 0,
    String? errorMessage,
  }) async {
    try {
      final db = await database;
      await db.insert('connection_history', {
        'device_address': deviceAddress,
        'connected_at': connectedAt.toIso8601String(),
        'disconnected_at': disconnectedAt?.toIso8601String(),
        'bytes_sent': bytesSent,
        'bytes_received': bytesReceived,
        'error_message': errorMessage,
      });
    } catch (e) {
      AppLogger.error('Error adding connection history: $e');
    }
  }

  /// Get connection history for a device
  Future<List<Map<String, dynamic>>> getConnectionHistory(String deviceAddress, {int limit = 10}) async {
    try {
      final db = await database;
      return await db.query(
        'connection_history',
        where: 'device_address = ?',
        whereArgs: [deviceAddress],
        orderBy: 'connected_at DESC',
        limit: limit,
      );
    } catch (e) {
      AppLogger.error('Error getting connection history: $e');
      return [];
    }
  }

  // ========== Message Queue Operations ==========

  /// Queue message for later sending
  Future<void> queueMessage({
    required String deviceAddress,
    required String message,
    required String messageType,
  }) async {
    try {
      final db = await database;
      await db.insert('message_queue', {
        'device_address': deviceAddress,
        'message': message,
        'message_type': messageType,
        'queued_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
      AppLogger.info('Queued message for device: $deviceAddress');
    } catch (e) {
      AppLogger.error('Error queuing message: $e');
    }
  }

  /// Get pending messages for a device
  Future<List<Map<String, dynamic>>> getPendingMessages(String deviceAddress) async {
    try {
      final db = await database;
      return await db.query(
        'message_queue',
        where: 'device_address = ? AND status = ?',
        whereArgs: [deviceAddress, 'pending'],
        orderBy: 'queued_at ASC',
      );
    } catch (e) {
      AppLogger.error('Error getting pending messages: $e');
      return [];
    }
  }

  /// Mark message as sent
  Future<void> markMessageSent(int messageId) async {
    try {
      final db = await database;
      await db.update(
        'message_queue',
        {
          'status': 'sent',
          'sent_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      AppLogger.error('Error marking message as sent: $e');
    }
  }

  /// Clear sent messages
  Future<void> clearSentMessages(String deviceAddress) async {
    try {
      final db = await database;
      await db.delete(
        'message_queue',
        where: 'device_address = ? AND status = ?',
        whereArgs: [deviceAddress, 'sent'],
      );
    } catch (e) {
      AppLogger.error('Error clearing sent messages: $e');
    }
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    AppLogger.info('Bluetooth database closed');
  }
}
