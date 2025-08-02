import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'dart:async';
import '../constants/app_constants.dart';
import 'database_helper.dart';

/// 数据库管理器 - 单例模式实现
/// 负责管理数据库的生命周期、连接状态和操作
class DatabaseManager {
  // 私有构造函数
  DatabaseManager._();

  // 单例实例
  static DatabaseManager? _instance;

  // 获取单例实例
  static DatabaseManager get instance {
    _instance ??= DatabaseManager._();
    return _instance!;
  }

  // 数据库实例
  Database? _database;

  // 表名常量
  static const String mediaItemsTable = 'media_items';
  static const String meditationSessionsTable = 'meditation_sessions';
  static const String userPreferencesTable = 'user_preferences';

  // 初始化状态管理
  bool _isInitializing = false;
  Exception? _lastInitializationError;
  int _initializationAttempts = 0;
  Completer<Database>? _initializationCompleter;

  // 数据库路径缓存
  String? _cachedDatabasePath;

  // 自动备份配置
  Timer? _autoBackupTimer;
  static const Duration autoBackupInterval = Duration(hours: 24);
  static const int maxBackupCount = 5;

  /// 获取数据库实例
  Future<Database> get database async {
    // 如果数据库已经初始化且连接正常，直接返回
    if (_database != null && _database!.isOpen) {
      try {
        await _database!.rawQuery('SELECT 1');
        return _database!;
      } catch (e) {
        debugPrint('Database connection failed, reinitializing: $e');
        await _closeDatabase();
      }
    }

    // 如果正在初始化，等待初始化完成
    if (_initializationCompleter != null &&
        !_initializationCompleter!.isCompleted) {
      debugPrint('Database initialization in progress, waiting...');
      try {
        final database = await _initializationCompleter!.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint('Database initialization timeout after 30 seconds');
            throw TimeoutException('Database initialization timeout');
          },
        );
        return database;
      } catch (e) {
        debugPrint('Error waiting for database initialization: $e');
        _initializationCompleter = null;
        _isInitializing = false;
      }
    }

    // 开始新的初始化
    return await _initializeDatabase();
  }

  /// 初始化数据库
  Future<Database> _initializeDatabase() async {
    _initializationCompleter = Completer<Database>();
    _isInitializing = true;
    _initializationAttempts++;

    try {
      debugPrint(
        'Starting database initialization (attempt $_initializationAttempts)',
      );

      // 获取数据库路径
      final path = await _getDatabasePath();
      debugPrint('Database path: $path');

      // 检查并处理现有数据库文件
      await _checkExistingDatabase(path);

      // 打开数据库
      final factory = databaseFactory;
      final database = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: AppConstants.databaseVersion,
          onCreate: _createTables,
          onUpgrade: _onUpgrade,
          onConfigure: _onConfigure,
          onOpen: _onOpen,
        ),
      );

      _database = database;
      _lastInitializationError = null;

      if (!_initializationCompleter!.isCompleted) {
        _initializationCompleter!.complete(database);
      }

      // 启动自动备份
      _startAutoBackup();

      debugPrint('Database initialized successfully');
      return database;
    } catch (e) {
      _lastInitializationError = e is Exception ? e : Exception(e.toString());

      if (!_initializationCompleter!.isCompleted) {
        _initializationCompleter!.completeError(e);
      }

      debugPrint('Database initialization failed: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// 获取数据库路径
  Future<String> _getDatabasePath() async {
    // 如果已缓存路径，直接返回
    if (_cachedDatabasePath != null) {
      return _cachedDatabasePath!;
    }

    if (kIsWeb) {
      _cachedDatabasePath = 'mindra_web.db';
      return _cachedDatabasePath!;
    }

    // 使用DatabaseHelper的路径获取逻辑
    _cachedDatabasePath = await DatabaseHelper.getDatabasePath();
    return _cachedDatabasePath!;
  }

  /// 检查现有数据库
  Future<void> _checkExistingDatabase(String path) async {
    final dbFile = File(path);
    if (!await dbFile.exists()) {
      return;
    }

    final fileSize = await dbFile.length();
    debugPrint('Existing database file found, size: $fileSize bytes');

    // 如果文件为空，删除
    if (fileSize == 0) {
      debugPrint('Database file is empty, removing...');
      await dbFile.delete();
      return;
    }

    // 验证数据库完整性
    final isValid = await _validateDatabase(path);
    if (!isValid) {
      // 备份损坏的数据库
      final backupPath =
          '$path.corrupted.${DateTime.now().millisecondsSinceEpoch}';
      await dbFile.copy(backupPath);
      debugPrint('Backed up corrupted database to: $backupPath');

      // 删除损坏的数据库
      await dbFile.delete();
      debugPrint('Removed corrupted database file');
    }
  }

  /// 验证数据库完整性
  Future<bool> _validateDatabase(String path) async {
    try {
      final factory = databaseFactory;
      final testDb = await factory.openDatabase(path);

      // 检查表结构
      final tables = await testDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      final tableNames = tables.map((t) => t['name'] as String).toList();
      final requiredTables = [
        mediaItemsTable,
        meditationSessionsTable,
        userPreferencesTable,
      ];

      final missingTables = requiredTables
          .where((t) => !tableNames.contains(t))
          .toList();

      if (missingTables.isNotEmpty) {
        debugPrint('Missing tables: ${missingTables.join(", ")}');
        await testDb.close();
        return false;
      }

      // 尝试查询每个表
      for (final table in requiredTables) {
        await testDb.rawQuery('SELECT COUNT(*) FROM $table');
      }

      await testDb.close();
      return true;
    } catch (e) {
      debugPrint('Database validation failed: $e');
      return false;
    }
  }

  /// 创建表
  Future<void> _createTables(Database db, int version) async {
    await DatabaseHelper.createTables(db, version);
  }

  /// 升级数据库
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await DatabaseHelper.onUpgrade(db, oldVersion, newVersion);
  }

  /// 配置数据库
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
  }

  /// 数据库打开回调
  Future<void> _onOpen(Database db) async {
    debugPrint('Database opened successfully');

    // 执行完整性检查
    final result = await db.rawQuery('PRAGMA integrity_check');
    if (result.isNotEmpty && result.first.values.first != 'ok') {
      debugPrint('Database integrity check failed: $result');
    }
  }

  /// 关闭数据库
  Future<void> _closeDatabase() async {
    if (_database != null) {
      try {
        await _database!.close();
      } catch (e) {
        debugPrint('Error closing database: $e');
      }
      _database = null;
    }
  }

  /// 启动自动备份
  void _startAutoBackup() {
    _autoBackupTimer?.cancel();

    if (kIsWeb) {
      return;
    }

    _autoBackupTimer = Timer.periodic(autoBackupInterval, (_) async {
      try {
        await createBackup();
      } catch (e) {
        debugPrint('Auto backup failed: $e');
      }
    });

    debugPrint(
      'Auto backup scheduled every ${autoBackupInterval.inHours} hours',
    );
  }

  /// 创建备份
  Future<bool> createBackup() async {
    try {
      if (_database == null || !_database!.isOpen) {
        debugPrint('Database not initialized, cannot create backup');
        return false;
      }

      final dbPath = _database!.path;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupDir = Directory(join(dirname(dbPath), 'backups'));

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final backupPath = join(backupDir.path, 'mindra_backup_$timestamp.db');

      // 使用在线备份API
      try {
        await _database!.execute('VACUUM INTO ?', [backupPath]);
        debugPrint('Database backup created using VACUUM INTO at: $backupPath');
      } catch (e) {
        // 回退到文件复制方法
        debugPrint('VACUUM INTO not supported, using file copy: $e');
        await _database!.execute('PRAGMA wal_checkpoint(FULL)');

        final dbFile = File(dbPath);
        await dbFile.copy(backupPath);
      }

      // 清理旧备份
      await _cleanupOldBackups(backupDir);

      return true;
    } catch (e) {
      debugPrint('Failed to create backup: $e');
      return false;
    }
  }

  /// 清理旧备份
  Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final backupFiles = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.db'))
          .cast<File>()
          .toList();

      if (backupFiles.length <= maxBackupCount) {
        return;
      }

      // 按修改时间排序
      backupFiles.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      // 删除旧备份
      for (int i = maxBackupCount; i < backupFiles.length; i++) {
        await backupFiles[i].delete();
        debugPrint('Deleted old backup: ${backupFiles[i].path}');
      }
    } catch (e) {
      debugPrint('Error cleaning up old backups: $e');
    }
  }

  /// 从备份恢复
  Future<bool> restoreFromBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        debugPrint('Backup file not found: $backupPath');
        return false;
      }

      // 验证备份文件
      if (!await _validateDatabase(backupPath)) {
        debugPrint('Backup file is corrupted: $backupPath');
        return false;
      }

      // 关闭当前数据库
      await _closeDatabase();

      // 替换数据库文件
      final dbPath = await _getDatabasePath();
      await backupFile.copy(dbPath);

      // 重新初始化
      await _initializeDatabase();

      debugPrint('Database restored from backup: $backupPath');
      return true;
    } catch (e) {
      debugPrint('Failed to restore from backup: $e');
      return false;
    }
  }

  /// 获取数据库状态
  Map<String, dynamic> get status {
    return {
      'isInitialized': _database != null,
      'isOpen': _database?.isOpen ?? false,
      'isInitializing': _isInitializing,
      'initializationAttempts': _initializationAttempts,
      'lastError': _lastInitializationError?.toString(),
      'databasePath': _cachedDatabasePath,
      'autoBackupEnabled': _autoBackupTimer != null,
    };
  }

  /// 重置数据库管理器
  Future<void> reset() async {
    _autoBackupTimer?.cancel();
    await _closeDatabase();
    _cachedDatabasePath = null;
    _initializationCompleter = null;
    _initializationAttempts = 0;
    _lastInitializationError = null;
  }

  /// 释放资源
  Future<void> dispose() async {
    _autoBackupTimer?.cancel();
    await _closeDatabase();
    _instance = null;
  }
}
