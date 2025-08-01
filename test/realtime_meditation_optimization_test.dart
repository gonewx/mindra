import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mindra/features/meditation/data/services/meditation_session_manager.dart';
import 'package:mindra/features/meditation/domain/entities/meditation_session.dart';
import 'package:mindra/features/media/domain/entities/media_item.dart';
import 'package:mindra/core/constants/media_category.dart';
import 'package:mindra/core/services/app_lifecycle_manager.dart';

void main() {
  group('实时冥想进度优化测试', () {
    setUp(() {
      // 每次测试前清理会话状态
      MeditationSessionManager.clearSession();
    });

    test('实时进度更新功能验证', () async {
      // 创建测试媒体项目
      final mediaItem = MediaItem(
        id: 'test-realtime-1',
        title: '实时更新测试音频',
        filePath: '/test/path/realtime.mp3',
        type: MediaType.audio,
        category: MediaCategory.meditation,
        duration: 300, // 5分钟
        createdAt: DateTime.now(),
        playCount: 0,
        tags: [],
        isFavorite: false,
        sortIndex: 0,
      );

      // 收集实时更新数据
      final List<Map<String, dynamic>> realTimeUpdates = [];
      final subscription = MeditationSessionManager.realTimeUpdateStream.listen(
        (data) {
          realTimeUpdates.add(Map<String, dynamic>.from(data));
        },
      );

      try {
        // 开始会话
        await MeditationSessionManager.startSession(
          mediaItem: mediaItem,
          sessionType: SessionType.meditation,
        );

        // 验证初始实时更新
        await Future.delayed(const Duration(milliseconds: 100));
        expect(realTimeUpdates.isNotEmpty, isTrue);
        expect(realTimeUpdates.first['sessionId'], isNotEmpty);
        expect(realTimeUpdates.first['actualDuration'], equals(0));

        // 模拟播放进度更新
        MeditationSessionManager.updateSessionProgress(30); // 30秒
        await Future.delayed(const Duration(milliseconds: 50));

        // 验证实时更新反映了新的进度
        final latestUpdate = realTimeUpdates.last;
        expect(latestUpdate['actualDuration'], equals(30));
        expect(latestUpdate['progress'], closeTo(0.1, 0.01)); // 30/300 = 0.1

        // 模拟暂停
        await MeditationSessionManager.pauseSession();
        await Future.delayed(const Duration(milliseconds: 50));

        // 验证暂停状态在实时更新中反映
        final pausedUpdate = realTimeUpdates.last;
        expect(pausedUpdate['isPlaying'], isFalse);

        // 暂停期间的进度更新不应该影响实际时长
        MeditationSessionManager.updateSessionProgress(60);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(
          MeditationSessionManager.currentSessionDuration,
          equals(30),
        ); // 仍然是30秒

        // 恢复播放
        await MeditationSessionManager.resumeSession();
        await Future.delayed(const Duration(milliseconds: 50));

        // 继续播放
        MeditationSessionManager.updateSessionProgress(90); // 90秒
        await Future.delayed(const Duration(milliseconds: 50));

        final resumedUpdate = realTimeUpdates.last;
        expect(resumedUpdate['isPlaying'], isTrue);
        expect(resumedUpdate['actualDuration'], equals(90));

        debugPrint('✅ 实时进度更新功能验证成功');
      } finally {
        await subscription.cancel();
        await MeditationSessionManager.stopSession();
      }
    });

    test('自动保存机制验证', () async {
      final mediaItem = MediaItem(
        id: 'test-autosave-1',
        title: '自动保存测试音频',
        filePath: '/test/path/autosave.mp3',
        type: MediaType.audio,
        category: MediaCategory.focus,
        duration: 600, // 10分钟
        createdAt: DateTime.now(),
        playCount: 0,
        tags: [],
        isFavorite: false,
        sortIndex: 0,
      );

      // 开始会话
      await MeditationSessionManager.startSession(
        mediaItem: mediaItem,
        sessionType: SessionType.focus,
      );

      expect(MeditationSessionManager.hasActiveSession, isTrue);

      // 模拟播放一段时间
      MeditationSessionManager.updateSessionProgress(120); // 2分钟

      // 测试强制保存功能
      await MeditationSessionManager.forceSaveCurrentState();

      // 验证会话状态保持不变
      expect(MeditationSessionManager.hasActiveSession, isTrue);
      expect(MeditationSessionManager.currentSessionDuration, equals(120));

      // 验证暂停时长统计
      await MeditationSessionManager.pauseSession();

      // 模拟暂停1秒
      await Future.delayed(const Duration(seconds: 1));

      await MeditationSessionManager.resumeSession();

      // 验证暂停时长被正确统计
      expect(
        MeditationSessionManager.currentSessionPausedDuration,
        greaterThanOrEqualTo(1),
      );

      await MeditationSessionManager.completeSession();

      debugPrint('✅ 自动保存机制验证成功');
    });

    test('多场景数据更新验证', () async {
      final mediaItem = MediaItem(
        id: 'test-multiscenario-1',
        title: '多场景测试音频',
        filePath: '/test/path/multiscenario.mp3',
        type: MediaType.audio,
        category: MediaCategory.sleep,
        duration: 1800, // 30分钟
        createdAt: DateTime.now(),
        playCount: 0,
        tags: [],
        isFavorite: false,
        sortIndex: 0,
      );

      // 监听数据更新
      bool dataUpdateReceived = false;
      final dataSubscription = MeditationSessionManager.dataUpdateStream.listen(
        (_) {
          dataUpdateReceived = true;
        },
      );

      // 监听实时更新
      int realTimeUpdateCount = 0;
      final realTimeSubscription = MeditationSessionManager.realTimeUpdateStream
          .listen((_) {
            realTimeUpdateCount++;
          });

      try {
        // 场景1: 正常播放完成
        await MeditationSessionManager.startSession(
          mediaItem: mediaItem,
          sessionType: SessionType.sleep,
        );

        // 重置更新计数
        dataUpdateReceived = false;
        realTimeUpdateCount = 0;

        // 模拟播放进度
        for (int i = 1; i <= 5; i++) {
          MeditationSessionManager.updateSessionProgress(i * 60); // 每分钟更新
          await Future.delayed(const Duration(milliseconds: 20));
        }

        // 验证实时更新
        expect(realTimeUpdateCount, greaterThan(0));

        // 完成会话
        await MeditationSessionManager.completeSession();

        // 验证数据更新通知
        expect(dataUpdateReceived, isTrue);

        // 场景2: 中途停止
        dataUpdateReceived = false;

        await MeditationSessionManager.startSession(
          mediaItem: mediaItem,
          sessionType: SessionType.sleep,
        );

        MeditationSessionManager.updateSessionProgress(180); // 3分钟

        // 中途停止
        await MeditationSessionManager.stopSession();

        // 验证停止也触发数据更新
        expect(dataUpdateReceived, isTrue);

        debugPrint('✅ 多场景数据更新验证成功');
      } finally {
        await dataSubscription.cancel();
        await realTimeSubscription.cancel();
      }
    });

    test('应用生命周期管理验证', () async {
      // 创建生命周期管理器实例
      final lifecycleManager = AppLifecycleManager.instance;

      // 验证生命周期管理器功能
      expect(lifecycleManager.isAppInForeground, isTrue); // 测试环境默认前台

      // 验证状态保存功能不会抛出异常
      expect(
        () async => await lifecycleManager.saveCurrentState(),
        returnsNormally,
      );

      debugPrint('✅ 应用生命周期管理验证成功');
    });

    test('会话状态详细信息验证', () async {
      final mediaItem = MediaItem(
        id: 'test-session-info-1',
        title: '会话信息测试音频',
        filePath: '/test/path/sessioninfo.mp3',
        type: MediaType.audio,
        category: MediaCategory.breathing,
        duration: 900, // 15分钟
        createdAt: DateTime.now(),
        playCount: 0,
        tags: [],
        isFavorite: false,
        sortIndex: 0,
      );

      // 初始状态：无活跃会话
      expect(MeditationSessionManager.getCurrentSessionInfo(), isNull);

      // 开始会话
      await MeditationSessionManager.startSession(
        mediaItem: mediaItem,
        sessionType: SessionType.breathing,
      );

      // 验证会话信息
      final sessionInfo = MeditationSessionManager.getCurrentSessionInfo();
      expect(sessionInfo, isNotNull);
      expect(sessionInfo!['session'], isNotNull);
      expect(sessionInfo['actualDuration'], equals(0));
      expect(sessionInfo['totalPausedDuration'], equals(0));
      expect(sessionInfo['isPaused'], isFalse);
      expect(sessionInfo['startTime'], isNotNull);

      // 播放一段时间
      MeditationSessionManager.updateSessionProgress(240); // 4分钟

      final updatedInfo = MeditationSessionManager.getCurrentSessionInfo();
      expect(updatedInfo!['actualDuration'], equals(240));

      // 暂停测试
      await MeditationSessionManager.pauseSession();
      await Future.delayed(const Duration(milliseconds: 100));
      await MeditationSessionManager.resumeSession();

      final pausedInfo = MeditationSessionManager.getCurrentSessionInfo();
      expect(pausedInfo!['isPaused'], isFalse); // 已恢复
      expect(pausedInfo['totalPausedDuration'], greaterThan(0));

      await MeditationSessionManager.completeSession();

      // 完成后无活跃会话
      expect(MeditationSessionManager.getCurrentSessionInfo(), isNull);

      debugPrint('✅ 会话状态详细信息验证成功');
    });

    test('边界条件和错误处理验证', () async {
      // 测试无活跃会话时的操作
      MeditationSessionManager.updateSessionProgress(100);
      expect(MeditationSessionManager.currentSessionDuration, equals(0));

      // 测试重复暂停
      await MeditationSessionManager.pauseSession(); // 无会话时暂停
      expect(MeditationSessionManager.isCurrentSessionPaused, isFalse);

      // 测试重复恢复
      await MeditationSessionManager.resumeSession(); // 无会话时恢复

      // 测试手动数据更新通知
      expect(
        () => MeditationSessionManager.notifyDataUpdate(),
        returnsNormally,
      );

      debugPrint('✅ 边界条件和错误处理验证成功');
    });
  });
}
