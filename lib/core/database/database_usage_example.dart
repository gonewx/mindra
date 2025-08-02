import 'package:flutter/foundation.dart';
import 'database_manager.dart';
import 'database_helper.dart';

/// 数据库使用示例
/// 展示如何使用新的DatabaseManager单例模式
class DatabaseUsageExample {
  /// 使用新的DatabaseManager（推荐）
  static Future<void> usingDatabaseManager() async {
    // 获取数据库管理器实例
    final dbManager = DatabaseManager.instance;

    // 获取数据库连接
    final database = await dbManager.database;

    // 执行数据库操作
    final result = await database.query('media_items');
    debugPrint('Media items count: ${result.length}');

    // 创建备份
    final backupSuccess = await dbManager.createBackup();
    debugPrint('Backup created: $backupSuccess');

    // 获取数据库状态
    final status = dbManager.status;
    debugPrint('Database status: $status');

    // 从备份恢复（示例）
    // await dbManager.restoreFromBackup('/path/to/backup.db');

    // 重置数据库（谨慎使用）
    // await dbManager.reset();
  }

  /// 使用旧的DatabaseHelper（向后兼容）
  static Future<void> usingDatabaseHelper() async {
    // 执行数据库操作
    await DatabaseHelper.insertMediaItem({
      'id': 'test_id',
      'title': 'Test Media',
      'file_path': '/path/to/file',
      // ... 其他字段
    });

    final mediaItems = await DatabaseHelper.getMediaItems();
    debugPrint('Media items: ${mediaItems.length}');
  }

  /// 迁移指南
  static void migrationGuide() {
    // 旧代码：
    // final db = await DatabaseHelper.database;

    // 新代码：
    // final dbManager = DatabaseManager.instance;
    // final db = await dbManager.database;

    // 优势：
    // 1. 更好的状态管理
    // 2. 自动备份功能
    // 3. 更清晰的生命周期
    // 4. 更容易测试和模拟
  }
}
