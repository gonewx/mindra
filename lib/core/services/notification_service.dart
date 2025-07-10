import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化时区数据
    tz.initializeTimeZones();

    // Android 初始化设置
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 初始化设置
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // 初始化设置
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // 初始化插件
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  /// 处理通知点击事件
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint('Notification clicked: ${response.payload}');
    // 这里可以处理通知点击后的导航逻辑
  }

  /// 请求通知权限
  Future<bool> requestPermissions() async {
    if (kIsWeb) {
      debugPrint('Web platform does not support local notifications');
      return false;
    }

    try {
      // Android 权限处理
      if (Platform.isAndroid) {
        // 检查并请求通知权限
        final notificationStatus = await Permission.notification.request();
        
        // 请求精确闹钟权限（Android 12+）
        final alarmStatus = await Permission.scheduleExactAlarm.request();
        
        // Android 13+ 需要特殊处理
        if (Platform.isAndroid) {
          final androidInfo = await _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission();
          
          debugPrint('Android notification permission: $androidInfo');
          debugPrint('Notification status: $notificationStatus');
          debugPrint('Alarm status: $alarmStatus');
          
          return androidInfo == true && 
                 notificationStatus == PermissionStatus.granted &&
                 (alarmStatus == PermissionStatus.granted || alarmStatus == PermissionStatus.limited);
        }
        
        return notificationStatus == PermissionStatus.granted;
      }
      
      // iOS 权限处理
      if (Platform.isIOS) {
        final bool? result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        
        debugPrint('iOS notification permission: $result');
        return result == true;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// 检查通知权限状态
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    
    try {
      if (Platform.isAndroid) {
        final notificationStatus = await Permission.notification.status;
        final alarmStatus = await Permission.scheduleExactAlarm.status;
        
        debugPrint('Checking permissions - Notification: $notificationStatus, Alarm: $alarmStatus');
        
        return notificationStatus == PermissionStatus.granted &&
               (alarmStatus == PermissionStatus.granted || alarmStatus == PermissionStatus.limited);
      }
      
      if (Platform.isIOS) {
        final bool? result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions()
            .then((permissions) => permissions?.isEnabled);
        
        return result == true;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error checking notification permissions: $e');
      return false;
    }
  }

  /// 显示即时通知
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized');
      return;
    }

    final details = notificationDetails ?? _getDefaultNotificationDetails();

    try {
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
      debugPrint('Notification shown: $title');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  /// 安排定时通知
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized');
      return;
    }

    final details = notificationDetails ?? _getDefaultNotificationDetails();

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('Notification scheduled: $title at $scheduledDate');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// 安排重复通知
  Future<void> scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    required List<int> weekdays, // 1=Monday, 7=Sunday
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    if (!_isInitialized) {
      debugPrint('NotificationService not initialized');
      return;
    }

    final details = notificationDetails ?? _getDefaultNotificationDetails();

    try {
      // 为每个工作日安排独立的通知
      for (int i = 0; i < weekdays.length; i++) {
        final weekday = weekdays[i];
        final notificationId = id + i;
        
        // 计算下一个指定工作日的时间
        final now = DateTime.now();
        DateTime scheduledDate = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
        
        // 调整到指定的工作日
        while (scheduledDate.weekday != weekday) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        
        // 如果时间已过，推迟到下周
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }

        await _flutterLocalNotificationsPlugin.zonedSchedule(
          notificationId,
          title,
          body,
          tz.TZDateTime.from(scheduledDate, tz.local),
          details,
          payload: payload,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      
      debugPrint('Repeating notifications scheduled for weekdays: $weekdays');
    } catch (e) {
      debugPrint('Error scheduling repeating notification: $e');
    }
  }

  /// 取消指定通知
  Future<void> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      debugPrint('Notification cancelled: $id');
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('All notifications cancelled');
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  /// 获取待发送的通知列表
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('Error getting pending notifications: $e');
      return [];
    }
  }

  /// 获取默认通知详情
  NotificationDetails _getDefaultNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      'meditation_reminders',
      '冥想提醒',
      channelDescription: '冥想应用的每日提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// 创建冥想提醒通知详情
  NotificationDetails createMeditationReminderDetails({
    bool enableSound = true,
    bool enableVibration = true,
  }) {
    final androidDetails = AndroidNotificationDetails(
      'meditation_reminders',
      '冥想提醒',
      channelDescription: '冥想应用的每日提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const BigTextStyleInformation(''),
      enableVibration: enableVibration,
      playSound: enableSound,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: enableSound,
      sound: enableSound ? 'default' : null,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// 获取系统时区
  static String getCurrentTimeZone() {
    return tz.local.name;
  }

  /// 清理服务资源
  void dispose() {
    _isInitialized = false;
  }
}