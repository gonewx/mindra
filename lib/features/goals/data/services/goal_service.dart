import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/web_storage_helper.dart';
import '../../domain/entities/user_goal.dart';

class GoalService {
  static const String _goalKey = 'user_goal';

  /// 保存用户目标设置
  static Future<void> saveGoal(UserGoal goal) async {
    try {
      final goalJson = goal.toJson();

      if (kIsWeb) {
        // Web 平台使用 WebStorageHelper
        await WebStorageHelper.setPreference(_goalKey, goalJson);
      } else {
        // 移动平台使用 DatabaseHelper
        await DatabaseHelper.setPreference(_goalKey, goalJson);
      }

      debugPrint('Goal saved successfully: $goal');
    } catch (e) {
      debugPrint('Error saving goal: $e');
      throw Exception('Failed to save goal: $e');
    }
  }

  /// 获取用户目标设置
  static Future<UserGoal> getGoal() async {
    try {
      String? goalJson;

      if (kIsWeb) {
        // Web 平台使用 WebStorageHelper
        goalJson = await WebStorageHelper.getPreference(_goalKey);
      } else {
        // 移动平台使用 DatabaseHelper
        goalJson = await DatabaseHelper.getPreference(_goalKey);
      }

      if (goalJson != null && goalJson.isNotEmpty) {
        final goal = UserGoal.fromJson(goalJson);
        debugPrint('Goal loaded successfully: $goal');
        return goal;
      } else {
        // 如果没有保存的目标，返回默认目标
        final defaultGoal = UserGoal.defaultGoal();
        debugPrint('No saved goal found, returning default: $defaultGoal');
        return defaultGoal;
      }
    } catch (e) {
      debugPrint('Error loading goal: $e');
      // 出错时返回默认目标
      return UserGoal.defaultGoal();
    }
  }

  /// 更新用户目标设置
  static Future<void> updateGoal({
    int? dailyGoalValue,
    GoalTimeUnit? dailyGoalUnit,
    int? weeklyGoalValue,
    GoalFrequencyUnit? weeklyGoalUnit,
    TimeOfDay? reminderTime,
  }) async {
    try {
      // 先获取当前目标
      final currentGoal = await getGoal();

      // 创建更新后的目标
      final updatedGoal = currentGoal.copyWith(
        dailyGoalValue: dailyGoalValue,
        dailyGoalUnit: dailyGoalUnit,
        weeklyGoalValue: weeklyGoalValue,
        weeklyGoalUnit: weeklyGoalUnit,
        reminderTime: reminderTime,
        updatedAt: DateTime.now(),
      );

      // 保存更新后的目标
      await saveGoal(updatedGoal);

      debugPrint('Goal updated successfully: $updatedGoal');
    } catch (e) {
      debugPrint('Error updating goal: $e');
      throw Exception('Failed to update goal: $e');
    }
  }

  /// 删除用户目标设置
  static Future<void> deleteGoal() async {
    try {
      if (kIsWeb) {
        // Web 平台使用 WebStorageHelper
        await WebStorageHelper.setPreference(_goalKey, '');
      } else {
        // 移动平台使用 DatabaseHelper
        await DatabaseHelper.deletePreference(_goalKey);
      }

      debugPrint('Goal deleted successfully');
    } catch (e) {
      debugPrint('Error deleting goal: $e');
      throw Exception('Failed to delete goal: $e');
    }
  }

  /// 检查是否有保存的目标设置
  static Future<bool> hasGoal() async {
    try {
      String? goalJson;

      if (kIsWeb) {
        goalJson = await WebStorageHelper.getPreference(_goalKey);
      } else {
        goalJson = await DatabaseHelper.getPreference(_goalKey);
      }

      return goalJson != null && goalJson.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking goal existence: $e');
      return false;
    }
  }

  /// 重置为默认目标设置
  static Future<void> resetToDefault() async {
    try {
      final defaultGoal = UserGoal.defaultGoal();
      await saveGoal(defaultGoal);
      debugPrint('Goal reset to default: $defaultGoal');
    } catch (e) {
      debugPrint('Error resetting goal to default: $e');
      throw Exception('Failed to reset goal to default: $e');
    }
  }

  /// 验证目标设置是否有效
  static bool isValidGoal(int dailyGoalValue, GoalTimeUnit dailyGoalUnit, int weeklyGoalValue, GoalFrequencyUnit weeklyGoalUnit) {
    // 验证每日目标数值范围
    switch (dailyGoalUnit) {
      case GoalTimeUnit.minutes:
        if (dailyGoalValue < 5 || dailyGoalValue > 120) return false; // 5分钟到2小时
        break;
      case GoalTimeUnit.hours:
        if (dailyGoalValue < 1 || dailyGoalValue > 8) return false; // 1小时到8小时
        break;
    }

    // 验证每周目标数值范围
    if (weeklyGoalValue < 1 || weeklyGoalValue > 21) return false; // 1次到21次

    return true;
  }

  /// 获取可用的每日目标选项（分钟）
  static List<int> getDailyGoalMinuteOptions() {
    return [5, 10, 15, 20, 30, 45, 60, 90, 120];
  }

  /// 获取可用的每日目标选项（小时）
  static List<int> getDailyGoalHourOptions() {
    return [1, 2, 3, 4, 6, 8];
  }

  /// 获取可用的每周目标选项
  static List<int> getWeeklyGoalOptions() {
    return [1, 3, 5, 7, 10, 14, 21];
  }
}
