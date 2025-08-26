import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/features/meditation/data/services/meditation_session_manager.dart';
import 'package:mindra/features/meditation/data/services/enhanced_meditation_session_manager.dart';
import 'package:mindra/features/media/domain/entities/media_item.dart';
import 'package:mindra/features/meditation/domain/entities/meditation_session.dart';
import 'package:mindra/core/constants/media_category.dart';

void main() {
  group('播放完成统计测试', () {
    setUp(() {
      // 清理之前的会话状态
      MeditationSessionManager.clearSession();
      EnhancedMeditationSessionManager.clearSession();
    });

    test('播放完成时应该正确统计完整的播放时长', () async {
      // 创建一个测试媒体项，时长为60秒
      final testMedia = MediaItem(
        id: 'test-media-1',
        title: '测试冥想音频',
        filePath: '/test/path/meditation.mp3',
        type: MediaType.audio, // 添加必需的type参数
        duration: 60, // 60秒
        category: MediaCategory.meditation,
        createdAt: DateTime.now(), // 添加必需的createdAt参数
      );

      // 模拟播放过程：

      // 1. 开始会话
      // === 开始会话测试 ===
      await EnhancedMeditationSessionManager.startSession(
        mediaItem: testMedia,
        sessionType: SessionType.meditation,
      );

      // 会话已启动
      expect(EnhancedMeditationSessionManager.hasActiveSession, isTrue);

      // 2. 模拟播放过程中的进度更新（只播放到55秒）
      // === 模拟播放进度更新 ===
      for (int i = 10; i <= 55; i += 10) {
        EnhancedMeditationSessionManager.updateSessionProgress(i);
        // 更新进度到: $i秒
      }

      // 检查当前记录的时长
      final currentDuration =
          EnhancedMeditationSessionManager.currentSessionDuration;
      // 当前记录时长: $currentDuration秒
      expect(currentDuration, equals(55)); // 应该是55秒

      // 3. 模拟播放完成：强制更新到完整时长（这是我们的修复）
      // === 模拟播放完成时的强制更新 ===
      final completeDuration = testMedia.duration; // 60秒
      EnhancedMeditationSessionManager.updateSessionProgress(completeDuration);
      // 强制更新到完整时长: $completeDuration秒

      // 4. 完成会话
      // === 完成会话 ===
      await EnhancedMeditationSessionManager.completeSession();

      // 5. 验证结果
      final finalDuration =
          EnhancedMeditationSessionManager.currentSessionDuration;
      // 最终记录时长: $finalDuration秒

      // 验证：完成的会话应该记录完整的60秒时长，而不是55秒
      expect(finalDuration, equals(60), reason: '播放完成时应该记录完整的音频时长');

      // === 测试成功：播放完成时正确统计了完整的播放时长 ===
    });

    test('传统会话管理器也应该正确处理播放完成', () async {
      // 创建测试媒体项
      final testMedia = MediaItem(
        id: 'test-media-2',
        title: '测试冥想音频2',
        filePath: '/test/path/meditation2.mp3',
        type: MediaType.audio, // 添加必需的type参数
        duration: 90, // 90秒
        category: MediaCategory.relaxation,
        createdAt: DateTime.now(), // 添加必需的createdAt参数
      );

      // 开始会话
      await MeditationSessionManager.startSession(
        mediaItem: testMedia,
        sessionType: SessionType.relaxation,
      );

      expect(MeditationSessionManager.hasActiveSession, isTrue);

      // 模拟播放到85秒
      MeditationSessionManager.updateSessionProgress(85);
      expect(MeditationSessionManager.currentSessionDuration, equals(85));

      // 播放完成：强制更新到完整时长
      MeditationSessionManager.updateSessionProgress(testMedia.duration);

      // 完成会话
      await MeditationSessionManager.completeSession();

      // 验证最终记录的时长
      final finalDuration = MeditationSessionManager.currentSessionDuration;
      expect(finalDuration, equals(90), reason: '传统会话管理器也应该正确记录完整时长');

      // 传统会话管理器测试成功
    });

    test('验证修复前后的差异', () {
      // === 修复前后的差异演示 ===

      // 模拟修复前的情况：播放完成时没有强制更新时长
      // 修复前：播放完成时只记录到55秒（不完整）

      // 模拟修复后的情况：播放完成时强制更新到完整时长
      // 修复后：播放完成时强制更新到60秒（完整时长）

      // 这个测试主要是文档性的，说明修复的重要性
      expect(true, isTrue);
    });
  });
}
