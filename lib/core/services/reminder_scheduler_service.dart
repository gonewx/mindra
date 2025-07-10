import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../../features/goals/domain/entities/user_goal.dart';
import '../../features/goals/data/services/goal_service.dart';
import '../localization/app_localizations.dart';

/// 提醒调度服务
/// 负责管理和调度所有冥想提醒
class ReminderSchedulerService {
  static final ReminderSchedulerService _instance =
      ReminderSchedulerService._internal();
  factory ReminderSchedulerService() => _instance;
  ReminderSchedulerService._internal();

  final NotificationService _notificationService = NotificationService();

  /// 提醒通知的基础ID
  static const int _baseReminderId = 1000;

  /// 初始化提醒调度服务
  Future<void> initialize() async {
    await _notificationService.initialize();

    // 启动时重新调度所有提醒
    await _rescheduleAllReminders();
  }

  /// 更新用户提醒设置
  Future<void> updateReminderSettings(UserGoal goal, [BuildContext? context]) async {
    try {
      // 取消现有的提醒
      await _cancelAllReminders();

      // 如果启用了提醒，重新调度
      if (goal.isReminderEnabled) {
        await _scheduleReminders(goal, context);
      }

      debugPrint('Reminder settings updated: ${goal.isReminderEnabled}');
    } catch (e) {
      debugPrint('Error updating reminder settings: $e');
      rethrow;
    }
  }

  /// 调度提醒
  Future<void> _scheduleReminders(UserGoal goal, [BuildContext? context]) async {
    if (!goal.isReminderEnabled) {
      debugPrint('Reminders disabled');
      return;
    }

    // 获取本地化文本（在异步操作之前）
    String title;
    String body;
    
    if (context != null) {
      final l10n = AppLocalizations.of(context)!;
      title = l10n.reminderNotificationTitle;
      final goalText = goal.getDailyGoalText(l10n);
      body = l10n.reminderNotificationBody(goalText);
    } else {
      // 回退到默认文本（英文）
      title = 'Meditation Time!';
      final goalValue = goal.dailyGoalValue;
      final unitText = goal.dailyGoalUnit == GoalTimeUnit.minutes ? 'minute' : 'hour';
      final pluralSuffix = goalValue == 1 ? '' : 's';
      body = 'Time to start your $goalValue $unitText$pluralSuffix meditation and let your mind relax.';
    }

    // 检查通知权限
    final hasPermission = await _notificationService.areNotificationsEnabled();
    if (!hasPermission) {
      debugPrint('Notification permissions not granted');
      return;
    }

    final reminderTime = goal.reminderTime;
    final weekdays = _parseReminderDays(goal.reminderDays);

    if (weekdays.isEmpty) {
      debugPrint('No reminder days selected');
      return;
    }

    // 创建通知详情
    final notificationDetails = _notificationService
        .createMeditationReminderDetails(
          enableSound: goal.enableSound,
          enableVibration: goal.enableVibration,
        );

    // 调度重复提醒
    await _notificationService.scheduleRepeatingNotification(
      id: _baseReminderId,
      title: title,
      body: body,
      time: reminderTime,
      weekdays: weekdays,
      payload: 'meditation_reminder',
      notificationDetails: notificationDetails,
    );

    debugPrint('Reminders scheduled for ${weekdays.length} days');
  }

  /// 取消所有提醒
  Future<void> _cancelAllReminders() async {
    try {
      // 取消基础提醒和相关的重复提醒
      for (int i = 0; i < 7; i++) {
        await _notificationService.cancelNotification(_baseReminderId + i);
      }

      debugPrint('All reminders cancelled');
    } catch (e) {
      debugPrint('Error cancelling reminders: $e');
    }
  }

  /// 重新调度所有提醒
  Future<void> _rescheduleAllReminders() async {
    try {
      final goal = await GoalService.getGoal();
      await updateReminderSettings(goal);
    } catch (e) {
      debugPrint('Error rescheduling reminders: $e');
    }
  }

  /// 解析提醒日期
  List<int> _parseReminderDays(List<String> reminderDays) {
    final Map<String, int> dayMap = {
      '周一': 1,
      '周二': 2,
      '周三': 3,
      '周四': 4,
      '周五': 5,
      '周六': 6,
      '周日': 7,
    };

    return reminderDays
        .map((day) => dayMap[day])
        .where((day) => day != null)
        .cast<int>()
        .toList();
  }

  /// 请求通知权限
  Future<bool> requestNotificationPermissions() async {
    try {
      return await _notificationService.requestPermissions();
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// 检查通知权限状态
  Future<bool> checkNotificationPermissions() async {
    try {
      return await _notificationService.areNotificationsEnabled();
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
      return false;
    }
  }

  /// 显示测试通知
  Future<void> showTestNotification([BuildContext? context]) async {
    try {
      // 获取本地化文本（在异步操作之前）
      String title;
      String body;
      
      if (context != null) {
        final l10n = AppLocalizations.of(context)!;
        title = l10n.testNotificationTitle;
        body = l10n.testNotificationBody;
      } else {
        // 回退到默认文本（英文）
        title = 'Test Notification';
        body = 'This is a test notification to verify that the reminder function works properly.';
      }

      final hasPermission = await _notificationService
          .areNotificationsEnabled();
      if (!hasPermission) {
        debugPrint('No notification permissions for test');
        return;
      }

      await _notificationService.showNotification(
        id: 9999,
        title: title,
        body: body,
        payload: 'test_notification',
      );
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  /// 获取待发送的提醒列表
  Future<List<String>> getPendingReminders() async {
    try {
      final pendingNotifications = await _notificationService
          .getPendingNotifications();
      return pendingNotifications
          .where((notification) => notification.id >= _baseReminderId)
          .map((notification) => '${notification.title} - ${notification.body}')
          .toList();
    } catch (e) {
      debugPrint('Error getting pending reminders: $e');
      return [];
    }
  }

  /// 启用提醒
  Future<void> enableReminders() async {
    try {
      final goal = await GoalService.getGoal();
      final updatedGoal = goal.copyWith(
        isReminderEnabled: true,
        updatedAt: DateTime.now(),
      );

      await GoalService.saveGoal(updatedGoal);
      await updateReminderSettings(updatedGoal);

      debugPrint('Reminders enabled');
    } catch (e) {
      debugPrint('Error enabling reminders: $e');
      rethrow;
    }
  }

  /// 禁用提醒
  Future<void> disableReminders() async {
    try {
      await _cancelAllReminders();

      final goal = await GoalService.getGoal();
      final updatedGoal = goal.copyWith(
        isReminderEnabled: false,
        updatedAt: DateTime.now(),
      );

      await GoalService.saveGoal(updatedGoal);

      debugPrint('Reminders disabled');
    } catch (e) {
      debugPrint('Error disabling reminders: $e');
      rethrow;
    }
  }

  /// 更新提醒时间
  Future<void> updateReminderTime(TimeOfDay time) async {
    try {
      final goal = await GoalService.getGoal();
      final updatedGoal = goal.copyWith(
        reminderTime: time,
        updatedAt: DateTime.now(),
      );

      await GoalService.saveGoal(updatedGoal);
      await updateReminderSettings(updatedGoal);

      debugPrint('Reminder time updated to ${time.hour}:${time.minute}');
    } catch (e) {
      debugPrint('Error updating reminder time: $e');
      rethrow;
    }
  }

  /// 更新提醒日期
  Future<void> updateReminderDays(List<String> days) async {
    try {
      final goal = await GoalService.getGoal();
      final updatedGoal = goal.copyWith(
        reminderDays: days,
        updatedAt: DateTime.now(),
      );

      await GoalService.saveGoal(updatedGoal);
      await updateReminderSettings(updatedGoal);

      debugPrint('Reminder days updated: $days');
    } catch (e) {
      debugPrint('Error updating reminder days: $e');
      rethrow;
    }
  }

  /// 获取下一个提醒时间
  Future<DateTime?> getNextReminderTime() async {
    try {
      final goal = await GoalService.getGoal();
      if (!goal.isReminderEnabled) {
        return null;
      }

      final reminderTime = goal.reminderTime;
      final weekdays = _parseReminderDays(goal.reminderDays);

      if (weekdays.isEmpty) {
        return null;
      }

      // 找到下一个提醒时间
      final now = DateTime.now();
      DateTime nextReminder = DateTime(
        now.year,
        now.month,
        now.day,
        reminderTime.hour,
        reminderTime.minute,
      );

      // 如果今天的提醒时间已过，从明天开始查找
      if (nextReminder.isBefore(now)) {
        nextReminder = nextReminder.add(const Duration(days: 1));
      }

      // 查找下一个匹配的工作日
      while (!weekdays.contains(nextReminder.weekday)) {
        nextReminder = nextReminder.add(const Duration(days: 1));
      }

      return nextReminder;
    } catch (e) {
      debugPrint('Error getting next reminder time: $e');
      return null;
    }
  }

  /// 清理资源
  void dispose() {
    _notificationService.dispose();
  }
}
