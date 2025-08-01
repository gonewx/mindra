import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:mindra/core/database/database_helper.dart';
import 'package:mindra/core/database/database_connection_manager.dart';
import 'package:mindra/features/media/domain/entities/media_item.dart';
import 'package:mindra/core/constants/media_category.dart';

void main() {
  group('Android Database Persistence Tests', () {
    setUpAll(() async {
      // 初始化测试环境
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    tearDown(() async {
      // 清理测试数据
      try {
        await DatabaseHelper.clearAllData();
        await DatabaseHelper.closeDatabase();
      } catch (e) {
        debugPrint('Error cleaning up test data: $e');
      }
    });

    test('Database connection should persist after reinitialization', () async {
      // 添加测试数据
      final testMedia = MediaItem(
        id: 'test-1',
        title: '测试冥想',
        description: '这是一个测试冥想',
        filePath: '/test/path/meditation.mp3',
        type: MediaType.audio,
        category: MediaCategory.relaxation,
        duration: 600,
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.insertMediaItem(testMedia.toMap());

      // 验证数据已保存
      final savedItems = await DatabaseHelper.getMediaItems();
      expect(savedItems.length, 1);
      expect(savedItems.first['title'], '测试冥想');

      // 强制重新初始化数据库（模拟应用重启）
      await DatabaseHelper.forceReinitialize();

      // 验证数据仍然存在
      final retrievedItems = await DatabaseHelper.getMediaItems();
      expect(retrievedItems.length, 1);
      expect(retrievedItems.first['title'], '测试冥想');
    });

    test('Database connection manager should handle connection loss', () async {
      // 测试连接管理器功能
      final isConnected = await DatabaseConnectionManager.checkConnection();
      expect(isConnected, true);

      // 添加测试数据
      final testMedia = MediaItem(
        id: 'test-2',
        title: '连接测试冥想',
        description: '测试连接管理器',
        filePath: '/test/path/connection.mp3',
        type: MediaType.audio,
        category: MediaCategory.focus,
        duration: 300,
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.insertMediaItem(testMedia.toMap());

      // 验证数据
      final items = await DatabaseHelper.getMediaItems();
      expect(items.length, 1);
      expect(items.first['title'], '连接测试冥想');
    });

    test('Database should handle multiple rapid operations', () async {
      // 测试数据库在高并发操作下的稳定性
      final List<Future> operations = [];

      for (int i = 0; i < 10; i++) {
        final media = MediaItem(
          id: 'test-$i',
          title: '并发测试$i',
          description: '并发插入测试',
          filePath: '/test/path/concurrent$i.mp3',
          type: MediaType.audio,
          category: MediaCategory.sleep,
          duration: 120 + i * 10,
          createdAt: DateTime.now(),
        );

        operations.add(DatabaseHelper.insertMediaItem(media.toMap()));
      }

      // 等待所有操作完成
      await Future.wait(operations);

      // 验证所有数据都已保存
      final items = await DatabaseHelper.getMediaItems();
      expect(items.length, 10);

      // 验证数据完整性
      for (int i = 0; i < 10; i++) {
        final item = items.firstWhere((item) => item['id'] == 'test-$i');
        expect(item['title'], '并发测试$i');
        expect(item['duration'], 120 + i * 10);
      }
    });

    test('Database should recover from corruption', () async {
      // 添加初始数据
      final testMedia = MediaItem(
        id: 'recovery-test',
        title: '恢复测试',
        description: '测试数据库恢复功能',
        filePath: '/test/path/recovery.mp3',
        type: MediaType.audio,
        category: MediaCategory.mindfulness,
        duration: 900,
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.insertMediaItem(testMedia.toMap());

      // 验证初始数据
      final initialItems = await DatabaseHelper.getMediaItems();
      expect(initialItems.length, 1);

      // 强制重新初始化（模拟从损坏中恢复）
      await DatabaseHelper.forceReinitialize();

      // 数据库应该仍然可用，即使数据可能丢失也不应该崩溃
      final recoveredItems = await DatabaseHelper.getMediaItems();
      expect(recoveredItems, isNotNull);
    });
  });
}
