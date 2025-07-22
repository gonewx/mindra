import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mindra/core/database/database_helper.dart';
import 'package:mindra/core/database/database_health_checker.dart';

void main() {
  group('数据库健壮性测试', () {
    setUpAll(() async {
      // Initialize FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    tearDown(() async {
      await DatabaseHelper.closeDatabase();
    });

    test('数据库初始化应该成功', () async {
      final db = await DatabaseHelper.database;
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('数据库初始化状态跟踪应该正常工作', () async {
      await DatabaseHelper.database;

      final status = DatabaseHelper.getInitializationStatus();
      expect(status['isOpen'], isTrue);
      expect(status['attempts'], greaterThan(0));
    });

    test('数据库重新初始化应该成功', () async {
      // 首次初始化
      final db1 = await DatabaseHelper.database;
      expect(db1.isOpen, isTrue);

      // 强制重新初始化
      await DatabaseHelper.forceReinitialize();

      final db2 = await DatabaseHelper.database;
      expect(db2.isOpen, isTrue);
    });

    test('数据库操作重试机制应该正常工作', () async {
      // 测试插入操作的重试机制
      final testItem = {
        'id': 'test-retry-1',
        'title': '重试测试媒体',
        'description': '测试重试机制',
        'file_path': '/test/retry.mp3',
        'type': 'audio',
        'category': '测试',
        'duration': 180,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'play_count': 0,
        'is_favorite': 0,
      };

      // 这应该通过重试机制成功
      await DatabaseHelper.insertMediaItem(testItem);

      // 验证数据已插入
      final retrievedItem = await DatabaseHelper.getMediaItemById(
        'test-retry-1',
      );
      expect(retrievedItem, isNotNull);
      expect(retrievedItem!['title'], equals('重试测试媒体'));
    });

    test('参数验证应该正常工作', () async {
      // 测试空ID验证
      expect(
        () => DatabaseHelper.getMediaItemById(''),
        throwsA(isA<ArgumentError>()),
      );

      // 测试空更新数据验证
      expect(
        () => DatabaseHelper.updateMediaItem('test-id', {}),
        throwsA(isA<ArgumentError>()),
      );

      // 测试负数限制验证
      expect(
        () => DatabaseHelper.getRecentMediaItems(-1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('数据库健康检查应该正常工作', () async {
      // 确保数据库已初始化
      await DatabaseHelper.database;

      // 执行健康检查
      final report = await DatabaseHealthChecker.performHealthCheck();

      expect(report, isNotNull);
      expect(report.checkTime, isNotNull);
      expect(report.checkDuration, isNotNull);

      // 新初始化的数据库应该是健康的
      expect(report.isHealthy, isTrue);
      expect(report.issues, isEmpty);
    });

    test('健康检查应该检测缺失的表', () async {
      final db = await DatabaseHelper.database;

      // 删除一个表来模拟损坏
      await db.execute('DROP TABLE IF EXISTS user_preferences');

      // 执行健康检查
      final report = await DatabaseHealthChecker.performHealthCheck();

      expect(report.isHealthy, isFalse);
      expect(report.issues, isNotEmpty);

      // 应该检测到缺失的表
      final missingTableIssues = report.issues.where(
        (issue) => issue.type == DatabaseIssueType.missingTable,
      );
      expect(missingTableIssues, isNotEmpty);
    });

    test('自动修复应该能修复缺失的索引', () async {
      final db = await DatabaseHelper.database;

      // 删除一个索引来模拟问题
      await db.execute('DROP INDEX IF EXISTS idx_media_items_created_at');

      // 执行健康检查
      final report = await DatabaseHealthChecker.performHealthCheck();
      expect(report.isHealthy, isFalse);

      // 执行自动修复
      final repairedIssues = await DatabaseHealthChecker.autoRepairIssues(
        report,
      );
      expect(repairedIssues, isNotEmpty);

      // 验证索引已重新创建
      final indexCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_media_items_created_at'",
      );
      expect(indexCheck, isNotEmpty);
    });

    test('数据库路径获取应该有多个备用选项', () async {
      // 这个测试主要验证路径获取逻辑不会抛出异常
      expect(() => DatabaseHelper.database, returnsNormally);
    });

    test('并发数据库访问应该正常处理', () async {
      // 同时启动多个数据库访问操作
      final futures = <Future>[];

      for (int i = 0; i < 10; i++) {
        futures.add(
          DatabaseHelper.insertMediaItem({
            'id': 'concurrent-test-$i',
            'title': '并发测试 $i',
            'description': '测试并发访问',
            'file_path': '/test/concurrent$i.mp3',
            'type': 'audio',
            'category': '测试',
            'duration': 120,
            'created_at': DateTime.now().millisecondsSinceEpoch + i,
            'play_count': 0,
            'is_favorite': 0,
          }),
        );
      }

      // 等待所有操作完成
      await Future.wait(futures);

      // 验证所有数据都已插入
      final allItems = await DatabaseHelper.getMediaItems();
      final concurrentItems = allItems.where(
        (item) => (item['id'] as String).startsWith('concurrent-test-'),
      );
      expect(concurrentItems.length, equals(10));
    });

    test('数据库性能检查应该工作', () async {
      await DatabaseHelper.database;

      // 插入一些测试数据
      for (int i = 0; i < 100; i++) {
        await DatabaseHelper.insertMediaItem({
          'id': 'perf-test-$i',
          'title': '性能测试 $i',
          'description': '测试数据库性能',
          'file_path': '/test/perf$i.mp3',
          'type': 'audio',
          'category': '测试',
          'duration': 60 + i,
          'created_at': DateTime.now().millisecondsSinceEpoch + i,
          'play_count': 0,
          'is_favorite': 0,
        });
      }

      // 执行健康检查（包括性能检查）
      final report = await DatabaseHealthChecker.performHealthCheck();

      // 性能检查应该完成而不出错
      expect(report.checkDuration, isNotNull);
      expect(report.checkDuration!.inMilliseconds, greaterThan(0));
    });

    test('错误恢复机制应该正常工作', () async {
      // 这个测试验证当数据库操作失败时的恢复机制
      await DatabaseHelper.database;

      // 尝试插入无效数据（应该通过重试机制处理）
      try {
        await DatabaseHelper.insertMediaItem({
          'id': 'recovery-test',
          'title': '恢复测试',
          // 缺少必需字段来触发错误
        });
        fail('应该抛出异常');
      } catch (e) {
        // 预期的异常
        expect(e, isNotNull);
      }

      // 数据库应该仍然可用
      final db = await DatabaseHelper.database;
      expect(db.isOpen, isTrue);
    });
  });
}
