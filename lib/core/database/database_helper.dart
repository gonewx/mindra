import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../constants/app_constants.dart';

class DatabaseHelper {
  static Database? _database;
  static const String _mediaItemsTable = 'media_items';
  static const String _meditationSessionsTable = 'meditation_sessions';
  static const String _userPreferencesTable = 'user_preferences';

  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  /// 获取数据库路径，特别处理AppImage环境
  static Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      return 'mindra_web.db';
    }

    // 检查是否在AppImage环境中运行
    final isAppImage =
        Platform.environment['APPIMAGE'] != null ||
        Platform.environment['APPDIR'] != null;

    if (isAppImage) {
      // AppImage环境：使用用户数据目录
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        final userDataDir = join(homeDir, '.local', 'share', 'Mindra');
        final directory = Directory(userDataDir);

        // 确保目录存在
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        final dbPath = join(userDataDir, AppConstants.databaseName);
        debugPrint('AppImage database path: $dbPath');
        return dbPath;
      }
    }

    // 普通环境：使用标准数据库路径
    try {
      final factory = databaseFactory;
      final databasePath = await factory.getDatabasesPath();
      return join(databasePath, AppConstants.databaseName);
    } catch (e) {
      // 如果获取标准路径失败，尝试使用临时目录
      debugPrint('Failed to get standard database path: $e');
      final tempDir = Directory.systemTemp;
      final fallbackDir = join(tempDir.path, 'mindra_db');
      final directory = Directory(fallbackDir);

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      return join(fallbackDir, AppConstants.databaseName);
    }
  }

  static Future<Database> _initDatabase() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // Get the database factory (should be set in main.dart)
        var factory = databaseFactory;

        // 获取适当的数据库路径
        final path = await _getDatabasePath();

        debugPrint('Attempting to initialize database at: $path');

        // 确保数据库目录存在且可写
        final dbDir = Directory(dirname(path));
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
        }

        // 检查目录权限
        try {
          final testFile = File(join(dbDir.path, '.write_test'));
          await testFile.writeAsString('test');
          await testFile.delete();
          debugPrint('Database directory is writable: ${dbDir.path}');
        } catch (e) {
          debugPrint(
            'Database directory is not writable: ${dbDir.path}, error: $e',
          );
          throw Exception('Database directory is not writable: ${dbDir.path}');
        }

        return await factory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: AppConstants.databaseVersion,
            onCreate: _createTables,
            onUpgrade: _onUpgrade,
          ),
        );
      } catch (e) {
        retryCount++;
        if (kDebugMode) {
          print('Database initialization attempt $retryCount failed: $e');
        }

        if (retryCount >= maxRetries) {
          throw Exception(
            'Failed to initialize database after $maxRetries attempts: $e',
          );
        }

        // 等待一段时间后重试，特别是华为设备可能需要更多时间
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }

    throw Exception('Unexpected error in database initialization');
  }

  static Future<void> _createTables(Database db, int version) async {
    // Create media_items table
    await db.execute('''
      CREATE TABLE $_mediaItemsTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        file_path TEXT NOT NULL,
        thumbnail_path TEXT,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        duration INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        last_played_at INTEGER,
        play_count INTEGER DEFAULT 0,
        tags TEXT,
        is_favorite INTEGER DEFAULT 0,
        source_url TEXT
      )
    ''');

    // Create meditation_sessions table
    await db.execute('''
      CREATE TABLE $_meditationSessionsTable (
        id TEXT PRIMARY KEY,
        media_item_id TEXT NOT NULL,
        title TEXT NOT NULL,
        duration INTEGER NOT NULL,
        actual_duration INTEGER NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        type TEXT NOT NULL,
        sound_effects TEXT,
        rating REAL DEFAULT 0.0,
        notes TEXT,
        is_completed INTEGER DEFAULT 0,
        FOREIGN KEY (media_item_id) REFERENCES $_mediaItemsTable (id)
      )
    ''');

    // Create user_preferences table
    await db.execute('''
      CREATE TABLE $_userPreferencesTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('''
      CREATE INDEX idx_media_items_created_at ON $_mediaItemsTable(created_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_media_items_category ON $_mediaItemsTable(category)
    ''');

    await db.execute('''
      CREATE INDEX idx_meditation_sessions_start_time ON $_meditationSessionsTable(start_time)
    ''');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Handle database upgrades here when needed
    if (oldVersion < newVersion) {
      // Add migration logic here
    }
  }

  // Media Items operations
  static Future<void> insertMediaItem(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert(
      _mediaItemsTable,
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getMediaItems() async {
    final db = await database;
    return await db.query(_mediaItemsTable, orderBy: 'created_at DESC');
  }

  static Future<Map<String, dynamic>?> getMediaItemById(String id) async {
    final db = await database;
    final results = await db.query(
      _mediaItemsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  static Future<List<Map<String, dynamic>>> getMediaItemsByCategory(
    String category,
  ) async {
    final db = await database;
    return await db.query(
      _mediaItemsTable,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getFavoriteMediaItems() async {
    final db = await database;
    return await db.query(
      _mediaItemsTable,
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getRecentMediaItems(
    int limit,
  ) async {
    final db = await database;
    return await db.query(
      _mediaItemsTable,
      where: 'last_played_at IS NOT NULL',
      orderBy: 'last_played_at DESC',
      limit: limit,
    );
  }

  static Future<void> updateMediaItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    await db.update(
      _mediaItemsTable,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteMediaItem(String id) async {
    final db = await database;
    await db.delete(_mediaItemsTable, where: 'id = ?', whereArgs: [id]);
  }

  // Meditation Sessions operations
  static Future<void> insertMeditationSession(
    Map<String, dynamic> session,
  ) async {
    final db = await database;
    await db.insert(
      _meditationSessionsTable,
      session,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getMeditationSessions() async {
    final db = await database;
    return await db.query(_meditationSessionsTable, orderBy: 'start_time DESC');
  }

  static Future<List<Map<String, dynamic>>> getAllMeditationSessions() async {
    final db = await database;
    return await db.query(_meditationSessionsTable, orderBy: 'start_time DESC');
  }

  static Future<List<Map<String, dynamic>>> getMeditationSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    return await db.query(
      _meditationSessionsTable,
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'start_time DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getRecentMeditationSessions({
    int limit = 3,
  }) async {
    final db = await database;
    return await db.query(
      _meditationSessionsTable,
      orderBy: 'start_time DESC',
      limit: limit,
    );
  }

  static Future<Map<String, dynamic>?> getMeditationStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_sessions,
        SUM(actual_duration) as total_duration,
        AVG(rating) as average_rating,
        COUNT(CASE WHEN is_completed = 1 THEN 1 END) as completed_sessions
      FROM $_meditationSessionsTable
    ''');

    return result.isNotEmpty ? result.first : null;
  }

  static Future<void> updateMeditationSession(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    await db.update(
      _meditationSessionsTable,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteMeditationSession(String id) async {
    final db = await database;
    await db.delete(_meditationSessionsTable, where: 'id = ?', whereArgs: [id]);
  }

  // User Preferences operations
  static Future<void> setPreference(String key, String value) async {
    final db = await database;
    await db.insert(_userPreferencesTable, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getPreference(String key) async {
    final db = await database;
    final result = await db.query(
      _userPreferencesTable,
      where: 'key = ?',
      whereArgs: [key],
    );

    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  static Future<void> deletePreference(String key) async {
    final db = await database;
    await db.delete(_userPreferencesTable, where: 'key = ?', whereArgs: [key]);
  }

  // Utility methods
  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete(_mediaItemsTable);
    await db.delete(_meditationSessionsTable);
    await db.delete(_userPreferencesTable);
  }

  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
