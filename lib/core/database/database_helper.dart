import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
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

  static Future<Database> _initDatabase() async {
    try {
      // Get the database factory (should be set in main.dart)
      var factory = databaseFactory;

      // For web platform, use in-memory database path
      String path;
      if (kIsWeb) {
        path = 'mindra_web.db';
      } else {
        final databasePath = await factory.getDatabasesPath();
        path = join(databasePath, AppConstants.databaseName);
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
      throw Exception('Failed to initialize database: $e');
    }
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
