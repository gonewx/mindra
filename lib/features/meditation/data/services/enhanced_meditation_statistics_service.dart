import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/web_storage_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/meditation_session.dart';
import '../../domain/entities/meditation_statistics.dart';

/// 增强版冥想统计服务 - 解决数据不一致问题
/// 核心改进：
/// 1. 智能会话合并：同一天内的多个播放片段自动合并
/// 2. 全面数据统计：包含所有有效播放时间，不仅仅是"完成"的会话
/// 3. 实时数据同步：确保统计数据始终准确反映用户的冥想活动
class EnhancedMeditationStatisticsService {
  /// 获取用户的冥想统计数据 - 增强版本
  static Future<MeditationStatistics> getStatistics([
    AppLocalizations? localizations,
  ]) async {
    try {
      // 获取所有会话记录 - 包括未完成的有效会话
      final sessions = await _getAllValidSessions();

      // 智能合并同一天内的会话片段
      final mergedDailySessions = _mergeSessionsByDay(sessions);

      // 计算统计数据 - 基于合并后的每日数据
      final now = DateTime.now();
      final weekStart = _getWeekStart(now);
      final weekEnd = weekStart.add(const Duration(days: 6));

      // 历史最长连续天数 - 基于每日有效冥想时间（>=1分钟）
      final streakDays = _calculateStreakDays(mergedDailySessions);

      // 本周时长 - 累计所有有效播放时间
      final weeklyMinutes = _calculateWeeklyMinutes(
        mergedDailySessions,
        weekStart,
        weekEnd,
      );

      // 总统计 - 包含所有有效播放数据
      final totalSessions = _calculateTotalSessions(mergedDailySessions);
      final totalMinutes = _calculateTotalMinutes(sessions);
      final averageRating = _calculateAverageRating(sessions);
      final completedSessions = _calculateCompletedSessions(sessions);

      // 本周每天的数据 - 基于实际播放时长
      final weeklyData = _calculateWeeklyData(mergedDailySessions, weekStart);

      // 生成成就 - 基于实际活动数据
      final achievements = localizations != null
          ? _generateAchievements(
              mergedDailySessions,
              streakDays,
              totalMinutes,
              completedSessions,
              localizations,
            )
          : <Achievement>[];

      // 生成月度记录 - 基于每日合并数据
      final monthlyRecords = _generateMonthlyRecords(mergedDailySessions, now);

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
      debugPrint('Error getting enhanced meditation statistics: $e');
      return _getEmptyStatistics();
    }
  }

  /// 获取所有有效的会话记录 - 不仅仅是完成的会话
  /// 有效会话定义：实际播放时长 >= 30秒
  static Future<List<MeditationSession>> _getAllValidSessions() async {
    List<MeditationSession> sessions;

    if (kIsWeb) {
      sessions = await WebStorageHelper.getAllMeditationSessions();
    } else {
      final rawSessions = await DatabaseHelper.getAllMeditationSessions();
      sessions = rawSessions
          .map((data) => MeditationSession.fromMap(data))
          .toList();
    }

    // 过滤有效会话：实际播放时长 >= 30秒
    return sessions.where((session) {
      return session.actualDuration >= 30; // 至少30秒才算有效冥想
    }).toList();
  }

  /// 智能合并同一天内的会话片段
  /// 核心逻辑：将同一天内的多个播放片段合并为一个有效的冥想活动记录
  static List<DailyMeditationSummary> _mergeSessionsByDay(
    List<MeditationSession> sessions,
  ) {
    // 按日期分组
    final Map<String, List<MeditationSession>> sessionsByDate = {};

    for (final session in sessions) {
      final dateKey = _getDateKey(session.startTime);
      sessionsByDate[dateKey] ??= [];
      sessionsByDate[dateKey]!.add(session);
    }

    // 为每一天创建合并的统计数据
    final dailySummaries = <DailyMeditationSummary>[];

    for (final entry in sessionsByDate.entries) {
      final dateKey = entry.key;
      final daySessions = entry.value;

      // 按开始时间排序
      daySessions.sort((a, b) => a.startTime.compareTo(b.startTime));

      // 计算当天的总统计
      final totalDuration = daySessions.fold<int>(
        0,
        (sum, session) => sum + session.actualDuration,
      );

      final totalSessions = daySessions.length;
      final hasCompletedSession = daySessions.any((s) => s.isCompleted);

      // 计算平均评分（仅限有评分的会话）
      final ratedSessions = daySessions.where((s) => s.rating > 0).toList();
      final averageRating = ratedSessions.isNotEmpty
          ? ratedSessions.fold<double>(0, (sum, s) => sum + s.rating) /
                ratedSessions.length
          : 0.0;

      // 收集使用的音效
      final soundEffects = <String>{};
      for (final session in daySessions) {
        soundEffects.addAll(session.soundEffects);
      }

      // 收集涉及的媒体类型
      final sessionTypes = daySessions.map((s) => s.type).toSet();

      dailySummaries.add(
        DailyMeditationSummary(
          date: _parseDateKey(dateKey),
          totalDurationSeconds: totalDuration,
          sessionCount: totalSessions,
          hasValidMeditation: totalDuration >= 60, // 至少1分钟才算有效冥想日
          hasCompletedSession: hasCompletedSession,
          averageRating: averageRating,
          usedSoundEffects: soundEffects.toList(),
          sessionTypes: sessionTypes.toList(),
          firstSessionStart: daySessions.first.startTime,
          lastSessionEnd:
              daySessions.last.endTime ?? daySessions.last.startTime,
        ),
      );
    }

    // 按日期排序
    dailySummaries.sort((a, b) => a.date.compareTo(b.date));

    return dailySummaries;
  }

  /// 计算历史最长连续冥想天数 - 基于每日有效冥想时间
  static int _calculateStreakDays(List<DailyMeditationSummary> dailySummaries) {
    if (dailySummaries.isEmpty) return 0;

    // 过滤出有效冥想日并按日期排序
    final validDays =
        dailySummaries.where((summary) => summary.hasValidMeditation).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    if (validDays.isEmpty) return 0;
    if (validDays.length == 1) return 1;

    // 计算最长连续天数
    int maxStreakDays = 1; // 至少有一天
    int currentStreakDays = 1;

    for (int i = 1; i < validDays.length; i++) {
      final currentDate = validDays[i].date;
      final previousDate = validDays[i - 1].date;

      // 检查是否是连续的日期（相差1天）
      if (currentDate.difference(previousDate).inDays == 1) {
        currentStreakDays++;
        maxStreakDays = maxStreakDays > currentStreakDays
            ? maxStreakDays
            : currentStreakDays;
      } else {
        currentStreakDays = 1; // 重新开始计算连续天数
      }
    }

    return maxStreakDays;
  }

  /// 计算本周总时长 - 包含所有有效播放时间
  static int _calculateWeeklyMinutes(
    List<DailyMeditationSummary> dailySummaries,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    var totalSeconds = 0;

    for (final summary in dailySummaries) {
      if (!summary.date.isBefore(weekStart) && !summary.date.isAfter(weekEnd)) {
        totalSeconds += summary.totalDurationSeconds;
      }
    }

    return totalSeconds ~/ 60;
  }

  /// 计算总会话数 - 基于每日有效冥想日
  static int _calculateTotalSessions(
    List<DailyMeditationSummary> dailySummaries,
  ) {
    return dailySummaries.where((s) => s.hasValidMeditation).length;
  }

  /// 计算总时长 - 包含所有有效播放时间
  static int _calculateTotalMinutes(List<MeditationSession> sessions) {
    return sessions.fold<int>(
          0,
          (sum, session) => sum + session.actualDuration,
        ) ~/
        60;
  }

  /// 计算平均评分 - 仅包含有评分的会话
  static double _calculateAverageRating(List<MeditationSession> sessions) {
    final ratedSessions = sessions.where((s) => s.rating > 0).toList();
    if (ratedSessions.isEmpty) return 0.0;

    return ratedSessions.fold<double>(0, (sum, s) => sum + s.rating) /
        ratedSessions.length;
  }

  /// 计算完成的会话数
  static int _calculateCompletedSessions(List<MeditationSession> sessions) {
    return sessions.where((s) => s.isCompleted).length;
  }

  /// 计算本周每天的数据 - 基于实际播放时长
  static List<int> _calculateWeeklyData(
    List<DailyMeditationSummary> dailySummaries,
    DateTime weekStart,
  ) {
    final weeklyData = List<int>.filled(7, 0);

    // 创建日期到摘要的映射
    final summaryMap = <String, DailyMeditationSummary>{};
    for (final summary in dailySummaries) {
      summaryMap[_getDateKey(summary.date)] = summary;
    }

    // 填充本周每天的数据
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateKey = _getDateKey(date);
      final summary = summaryMap[dateKey];

      if (summary != null) {
        weeklyData[i] = summary.totalDurationSeconds ~/ 60;
      }
    }

    return weeklyData;
  }

  /// 生成成就 - 基于实际活动数据
  static List<Achievement> _generateAchievements(
    List<DailyMeditationSummary> dailySummaries,
    int streakDays,
    int totalMinutes,
    int completedSessions,
    AppLocalizations localizations,
  ) {
    final achievements = <Achievement>[];
    final sessionTypes = <SessionType>{};
    var maxDailyDuration = 0;

    // 收集统计数据
    for (final summary in dailySummaries) {
      sessionTypes.addAll(summary.sessionTypes);
      if (summary.totalDurationSeconds > maxDailyDuration) {
        maxDailyDuration = summary.totalDurationSeconds;
      }
    }

    final maxDailyMinutes = maxDailyDuration ~/ 60;

    for (final achievement in AchievementDefinitions.getDefaultAchievements(
      localizations,
    )) {
      bool isEarned = false;
      DateTime? earnedDate;

      switch (achievement.id) {
        case 'first_meditation':
          isEarned = dailySummaries.any((s) => s.hasValidMeditation);
          if (isEarned) {
            earnedDate = dailySummaries
                .where((s) => s.hasValidMeditation)
                .first
                .firstSessionStart;
          }
          break;
        case 'week_streak':
          isEarned = streakDays >= 7;
          break;
        case 'focus_master':
          isEarned = maxDailyMinutes >= 30;
          break;
        case 'meditation_expert':
          isEarned = totalMinutes >= 600; // 10小时
          break;
        case 'consistency_champion':
          isEarned = streakDays >= 30;
          break;
        case 'variety_seeker':
          isEarned = sessionTypes.length >= 3; // 降低要求，更现实
          break;
      }

      achievements.add(
        achievement.copyWith(isEarned: isEarned, earnedDate: earnedDate),
      );
    }

    return achievements;
  }

  /// 生成月度记录 - 基于每日合并数据
  static List<MeditationDayRecord> _generateMonthlyRecords(
    List<DailyMeditationSummary> dailySummaries,
    DateTime now,
  ) {
    final records = <MeditationDayRecord>[];
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    // 创建日期到摘要的映射
    final summaryMap = <String, DailyMeditationSummary>{};
    for (final summary in dailySummaries) {
      if (summary.date.year == now.year && summary.date.month == now.month) {
        summaryMap[_getDateKey(summary.date)] = summary;
      }
    }

    // 为每一天生成记录
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(now.year, now.month, day);
      final dateKey = _getDateKey(date);
      final summary = summaryMap[dateKey];

      records.add(
        MeditationDayRecord(
          date: date,
          sessionCount: summary?.sessionCount ?? 0,
          totalMinutes: (summary?.totalDurationSeconds ?? 0) ~/ 60,
          hasSession: summary?.hasValidMeditation ?? false,
        ),
      );
    }

    return records;
  }

  /// 辅助方法：获取周开始日期（周一）
  static DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  /// 辅助方法：获取日期键
  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 辅助方法：解析日期键
  static DateTime _parseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
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
}

/// 每日冥想摘要 - 智能合并同一天内的多个会话
class DailyMeditationSummary {
  final DateTime date;
  final int totalDurationSeconds;
  final int sessionCount;
  final bool hasValidMeditation; // 是否达到有效冥想标准（>=1分钟）
  final bool hasCompletedSession;
  final double averageRating;
  final List<String> usedSoundEffects;
  final List<SessionType> sessionTypes;
  final DateTime firstSessionStart;
  final DateTime? lastSessionEnd;

  const DailyMeditationSummary({
    required this.date,
    required this.totalDurationSeconds,
    required this.sessionCount,
    required this.hasValidMeditation,
    required this.hasCompletedSession,
    required this.averageRating,
    required this.usedSoundEffects,
    required this.sessionTypes,
    required this.firstSessionStart,
    this.lastSessionEnd,
  });

  int get totalMinutes => totalDurationSeconds ~/ 60;
}
