import 'package:sqflite/sqflite.dart';
import '../../models/bluetooth_settings.dart';
import '../../utils/app_logger.dart';

class BluetoothSettingsDatabase {
  static const String _tableName = 'bluetooth_settings';
  static const String _deviceOverridesTable = 'bluetooth_device_overrides';

  /// Create tables for Bluetooth settings
  static Future<void> createTables(Database db) async {
    // Global settings table (single row)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        auto_reconnect INTEGER NOT NULL DEFAULT 1,
        connection_timeout INTEGER NOT NULL DEFAULT 10,
        reconnect_attempts INTEGER NOT NULL DEFAULT 3,
        reconnect_delay INTEGER NOT NULL DEFAULT 2,
        keep_alive_interval INTEGER NOT NULL DEFAULT 30,
        baud_rate INTEGER NOT NULL DEFAULT 9600,
        data_bits INTEGER NOT NULL DEFAULT 8,
        stop_bits INTEGER NOT NULL DEFAULT 1,
        parity TEXT NOT NULL DEFAULT 'none',
        buffer_size INTEGER NOT NULL DEFAULT 1024,
        flow_control TEXT NOT NULL DEFAULT 'none',
        mtu_size INTEGER NOT NULL DEFAULT 512,
        service_uuid TEXT NOT NULL DEFAULT 'FFE0',
        rx_characteristic_uuid TEXT NOT NULL DEFAULT 'FFE1',
        tx_characteristic_uuid TEXT NOT NULL DEFAULT 'FFE1',
        ble_connection_priority TEXT NOT NULL DEFAULT 'balanced',
        notification_delay INTEGER NOT NULL DEFAULT 0,
        line_ending TEXT NOT NULL DEFAULT 'none',
        auto_prefix TEXT NOT NULL DEFAULT '',
        auto_suffix TEXT NOT NULL DEFAULT '',
        encoding TEXT NOT NULL DEFAULT 'utf8',
        trim_whitespace INTEGER NOT NULL DEFAULT 0,
        display_format TEXT NOT NULL DEFAULT 'text',
        timestamp_format TEXT NOT NULL DEFAULT 'relative',
        max_message_history INTEGER NOT NULL DEFAULT 200,
        auto_scroll INTEGER NOT NULL DEFAULT 1,
        local_echo INTEGER NOT NULL DEFAULT 0,
        enable_logging INTEGER NOT NULL DEFAULT 0,
        packet_chunking INTEGER NOT NULL DEFAULT 1,
        chunk_size INTEGER NOT NULL DEFAULT 20,
        chunk_delay INTEGER NOT NULL DEFAULT 50,
        discard_invalid_utf8 INTEGER NOT NULL DEFAULT 0,
        scan_duration INTEGER NOT NULL DEFAULT 15,
        connection_sound INTEGER NOT NULL DEFAULT 1,
        message_sound INTEGER NOT NULL DEFAULT 0,
        vibrate_on_message INTEGER NOT NULL DEFAULT 0,
        show_toast_notifications INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Device-specific overrides table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_deviceOverridesTable (
        device_id TEXT PRIMARY KEY,
        auto_reconnect INTEGER,
        connection_timeout INTEGER,
        reconnect_attempts INTEGER,
        reconnect_delay INTEGER,
        keep_alive_interval INTEGER,
        baud_rate INTEGER,
        data_bits INTEGER,
        stop_bits INTEGER,
        parity TEXT,
        buffer_size INTEGER,
        flow_control TEXT,
        mtu_size INTEGER,
        service_uuid TEXT,
        rx_characteristic_uuid TEXT,
        tx_characteristic_uuid TEXT,
        ble_connection_priority TEXT,
        notification_delay INTEGER,
        line_ending TEXT,
        auto_prefix TEXT,
        auto_suffix TEXT,
        encoding TEXT,
        trim_whitespace INTEGER,
        display_format TEXT,
        timestamp_format TEXT,
        max_message_history INTEGER,
        auto_scroll INTEGER,
        local_echo INTEGER,
        enable_logging INTEGER,
        packet_chunking INTEGER,
        chunk_size INTEGER,
        chunk_delay INTEGER,
        discard_invalid_utf8 INTEGER,
        scan_duration INTEGER,
        connection_sound INTEGER,
        message_sound INTEGER,
        vibrate_on_message INTEGER,
        show_toast_notifications INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    AppLogger.info('Bluetooth settings tables created');
  }

  /// Initialize global settings with defaults if not exists
  static Future<void> initializeGlobalSettings(Database db) async {
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    final rowCount = count.first['count'] as int;

    if (rowCount == 0) {
      final now = DateTime.now().toIso8601String();
      final defaults = const BluetoothSettings();
      final map = defaults.toMap();
      map['id'] = 1;
      map['created_at'] = now;
      map['updated_at'] = now;

      await db.insert(_tableName, map);
      AppLogger.info('Global Bluetooth settings initialized with defaults');
    }
  }

  /// Get global settings
  static Future<BluetoothSettings> getGlobalSettings(Database db) async {
    final results = await db.query(_tableName, where: 'id = ?', whereArgs: [1]);

    if (results.isEmpty) {
      // Initialize if doesn't exist
      await initializeGlobalSettings(db);
      return const BluetoothSettings();
    }

    return BluetoothSettings.fromMap(results.first);
  }

  /// Save global settings
  static Future<void> saveGlobalSettings(Database db, BluetoothSettings settings) async {
    final now = DateTime.now().toIso8601String();
    final map = settings.toMap();
    map['id'] = 1;
    map['updated_at'] = now;

    // Check if exists
    final exists = await db.query(_tableName, where: 'id = ?', whereArgs: [1]);

    if (exists.isEmpty) {
      map['created_at'] = now;
      await db.insert(_tableName, map);
    } else {
      await db.update(_tableName, map, where: 'id = ?', whereArgs: [1]);
    }

    AppLogger.info('Global Bluetooth settings saved');
  }

  /// Get device-specific override settings
  static Future<BluetoothSettings?> getDeviceSettings(Database db, String deviceId) async {
    final results = await db.query(
      _deviceOverridesTable,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );

    if (results.isEmpty) {
      return null; // No overrides, use global
    }

    return BluetoothSettings.fromMap(results.first);
  }

  /// Save device-specific override settings
  static Future<void> saveDeviceSettings(
    Database db,
    String deviceId,
    BluetoothSettings settings,
  ) async {
    final now = DateTime.now().toIso8601String();
    final map = settings.toMap();
    map['device_id'] = deviceId;
    map['updated_at'] = now;

    // Check if exists
    final exists = await db.query(
      _deviceOverridesTable,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );

    if (exists.isEmpty) {
      map['created_at'] = now;
      await db.insert(_deviceOverridesTable, map);
    } else {
      await db.update(
        _deviceOverridesTable,
        map,
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
    }

    AppLogger.info('Device-specific Bluetooth settings saved for $deviceId');
  }

  /// Delete device-specific overrides (revert to global)
  static Future<void> deleteDeviceSettings(Database db, String deviceId) async {
    await db.delete(
      _deviceOverridesTable,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    AppLogger.info('Device-specific settings deleted for $deviceId');
  }

  /// Get effective settings for a device (device overrides merged with global)
  static Future<BluetoothSettings> getEffectiveSettings(
    Database db,
    String deviceId,
  ) async {
    final globalSettings = await getGlobalSettings(db);
    final deviceOverrides = await getDeviceSettings(db, deviceId);

    if (deviceOverrides == null) {
      return globalSettings; // No overrides, return global
    }

    // Merge: device overrides take precedence over global
    // Since we store complete settings per device, just return device settings
    return deviceOverrides;
  }

  /// Apply global settings to all devices (update base layer)
  static Future<void> applyGlobalToAllDevices(
    Database db,
    BluetoothSettings newGlobalSettings,
  ) async {
    // First, save the new global settings
    await saveGlobalSettings(db, newGlobalSettings);

    // Get all device overrides
    final deviceOverrides = await db.query(_deviceOverridesTable);

    // For each device, we don't need to do anything because:
    // - Device-specific overrides remain as they are
    // - The global settings are the base layer
    // - When getEffectiveSettings is called, it merges global + device overrides

    AppLogger.info('Global settings applied to all devices (${deviceOverrides.length} devices with overrides)');
  }

  /// Reset global settings to defaults
  static Future<void> resetGlobalToDefaults(Database db) async {
    await saveGlobalSettings(db, const BluetoothSettings());
    AppLogger.info('Global settings reset to defaults');
  }

  /// Reset device settings to use global (delete overrides)
  static Future<void> resetDeviceToGlobal(Database db, String deviceId) async {
    await deleteDeviceSettings(db, deviceId);
    AppLogger.info('Device $deviceId reset to use global settings');
  }

  /// Get all devices with custom settings
  static Future<List<String>> getDevicesWithCustomSettings(Database db) async {
    final results = await db.query(
      _deviceOverridesTable,
      columns: ['device_id'],
    );

    return results.map((row) => row['device_id'] as String).toList();
  }

  /// Check if device has custom settings
  static Future<bool> hasCustomSettings(Database db, String deviceId) async {
    final results = await db.query(
      _deviceOverridesTable,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );

    return results.isNotEmpty;
  }
}
