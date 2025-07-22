import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/constants/weekday.dart';

/// 目标时间单位枚举
enum GoalTimeUnit { minutes, hours }

/// 目标频率单位枚举
enum GoalFrequencyUnit { times, sessions }

class UserGoal extends Equatable {
  final int dailyGoalValue; // 每日目标数值，如 20
  final GoalTimeUnit dailyGoalUnit; // 每日目标单位，如 minutes
  final int weeklyGoalValue; // 每周目标数值，如 7
  final GoalFrequencyUnit weeklyGoalUnit; // 每周目标单位，如 times
  final TimeOfDay reminderTime; // 提醒时间
  final bool isReminderEnabled; // 是否启用提醒
  final List<Weekday> reminderDays; // 提醒日期
  final bool enableSound; // 是否启用声音
  final bool enableVibration; // 是否启用振动
  final DateTime createdAt; // 创建时间
  final DateTime updatedAt; // 更新时间

  const UserGoal({
    required this.dailyGoalValue,
    this.dailyGoalUnit = GoalTimeUnit.minutes,
    required this.weeklyGoalValue,
    this.weeklyGoalUnit = GoalFrequencyUnit.times,
    required this.reminderTime,
    this.isReminderEnabled = false,
    this.reminderDays = const [
      Weekday.monday,
      Weekday.tuesday,
      Weekday.wednesday,
      Weekday.thursday,
      Weekday.friday,
      Weekday.saturday,
      Weekday.sunday,
    ],
    this.enableSound = true,
    this.enableVibration = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // 默认目标设置
  factory UserGoal.defaultGoal([AppLocalizations? l10n]) {
    final now = DateTime.now();
    return UserGoal(
      dailyGoalValue: 20,
      dailyGoalUnit: GoalTimeUnit.minutes,
      weeklyGoalValue: 7,
      weeklyGoalUnit: GoalFrequencyUnit.times,
      reminderTime: const TimeOfDay(hour: 9, minute: 0),
      isReminderEnabled: false,
      reminderDays: const [
        Weekday.monday,
        Weekday.tuesday,
        Weekday.wednesday,
        Weekday.thursday,
        Weekday.friday,
        Weekday.saturday,
        Weekday.sunday,
      ],
      enableSound: true,
      enableVibration: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  UserGoal copyWith({
    int? dailyGoalValue,
    GoalTimeUnit? dailyGoalUnit,
    int? weeklyGoalValue,
    GoalFrequencyUnit? weeklyGoalUnit,
    TimeOfDay? reminderTime,
    bool? isReminderEnabled,
    List<Weekday>? reminderDays,
    bool? enableSound,
    bool? enableVibration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserGoal(
      dailyGoalValue: dailyGoalValue ?? this.dailyGoalValue,
      dailyGoalUnit: dailyGoalUnit ?? this.dailyGoalUnit,
      weeklyGoalValue: weeklyGoalValue ?? this.weeklyGoalValue,
      weeklyGoalUnit: weeklyGoalUnit ?? this.weeklyGoalUnit,
      reminderTime: reminderTime ?? this.reminderTime,
      isReminderEnabled: isReminderEnabled ?? this.isReminderEnabled,
      reminderDays: reminderDays ?? this.reminderDays,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 转换为 Map 用于存储
  Map<String, dynamic> toMap() {
    return {
      'daily_goal_value': dailyGoalValue,
      'daily_goal_unit': dailyGoalUnit.name,
      'weekly_goal_value': weeklyGoalValue,
      'weekly_goal_unit': weeklyGoalUnit.name,
      'reminder_hour': reminderTime.hour,
      'reminder_minute': reminderTime.minute,
      'is_reminder_enabled': isReminderEnabled,
      'reminder_days': reminderDays.stringValues.join(','),
      'enable_sound': enableSound,
      'enable_vibration': enableVibration,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // 从 Map 创建实例
  factory UserGoal.fromMap(Map<String, dynamic> map) {
    return UserGoal(
      dailyGoalValue:
          map['daily_goal_value'] ?? map['daily_goal_minutes'] ?? 20,
      dailyGoalUnit: GoalTimeUnit.values.firstWhere(
        (unit) => unit.name == (map['daily_goal_unit'] ?? 'minutes'),
        orElse: () => GoalTimeUnit.minutes,
      ),
      weeklyGoalValue:
          map['weekly_goal_value'] ?? map['weekly_goal_count'] ?? 7,
      weeklyGoalUnit: GoalFrequencyUnit.values.firstWhere(
        (unit) => unit.name == (map['weekly_goal_unit'] ?? 'times'),
        orElse: () => GoalFrequencyUnit.times,
      ),
      reminderTime: TimeOfDay(
        hour: map['reminder_hour'] ?? 9,
        minute: map['reminder_minute'] ?? 0,
      ),
      isReminderEnabled: map['is_reminder_enabled'] ?? false,
      reminderDays: _parseReminderDaysFromMap(map['reminder_days']),
      enableSound: map['enable_sound'] ?? true,
      enableVibration: map['enable_vibration'] ?? true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// 从Map中解析提醒日期，兼容旧数据
  static List<Weekday> _parseReminderDaysFromMap(dynamic reminderDaysValue) {
    if (reminderDaysValue == null) {
      return WeekdayExtension.allWeekdays;
    }

    final reminderDaysString = reminderDaysValue.toString();
    final dayStrings = reminderDaysString.split(',');

    // 尝试从枚举名称解析
    try {
      return WeekdayListExtension.fromStringList(dayStrings);
    } catch (_) {
      // 如果失败，尝试从本地化字符串解析（兼容旧数据）
      return WeekdayListExtension.fromLocalizedStringList(dayStrings);
    }
  }

  // 转换为 JSON 字符串用于存储
  String toJson() {
    return '''
{
  "daily_goal_value": $dailyGoalValue,
  "daily_goal_unit": "${dailyGoalUnit.name}",
  "weekly_goal_value": $weeklyGoalValue,
  "weekly_goal_unit": "${weeklyGoalUnit.name}",
  "reminder_hour": ${reminderTime.hour},
  "reminder_minute": ${reminderTime.minute},
  "is_reminder_enabled": $isReminderEnabled,
  "reminder_days": "${reminderDays.stringValues.join(',')}",
  "enable_sound": $enableSound,
  "enable_vibration": $enableVibration,
  "created_at": ${createdAt.millisecondsSinceEpoch},
  "updated_at": ${updatedAt.millisecondsSinceEpoch}
}''';
  }

  // 从 JSON 字符串创建实例
  factory UserGoal.fromJson(String jsonString) {
    // 简单的 JSON 解析，避免依赖 dart:convert
    final lines = jsonString.split('\n');
    int dailyGoalValue = 20;
    GoalTimeUnit dailyGoalUnit = GoalTimeUnit.minutes;
    int weeklyGoalValue = 7;
    GoalFrequencyUnit weeklyGoalUnit = GoalFrequencyUnit.times;
    int reminderHour = 9;
    int reminderMinute = 0;
    bool isReminderEnabled = false;
    String reminderDaysString = '周一,周二,周三,周四,周五,周六,周日';
    bool enableSound = true;
    bool enableVibration = true;
    int createdAt = DateTime.now().millisecondsSinceEpoch;
    int updatedAt = DateTime.now().millisecondsSinceEpoch;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('"daily_goal_value":')) {
        dailyGoalValue =
            int.tryParse(trimmed.split(':')[1].replaceAll(',', '').trim()) ??
            20;
      } else if (trimmed.startsWith('"daily_goal_unit":')) {
        final unitString = trimmed.split('"')[3];
        dailyGoalUnit = GoalTimeUnit.values.firstWhere(
          (unit) => unit.name == unitString,
          orElse: () => GoalTimeUnit.minutes,
        );
      } else if (trimmed.startsWith('"weekly_goal_value":')) {
        weeklyGoalValue =
            int.tryParse(trimmed.split(':')[1].replaceAll(',', '').trim()) ?? 7;
      } else if (trimmed.startsWith('"weekly_goal_unit":')) {
        final unitString = trimmed.split('"')[3];
        weeklyGoalUnit = GoalFrequencyUnit.values.firstWhere(
          (unit) => unit.name == unitString,
          orElse: () => GoalFrequencyUnit.times,
        );
      } else if (trimmed.startsWith('"reminder_hour":')) {
        reminderHour =
            int.tryParse(trimmed.split(':')[1].replaceAll(',', '').trim()) ?? 9;
      } else if (trimmed.startsWith('"reminder_minute":')) {
        reminderMinute =
            int.tryParse(trimmed.split(':')[1].replaceAll(',', '').trim()) ?? 0;
      } else if (trimmed.startsWith('"is_reminder_enabled":')) {
        isReminderEnabled =
            trimmed.split(':')[1].replaceAll(',', '').trim() == 'true';
      } else if (trimmed.startsWith('"reminder_days":')) {
        reminderDaysString = trimmed.split('"')[3];
      } else if (trimmed.startsWith('"enable_sound":')) {
        enableSound =
            trimmed.split(':')[1].replaceAll(',', '').trim() == 'true';
      } else if (trimmed.startsWith('"enable_vibration":')) {
        enableVibration =
            trimmed.split(':')[1].replaceAll(',', '').trim() == 'true';
      } else if (trimmed.startsWith('"created_at":')) {
        createdAt =
            int.tryParse(trimmed.split(':')[1].replaceAll(',', '').trim()) ??
            DateTime.now().millisecondsSinceEpoch;
      } else if (trimmed.startsWith('"updated_at":')) {
        updatedAt =
            int.tryParse(trimmed.split(':')[1].trim()) ??
            DateTime.now().millisecondsSinceEpoch;
      }
    }

    return UserGoal(
      dailyGoalValue: dailyGoalValue,
      dailyGoalUnit: dailyGoalUnit,
      weeklyGoalValue: weeklyGoalValue,
      weeklyGoalUnit: weeklyGoalUnit,
      reminderTime: TimeOfDay(hour: reminderHour, minute: reminderMinute),
      isReminderEnabled: isReminderEnabled,
      reminderDays: _parseReminderDaysFromMap(reminderDaysString),
      enableSound: enableSound,
      enableVibration: enableVibration,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }

  // 获取每日目标的分钟数
  int get dailyGoalMinutes {
    switch (dailyGoalUnit) {
      case GoalTimeUnit.minutes:
        return dailyGoalValue;
      case GoalTimeUnit.hours:
        return dailyGoalValue * 60;
    }
  }

  // 获取每周目标的次数
  int get weeklyGoalCount {
    return weeklyGoalValue;
  }

  // 获取格式化的每日目标文本
  String getDailyGoalText(AppLocalizations localizations) {
    switch (dailyGoalUnit) {
      case GoalTimeUnit.minutes:
        return localizations.statsMinutesFormat(dailyGoalValue);
      case GoalTimeUnit.hours:
        return localizations.locale.languageCode == 'zh'
            ? '$dailyGoalValue小时'
            : '$dailyGoalValue ${dailyGoalValue == 1 ? "hour" : "hours"}';
    }
  }

  // 获取格式化的每周目标文本
  String getWeeklyGoalText(AppLocalizations localizations) {
    switch (weeklyGoalUnit) {
      case GoalFrequencyUnit.times:
        return localizations.statsTimesFormat(weeklyGoalValue);
      case GoalFrequencyUnit.sessions:
        return localizations.locale.languageCode == 'zh'
            ? '$weeklyGoalValue学习'
            : '$weeklyGoalValue ${weeklyGoalValue == 1 ? "session" : "sessions"}';
    }
  }

  // 格式化提醒时间为字符串
  String get reminderTimeString {
    final hour = reminderTime.hour.toString().padLeft(2, '0');
    final minute = reminderTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  List<Object?> get props => [
    dailyGoalValue,
    dailyGoalUnit,
    weeklyGoalValue,
    weeklyGoalUnit,
    reminderTime,
    isReminderEnabled,
    reminderDays,
    enableSound,
    enableVibration,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() {
    return 'UserGoal(dailyGoal: $dailyGoalValue ${dailyGoalUnit.name}, weeklyGoal: $weeklyGoalValue ${weeklyGoalUnit.name}, reminderTime: $reminderTimeString, isReminderEnabled: $isReminderEnabled)';
  }
}
