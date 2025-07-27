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

  // 数据库初始化状态跟踪
  static bool _isInitializing = false;
  static Exception? _lastInitializationError;
  static int _initializationAttempts = 0;

  static Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    // 防止并发初始化
    if (_isInitializing) {
      // 等待当前初始化完成
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_database != null && _database!.isOpen) {
        return _database!;
      }
    }

    _database = await _initDatabase();
    return _database!;
  }

  /// 获取数据库路径，支持多种备用方案
  static Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      return 'mindra_web.db';
    }

    final List<String> candidatePaths = [];

    try {
      // 方案1: 标准数据库路径
      final factory = databaseFactory;
      final standardPath = await factory.getDatabasesPath();
      candidatePaths.add(join(standardPath, AppConstants.databaseName));
    } catch (e) {
      debugPrint('Failed to get standard database path: $e');
    }

    // 方案2: 应用文档目录
    try {
      // 对于Android，尝试使用应用私有目录
      if (Platform.isAndroid) {
        final appDataDir = Platform.environment['ANDROID_DATA'] ?? '/data/data';
        final packageName = 'com.mindra.app'; // 根据实际包名调整
        candidatePaths.add(
          join(appDataDir, packageName, 'databases', AppConstants.databaseName),
        );
      }
    } catch (e) {
      debugPrint('Failed to get Android app data path: $e');
    }

    // 方案3: 外部存储目录（仅Android）
    try {
      if (Platform.isAndroid) {
        final externalStorage =
            Platform.environment['EXTERNAL_STORAGE'] ?? '/sdcard';
        final appDir = join(
          externalStorage,
          'Android',
          'data',
          'com.mindra.app',
          'files',
        );
        candidatePaths.add(join(appDir, AppConstants.databaseName));
      }
    } catch (e) {
      debugPrint('Failed to get external storage path: $e');
    }

    // 方案4: AppImage环境特殊处理
    final isAppImage =
        Platform.environment['APPIMAGE'] != null ||
        Platform.environment['APPDIR'] != null;
    if (isAppImage) {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        final userDataDir = join(homeDir, '.local', 'share', 'Mindra');
        candidatePaths.add(join(userDataDir, AppConstants.databaseName));
      }
    }

    // 方案5: 用户主目录
    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        candidatePaths.add(join(homeDir, '.mindra', AppConstants.databaseName));
      }
    } catch (e) {
      debugPrint('Failed to get home directory path: $e');
    }

    // 方案6: 临时目录作为最后备用
    try {
      final tempDir = Directory.systemTemp;
      final fallbackDir = join(tempDir.path, 'mindra_db');
      candidatePaths.add(join(fallbackDir, AppConstants.databaseName));
    } catch (e) {
      debugPrint('Failed to get temp directory path: $e');
    }

    // 尝试每个候选路径
    for (final path in candidatePaths) {
      try {
        final dbDir = Directory(dirname(path));

        // 确保目录存在
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
        }

        // 测试目录可写性
        final testFile = File(
          join(
            dbDir.path,
            '.write_test_${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
        await testFile.writeAsString('test');
        await testFile.delete();

        debugPrint('Selected database path: $path');
        return path;
      } catch (e) {
        debugPrint('Path $path is not suitable: $e');
        continue;
      }
    }

    throw Exception(
      'No suitable database path found after trying ${candidatePaths.length} options',
    );
  }

  static Future<Database> _initDatabase() async {
    _isInitializing = true;
    _initializationAttempts++;

    try {
      const maxRetries = 5; // 增加重试次数
      int retryCount = 0;
      Exception? lastException;

      while (retryCount < maxRetries) {
        try {
          debugPrint(
            'Database initialization attempt ${retryCount + 1}/$maxRetries',
          );

          // 获取数据库工厂
          var factory = databaseFactory;

          // 获取适当的数据库路径
          final path = await _getDatabasePath();

          debugPrint('Attempting to initialize database at: $path');

          // 检查是否存在损坏的数据库文件
          final dbFile = File(path);
          if (await dbFile.exists()) {
            try {
              // 尝试打开现有数据库进行健康检查
              final testDb = await factory.openDatabase(path);
              await testDb.rawQuery('SELECT 1');

              // 检查表是否完整
              final tables = await testDb.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND name IN (?, ?, ?)",
                [
                  _mediaItemsTable,
                  _meditationSessionsTable,
                  _userPreferencesTable,
                ],
              );

              await testDb.close();

              if (tables.length == 3) {
                debugPrint('Existing database file is healthy and complete');
              } else {
                debugPrint(
                  'Existing database file is incomplete (${tables.length}/3 tables), removing',
                );
                await dbFile.delete();
              }
            } catch (e) {
              debugPrint('Existing database file is corrupted, removing: $e');
              try {
                await dbFile.delete();
              } catch (deleteError) {
                debugPrint('Failed to delete corrupted database: $deleteError');
              }
            }
          }

          // 打开或创建数据库
          final database = await factory.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: AppConstants.databaseVersion,
              onCreate: _createTables,
              onUpgrade: _onUpgrade,
              onOpen: _onDatabaseOpen,
              onConfigure: _onDatabaseConfigure,
            ),
          );

          // 验证数据库是否正常工作
          await _validateDatabase(database);

          debugPrint('Database initialized successfully at: $path');
          _lastInitializationError = null;
          return database;
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          retryCount++;

          debugPrint('Database initialization attempt $retryCount failed: $e');

          if (retryCount < maxRetries) {
            // 渐进式退避策略
            final delayMs =
                200 * retryCount * retryCount; // 200ms, 800ms, 1800ms, 3200ms
            debugPrint('Retrying database initialization in ${delayMs}ms...');
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        }
      }

      _lastInitializationError = lastException;
      throw Exception(
        'Failed to initialize database after $maxRetries attempts. Last error: $lastException',
      );
    } finally {
      _isInitializing = false;
    }
  }

  /// 数据库配置回调
  static Future<void> _onDatabaseConfigure(Database db) async {
    try {
      // 启用外键约束
      await db.execute('PRAGMA foreign_keys = ON');
      // 设置WAL模式以提高并发性能
      await db.execute('PRAGMA journal_mode = WAL');
      // 设置同步模式
      await db.execute('PRAGMA synchronous = NORMAL');
      // 设置缓存大小
      await db.execute('PRAGMA cache_size = -2000'); // 2MB cache
      debugPrint('Database configuration applied successfully');
    } catch (e) {
      debugPrint('Warning: Failed to apply database configuration: $e');
      // 配置失败不应该阻止数据库初始化
    }
  }

  /// 数据库打开回调
  static Future<void> _onDatabaseOpen(Database db) async {
    try {
      // 验证数据库完整性
      final result = await db.rawQuery('PRAGMA integrity_check');
      if (result.isNotEmpty && result.first.values.first != 'ok') {
        debugPrint('Database integrity check failed: ${result.first}');
        throw Exception('Database integrity check failed');
      }
      debugPrint('Database integrity check passed');
    } catch (e) {
      debugPrint('Warning: Database integrity check failed: $e');
      // 完整性检查失败时记录警告但继续
    }
  }

  /// 验证数据库是否正常工作
  static Future<void> _validateDatabase(Database db) async {
    try {
      // 检查必要的表是否存在
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN (?, ?, ?)",
        [_mediaItemsTable, _meditationSessionsTable, _userPreferencesTable],
      );

      if (tables.length != 3) {
        throw Exception(
          'Required tables are missing. Found: ${tables.map((t) => t['name']).join(', ')}',
        );
      }

      // 尝试执行简单查询
      await db.rawQuery('SELECT COUNT(*) FROM $_mediaItemsTable');
      await db.rawQuery('SELECT COUNT(*) FROM $_meditationSessionsTable');
      await db.rawQuery('SELECT COUNT(*) FROM $_userPreferencesTable');

      debugPrint('Database validation passed');
    } catch (e) {
      debugPrint('Database validation failed: $e');
      throw Exception('Database validation failed: $e');
    }
  }

  static Future<void> _createTables(Database db, int version) async {
    try {
      debugPrint('Creating database tables...');

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

      debugPrint('Database tables created successfully');
    } catch (e) {
      debugPrint('Error creating database tables: $e');
      rethrow;
    }
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    try {
      debugPrint('Upgrading database from version $oldVersion to $newVersion');

      // 处理数据库升级逻辑
      if (oldVersion < newVersion) {
        // 这里添加具体的升级逻辑
        // 例如：添加新列、创建新表等

        // 示例：如果需要添加新列
        // if (oldVersion < 2) {
        //   await db.execute('ALTER TABLE $_mediaItemsTable ADD COLUMN new_column TEXT');
        // }
      }

      debugPrint('Database upgrade completed successfully');
    } catch (e) {
      debugPrint('Error upgrading database: $e');
      rethrow;
    }
  }

  /// 获取数据库初始化状态
  static Map<String, dynamic> getInitializationStatus() {
    return {
      'isInitializing': _isInitializing,
      'attempts': _initializationAttempts,
      'lastError': _lastInitializationError?.toString(),
      'isOpen': _database?.isOpen ?? false,
    };
  }

  /// 强制重新初始化数据库
  static Future<void> forceReinitialize() async {
    debugPrint('Forcing database reinitialization...');

    try {
      if (_database != null && _database!.isOpen) {
        await _database!.close();
      }
    } catch (e) {
      debugPrint('Error closing existing database: $e');
    }

    _database = null;
    _lastInitializationError = null;
    _initializationAttempts = 0;

    // 重新初始化
    await database;
    debugPrint('Database reinitialization completed');
  }

  /// 执行数据库操作并在失败时重试
  static Future<T> _executeWithRetry<T>(
    Future<T> Function() operation,
    String operationName, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 300),
  }) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        debugPrint('$operationName attempt $attempt failed: $e');

        // 如果是数据库连接问题，尝试重新初始化
        if (e.toString().toLowerCase().contains('database') &&
            (e.toString().contains('closed') ||
                e.toString().contains('lock'))) {
          debugPrint(
            'Database connection issue detected, attempting to reinitialize...',
          );
          try {
            await forceReinitialize();
          } catch (reinitError) {
            debugPrint('Failed to reinitialize database: $reinitError');
          }
        }

        if (attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt);
        }
      }
    }

    throw Exception(
      'Failed to execute $operationName after $maxRetries attempts. Last error: $lastException',
    );
  }

  // Media Items operations
  static Future<void> insertMediaItem(Map<String, dynamic> item) async {
    await _executeWithRetry(() async {
      final db = await database;
      await db.insert(
        _mediaItemsTable,
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }, 'insertMediaItem');
  }

  static Future<List<Map<String, dynamic>>> getMediaItems() async {
    return await _executeWithRetry(() async {
      final db = await database;
      return await db.query(_mediaItemsTable, orderBy: 'created_at DESC');
    }, 'getMediaItems');
  }

  static Future<Map<String, dynamic>?> getMediaItemById(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('Media item ID cannot be empty');
    }

    return await _executeWithRetry(() async {
      final db = await database;
      final results = await db.query(
        _mediaItemsTable,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    }, 'getMediaItemById');
  }

  static Future<List<Map<String, dynamic>>> getMediaItemsByCategory(
    String category,
  ) async {
    if (category.isEmpty) {
      throw ArgumentError('Category cannot be empty');
    }

    return await _executeWithRetry(() async {
      final db = await database;
      return await db.query(
        _mediaItemsTable,
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'created_at DESC',
      );
    }, 'getMediaItemsByCategory');
  }

  static Future<List<Map<String, dynamic>>> getFavoriteMediaItems() async {
    return await _executeWithRetry(() async {
      final db = await database;
      return await db.query(
        _mediaItemsTable,
        where: 'is_favorite = ?',
        whereArgs: [1],
        orderBy: 'created_at DESC',
      );
    }, 'getFavoriteMediaItems');
  }

  static Future<List<Map<String, dynamic>>> getRecentMediaItems(
    int limit,
  ) async {
    if (limit <= 0) {
      throw ArgumentError('Limit must be positive');
    }

    return await _executeWithRetry(() async {
      final db = await database;
      return await db.query(
        _mediaItemsTable,
        where: 'last_played_at IS NOT NULL',
        orderBy: 'last_played_at DESC',
        limit: limit,
      );
    }, 'getRecentMediaItems');
  }

  static Future<void> updateMediaItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    if (id.isEmpty) {
      throw ArgumentError('Media item ID cannot be empty');
    }
    if (updates.isEmpty) {
      throw ArgumentError('Updates cannot be empty');
    }

    await _executeWithRetry(() async {
      final db = await database;
      final result = await db.update(
        _mediaItemsTable,
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result == 0) {
        debugPrint('Warning: No rows updated for media item ID: $id');
      }
    }, 'updateMediaItem');
  }

  static Future<void> deleteMediaItem(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('Media item ID cannot be empty');
    }

    await _executeWithRetry(() async {
      final db = await database;

      // 开始事务以确保数据一致性
      await db.transaction((txn) async {
        // 首先删除相关的冥想会话记录
        await txn.delete(
          _meditationSessionsTable,
          where: 'media_item_id = ?',
          whereArgs: [id],
        );

        // 然后删除媒体项
        final result = await txn.delete(
          _mediaItemsTable,
          where: 'id = ?',
          whereArgs: [id],
        );

        if (result == 0) {
          debugPrint('Warning: No rows deleted for media item ID: $id');
        }
      });
    }, 'deleteMediaItem');
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
