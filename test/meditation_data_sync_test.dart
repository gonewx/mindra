import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mindra/features/meditation/data/services/meditation_session_manager.dart';
import 'package:mindra/features/meditation/domain/entities/meditation_session.dart';
import 'package:mindra/features/media/domain/entities/media_item.dart';
import 'package:mindra/core/constants/media_category.dart';

void main() {
  group('冥想数据同步测试', () {
    setUp(() {
      // 每次测试前清理会话状态
      MeditationSessionManager.clearSession();
    });

    test('播放完成后应该触发数据更新通知', () async {
      // 创建一个模拟的媒体项目
      final mediaItem = MediaItem(
        id: 'test-media-1',
        title: '测试冥想音频',
        filePath: '/test/path/audio.mp3',
        type: MediaType.audio,
        category: MediaCategory.meditation,
        duration: 600, // 10分钟
        createdAt: DateTime.now(),
        playCount: 0,
        tags: [],
        isFavorite: false,
        sortIndex: 0,
      );

      // 监听数据更新流
      bool dataUpdateReceived = false;
      final subscription = MeditationSessionManager.dataUpdateStream.listen((
        _,
      ) {
        dataUpdateReceived = true;
      });

      try {
        // 开始会话
        final sessionId = await MeditationSessionManager.startSession(
          mediaItem: mediaItem,
          sessionType: SessionType.meditation,
        );

        expect(MeditationSessionManager.hasActiveSession, isTrue);
        expect(sessionId, isNotEmpty);

        // 模拟播放完成
        await MeditationSessionManager.completeSession();

        // 验证会话已结束
        expect(MeditationSessionManager.hasActiveSession, isFalse);

        // 验证数据更新通知已发送
        expect(dataUpdateReceived, isTrue);

        debugPrint('✅ 播放完成后成功触发数据更新通知');
      } finally {
        await subscription.cancel();
      }
    });

    test('手动调用notifyDataUpdate应该触发数据更新通知', () async {
      bool dataUpdateReceived = false;
      final subscription = MeditationSessionManager.dataUpdateStream.listen((
        _,
      ) {
        dataUpdateReceived = true;
      });

      try {
        // 手动触发数据更新通知
        MeditationSessionManager.notifyDataUpdate();

        // 等待事件处理
        await Future.delayed(const Duration(milliseconds: 10));

        // 验证数据更新通知已发送
        expect(dataUpdateReceived, isTrue);

        debugPrint('✅ 手动调用notifyDataUpdate成功触发数据更新通知');
      } finally {
        await subscription.cancel();
      }
    });

    test('停止会话也应该触发数据更新通知', () async {
      // 创建一个模拟的媒体项目
      final mediaItem = MediaItem(
        id: 'test-media-2',
        title: '测试冥想音频2',
        filePath: '/test/path/audio2.mp3',
        type: MediaType.audio,
        category: MediaCategory.breathing,
        duration: 300, // 5分钟
        createdAt: DateTime.now(),
        playCount: 0,
        tags: [],
        isFavorite: false,
        sortIndex: 0,
      );

      // 监听数据更新流
      bool dataUpdateReceived = false;
      final subscription = MeditationSessionManager.dataUpdateStream.listen((
        _,
      ) {
        dataUpdateReceived = true;
      });

      try {
        // 开始会话
        await MeditationSessionManager.startSession(
          mediaItem: mediaItem,
          sessionType: SessionType.breathing,
        );

        expect(MeditationSessionManager.hasActiveSession, isTrue);

        // 重置数据更新标志
        dataUpdateReceived = false;

        // 停止会话（未完成但保存进度）
        await MeditationSessionManager.stopSession();

        // 验证会话已结束
        expect(MeditationSessionManager.hasActiveSession, isFalse);

        // 验证数据更新通知已发送
        expect(dataUpdateReceived, isTrue);

        debugPrint('✅ 停止会话成功触发数据更新通知');
      } finally {
        await subscription.cancel();
      }
    });

    test('多个监听器都应该收到数据更新通知', () async {
      bool listener1Received = false;
      bool listener2Received = false;

      final subscription1 = MeditationSessionManager.dataUpdateStream.listen((
        _,
      ) {
        listener1Received = true;
      });

      final subscription2 = MeditationSessionManager.dataUpdateStream.listen((
        _,
      ) {
        listener2Received = true;
      });

      try {
        // 手动触发数据更新通知
        MeditationSessionManager.notifyDataUpdate();

        // 等待事件处理
        await Future.delayed(const Duration(milliseconds: 10));

        // 验证所有监听器都收到通知
        expect(listener1Received, isTrue);
        expect(listener2Received, isTrue);

        debugPrint('✅ 多个监听器都成功收到数据更新通知');
      } finally {
        await subscription1.cancel();
        await subscription2.cancel();
      }
    });
  });
}
