import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/web_storage_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/meditation_session.dart';
import '../../domain/entities/meditation_statistics.dart';

class MeditationStatisticsService {
  /// 获取用户的冥想统计数据
  static Future<MeditationStatistics> getStatistics([AppLocalizations? localizations]) async {
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

      // 计算统计数据
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      // 计算连续天数
      final streakDays = _calculateStreakDays(sessions);

      // 计算本周时长
      final weeklyMinutes = _calculateWeeklyMinutes(
        sessions,
        weekStart,
        weekEnd,
      );

      // 计算总统计
      final totalSessions = sessions.length;
      final totalMinutes = sessions.fold<int>(
        0,
        (sum, session) => sum + (session.actualDuration ~/ 60),
      );
      final averageRating = sessions.isNotEmpty
          ? sessions.fold<double>(0, (sum, session) => sum + session.rating) /
                sessions.length
          : 0.0;
      final completedSessions = sessions
          .where((session) => session.isCompleted)
          .length;

      // 计算本周每天的数据
      final weeklyData = _calculateWeeklyData(sessions, weekStart);

      // 生成成就
      final achievements = localizations != null 
          ? _generateAchievements(
              sessions,
              streakDays,
              totalMinutes,
              completedSessions,
              localizations,
            )
          : <Achievement>[];

      // 生成月度记录
      final monthlyRecords = _generateMonthlyRecords(sessions, now);

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

  /// 计算连续天数
  static int _calculateStreakDays(List<MeditationSession> sessions) {
    if (sessions.isEmpty) return 0;

    final now = DateTime.now();
    final completedSessions = sessions
        .where((session) => session.isCompleted)
        .toList();
    if (completedSessions.isEmpty) return 0;

    // 按日期分组
    final Map<String, List<MeditationSession>> sessionsByDate = {};
    for (final session in completedSessions) {
      final dateKey = _getDateKey(session.startTime);
      sessionsByDate[dateKey] = sessionsByDate[dateKey] ?? [];
      sessionsByDate[dateKey]!.add(session);
    }

    // 计算连续天数
    int streakDays = 0;
    var currentDate = now;

    while (true) {
      final dateKey = _getDateKey(currentDate);
      if (sessionsByDate.containsKey(dateKey)) {
        streakDays++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streakDays;
  }

  /// 计算本周时长
  static int _calculateWeeklyMinutes(
    List<MeditationSession> sessions,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    final weeklySessions = sessions.where((session) {
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
      final endDate = DateTime(weekEnd.year, weekEnd.month, weekEnd.day);
      return !sessionDate.isBefore(startDate) && !sessionDate.isAfter(endDate);
    }).toList();

    return weeklySessions.fold<int>(
      0,
      (sum, session) => sum + (session.actualDuration ~/ 60),
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

      if (dayIndex >= 0 && dayIndex < 7) {
        weeklyData[dayIndex] += session.actualDuration ~/ 60;
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

    for (final achievement in AchievementDefinitions.getDefaultAchievements(localizations)) {
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
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    // 按日期分组会话
    final Map<String, List<MeditationSession>> sessionsByDate = {};
    for (final session in sessions) {
      final dateKey = _getDateKey(session.startTime);
      sessionsByDate[dateKey] = sessionsByDate[dateKey] ?? [];
      sessionsByDate[dateKey]!.add(session);
    }

    // 为每一天生成记录
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(now.year, now.month, day);
      final dateKey = _getDateKey(date);
      final daySessions = sessionsByDate[dateKey] ?? [];

      records.add(
        MeditationDayRecord(
          date: date,
          sessionCount: daySessions.length,
          totalMinutes: daySessions.fold<int>(
            0,
            (sum, session) => sum + (session.actualDuration ~/ 60),
          ),
          hasSession: daySessions.isNotEmpty,
        ),
      );
    }

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
    DateTime end,
    [AppLocalizations? localizations]
  ) async {
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
        (sum, session) => sum + (session.actualDuration ~/ 60),
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
