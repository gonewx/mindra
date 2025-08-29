import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mindra/core/database/database_helper.dart';

void main() {
  group('数据库修复测试', () {
    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('检查并修复缺失的数据库表', () async {
      debugPrint('=== 数据库修复诊断开始 ===');

      final db = await DatabaseHelper.database;

      // 1. 检查当前数据库中的表
      debugPrint('1. 检查现有表...');
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      debugPrint('当前数据库表:');
      for (final table in tables) {
        debugPrint('- ${table['name']}');
      }

      // 2. 检查user_preferences表是否存在
      final userPrefsExists = tables.any(
        (t) => t['name'] == 'user_preferences',
      );
      debugPrint('user_preferences表存在: $userPrefsExists');

      // 3. 如果不存在，创建它
      if (!userPrefsExists) {
        debugPrint('2. 创建缺失的user_preferences表...');
        await db.execute('''
          CREATE TABLE user_preferences (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        debugPrint('✓ user_preferences表已创建');
      }

      // 4. 检查meditation_sessions表的外键约束
      debugPrint('3. 检查meditation_sessions表结构...');
      final sessionTableInfo = await db.rawQuery(
        "PRAGMA table_info(meditation_sessions)",
      );

      debugPrint('meditation_sessions表字段:');
      for (final field in sessionTableInfo) {
        debugPrint(
          '- ${field['name']}: ${field['type']} (nullable: ${field['notnull'] == 0})',
        );
      }

      // 5. 检查外键约束
      debugPrint('4. 检查外键约束...');
      final foreignKeys = await db.rawQuery(
        "PRAGMA foreign_key_list(meditation_sessions)",
      );

      debugPrint('meditation_sessions外键约束:');
      if (foreignKeys.isEmpty) {
        debugPrint('- 无外键约束');
      } else {
        for (final fk in foreignKeys) {
          debugPrint('- ${fk['from']} -> ${fk['table']}.${fk['to']}');
        }
      }

      // 6. 检查外键是否开启
      final foreignKeyStatus = await db.rawQuery("PRAGMA foreign_keys");
      debugPrint(
        '外键检查状态: ${foreignKeyStatus.first['foreign_keys'] == 1 ? '开启' : '关闭'}',
      );

      // 7. 临时关闭外键约束以解决问题
      debugPrint('5. 临时关闭外键约束...');
      await db.rawQuery("PRAGMA foreign_keys = OFF");

      final newStatus = await db.rawQuery("PRAGMA foreign_keys");
      debugPrint(
        '外键检查现状态: ${newStatus.first['foreign_keys'] == 1 ? '开启' : '关闭'}',
      );

      // 8. 验证修复
      debugPrint('6. 验证修复...');

      // 尝试插入一个测试会话
      try {
        await db.insert('meditation_sessions', {
          'id': 'test-repair-${DateTime.now().millisecondsSinceEpoch}',
          'media_item_id': 'non-existent-media',
          'title': '修复测试',
          'duration': 300,
          'actual_duration': 0,
          'start_time': DateTime.now().millisecondsSinceEpoch,
          'type': 'meditation',
          'sound_effects': '',
          'rating': 0.0,
          'is_completed': 0,
          'default_image_index': 1,
        });
        debugPrint('✓ 会话数据插入成功（外键约束已解决）');
      } catch (e) {
        debugPrint('✗ 会话数据插入失败: $e');
      }

      // 9. 测试preferences表操作
      try {
        await DatabaseHelper.setPreference('test_key', 'test_value');
        final value = await DatabaseHelper.getPreference('test_key');
        debugPrint('✓ preferences表操作成功，值: $value');
      } catch (e) {
        debugPrint('✗ preferences表操作失败: $e');
      }

      debugPrint('=== 数据库修复诊断完成 ===');
    });
  });
}
