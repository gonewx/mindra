import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/features/player/services/global_player_service.dart';

void main() {
  group('Timer Integration Tests', () {
    late GlobalPlayerService playerService;

    setUp(() {
      playerService = GlobalPlayerService();
    });

    tearDown(() {
      playerService.cancelSleepTimer();
    });

    test('timer should be created and managed correctly', () {
      // 验证初始状态
      expect(playerService.hasActiveTimer, isFalse);

      // 设置定时器
      playerService.setSleepTimer(30);
      expect(playerService.hasActiveTimer, isTrue);

      // 取消定时器
      playerService.cancelSleepTimer();
      expect(playerService.hasActiveTimer, isFalse);
    });

    test('timer should replace previous timer when set multiple times', () {
      // 设置第一个定时器
      playerService.setSleepTimer(15);
      expect(playerService.hasActiveTimer, isTrue);

      // 设置第二个定时器（应该替换第一个）
      playerService.setSleepTimer(30);
      expect(playerService.hasActiveTimer, isTrue);

      // 应该仍然只有一个定时器
      playerService.cancelSleepTimer();
      expect(playerService.hasActiveTimer, isFalse);
    });

    test('timer should handle rapid operations correctly', () async {
      // 快速设置和取消定时器
      for (int i = 0; i < 5; i++) {
        playerService.setSleepTimer(i + 1);
        expect(playerService.hasActiveTimer, isTrue);

        await Future.delayed(const Duration(milliseconds: 10));

        playerService.cancelSleepTimer();
        expect(playerService.hasActiveTimer, isFalse);
      }
    });

    test('timer should work with various time values', () {
      final testValues = [1, 5, 10, 15, 30, 45, 60, 90, 120];

      for (final minutes in testValues) {
        playerService.setSleepTimer(minutes);
        expect(
          playerService.hasActiveTimer,
          isTrue,
          reason: 'Timer should be active for $minutes minutes',
        );

        playerService.cancelSleepTimer();
        expect(
          playerService.hasActiveTimer,
          isFalse,
          reason: 'Timer should be cancelled for $minutes minutes',
        );
      }
    });

    test('timer should handle edge cases', () {
      // 测试0分钟定时器
      playerService.setSleepTimer(0);
      expect(playerService.hasActiveTimer, isTrue);
      playerService.cancelSleepTimer();

      // 测试很大的定时器值
      playerService.setSleepTimer(999);
      expect(playerService.hasActiveTimer, isTrue);
      playerService.cancelSleepTimer();

      // 测试取消不存在的定时器
      expect(playerService.hasActiveTimer, isFalse);
      playerService.cancelSleepTimer(); // 不应该抛出异常
      expect(playerService.hasActiveTimer, isFalse);
    });

    test('timer should persist across state changes', () async {
      // 设置定时器
      playerService.setSleepTimer(20);
      expect(playerService.hasActiveTimer, isTrue);

      // 模拟一些状态变化
      await Future.delayed(const Duration(milliseconds: 50));

      // 定时器应该仍然存在
      expect(playerService.hasActiveTimer, isTrue);

      // 清理
      playerService.cancelSleepTimer();
      expect(playerService.hasActiveTimer, isFalse);
    });

    test('timer should handle concurrent operations', () async {
      // 并发设置定时器
      final futures = <Future>[];

      for (int i = 0; i < 10; i++) {
        futures.add(
          Future.delayed(
            Duration(milliseconds: i * 10),
            () => playerService.setSleepTimer(i + 1),
          ),
        );
      }

      await Future.wait(futures);

      // 应该有一个活动的定时器
      expect(playerService.hasActiveTimer, isTrue);

      // 清理
      playerService.cancelSleepTimer();
      expect(playerService.hasActiveTimer, isFalse);
    });

    test('timer functionality should be consistent', () {
      // 测试功能的一致性

      // 多次设置和取消定时器
      for (int i = 0; i < 20; i++) {
        playerService.setSleepTimer(30);
        expect(playerService.hasActiveTimer, isTrue);

        playerService.cancelSleepTimer();
        expect(playerService.hasActiveTimer, isFalse);
      }
    });
  });

  group('Timer UI Integration Tests', () {
    test('timer state should be accessible for UI', () {
      final playerService = GlobalPlayerService();

      // 验证UI可以访问定时器状态
      expect(playerService.hasActiveTimer, isFalse);

      // 设置定时器
      playerService.setSleepTimer(10);
      expect(playerService.hasActiveTimer, isTrue);

      // 取消定时器
      playerService.cancelSleepTimer();
      expect(playerService.hasActiveTimer, isFalse);
    });

    test('timer should work with typical UI workflows', () {
      final playerService = GlobalPlayerService();

      // 模拟用户选择定时器
      final userSelectedTimes = [5, 10, 15, 30, 45, 60];

      for (final time in userSelectedTimes) {
        // 用户选择定时器时间
        playerService.setSleepTimer(time);
        expect(playerService.hasActiveTimer, isTrue);

        // 用户取消定时器
        playerService.cancelSleepTimer();
        expect(playerService.hasActiveTimer, isFalse);
      }
    });
  });

  group('Timer Error Handling Tests', () {
    test('timer should handle errors gracefully', () {
      final playerService = GlobalPlayerService();

      // 测试多次取消
      playerService.cancelSleepTimer();
      playerService.cancelSleepTimer();
      playerService.cancelSleepTimer();

      // 不应该抛出异常
      expect(playerService.hasActiveTimer, isFalse);

      // 设置定时器后多次取消
      playerService.setSleepTimer(10);
      expect(playerService.hasActiveTimer, isTrue);

      playerService.cancelSleepTimer();
      playerService.cancelSleepTimer();
      playerService.cancelSleepTimer();

      expect(playerService.hasActiveTimer, isFalse);
    });
  });
}
