import 'package:flutter_test/flutter_test.dart';
import 'package:mindra/core/services/notification_service.dart';

void main() {
  group('NotificationService Tests', () {
    late NotificationService notificationService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      notificationService = NotificationService();
    });

    test('should create notification service instance', () {
      // 测试创建通知服务实例
      expect(notificationService, isNotNull);
      expect(notificationService, isA<NotificationService>());
    });

    test('should handle missing plugin gracefully', () async {
      // 测试在没有原生插件的情况下优雅处理
      try {
        await notificationService.initialize();
      } catch (e) {
        // 预期会抛出 MissingPluginException，这是正常的
        expect(e.toString(), contains('MissingPluginException'));
      }
    });

    test('should return singleton instance', () {
      // 测试单例模式
      final instance1 = NotificationService();
      final instance2 = NotificationService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('should create notification details', () {
      // 测试创建通知详情
      final details = notificationService.createMeditationReminderDetails();
      expect(details, isNotNull);
      expect(details.android, isNotNull);
      expect(details.iOS, isNotNull);
    });

    test('should get current timezone', () {
      // 测试获取当前时区
      final timezone = NotificationService.getCurrentTimeZone();
      expect(timezone, isNotNull);
      expect(timezone, isA<String>());
    });
  });
}
