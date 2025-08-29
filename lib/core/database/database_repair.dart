import 'package:flutter/foundation.dart';
import 'database_helper.dart';

class DatabaseRepair {
  /// 修复数据库问题，确保所有必需的表和结构都正确
  static Future<void> repairDatabase() async {
    try {
      debugPrint('=== 开始数据库修复 ===');

      // 获取数据库实例
      final db = await DatabaseHelper.database;

      // 检查当前表结构
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final existingTableNames = tables.map((t) => t['name'] as String).toSet();

      debugPrint('当前数据库表: ${existingTableNames.toList()}');

      // 修复缺失的user_preferences表
      if (!existingTableNames.contains('user_preferences')) {
        debugPrint('修复：创建缺失的user_preferences表');
        await db.execute('''
          CREATE TABLE user_preferences (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        debugPrint('✅ user_preferences表创建成功');
      }

      // 检查外键约束状态
      final foreignKeyStatus = await db.rawQuery("PRAGMA foreign_keys");
      final isEnabled = foreignKeyStatus.first['foreign_keys'] == 1;
      debugPrint('外键约束状态: ${isEnabled ? "开启" : "关闭"}');

      if (isEnabled) {
        debugPrint('建议：外键约束可能导致会话保存失败');
        debugPrint('解决方案：会话管理器会自动创建缺失的MediaItem记录');
      }

      debugPrint('=== 数据库修复完成 ===');

      // 验证修复结果
      await _verifyRepair(db);
    } catch (e) {
      debugPrint('数据库修复失败: $e');
      rethrow;
    }
  }

  /// 验证数据库修复结果
  static Future<void> _verifyRepair(db) async {
    try {
      debugPrint('=== 验证数据库修复结果 ===');

      // 测试preferences操作
      await DatabaseHelper.setPreference('repair_test', '修复测试成功');
      final testValue = await DatabaseHelper.getPreference('repair_test');
      debugPrint('preferences操作测试: ${testValue == '修复测试成功' ? "✅ 成功" : "❌ 失败"}');

      // 清理测试数据
      await db.delete(
        'user_preferences',
        where: 'key = ?',
        whereArgs: ['repair_test'],
      );

      debugPrint('=== 数据库修复验证完成 ===');
    } catch (e) {
      debugPrint('数据库修复验证失败: $e');
    }
  }
}
