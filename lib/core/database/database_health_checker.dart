import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'database_helper.dart';

/// 数据库健康检查和自动修复工具
class DatabaseHealthChecker {
  static const Duration _checkInterval = Duration(minutes: 30);
  static DateTime? _lastHealthCheck;

  /// 执行完整的数据库健康检查
  static Future<DatabaseHealthReport> performHealthCheck() async {
    debugPrint('Starting database health check...');

    final report = DatabaseHealthReport();
    final startTime = DateTime.now();

    try {
      // 1. 检查数据库连接状态
      await _checkDatabaseConnection(report);

      // 2. 检查表结构完整性
      await _checkTableStructure(report);

      // 3. 检查数据完整性
      await _checkDataIntegrity(report);

      // 4. 检查索引状态
      await _checkIndexes(report);

      // 5. 检查数据库性能
      await _checkPerformance(report);

      // 6. 检查存储空间
      await _checkStorageSpace(report);

      report.isHealthy = report.issues.isEmpty;
      report.checkDuration = DateTime.now().difference(startTime);

      debugPrint(
        'Database health check completed in ${report.checkDuration?.inMilliseconds ?? 0}ms',
      );
      debugPrint(
        'Health status: ${report.isHealthy ? "HEALTHY" : "ISSUES FOUND"}',
      );

      if (report.issues.isNotEmpty) {
        debugPrint('Found ${report.issues.length} issues:');
        for (final issue in report.issues) {
          debugPrint(
            '  - ${issue.severity.name.toUpperCase()}: ${issue.description}',
          );
        }
      }
    } catch (e) {
      debugPrint('Database health check failed: $e');
      report.issues.add(
        DatabaseIssue(
          type: DatabaseIssueType.connectionError,
          severity: IssueSeverity.critical,
          description: 'Health check failed: $e',
          suggestion: 'Try restarting the application or clearing app data',
        ),
      );
      report.isHealthy = false;
    }

    _lastHealthCheck = DateTime.now();
    return report;
  }

  /// 检查是否需要进行健康检查
  static bool shouldPerformHealthCheck() {
    if (_lastHealthCheck == null) return true;

    final timeSinceLastCheck = DateTime.now().difference(_lastHealthCheck!);
    return timeSinceLastCheck > _checkInterval;
  }

  /// 自动修复发现的问题
  static Future<List<String>> autoRepairIssues(
    DatabaseHealthReport report,
  ) async {
    final repairedIssues = <String>[];

    debugPrint('Starting auto-repair for ${report.issues.length} issues...');

    for (final issue in report.issues) {
      try {
        switch (issue.type) {
          case DatabaseIssueType.corruptedData:
            await _repairCorruptedData(issue);
            repairedIssues.add('Repaired corrupted data: ${issue.description}');
            break;

          case DatabaseIssueType.missingTable:
            await _repairMissingTable(issue);
            repairedIssues.add('Recreated missing table: ${issue.description}');
            break;

          case DatabaseIssueType.missingIndex:
            await _repairMissingIndex(issue);
            repairedIssues.add('Recreated missing index: ${issue.description}');
            break;

          case DatabaseIssueType.connectionError:
            await _repairConnection();
            repairedIssues.add('Repaired database connection');
            break;

          case DatabaseIssueType.performanceIssue:
            await _optimizePerformance(issue);
            repairedIssues.add('Optimized performance: ${issue.description}');
            break;

          case DatabaseIssueType.storageIssue:
            await _cleanupStorage(issue);
            repairedIssues.add('Cleaned up storage: ${issue.description}');
            break;
        }
      } catch (e) {
        debugPrint('Failed to repair issue ${issue.type}: $e');
      }
    }

    debugPrint('Auto-repair completed. Fixed ${repairedIssues.length} issues.');
    return repairedIssues;
  }

  /// 检查数据库连接状态
  static Future<void> _checkDatabaseConnection(
    DatabaseHealthReport report,
  ) async {
    try {
      final db = await DatabaseHelper.database;

      if (!db.isOpen) {
        report.issues.add(
          DatabaseIssue(
            type: DatabaseIssueType.connectionError,
            severity: IssueSeverity.critical,
            description: 'Database is not open',
            suggestion: 'Restart the application',
          ),
        );
        return;
      }

      // 尝试执行简单查询
      await db.rawQuery('SELECT 1');
    } catch (e) {
      report.issues.add(
        DatabaseIssue(
          type: DatabaseIssueType.connectionError,
          severity: IssueSeverity.critical,
          description: 'Database connection test failed: $e',
          suggestion: 'Check database file permissions and disk space',
        ),
      );
    }
  }

  /// 检查表结构完整性
  static Future<void> _checkTableStructure(DatabaseHealthReport report) async {
    try {
      final db = await DatabaseHelper.database;

      // 检查必要的表是否存在
      final expectedTables = [
        'media_items',
        'meditation_sessions',
        'user_preferences',
      ];

      for (final tableName in expectedTables) {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName],
        );

        if (result.isEmpty) {
          report.issues.add(
            DatabaseIssue(
              type: DatabaseIssueType.missingTable,
              severity: IssueSeverity.critical,
              description: 'Missing table: $tableName',
              suggestion: 'Recreate the database schema',
              metadata: {'tableName': tableName},
            ),
          );
        }
      }
    } catch (e) {
      report.issues.add(
        DatabaseIssue(
          type: DatabaseIssueType.connectionError,
          severity: IssueSeverity.high,
          description: 'Table structure check failed: $e',
          suggestion: 'Check database integrity',
        ),
      );
    }
  }

  /// 检查数据完整性
  static Future<void> _checkDataIntegrity(DatabaseHealthReport report) async {
    try {
      final db = await DatabaseHelper.database;

      // 检查PRAGMA integrity_check
      final integrityResult = await db.rawQuery('PRAGMA integrity_check');
      if (integrityResult.isNotEmpty) {
        final result = integrityResult.first.values.first;
        if (result != 'ok') {
          report.issues.add(
            DatabaseIssue(
              type: DatabaseIssueType.corruptedData,
              severity: IssueSeverity.high,
              description: 'Database integrity check failed: $result',
              suggestion: 'Consider rebuilding the database',
            ),
          );
        }
      }

      // 检查外键约束
      final foreignKeyResult = await db.rawQuery('PRAGMA foreign_key_check');
      if (foreignKeyResult.isNotEmpty) {
        report.issues.add(
          DatabaseIssue(
            type: DatabaseIssueType.corruptedData,
            severity: IssueSeverity.medium,
            description: 'Foreign key constraint violations found',
            suggestion: 'Clean up orphaned records',
          ),
        );
      }
    } catch (e) {
      report.issues.add(
        DatabaseIssue(
          type: DatabaseIssueType.corruptedData,
          severity: IssueSeverity.high,
          description: 'Data integrity check failed: $e',
          suggestion: 'Check database file corruption',
        ),
      );
    }
  }

  /// 检查索引状态
  static Future<void> _checkIndexes(DatabaseHealthReport report) async {
    try {
      final db = await DatabaseHelper.database;

      // 检查预期的索引是否存在
      final expectedIndexes = [
        'idx_media_items_created_at',
        'idx_media_items_category',
        'idx_meditation_sessions_start_time',
      ];

      for (final indexName in expectedIndexes) {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
          [indexName],
        );

        if (result.isEmpty) {
          report.issues.add(
            DatabaseIssue(
              type: DatabaseIssueType.missingIndex,
              severity: IssueSeverity.medium,
              description: 'Missing index: $indexName',
              suggestion: 'Recreate the index to improve performance',
              metadata: {'indexName': indexName},
            ),
          );
        }
      }
    } catch (e) {
      report.issues.add(
        DatabaseIssue(
          type: DatabaseIssueType.performanceIssue,
          severity: IssueSeverity.low,
          description: 'Index check failed: $e',
          suggestion: 'Verify database structure',
        ),
      );
    }
  }

  /// 检查数据库性能
  static Future<void> _checkPerformance(DatabaseHealthReport report) async {
    try {
      final db = await DatabaseHelper.database;

      // 测试查询性能
      final startTime = DateTime.now();
      await db.rawQuery('SELECT COUNT(*) FROM media_items');
      final queryTime = DateTime.now().difference(startTime);

      if (queryTime.inMilliseconds > 1000) {
        // 超过1秒
        report.issues.add(
          DatabaseIssue(
            type: DatabaseIssueType.performanceIssue,
            severity: IssueSeverity.medium,
            description:
                'Slow query performance: ${queryTime.inMilliseconds}ms',
            suggestion: 'Consider database optimization or cleanup',
          ),
        );
      }

      // 检查数据库大小
      final dbStats = await db.rawQuery('PRAGMA page_count');
      final pageCount = dbStats.first.values.first as int;
      final dbSize = pageCount * 4096; // 假设页面大小为4KB

      if (dbSize > 100 * 1024 * 1024) {
        // 超过100MB
        report.issues.add(
          DatabaseIssue(
            type: DatabaseIssueType.storageIssue,
            severity: IssueSeverity.low,
            description:
                'Large database size: ${(dbSize / 1024 / 1024).toStringAsFixed(1)}MB',
            suggestion: 'Consider archiving old data',
          ),
        );
      }
    } catch (e) {
      debugPrint('Performance check failed: $e');
    }
  }

  /// 检查存储空间
  static Future<void> _checkStorageSpace(DatabaseHealthReport report) async {
    if (kIsWeb) return; // Web平台不需要检查存储空间

    try {
      // 获取数据库文件路径
      final dbPath = await DatabaseHelper.database.then((db) => db.path);
      if (dbPath == null) return;

      final dbFile = File(dbPath);
      if (!await dbFile.exists()) return;

      final dbDirectory = dbFile.parent;

      // 检查可用空间（简化版本，实际实现可能需要平台特定代码）
      try {
        final stat = await dbDirectory.stat();
        // 这里可以添加更详细的磁盘空间检查逻辑
      } catch (e) {
        debugPrint('Storage space check failed: $e');
      }
    } catch (e) {
      debugPrint('Storage space check error: $e');
    }
  }

  // 修复方法
  static Future<void> _repairCorruptedData(DatabaseIssue issue) async {
    debugPrint('Repairing corrupted data: ${issue.description}');
    // 实现数据修复逻辑
    await DatabaseHelper.forceReinitialize();
  }

  static Future<void> _repairMissingTable(DatabaseIssue issue) async {
    final tableName = issue.metadata?['tableName'] as String?;
    if (tableName == null) return;

    debugPrint('Recreating missing table: $tableName');
    await DatabaseHelper.forceReinitialize();
  }

  static Future<void> _repairMissingIndex(DatabaseIssue issue) async {
    final indexName = issue.metadata?['indexName'] as String?;
    if (indexName == null) return;

    debugPrint('Recreating missing index: $indexName');

    final db = await DatabaseHelper.database;

    // 根据索引名称重新创建索引
    switch (indexName) {
      case 'idx_media_items_created_at':
        await db.execute(
          'CREATE INDEX idx_media_items_created_at ON media_items(created_at)',
        );
        break;
      case 'idx_media_items_category':
        await db.execute(
          'CREATE INDEX idx_media_items_category ON media_items(category)',
        );
        break;
      case 'idx_meditation_sessions_start_time':
        await db.execute(
          'CREATE INDEX idx_meditation_sessions_start_time ON meditation_sessions(start_time)',
        );
        break;
    }
  }

  static Future<void> _repairConnection() async {
    debugPrint('Repairing database connection');
    await DatabaseHelper.forceReinitialize();
  }

  static Future<void> _optimizePerformance(DatabaseIssue issue) async {
    debugPrint('Optimizing database performance');

    try {
      final db = await DatabaseHelper.database;

      // 运行VACUUM命令清理数据库
      await db.execute('VACUUM');

      // 重新分析统计信息
      await db.execute('ANALYZE');
    } catch (e) {
      debugPrint('Performance optimization failed: $e');
    }
  }

  static Future<void> _cleanupStorage(DatabaseIssue issue) async {
    debugPrint('Cleaning up database storage');

    try {
      final db = await DatabaseHelper.database;

      // 清理旧的会话记录（保留最近30天）
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      await db.delete(
        'meditation_sessions',
        where: 'start_time < ?',
        whereArgs: [thirtyDaysAgo.millisecondsSinceEpoch],
      );

      // 运行VACUUM释放空间
      await db.execute('VACUUM');
    } catch (e) {
      debugPrint('Storage cleanup failed: $e');
    }
  }
}

/// 数据库健康报告
class DatabaseHealthReport {
  bool isHealthy = true;
  final List<DatabaseIssue> issues = [];
  Duration? checkDuration;
  DateTime checkTime = DateTime.now();

  /// 获取按严重程度分组的问题
  Map<IssueSeverity, List<DatabaseIssue>> get issuesBySeverity {
    final grouped = <IssueSeverity, List<DatabaseIssue>>{};
    for (final issue in issues) {
      grouped.putIfAbsent(issue.severity, () => []).add(issue);
    }
    return grouped;
  }

  /// 获取最高严重程度
  IssueSeverity? get highestSeverity {
    if (issues.isEmpty) return null;

    final severities = issues.map((i) => i.severity).toSet();
    if (severities.contains(IssueSeverity.critical))
      return IssueSeverity.critical;
    if (severities.contains(IssueSeverity.high)) return IssueSeverity.high;
    if (severities.contains(IssueSeverity.medium)) return IssueSeverity.medium;
    return IssueSeverity.low;
  }

  @override
  String toString() {
    return 'DatabaseHealthReport(isHealthy: $isHealthy, issues: ${issues.length}, duration: ${checkDuration?.inMilliseconds}ms)';
  }
}

/// 数据库问题
class DatabaseIssue {
  final DatabaseIssueType type;
  final IssueSeverity severity;
  final String description;
  final String suggestion;
  final Map<String, dynamic>? metadata;

  DatabaseIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.suggestion,
    this.metadata,
  });

  @override
  String toString() {
    return 'DatabaseIssue(type: $type, severity: $severity, description: $description)';
  }
}

/// 数据库问题类型
enum DatabaseIssueType {
  connectionError,
  missingTable,
  missingIndex,
  corruptedData,
  performanceIssue,
  storageIssue,
}

/// 问题严重程度
enum IssueSeverity { low, medium, high, critical }
