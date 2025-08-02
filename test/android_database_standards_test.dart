import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:mindra/core/database/database_helper.dart';
import 'package:mindra/core/constants/app_constants.dart';

void main() {
  group('Android Database Standards Tests', () {
    setUpAll(() async {
      // 模拟非Web环境
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    tearDownAll(() async {
      debugDefaultTargetPlatformOverride = null;
      await DatabaseHelper.closeDatabase();
    });

    test('应该使用标准API获取数据库路径', () async {
      // 获取数据库调试信息
      final debugInfo = await DatabaseHelper.getDatabaseDebugInfo();

      // 验证系统信息存在
      final systemInfo = debugInfo['system_info'] as Map<String, dynamic>?;
      expect(systemInfo, isNotNull);

      debugPrint('  系统信息: $systemInfo');

      // 在测试环境中，系统可能显示为linux，但我们仍然验证使用了标准API
      expect(systemInfo!['follows_standards'], isTrue);
      expect(systemInfo['path_method'], contains('standard API'));

      debugPrint('✓ 数据库路径获取符合标准实践');
      debugPrint('  方法: ${systemInfo['path_method']}');
      debugPrint('  平台: ${systemInfo['platform']}');
    });

    test('数据库文件应该位于标准位置', () async {
      final db = await DatabaseHelper.database;
      final dbPath = db.path;

      // 验证路径不包含硬编码的绝对路径
      expect(dbPath, isNot(contains('/data/data/com.mindra.app/databases')));
      expect(dbPath, isNot(contains('/sdcard')));
      expect(dbPath, isNot(contains('/storage/emulated')));

      // 验证路径包含标准数据库名称
      expect(dbPath, contains(AppConstants.databaseName));

      debugPrint('✓ 数据库文件位于标准位置: $dbPath');
    });

    test('应该能正常进行数据库操作', () async {
      // 测试基本数据库操作
      final testItem = {
        'id': 'test_standards_001',
        'title': '标准实践测试',
        'description': '测试Android标准实践实现',
        'file_path': 'test.mp3',
        'type': 'audio',
        'category': 'meditation',
        'duration': 300,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'sort_index': 1,
      };

      // 插入测试数据
      await DatabaseHelper.insertMediaItem(testItem);

      // 查询测试数据
      final retrievedItem = await DatabaseHelper.getMediaItemById(
        'test_standards_001',
      );
      expect(retrievedItem, isNotNull);
      expect(retrievedItem!['title'], equals('标准实践测试'));

      // 清理测试数据
      await DatabaseHelper.deleteMediaItem('test_standards_001');

      debugPrint('✓ 数据库基本操作正常工作');
    });

    test('存在的数据库文件检查应该只返回标准位置', () async {
      final existingFiles = await DatabaseHelper.findExistingDatabaseFiles();

      // 应该至少找到一个文件（当前标准位置的文件）
      expect(existingFiles, isNotEmpty);

      // 检查是否包含标准数据库名称
      final hasStandardDb = existingFiles.any(
        (file) => file.contains(AppConstants.databaseName),
      );
      expect(hasStandardDb, isTrue);

      debugPrint('✓ 存在的数据库文件检查正常');
      debugPrint('  找到文件: ${existingFiles.length} 个');
      for (final file in existingFiles) {
        debugPrint('  - $file');
      }
    });

    test('数据库调试信息应该反映标准实践', () async {
      final debugInfo = await DatabaseHelper.getDatabaseDebugInfo();

      // 检查基本信息
      expect(debugInfo['database_path'], isNotNull);
      expect(debugInfo['file_exists'], isTrue);
      expect(debugInfo['tables'], isNotNull);

      // 检查系统信息
      final systemInfo = debugInfo['system_info'] as Map<String, dynamic>;
      expect(systemInfo['follows_standards'], isTrue);
      expect(systemInfo['path_method'], contains('standard API'));

      debugPrint('✓ 数据库调试信息正确反映标准实践');
      debugPrint('  路径: ${debugInfo['database_path']}');
      debugPrint('  文件大小: ${debugInfo['file_size']} 字节');
      debugPrint('  表数量: ${(debugInfo['tables'] as List).length}');
      debugPrint('  平台: ${systemInfo['platform']}');
    });
  });
}
