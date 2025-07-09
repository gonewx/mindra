import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class UserGoal extends Equatable {
  final String dailyGoal; // 每日目标，如 "20分钟"
  final String weeklyGoal; // 每周目标，如 "7次"
  final TimeOfDay reminderTime; // 提醒时间
  final DateTime createdAt; // 创建时间
  final DateTime updatedAt; // 更新时间

  const UserGoal({
    required this.dailyGoal,
    required this.weeklyGoal,
    required this.reminderTime,
    required this.createdAt,
    required this.updatedAt,
  });

  // 默认目标设置
  factory UserGoal.defaultGoal() {
    final now = DateTime.now();
    return UserGoal(
      dailyGoal: '20分钟',
      weeklyGoal: '7次',
      reminderTime: const TimeOfDay(hour: 9, minute: 0),
      createdAt: now,
      updatedAt: now,
    );
  }

  UserGoal copyWith({
    String? dailyGoal,
    String? weeklyGoal,
    TimeOfDay? reminderTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserGoal(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      reminderTime: reminderTime ?? this.reminderTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // 转换为 Map 用于存储
  Map<String, dynamic> toMap() {
    return {
      'daily_goal': dailyGoal,
      'weekly_goal': weeklyGoal,
      'reminder_hour': reminderTime.hour,
      'reminder_minute': reminderTime.minute,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // 从 Map 创建实例
  factory UserGoal.fromMap(Map<String, dynamic> map) {
    return UserGoal(
      dailyGoal: map['daily_goal'] ?? '20分钟',
      weeklyGoal: map['weekly_goal'] ?? '7次',
      reminderTime: TimeOfDay(
        hour: map['reminder_hour'] ?? 9,
        minute: map['reminder_minute'] ?? 0,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  // 转换为 JSON 字符串用于存储
  String toJson() {
    return '''
{
  "daily_goal": "$dailyGoal",
  "weekly_goal": "$weeklyGoal",
  "reminder_hour": ${reminderTime.hour},
  "reminder_minute": ${reminderTime.minute},
  "created_at": ${createdAt.millisecondsSinceEpoch},
  "updated_at": ${updatedAt.millisecondsSinceEpoch}
}''';
  }

  // 从 JSON 字符串创建实例
  factory UserGoal.fromJson(String jsonString) {
    // 简单的 JSON 解析，避免依赖 dart:convert
    final lines = jsonString.split('\n');
    String dailyGoal = '20分钟';
    String weeklyGoal = '7次';
    int reminderHour = 9;
    int reminderMinute = 0;
    int createdAt = DateTime.now().millisecondsSinceEpoch;
    int updatedAt = DateTime.now().millisecondsSinceEpoch;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('"daily_goal":')) {
        dailyGoal = trimmed.split('"')[3];
      } else if (trimmed.startsWith('"weekly_goal":')) {
        weeklyGoal = trimmed.split('"')[3];
      } else if (trimmed.startsWith('"reminder_hour":')) {
        reminderHour = int.tryParse(trimmed.split(':')[1].replaceAll(',', '').trim()) ?? 9;
      } else if (trimmed.startsWith('"reminder_minute":')) {
        reminderMinute = int.tryParse(trimmed.split(':')[1].replaceAll(',', '').trim()) ?? 0;
      } else if (trimmed.startsWith('"created_at":')) {
        createdAt = int.tryParse(trimmed.split(':')[1].replaceAll(',', '').trim()) ?? DateTime.now().millisecondsSinceEpoch;
      } else if (trimmed.startsWith('"updated_at":')) {
        updatedAt = int.tryParse(trimmed.split(':')[1].trim()) ?? DateTime.now().millisecondsSinceEpoch;
      }
    }

    return UserGoal(
      dailyGoal: dailyGoal,
      weeklyGoal: weeklyGoal,
      reminderTime: TimeOfDay(hour: reminderHour, minute: reminderMinute),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }

  // 获取每日目标的分钟数
  int get dailyGoalMinutes {
    final match = RegExp(r'(\d+)').firstMatch(dailyGoal);
    return match != null ? int.tryParse(match.group(1)!) ?? 20 : 20;
  }

  // 获取每周目标的次数
  int get weeklyGoalCount {
    final match = RegExp(r'(\d+)').firstMatch(weeklyGoal);
    return match != null ? int.tryParse(match.group(1)!) ?? 7 : 7;
  }

  // 格式化提醒时间为字符串
  String get reminderTimeString {
    final hour = reminderTime.hour.toString().padLeft(2, '0');
    final minute = reminderTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  List<Object?> get props => [
        dailyGoal,
        weeklyGoal,
        reminderTime,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'UserGoal(dailyGoal: $dailyGoal, weeklyGoal: $weeklyGoal, reminderTime: ${reminderTimeString})';
  }
}
