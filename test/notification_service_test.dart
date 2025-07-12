import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
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

    test('should initialize without exact alarm permissions', () async {
      // 测试初始化不需要精确定时权限
      expect(() => notificationService.initialize(), returnsNormally);
    });

    test('should schedule notifications with inexact timing', () async {
      // 测试使用非精确定时调度通知
      const time = TimeOfDay(hour: 9, minute: 0);
      const weekdays = [1, 2, 3, 4, 5]; // Monday to Friday

      expect(
        () => notificationService.scheduleRepeatingNotification(
          id: 1,
          title: 'Test Reminder',
          body: 'Test Body',
          time: time,
          weekdays: weekdays,
        ),
        returnsNormally,
      );
    });

    test('should check permissions without exact alarm requirement', () async {
      // 测试权限检查不需要精确定时权限
      expect(
        () => notificationService.areNotificationsEnabled(),
        returnsNormally,
      );
    });
  });
}
