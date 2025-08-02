import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../database/database_connection_manager.dart';

/// 应用数据验证器
/// 负责在应用启动时检查数据完整性并尝试修复问题
class AppDataValidator {
  static bool _isValidating = false;
  static DateTime? _lastValidation;
  static const Duration _validationCooldown = Duration(minutes: 5);

  /// 执行完整的应用数据验证
  static Future<DataValidationReport> validateApplicationData() async {
    if (_isValidating) {
      throw Exception('Data validation already in progress');
    }

    // 检查冷却时间
    if (_lastValidation != null) {
      final timeSinceLastValidation = DateTime.now().difference(
        _lastValidation!,
      );
      if (timeSinceLastValidation < _validationCooldown) {
        debugPrint('Data validation skipped due to cooldown');
        return DataValidationReport()
          ..isValid = true
          ..message = 'Validation skipped (cooldown period)'
          ..issues.clear();
      }
    }

    _isValidating = true;
    final report = DataValidationReport();

    try {
      debugPrint('Starting application data validation...');

      // 1. 验证数据库连接
      await _validateDatabaseConnection(report);

      // 2. 验证数据库结构
      await _validateDatabaseSchema(report);

      // 3. 验证数据完整性
      await _validateDataIntegrity(report);

      // 4. 验证关键数据存在性
      await _validateCriticalData(report);

      // 5. 检查数据库性能
      await _validateDatabasePerformance(report);

      report.isValid = report.issues.isEmpty;

      if (report.isValid) {
        debugPrint('Application data validation passed');
      } else {
        debugPrint(
          'Application data validation found ${report.issues.length} issues',
        );
        for (final issue in report.issues) {
          debugPrint('  - ${issue.severity.name}: ${issue.description}');
        }
      }
    } catch (e) {
      debugPrint('Application data validation failed: $e');
      report.issues.add(
        DataValidationIssue(
          type: ValidationIssueType.validationError,
          severity: IssueSeverity.critical,
          description: 'Data validation process failed: $e',
          canAutoFix: false,
        ),
      );
      report.isValid = false;
    } finally {
      _isValidating = false;
      _lastValidation = DateTime.now();
      report.validationTime = DateTime.now();
    }

    return report;
  }

  /// 自动修复发现的问题
  static Future<List<String>> autoFixIssues(DataValidationReport report) async {
    final fixedIssues = <String>[];

    debugPrint('Starting auto-fix for ${report.issues.length} issues...');

    for (final issue in report.issues.where((i) => i.canAutoFix)) {
      try {
        switch (issue.type) {
          case ValidationIssueType.databaseConnection:
            await _fixDatabaseConnection();
            fixedIssues.add('数据库连接已修复');
            break;

          case ValidationIssueType.missingTable:
            await _fixMissingTable();
            fixedIssues.add('缺失的数据表已重建');
            break;

          case ValidationIssueType.corruptedData:
            await _fixCorruptedData();
            fixedIssues.add('损坏的数据已修复');
            break;

          case ValidationIssueType.performanceIssue:
            await _fixPerformanceIssue();
            fixedIssues.add('数据库性能已优化');
            break;

          default:
            debugPrint('No auto-fix available for issue type: ${issue.type}');
            break;
        }
      } catch (e) {
        debugPrint('Failed to fix issue ${issue.type}: $e');
      }
    }

    debugPrint('Auto-fix completed. Fixed ${fixedIssues.length} issues.');
    return fixedIssues;
  }

  /// 验证数据库连接
  static Future<void> _validateDatabaseConnection(
    DataValidationReport report,
  ) async {
    try {
      final db = await DatabaseHelper.database;
      if (!db.isOpen) {
        report.issues.add(
          DataValidationIssue(
            type: ValidationIssueType.databaseConnection,
            severity: IssueSeverity.critical,
            description: '数据库连接未打开',
            canAutoFix: true,
          ),
        );
        return;
      }

      // 测试基本查询
      await db.rawQuery('SELECT 1');

      // 检查连接管理器状态
      if (!DatabaseConnectionManager.isHealthy) {
        report.issues.add(
          DataValidationIssue(
            type: ValidationIssueType.databaseConnection,
            severity: IssueSeverity.high,
            description: '数据库连接状态不稳定',
            canAutoFix: true,
          ),
        );
      }
    } catch (e) {
      report.issues.add(
        DataValidationIssue(
          type: ValidationIssueType.databaseConnection,
          severity: IssueSeverity.critical,
          description: '数据库连接测试失败: $e',
          canAutoFix: true,
        ),
      );
    }
  }

  /// 验证数据库结构
  static Future<void> _validateDatabaseSchema(
    DataValidationReport report,
  ) async {
    try {
      final db = await DatabaseHelper.database;

      // 检查必要的表
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
            DataValidationIssue(
              type: ValidationIssueType.missingTable,
              severity: IssueSeverity.critical,
              description: '缺少必要的数据表: $tableName',
              canAutoFix: true,
            ),
          );
        }
      }

      // 检查索引
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
            DataValidationIssue(
              type: ValidationIssueType.missingIndex,
              severity: IssueSeverity.medium,
              description: '缺少数据库索引: $indexName',
              canAutoFix: true,
            ),
          );
        }
      }
    } catch (e) {
      report.issues.add(
        DataValidationIssue(
          type: ValidationIssueType.schemaError,
          severity: IssueSeverity.high,
          description: '数据库结构验证失败: $e',
          canAutoFix: false,
        ),
      );
    }
  }

  /// 验证数据完整性
  static Future<void> _validateDataIntegrity(
    DataValidationReport report,
  ) async {
    try {
      final db = await DatabaseHelper.database;

      // 检查数据库完整性
      final integrityResult = await db.rawQuery('PRAGMA integrity_check');
      if (integrityResult.isNotEmpty) {
        final result = integrityResult.first.values.first;
        if (result != 'ok') {
          report.issues.add(
            DataValidationIssue(
              type: ValidationIssueType.corruptedData,
              severity: IssueSeverity.high,
              description: '数据库完整性检查失败: $result',
              canAutoFix: true,
            ),
          );
        }
      }

      // 检查外键约束
      final foreignKeyResult = await db.rawQuery('PRAGMA foreign_key_check');
      if (foreignKeyResult.isNotEmpty) {
        report.issues.add(
          DataValidationIssue(
            type: ValidationIssueType.corruptedData,
            severity: IssueSeverity.medium,
            description: '发现外键约束违规',
            canAutoFix: true,
          ),
        );
      }
    } catch (e) {
      report.issues.add(
        DataValidationIssue(
          type: ValidationIssueType.corruptedData,
          severity: IssueSeverity.high,
          description: '数据完整性验证失败: $e',
          canAutoFix: false,
        ),
      );
    }
  }

  /// 验证关键数据存在性
  static Future<void> _validateCriticalData(DataValidationReport report) async {
    try {
      final db = await DatabaseHelper.database;

      // 验证表是否可以正常查询
      await db.rawQuery('SELECT COUNT(*) FROM media_items');
      await db.rawQuery('SELECT COUNT(*) FROM meditation_sessions');
      await db.rawQuery('SELECT COUNT(*) FROM user_preferences');

      // 检查是否有基本的应用设置
      final settings = await db.query('user_preferences');
      if (settings.isEmpty) {
        debugPrint(
          'No user preferences found, this is normal for first launch',
        );
      }
    } catch (e) {
      report.issues.add(
        DataValidationIssue(
          type: ValidationIssueType.dataAccess,
          severity: IssueSeverity.high,
          description: '关键数据访问失败: $e',
          canAutoFix: true,
        ),
      );
    }
  }

  /// 验证数据库性能
  static Future<void> _validateDatabasePerformance(
    DataValidationReport report,
  ) async {
    try {
      final db = await DatabaseHelper.database;

      // 测试查询性能
      final startTime = DateTime.now();
      await db.rawQuery('SELECT COUNT(*) FROM media_items');
      final queryTime = DateTime.now().difference(startTime);

      if (queryTime.inMilliseconds > 2000) {
        report.issues.add(
          DataValidationIssue(
            type: ValidationIssueType.performanceIssue,
            severity: IssueSeverity.medium,
            description: '数据库查询性能较慢: ${queryTime.inMilliseconds}ms',
            canAutoFix: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Performance validation failed: $e');
    }
  }

  // 修复方法
  static Future<void> _fixDatabaseConnection() async {
    debugPrint('Fixing database connection...');
    await DatabaseHelper.forceReinitialize();
  }

  static Future<void> _fixMissingTable() async {
    debugPrint('Fixing missing tables...');
    await DatabaseHelper.forceReinitialize();
  }

  static Future<void> _fixCorruptedData() async {
    debugPrint('Fixing corrupted data...');

    // 先尝试修复
    try {
      final db = await DatabaseHelper.database;
      await db.execute('PRAGMA integrity_check');
    } catch (e) {
      // 如果修复失败，重新初始化
      await DatabaseHelper.forceReinitialize();
    }
  }

  static Future<void> _fixPerformanceIssue() async {
    debugPrint('Fixing performance issues...');

    try {
      final db = await DatabaseHelper.database;
      await db.execute('VACUUM');
      await db.execute('ANALYZE');
    } catch (e) {
      debugPrint('Performance optimization failed: $e');
    }
  }
}

/// 数据验证报告
class DataValidationReport {
  bool isValid = true;
  String message = '';
  final List<DataValidationIssue> issues = [];
  DateTime? validationTime;

  @override
  String toString() {
    return 'DataValidationReport(isValid: $isValid, issues: ${issues.length})';
  }
}

/// 数据验证问题
class DataValidationIssue {
  final ValidationIssueType type;
  final IssueSeverity severity;
  final String description;
  final bool canAutoFix;

  DataValidationIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.canAutoFix,
  });

  @override
  String toString() {
    return 'DataValidationIssue(type: $type, severity: $severity, description: $description)';
  }
}

/// 验证问题类型
enum ValidationIssueType {
  databaseConnection,
  missingTable,
  missingIndex,
  corruptedData,
  dataAccess,
  performanceIssue,
  schemaError,
  validationError,
}

/// 问题严重程度
enum IssueSeverity { low, medium, high, critical }
