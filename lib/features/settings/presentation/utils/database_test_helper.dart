import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/constants/media_category.dart';

/// 数据库测试辅助工具 - 仅用于开发调试
class DatabaseTestHelper {
  /// 生成测试数据
  static Future<void> generateTestData() async {
    if (!kDebugMode) {
      debugPrint('Test data generation is only available in debug mode');
      return;
    }

    try {
      debugPrint('开始生成测试数据...');

      // 生成测试媒体项目
      await _generateTestMediaItems();

      // 生成测试冥想会话
      await _generateTestMeditationSessions();

      // 生成测试用户偏好
      await _generateTestUserPreferences();

      debugPrint('测试数据生成完成');
    } catch (e) {
      debugPrint('生成测试数据失败: $e');
      rethrow;
    }
  }

  /// 清空所有数据
  static Future<void> clearAllData() async {
    if (!kDebugMode) {
      debugPrint('Data clearing is only available in debug mode');
      return;
    }

    try {
      debugPrint('清空所有数据...');
      await DatabaseHelper.clearAllData();
      debugPrint('数据清空完成');
    } catch (e) {
      debugPrint('清空数据失败: $e');
      rethrow;
    }
  }

  /// 生成测试媒体项目
  static Future<void> _generateTestMediaItems() async {
    final testMediaItems = [
      {
        'id': 'test_meditation_001',
        'title': '深度冥想练习',
        'description': '一个 10 分钟的深度冥想练习，帮助你放松身心',
        'file_path': 'assets/audio/meditation_01.mp3',
        'thumbnail_path': null,
        'type': 'audio',
        'category': MediaCategory.meditation.name,
        'duration': 600, // 10 minutes
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'last_played_at': null,
        'play_count': 0,
        'tags': '冥想,放松,专注',
        'is_favorite': 0,
        'source_url': null,
        'sort_index': 1,
      },
      {
        'id': 'test_sleep_001',
        'title': '睡眠引导音频',
        'description': '帮助快速入睡的引导音频',
        'file_path': 'assets/audio/sleep_01.mp3',
        'thumbnail_path': null,
        'type': 'audio',
        'category': MediaCategory.sleep.name,
        'duration': 1200, // 20 minutes
        'created_at':
            DateTime.now().millisecondsSinceEpoch - 86400000, // 1 day ago
        'last_played_at':
            DateTime.now().millisecondsSinceEpoch - 3600000, // 1 hour ago
        'play_count': 3,
        'tags': '睡眠,放松,安眠',
        'is_favorite': 1,
        'source_url': null,
        'sort_index': 2,
      },
      {
        'id': 'test_focus_001',
        'title': '专注力训练',
        'description': '提升注意力和专注力的训练音频',
        'file_path': 'assets/audio/focus_01.mp3',
        'thumbnail_path': null,
        'type': 'audio',
        'category': MediaCategory.focus.name,
        'duration': 900, // 15 minutes
        'created_at':
            DateTime.now().millisecondsSinceEpoch - 172800000, // 2 days ago
        'last_played_at': null,
        'play_count': 0,
        'tags': '专注,学习,效率',
        'is_favorite': 0,
        'source_url': null,
        'sort_index': 3,
      },
    ];

    for (final item in testMediaItems) {
      await DatabaseHelper.insertMediaItem(item);
      debugPrint('已添加测试媒体: ${item['title']}');
    }
  }

  /// 生成测试冥想会话
  static Future<void> _generateTestMeditationSessions() async {
    final now = DateTime.now();
    final testSessions = [
      {
        'id': 'session_001',
        'media_item_id': 'test_meditation_001',
        'title': '深度冥想练习',
        'duration': 600,
        'actual_duration': 580, // 实际完成了 9分40秒
        'start_time': now
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch,
        'end_time': now
            .subtract(const Duration(hours: 2, minutes: -10))
            .millisecondsSinceEpoch,
        'type': 'meditation',
        'sound_effects': 'rain,ocean',
        'rating': 4.5,
        'notes': '感觉很放松，效果不错',
        'is_completed': 1,
      },
      {
        'id': 'session_002',
        'media_item_id': 'test_sleep_001',
        'title': '睡眠引导音频',
        'duration': 1200,
        'actual_duration': 1200, // 完整听完
        'start_time': now
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch,
        'end_time': now
            .subtract(const Duration(days: 1, minutes: -20))
            .millisecondsSinceEpoch,
        'type': 'sleep',
        'sound_effects': 'wind_chimes',
        'rating': 5.0,
        'notes': '很快就睡着了',
        'is_completed': 1,
      },
    ];

    for (final session in testSessions) {
      await DatabaseHelper.insertMeditationSession(session);
      debugPrint('已添加测试会话: ${session['title']}');
    }
  }

  /// 生成测试用户偏好
  static Future<void> _generateTestUserPreferences() async {
    final testPreferences = {
      'theme_mode': 'system',
      'language_code': 'zh',
      'onboarding_completed': 'true',
      'notification_enabled': 'true',
      'daily_reminder_time': '09:00',
      'sound_effects_volume': '0.7',
    };

    for (final entry in testPreferences.entries) {
      await DatabaseHelper.setPreference(entry.key, entry.value);
      debugPrint('已设置用户偏好: ${entry.key} = ${entry.value}');
    }
  }

  /// 获取数据库统计信息
  static Future<Map<String, int>> getDatabaseStats() async {
    try {
      final db = await DatabaseHelper.database;

      final mediaResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM media_items',
      );
      final sessionResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM meditation_sessions',
      );
      final prefResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM user_preferences',
      );

      return {
        'media_items': mediaResult.first['count'] as int,
        'meditation_sessions': sessionResult.first['count'] as int,
        'user_preferences': prefResult.first['count'] as int,
      };
    } catch (e) {
      debugPrint('获取数据库统计信息失败: $e');
      return {
        'media_items': 0,
        'meditation_sessions': 0,
        'user_preferences': 0,
      };
    }
  }
}
