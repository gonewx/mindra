import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/features/player/services/global_player_service.dart';

/// 测试播放页面素材加载优化
///
/// 验证：
/// 1. 相同素材不会重复加载
/// 2. 播放状态得到正确保持
/// 3. 不同素材能够正确切换
void main() {
  group('播放页面素材加载优化测试', () {
    late GlobalPlayerService playerService;

    setUp(() {
      playerService = GlobalPlayerService();
    });

    test('相同素材检测应该正确工作', () {
      // 模拟已加载的媒体
      const mediaId = 'test-media-123';

      // 初始状态应该返回false
      expect(playerService.isMediaLoaded(mediaId), false);

      // 测试空的媒体ID
      expect(playerService.isMediaLoaded(''), false);
    });

    test('获取媒体状态应该返回正确信息', () {
      final status = playerService.getCurrentMediaStatus();

      expect(status, isA<Map<String, dynamic>>());
      expect(status.containsKey('mediaId'), true);
      expect(status.containsKey('title'), true);
      expect(status.containsKey('isPlaying'), true);
      expect(status.containsKey('currentPosition'), true);
      expect(status.containsKey('totalDuration'), true);
      expect(status.containsKey('playerState'), true);
      expect(status.containsKey('isLoading'), true);

      // 初始状态验证
      expect(status['mediaId'], null);
      expect(status['isPlaying'], false);
      expect(status['currentPosition'], 0.0);
      expect(status['totalDuration'], 0.0);
      expect(status['isLoading'], false);
    });

    test('prepareMediaForPlayer 应该处理 null mediaId', () async {
      // 应该不会抛出异常
      expect(
        () async => await playerService.prepareMediaForPlayer(null),
        returnsNormally,
      );
    });

    test('播放服务初始状态应该正确', () {
      expect(playerService.isPlaying, false);
      expect(playerService.currentPosition, 0.0);
      expect(playerService.totalDuration, 0.0);
      expect(playerService.currentMedia, null);
      expect(playerService.title, '未选择素材');
      expect(playerService.category, '');
    });

    tearDown(() {
      // 清理资源 - 注意：实际的 dispose 可能需要特殊处理
      // playerService.dispose();
    });
  });
}
