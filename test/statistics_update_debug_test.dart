import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mindra/features/meditation/data/services/meditation_session_manager.dart';
import 'package:mindra/features/meditation/data/services/meditation_statistics_service.dart';
import 'package:mindra/features/meditation/domain/entities/meditation_session.dart';
import 'package:mindra/features/media/domain/entities/media_item.dart';
import 'package:mindra/core/constants/media_category.dart';
import 'package:mindra/core/database/database_helper.dart';

void main() {
  group('统计数据更新诊断测试', () {
    setUpAll(() async {
      // 初始化FFI数据库工厂
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // 初始化数据库
      await DatabaseHelper.database;
    });

    test('验证数据更新流机制', () async {
      debugPrint('=== 开始统计数据更新诊断测试 ===');

      // 1. 检查流控制器状态
      debugPrint('1. 检查数据更新流状态...');
      var updateReceived = false;

      // 监听数据更新流
      final dataUpdateSubscription = MeditationSessionManager.dataUpdateStream
          .listen((_) {
            debugPrint('✓ 数据更新流收到通知');
            updateReceived = true;
          });

      // 监听实时更新流
      final realtimeSubscription = MeditationSessionManager.realTimeUpdateStream
          .listen((data) {
            debugPrint('✓ 实时更新流收到数据: $data');
          });

      // 2. 创建测试媒体
      final testMedia = MediaItem(
        id: 'test-${DateTime.now().millisecondsSinceEpoch}',
        title: '诊断测试冥想',
        filePath: 'test://audio.mp3',
        type: MediaType.audio,
        duration: 600,
        category: MediaCategory.meditation,
        createdAt: DateTime.now(),
      );

      // 3. 开始会话
      debugPrint('2. 开始测试会话...');
      final sessionId = await MeditationSessionManager.startSession(
        mediaItem: testMedia,
        sessionType: SessionType.meditation,
      );
      debugPrint('✓ 会话已开始，ID: $sessionId');

      // 4. 模拟播放进度更新
      debugPrint('3. 模拟播放进度更新...');
      for (int i = 30; i <= 300; i += 30) {
        MeditationSessionManager.updateSessionProgress(i);
        await Future.delayed(Duration(milliseconds: 100));
      }
      debugPrint('✓ 播放进度更新完成');

      // 5. 完成会话
      debugPrint('4. 完成测试会话...');
      await MeditationSessionManager.completeSession(
        rating: 4.5,
        notes: '诊断测试会话',
      );
      debugPrint('✓ 会话已完成');

      // 6. 等待异步操作完成
      await Future.delayed(Duration(milliseconds: 500));

      // 7. 验证流通知
      debugPrint('5. 验证流通知状态...');
      expect(updateReceived, true, reason: '数据更新流应该收到通知');
      debugPrint(updateReceived ? '✓ 数据更新流正常' : '✗ 数据更新流失败');

      // 8. 获取统计数据
      debugPrint('6. 获取统计数据...');
      final statistics = await MeditationStatisticsService.getStatistics();

      debugPrint('统计数据结果:');
      debugPrint('- 总会话数: ${statistics.totalSessions}');
      debugPrint('- 总时长: ${statistics.totalMinutes}分钟');
      debugPrint('- 连续天数: ${statistics.streakDays}');
      debugPrint('- 本周时长: ${statistics.weeklyMinutes}分钟');
      debugPrint(
        '- 今日月度记录: ${statistics.monthlyRecords.isNotEmpty ? statistics.monthlyRecords.last.totalMinutes : 0}分钟',
      );

      // 9. 验证数据库中的会话数据
      debugPrint('7. 验证数据库数据...');
      final sessions = await DatabaseHelper.getAllMeditationSessions();
      final latestSession = sessions.isNotEmpty
          ? MeditationSession.fromMap(sessions.last)
          : null;

      if (latestSession != null) {
        debugPrint('最新会话数据:');
        debugPrint('- ID: ${latestSession.id}');
        debugPrint('- 标题: ${latestSession.title}');
        debugPrint('- 实际时长: ${latestSession.actualDuration}秒');
        debugPrint('- 是否完成: ${latestSession.isCompleted}');
        debugPrint('- 开始时间: ${latestSession.startTime}');
        debugPrint('- 结束时间: ${latestSession.endTime}');
      } else {
        debugPrint('✗ 没有找到会话数据');
      }

      // 10. 测试手动数据更新通知
      debugPrint('8. 测试手动数据更新通知...');
      var manualUpdateReceived = false;
      final manualUpdateSubscription = MeditationSessionManager.dataUpdateStream
          .listen((_) {
            debugPrint('✓ 手动数据更新流收到通知');
            manualUpdateReceived = true;
          });

      MeditationSessionManager.notifyDataUpdate();
      await Future.delayed(Duration(milliseconds: 100));

      debugPrint(manualUpdateReceived ? '✓ 手动通知流正常' : '✗ 手动通知流失败');

      // 清理
      await dataUpdateSubscription.cancel();
      await realtimeSubscription.cancel();
      await manualUpdateSubscription.cancel();

      debugPrint('=== 统计数据更新诊断测试完成 ===');
    });

    test('验证DailyGoalCard数据监听机制', () async {
      debugPrint('=== 开始DailyGoalCard数据监听测试 ===');

      var listenerTriggered = false;
      var listenerCallCount = 0;

      // 模拟DailyGoalCard的监听逻辑
      final subscription = MeditationSessionManager.dataUpdateStream.listen((
        _,
      ) {
        listenerCallCount++;
        listenerTriggered = true;
        debugPrint('✓ DailyGoalCard监听器被触发 (第$listenerCallCount次)');
      });

      // 触发几次更新
      debugPrint('触发数据更新通知...');
      MeditationSessionManager.notifyDataUpdate();
      await Future.delayed(Duration(milliseconds: 50));

      MeditationSessionManager.notifyDataUpdate();
      await Future.delayed(Duration(milliseconds: 50));

      debugPrint('监听器触发状态: $listenerTriggered, 调用次数: $listenerCallCount');
      expect(listenerTriggered, true);
      expect(listenerCallCount, 2);

      await subscription.cancel();
      debugPrint('=== DailyGoalCard数据监听测试完成 ===');
    });
  });
}
