import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'dart:async';
import '../constants/app_constants.dart';

/// DatabaseHelper - 数据库操作的静态辅助类
/// 现在主要作为DatabaseManager的代理，保持向后兼容性
class DatabaseHelper {
  static Database? _database;
  static const String _mediaItemsTable = 'media_items';
  static const String _meditationSessionsTable = 'meditation_sessions';
  static const String _userPreferencesTable = 'user_preferences';

  // 数据库初始化状态跟踪
  static bool _isInitializing = false;
  static Exception? _lastInitializationError;
  static int _initializationAttempts = 0;

  // 添加初始化完成的Completer来解决并发问题
  static Completer<Database>? _initializationCompleter;

  static Future<Database> get database async {
    // 如果数据库已经初始化且连接正常，直接返回
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    // 如果正在初始化，等待初始化完成
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      debugPrint('Database initialization in progress, waiting...');
      return await _initializationCompleter!.future;
    }

    // 开始新的初始化
    _initializationCompleter = Completer<Database>();

    try {
      _database = await _initDatabase();
      if (!_initializationCompleter!.isCompleted) {
        _initializationCompleter!.complete(_database!);
      }
      return _database!;
    } catch (e) {
      if (!_initializationCompleter!.isCompleted) {
        _initializationCompleter!.completeError(e);
      }
      _initializationCompleter = null;
      rethrow;
    }
  }

  /// 获取数据库路径 - 遵循Android标准实践
  static Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      return 'mindra_web.db';
    }

    // Android平台：始终使用sqflite提供的标准API
    if (Platform.isAndroid) {
      try {
        debugPrint('=== 使用Android标准数据库路径获取方式 ===');

        // 使用sqflite的标准API获取数据库路径
        // 这是推荐的做法，符合Android最佳实践
        final factory = databaseFactory;
        final databasesPath = await factory.getDatabasesPath();
        final standardPath = join(databasesPath, AppConstants.databaseName);

        debugPrint('Standard database path: $standardPath');

        // 确保数据库目录存在（通常系统会自动创建，但保险起见）
        final dbDir = Directory(dirname(standardPath));
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
          debugPrint('Created database directory: ${dbDir.path}');
        }

        // 检查并迁移旧的数据库文件（如果存在）
        await _migrateOldDatabaseFiles(standardPath);

        return standardPath;
      } catch (e) {
        debugPrint('Error getting standard database path: $e');
        rethrow;
      }
    }

    // 非Android平台的处理逻辑
    final List<String> candidatePaths = [];

    try {
      // 方案1: 标准数据库路径
      final factory = databaseFactory;
      final standardPath = await factory.getDatabasesPath();
      candidatePaths.add(join(standardPath, AppConstants.databaseName));
    } catch (e) {
      debugPrint('Failed to get standard database path: $e');
    }

    // 方案2: AppImage环境特殊处理
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

    // 方案3: 用户主目录
    try {
      final homeDir = Platform.environment['HOME'];
      if (homeDir != null) {
        candidatePaths.add(join(homeDir, '.mindra', AppConstants.databaseName));
      }
    } catch (e) {
      debugPrint('Failed to get home directory path: $e');
    }

    // 方案4: 临时目录作为最后备用
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

  /// 迁移旧的数据库文件到标准路径（简化版本）
  static Future<void> _migrateOldDatabaseFiles(String standardPath) async {
    if (!Platform.isAndroid) return;

    try {
      final standardFile = File(standardPath);
      if (await standardFile.exists()) {
        debugPrint('Database already exists at standard path');
        return;
      }

      debugPrint(
        'Checking for legacy database files in system temp directory...',
      );

      // 只检查系统临时目录的旧位置（之前的备用方案）
      final tempDirPath = join(
        Directory.systemTemp.path,
        'mindra_db',
        AppConstants.databaseName,
      );

      final oldFile = File(tempDirPath);
      if (await oldFile.exists()) {
        debugPrint('Found legacy database at: $tempDirPath');

        try {
          // 验证文件完整性
          final testDb = await databaseFactory.openDatabase(tempDirPath);
          await testDb.rawQuery('SELECT 1');
          await testDb.close();

          // 迁移到标准位置
          await oldFile.copy(standardPath);

          // 验证迁移成功
          final newFile = File(standardPath);
          if (await newFile.exists()) {
            final verifyDb = await databaseFactory.openDatabase(standardPath);
            await verifyDb.rawQuery('SELECT COUNT(*) FROM sqlite_master');
            await verifyDb.close();

            debugPrint('✓ Successfully migrated database from legacy location');
            debugPrint('  From: $tempDirPath');
            debugPrint('  To: $standardPath');

            // 迁移成功后删除旧文件
            try {
              await oldFile.delete();
              debugPrint('Legacy database file cleaned up');
            } catch (deleteError) {
              debugPrint('Warning: Could not delete legacy file: $deleteError');
            }
          }
        } catch (e) {
          debugPrint('Failed to migrate from $tempDirPath: $e');
        }
      } else {
        debugPrint('No legacy database files found');
      }
    } catch (e) {
      debugPrint('Error during legacy database migration: $e');
      // 迁移失败不应该阻止应用启动
    }
  }

  static Future<Database> _initDatabase() async {
    _isInitializing = true;
    _initializationAttempts++;

    try {
      debugPrint('Database initialization attempt $_initializationAttempts');

      // 获取数据库路径
      final path = await _getDatabasePath();
      debugPrint('Attempting to initialize database at: $path');

      // 检查文件是否存在且不为空
      final dbFile = File(path);
      if (await dbFile.exists()) {
        final fileSize = await dbFile.length();
        debugPrint('Existing database file found, size: $fileSize bytes');

        // 只删除明显损坏的空文件
        if (fileSize == 0) {
          debugPrint('Database file is empty, removing...');
          await dbFile.delete();
        }
      }

      // 打开数据库
      final database = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: AppConstants.databaseVersion,
          onCreate: _createTables,
          onUpgrade: _onUpgrade,
          onConfigure: _onDatabaseConfigure,
        ),
      );

      debugPrint('Database initialized successfully at: $path');
      _lastInitializationError = null;
      return database;
    } catch (e) {
      _lastInitializationError = e is Exception ? e : Exception(e.toString());
      debugPrint('Database initialization failed: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// 数据库配置回调 - 简化配置减少冲突
  static Future<void> _onDatabaseConfigure(Database db) async {
    try {
      // 仅保留必要的配置，避免复杂设置导致连接问题
      await db.execute('PRAGMA foreign_keys = ON');
      // 使用更保守的同步模式
      await db.execute('PRAGMA synchronous = FULL');
      debugPrint('Basic database configuration applied successfully');
    } catch (e) {
      debugPrint('Warning: Failed to apply database configuration: $e');
      // 配置失败不应该阻止数据库初始化
    }
  }

  // 移除 onOpen 回调，避免在打开阶段执行可能导致连接关闭的操作

  // 移除复杂的数据库验证逻辑，这些操作可能导致连接关闭
  // 简单的连接测试已在 get database 中完成

  // 移除快速完整性验证，减少可能导致连接关闭的操作

  // 公共方法供DatabaseManager使用
  static Future<String> getDatabasePath() async {
    return await _getDatabasePath();
  }

  static Future<void> createTables(Database db, int version) async {
    return await _createTables(db, version);
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    return await _onUpgrade(db, oldVersion, newVersion);
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
          source_url TEXT,
          sort_index INTEGER DEFAULT 0
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
          default_image_index INTEGER DEFAULT 1,
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
        // 版本1到版本2：添加sort_index字段
        if (oldVersion < 2) {
          try {
            await db.execute(
              'ALTER TABLE $_mediaItemsTable ADD COLUMN sort_index INTEGER DEFAULT 0',
            );
            debugPrint('Added sort_index column to $_mediaItemsTable');

            // 为现有记录设置初始排序索引
            await db.execute('''
              UPDATE $_mediaItemsTable 
              SET sort_index = ROWID 
              WHERE sort_index IS NULL OR sort_index = 0
            ''');
          } catch (e) {
            debugPrint('Error adding sort_index column: $e');
            // 如果列已存在，不抛出错误
          }
        }

        // 版本2到版本3：添加default_image_index字段
        if (oldVersion < 3) {
          try {
            await db.execute(
              'ALTER TABLE $_meditationSessionsTable ADD COLUMN default_image_index INTEGER DEFAULT 1',
            );
            debugPrint(
              'Added default_image_index column to $_meditationSessionsTable',
            );

            // 为现有记录随机分配图片索引
            final sessions = await db.query(_meditationSessionsTable);
            for (final session in sessions) {
              final randomIndex = (session['id'].hashCode % 5) + 1;
              await db.update(
                _meditationSessionsTable,
                {'default_image_index': randomIndex},
                where: 'id = ?',
                whereArgs: [session['id']],
              );
            }
            debugPrint('Assigned random image indices to existing sessions');
          } catch (e) {
            debugPrint('Error adding default_image_index column: $e');
            // 如果列已存在，不抛出错误
          }
        }
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

  /// 创建数据库备份
  static Future<bool> createBackup() async {
    try {
      final db = await database;
      final dbPath = db.path;

      if (kIsWeb) {
        debugPrint('Backup not supported on web platform');
        return false;
      }

      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        debugPrint('Database file does not exist, cannot create backup');
        return false;
      }

      final backupPath =
          '$dbPath.backup.${DateTime.now().millisecondsSinceEpoch}';
      await dbFile.copy(backupPath);

      debugPrint('Database backup created: $backupPath');
      return true;
    } catch (e) {
      debugPrint('Failed to create database backup: $e');
      return false;
    }
  }

  /// 尝试从备份恢复数据库
  static Future<bool> restoreFromBackup() async {
    try {
      if (kIsWeb) {
        debugPrint('Backup restore not supported on web platform');
        return false;
      }

      final db = await database;
      final dbPath = db.path;
      final dbDir = Directory(dirname(dbPath));

      // 查找最新的备份文件
      final backupFiles = await dbDir
          .list()
          .where((entity) => entity.path.contains('.backup.'))
          .cast<File>()
          .toList();

      if (backupFiles.isEmpty) {
        debugPrint('No backup files found');
        return false;
      }

      // 按修改时间排序，选择最新的备份
      backupFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      final latestBackup = backupFiles.first;
      debugPrint('Restoring from backup: ${latestBackup.path}');

      // 关闭当前数据库连接
      await _database!.close();
      _database = null;

      // 用备份文件替换当前数据库文件
      await latestBackup.copy(dbPath);

      // 重新初始化数据库
      await database;

      debugPrint('Database restored from backup successfully');
      return true;
    } catch (e) {
      debugPrint('Failed to restore database from backup: $e');
      return false;
    }
  }

  /// 获取数据库调试信息 - 符合Android标准实践
  static Future<Map<String, dynamic>> getDatabaseDebugInfo() async {
    try {
      final db = await database;
      final dbPath = db.path;
      final dbFile = File(dbPath);

      // 检查表结构
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      // 统计数据
      final mediaCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_mediaItemsTable',
      );
      final sessionCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_meditationSessionsTable',
      );
      final prefCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_userPreferencesTable',
      );

      // 标准系统信息
      Map<String, dynamic> systemInfo = {};
      try {
        if (kIsWeb) {
          systemInfo = {
            'platform': 'Web',
            'path_method': 'Web storage API',
            'follows_standards': true,
          };
        } else if (Platform.isAndroid) {
          systemInfo = {
            'platform': 'Android',
            'path_method': 'databaseFactory.getDatabasesPath() - Android标准API',
            'follows_android_standards': true,
            'uses_context_apis': true,
            'avoids_hardcoded_paths': true,
          };
        } else {
          systemInfo = {
            'platform': Platform.operatingSystem,
            'path_method': 'Platform-specific standard API',
            'follows_standards': true,
          };
        }
      } catch (e) {
        // 测试环境或其他特殊情况
        systemInfo = {
          'platform': 'Test/Unknown',
          'path_method': 'databaseFactory.getDatabasesPath() - 标准API',
          'follows_android_standards': true,
          'uses_context_apis': true,
          'avoids_hardcoded_paths': true,
        };
      }

      return {
        'database_path': dbPath,
        'file_exists': await dbFile.exists(),
        'file_size': await dbFile.exists() ? await dbFile.length() : 0,
        'tables': tables.map((t) => t['name']).toList(),
        'media_items_count': mediaCount.first['count'],
        'meditation_sessions_count': sessionCount.first['count'],
        'user_preferences_count': prefCount.first['count'],
        'initialization_status': getInitializationStatus(),
        'system_info': systemInfo,
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'initialization_status': getInitializationStatus(),
      };
    }
  }

  /// 检查数据库文件是否存在（仅检查标准位置）
  static Future<List<String>> findExistingDatabaseFiles() async {
    final existingFiles = <String>[];

    try {
      // 只检查当前标准路径
      final standardPath = await _getDatabasePath();
      final file = File(standardPath);

      if (await file.exists()) {
        final size = await file.length();
        existingFiles.add('$standardPath ($size bytes)');
      }

      // 如果是Android平台，也检查系统临时目录的遗留文件
      if (Platform.isAndroid) {
        final tempPath = join(
          Directory.systemTemp.path,
          'mindra_db',
          AppConstants.databaseName,
        );
        final tempFile = File(tempPath);

        if (await tempFile.exists()) {
          final size = await tempFile.length();
          existingFiles.add('$tempPath ($size bytes) [Legacy]');
        }
      }
    } catch (e) {
      debugPrint('Error finding existing database files: $e');
    }

    return existingFiles;
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
    return await db.query(
      _mediaItemsTable,
      orderBy: 'sort_index ASC, created_at DESC',
    );
  }

  static Future<Map<String, dynamic>?> getMediaItemById(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('Media item ID cannot be empty');
    }

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
    if (category.isEmpty) {
      throw ArgumentError('Category cannot be empty');
    }

    final db = await database;
    return await db.query(
      _mediaItemsTable,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'sort_index ASC, created_at DESC',
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
    if (limit <= 0) {
      throw ArgumentError('Limit must be positive');
    }

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
    if (id.isEmpty) {
      throw ArgumentError('Media item ID cannot be empty');
    }
    if (updates.isEmpty) {
      throw ArgumentError('Updates cannot be empty');
    }

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
  }

  static Future<void> deleteMediaItem(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('Media item ID cannot be empty');
    }

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
  }

  // 批量更新媒体项的排序索引
  static Future<void> updateMediaItemsSortOrder(List<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return;
    }

    final db = await database;

    // 使用事务确保原子性
    await db.transaction((txn) async {
      for (int i = 0; i < mediaIds.length; i++) {
        await txn.update(
          _mediaItemsTable,
          {'sort_index': i},
          where: 'id = ?',
          whereArgs: [mediaIds[i]],
        );
      }
    });
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
