import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/web_storage_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/meditation_session.dart';
import '../../domain/entities/meditation_statistics.dart';

class MeditationStatisticsService {
  /// 获取用户的冥想统计数据
  static Future<MeditationStatistics> getStatistics([
    AppLocalizations? localizations,
  ]) async {
    try {
      // 获取所有会话记录
      List<MeditationSession> sessions;

      if (kIsWeb) {
        sessions = await WebStorageHelper.getAllMeditationSessions();
      } else {
        // 从数据库获取原始数据并转换为实体
        final rawSessions = await DatabaseHelper.getAllMeditationSessions();
        sessions = rawSessions
            .map((data) => MeditationSession.fromMap(data))
            .toList();
      }

      // 融合增强版会话管理器的每日统计数据
      sessions = await _mergeEnhancedDailyStats(sessions);

      // 计算统计数据
      final now = DateTime.now();
      // 修正本周计算：获取本周一的开始时间（00:00:00）
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1),
      );
      final weekEnd = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + 6,
        23,
        59,
        59,
      );

      // 过滤有效会话（统一过滤逻辑）
      final validSessions = sessions
          .where((session) => session.isCompleted || session.actualDuration > 0)
          .toList();

      // 计算当前连续天数
      final streakDays = _calculateStreakDays(validSessions);

      // 计算本周时长
      final weeklyMinutes = _calculateWeeklyMinutes(
        validSessions,
        weekStart,
        weekEnd,
      );

      // 计算总统计（使用已过滤的有效会话）
      final totalSessions = validSessions.length;
      final totalMinutes = validSessions.fold<int>(
        0,
        (sum, session) =>
            sum +
            (session.actualDuration > 0
                ? ((session.actualDuration + 59) ~/ 60)
                : 0),
      );
      final averageRating = validSessions.isNotEmpty
          ? validSessions.fold<double>(
                  0,
                  (sum, session) => sum + session.rating,
                ) /
                validSessions.length
          : 0.0;
      final completedSessions = validSessions.length; // 所有有效会话都算作已完成

      // 计算本周每天的数据
      final weeklyData = _calculateWeeklyData(validSessions, weekStart);

      // 生成成就
      final achievements = localizations != null
          ? _generateAchievements(
              validSessions,
              streakDays,
              totalMinutes,
              completedSessions,
              localizations,
            )
          : <Achievement>[];

      // 生成月度记录
      final monthlyRecords = _generateMonthlyRecords(validSessions, now);

      return MeditationStatistics(
        streakDays: streakDays,
        weeklyMinutes: weeklyMinutes,
        totalSessions: totalSessions,
        totalMinutes: totalMinutes,
        averageRating: averageRating,
        completedSessions: completedSessions,
        weeklyData: weeklyData,
        achievements: achievements,
        monthlyRecords: monthlyRecords,
      );
    } catch (e) {
      debugPrint('Error getting meditation statistics: $e');
      // 返回空统计数据
      return _getEmptyStatistics();
    }
  }

  /// 计算当前连续天数
  static int _calculateStreakDays(List<MeditationSession> validSessions) {
    if (validSessions.isEmpty) return 0;

    // 按日期分组
    final Map<String, List<MeditationSession>> sessionsByDate = {};
    for (final session in validSessions) {
      final dateKey = _getDateKey(session.startTime);
      sessionsByDate[dateKey] = sessionsByDate[dateKey] ?? [];
      sessionsByDate[dateKey]!.add(session);
    }

    if (sessionsByDate.isEmpty) return 0;

    // debugPrint('连续天数计算 - 有效会话数量: ${validSessions.length}');
    // debugPrint('连续天数计算 - 有冥想的日期: ${sessionsByDate.keys.toList()..sort()}');

    // 计算当前连续天数（从今天或最近的冥想日期开始往前推）
    final today = DateTime.now();
    final todayKey = _getDateKey(today);
    final yesterdayKey = _getDateKey(today.subtract(const Duration(days: 1)));

    // 确定开始计算的日期
    DateTime startDate;
    if (sessionsByDate.containsKey(todayKey)) {
      startDate = today;
    } else if (sessionsByDate.containsKey(yesterdayKey)) {
      startDate = today.subtract(const Duration(days: 1));
    } else {
      // 如果今天和昨天都没有冥想，找到最近的冥想日期
      final sortedDates = sessionsByDate.keys.toList()..sort();
      if (sortedDates.isEmpty) return 0;

      // 检查最近的冥想日期是否在合理范围内（比如一周内）
      final latestDateKey = sortedDates.last;
      final latestDate = _parseDateKeyLocal(latestDateKey);
      final daysSinceLatest = today.difference(latestDate).inDays;

      if (daysSinceLatest > 1) {
        // 如果超过1天没有冥想，连续天数为0
        // debugPrint('连续天数计算 - 最近冥想日期: $latestDateKey, 距今: $daysSinceLatest 天');
        return 0;
      }
      startDate = latestDate;
    }

    int currentStreakDays = 0;
    DateTime checkDate = startDate;

    // 从开始日期往前推，计算连续天数
    while (true) {
      final dateKey = _getDateKey(checkDate);
      if (sessionsByDate.containsKey(dateKey)) {
        currentStreakDays++;
        // debugPrint('连续天数计算 - 第$currentStreakDays天: $dateKey');
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    debugPrint('连续天数计算 - 最终结果: $currentStreakDays 天');
    return currentStreakDays;
  }

  /// 本地解析日期键（避免重复代码）
  static DateTime _parseDateKeyLocal(String dateKey) {
    final parts = dateKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// 计算本周时长
  static int _calculateWeeklyMinutes(
    List<MeditationSession> sessions,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final weeklySessions = sessions.where((session) {
      // 使用会话的开始时间与本周范围进行比较
      return session.startTime.isAfter(
            weekStart.subtract(const Duration(milliseconds: 1)),
          ) &&
          session.startTime.isBefore(
            weekEnd.add(const Duration(milliseconds: 1)),
          );
    }).toList();

    return weeklySessions.fold<int>(
      0,
      (sum, session) =>
          sum +
          (session.actualDuration > 0
              ? ((session.actualDuration + 59) ~/ 60)
              : 0),
    );
  }

  /// 计算本周每天的数据
  static List<int> _calculateWeeklyData(
    List<MeditationSession> sessions,
    DateTime weekStart,
  ) {
    final weeklyData = List<int>.filled(7, 0);

    for (final session in sessions) {
      final sessionDate = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      final startDate = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final dayIndex = sessionDate.difference(startDate).inDays;

      // 确保只计算本周内的会话数据
      if (dayIndex >= 0 && dayIndex < 7) {
        weeklyData[dayIndex] += session.actualDuration > 0
            ? ((session.actualDuration + 59) ~/ 60)
            : 0;
      }
    }

    return weeklyData;
  }

  /// 生成成就
  static List<Achievement> _generateAchievements(
    List<MeditationSession> sessions,
    int streakDays,
    int totalMinutes,
    int completedSessions,
    AppLocalizations localizations,
  ) {
    final achievements = <Achievement>[];
    final sessionTypes = sessions.map((s) => s.type).toSet();
    final maxSessionDuration = sessions.isNotEmpty
        ? sessions
                  .map((s) => s.actualDuration)
                  .reduce((a, b) => a > b ? a : b) ~/
              60
        : 0;

    for (final achievement in AchievementDefinitions.getDefaultAchievements(
      localizations,
    )) {
      bool isEarned = false;
      DateTime? earnedDate;

      switch (achievement.id) {
        case 'first_meditation':
          isEarned = completedSessions > 0;
          if (isEarned) earnedDate = sessions.first.startTime;
          break;
        case 'week_streak':
          isEarned = streakDays >= 7;
          break;
        case 'focus_master':
          isEarned = maxSessionDuration >= 30;
          break;
        case 'meditation_expert':
          isEarned = totalMinutes >= 600; // 10小时
          break;
        case 'consistency_champion':
          isEarned = streakDays >= 30;
          break;
        case 'variety_seeker':
          isEarned = sessionTypes.length >= 5;
          break;
      }

      achievements.add(
        achievement.copyWith(isEarned: isEarned, earnedDate: earnedDate),
      );
    }

    return achievements;
  }

  /// 生成月度记录
  static List<MeditationDayRecord> _generateMonthlyRecords(
    List<MeditationSession> sessions,
    DateTime now,
  ) {
    final records = <MeditationDayRecord>[];

    // 按日期分组会话
    final Map<String, List<MeditationSession>> sessionsByDate = {};
    for (final session in sessions) {
      final dateKey = _getDateKey(session.startTime);
      sessionsByDate[dateKey] = sessionsByDate[dateKey] ?? [];
      sessionsByDate[dateKey]!.add(session);
    }

    // 生成当前月份的每日记录
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0);

    for (int day = 1; day <= currentMonthEnd.day; day++) {
      final date = DateTime(now.year, now.month, day);
      final dateKey = _getDateKey(date);
      final daySessions = sessionsByDate[dateKey] ?? [];

      records.add(
        MeditationDayRecord(
          date: date,
          sessionCount: daySessions.length,
          totalMinutes: daySessions.fold<int>(
            0,
            (sum, session) =>
                sum +
                (session.actualDuration > 0
                    ? ((session.actualDuration + 59) ~/ 60)
                    : 0),
          ),
          hasSession: daySessions.isNotEmpty,
        ),
      );
    }

    // 如果有其他月份的会话数据，也包含在记录中（用于历史数据完整性）
    final currentMonthKeys = records.map((r) => _getDateKey(r.date)).toSet();
    for (final dateKey in sessionsByDate.keys) {
      if (!currentMonthKeys.contains(dateKey)) {
        final parts = dateKey.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final daySessions = sessionsByDate[dateKey]!;

        records.add(
          MeditationDayRecord(
            date: date,
            sessionCount: daySessions.length,
            totalMinutes: daySessions.fold<int>(
              0,
              (sum, session) =>
                  sum +
                  (session.actualDuration > 0
                      ? ((session.actualDuration + 59) ~/ 60)
                      : 0),
            ),
            hasSession: true,
          ),
        );
      }
    }

    // 按日期排序
    records.sort((a, b) => a.date.compareTo(b.date));

    return records;
  }

  /// 获取日期键
  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 获取空统计数据
  static MeditationStatistics _getEmptyStatistics() {
    return const MeditationStatistics(
      streakDays: 0,
      weeklyMinutes: 0,
      totalSessions: 0,
      totalMinutes: 0,
      averageRating: 0.0,
      completedSessions: 0,
      weeklyData: [0, 0, 0, 0, 0, 0, 0],
      achievements: [],
      monthlyRecords: [],
    );
  }

  /// 融合增强版会话管理器的每日统计数据
  static Future<List<MeditationSession>> _mergeEnhancedDailyStats(
    List<MeditationSession> originalSessions,
  ) async {
    try {
      final Map<String, List<MeditationSession>> sessionsByDate = {};
      final Map<String, int> dailyTotalsByDate = {};

      // 将原始会话按日期分组
      for (final session in originalSessions) {
        final dateKey = _getDateKey(session.startTime);
        sessionsByDate[dateKey] = sessionsByDate[dateKey] ?? [];
        sessionsByDate[dateKey]!.add(session);

        // 计算每日总时长
        final currentTotal = dailyTotalsByDate[dateKey] ?? 0;
        dailyTotalsByDate[dateKey] = currentTotal + session.actualDuration;
      }

      // 读取最近30天的增强版每日统计数据
      final now = DateTime.now();
      final List<MeditationSession> mergedSessions = List.from(
        originalSessions,
      );

      for (int i = 0; i < 30; i++) {
        final checkDate = now.subtract(Duration(days: i));
        final dateKey = _getDateKey(checkDate);

        // 尝试读取该日期的增强版统计数据
        String? enhancedStatsJson;
        final prefKey = 'daily_stats_$dateKey';

        if (kIsWeb) {
          enhancedStatsJson = await WebStorageHelper.getPreference(prefKey);
        } else {
          enhancedStatsJson = await DatabaseHelper.getPreference(prefKey);
        }

        if (enhancedStatsJson != null && enhancedStatsJson.isNotEmpty) {
          try {
            // 解析增强版统计数据
            final regex = RegExp(r'"totalDurationSeconds":(\d+)');
            final match = regex.firstMatch(enhancedStatsJson);

            if (match != null) {
              final enhancedTotalSeconds = int.parse(match.group(1)!);
              final currentTotalSeconds = dailyTotalsByDate[dateKey] ?? 0;

              // 如果增强版的统计数据大于数据库记录的总和，说明有遗漏的数据
              if (enhancedTotalSeconds > currentTotalSeconds) {
                final missingSeconds =
                    enhancedTotalSeconds - currentTotalSeconds;

                debugPrint(
                  'Statistics merge: Found missing data for $dateKey: '
                  '${missingSeconds}s (enhanced: ${enhancedTotalSeconds}s, db: ${currentTotalSeconds}s)',
                );

                // 创建一个虚拟会话记录来补足缺失的统计数据
                final virtualSession = MeditationSession(
                  id: 'virtual_${dateKey}_${DateTime.now().millisecondsSinceEpoch}',
                  mediaItemId: 'enhanced_daily_stats',
                  title: '每日累计冥想时长',
                  duration: missingSeconds,
                  actualDuration: missingSeconds,
                  startTime: checkDate,
                  endTime: checkDate.add(Duration(seconds: missingSeconds)),
                  type: SessionType.meditation,
                  soundEffects: [],
                  isCompleted: true,
                  rating: 0.0,
                  notes: '增强版会话管理器记录的每日累计时长',
                  defaultImageIndex: 1,
                );

                mergedSessions.add(virtualSession);
                debugPrint(
                  'Added virtual session for $dateKey with ${missingSeconds}s',
                );
              }
            }
          } catch (e) {
            debugPrint('Error parsing enhanced stats for $dateKey: $e');
          }
        }
      }

      return mergedSessions;
    } catch (e) {
      debugPrint('Error merging enhanced daily stats: $e');
      return originalSessions; // 发生错误时返回原始数据
    }
  }

  /// 刷新统计数据缓存
  static Future<void> refreshStatistics() async {
    try {
      // 这里可以添加缓存清理逻辑
      debugPrint('Statistics cache refreshed');
    } catch (e) {
      debugPrint('Error refreshing statistics cache: $e');
    }
  }

  /// 获取特定日期范围的统计数据
  static Future<MeditationStatistics> getStatisticsForDateRange(
    DateTime start,
    DateTime end, [
    AppLocalizations? localizations,
  ]) async {
    try {
      List<MeditationSession> allSessions;

      if (kIsWeb) {
        allSessions = await WebStorageHelper.getAllMeditationSessions();
      } else {
        // 从数据库获取原始数据并转换为实体
        final rawSessions = await DatabaseHelper.getAllMeditationSessions();
        allSessions = rawSessions
            .map((data) => MeditationSession.fromMap(data))
            .toList();
      }

      // 过滤指定日期范围的会话
      final filteredSessions = allSessions.where((session) {
        final sessionDate = DateTime(
          session.startTime.year,
          session.startTime.month,
          session.startTime.day,
        );
        final startDate = DateTime(start.year, start.month, start.day);
        final endDate = DateTime(end.year, end.month, end.day);
        return !sessionDate.isBefore(startDate) &&
            !sessionDate.isAfter(endDate);
      }).toList();

      // 基于过滤后的会话计算统计数据
      final totalSessions = filteredSessions.length;
      final totalMinutes = filteredSessions.fold<int>(
        0,
        (sum, session) =>
            sum +
            (session.actualDuration > 0
                ? ((session.actualDuration + 59) ~/ 60)
                : 0),
      );
      final averageRating = filteredSessions.isNotEmpty
          ? filteredSessions.fold<double>(
                  0,
                  (sum, session) => sum + session.rating,
                ) /
                filteredSessions.length
          : 0.0;
      final completedSessions = filteredSessions
          .where((session) => session.isCompleted)
          .length;

      return MeditationStatistics(
        streakDays: _calculateStreakDays(filteredSessions),
        weeklyMinutes: totalMinutes,
        totalSessions: totalSessions,
        totalMinutes: totalMinutes,
        averageRating: averageRating,
        completedSessions: completedSessions,
        weeklyData: _calculateWeeklyData(filteredSessions, start),
        achievements: localizations != null
            ? _generateAchievements(
                filteredSessions,
                0,
                totalMinutes,
                completedSessions,
                localizations,
              )
            : <Achievement>[],
        monthlyRecords: _generateMonthlyRecords(filteredSessions, end),
      );
    } catch (e) {
      debugPrint('Error getting statistics for date range: $e');
      return _getEmptyStatistics();
    }
  }
}
