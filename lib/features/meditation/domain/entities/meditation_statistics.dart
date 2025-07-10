import 'package:equatable/equatable.dart';

class MeditationStatistics extends Equatable {
  final int streakDays;
  final int weeklyMinutes;
  final int totalSessions;
  final int totalMinutes;
  final double averageRating;
  final int completedSessions;
  final List<int> weeklyData; // 7天的数据
  final List<Achievement> achievements;
  final List<MeditationDayRecord> monthlyRecords;

  const MeditationStatistics({
    required this.streakDays,
    required this.weeklyMinutes,
    required this.totalSessions,
    required this.totalMinutes,
    required this.averageRating,
    required this.completedSessions,
    required this.weeklyData,
    required this.achievements,
    required this.monthlyRecords,
  });

  MeditationStatistics copyWith({
    int? streakDays,
    int? weeklyMinutes,
    int? totalSessions,
    int? totalMinutes,
    double? averageRating,
    int? completedSessions,
    List<int>? weeklyData,
    List<Achievement>? achievements,
    List<MeditationDayRecord>? monthlyRecords,
  }) {
    return MeditationStatistics(
      streakDays: streakDays ?? this.streakDays,
      weeklyMinutes: weeklyMinutes ?? this.weeklyMinutes,
      totalSessions: totalSessions ?? this.totalSessions,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      averageRating: averageRating ?? this.averageRating,
      completedSessions: completedSessions ?? this.completedSessions,
      weeklyData: weeklyData ?? this.weeklyData,
      achievements: achievements ?? this.achievements,
      monthlyRecords: monthlyRecords ?? this.monthlyRecords,
    );
  }

  @override
  List<Object?> get props => [
        streakDays,
        weeklyMinutes,
        totalSessions,
        totalMinutes,
        averageRating,
        completedSessions,
        weeklyData,
        achievements,
        monthlyRecords,
      ];
}

class Achievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final bool isEarned;
  final DateTime? earnedDate;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.isEarned,
    this.earnedDate,
  });

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    String? iconName,
    bool? isEarned,
    DateTime? earnedDate,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      isEarned: isEarned ?? this.isEarned,
      earnedDate: earnedDate ?? this.earnedDate,
    );
  }

  @override
  List<Object?> get props => [id, title, description, iconName, isEarned, earnedDate];
}

class MeditationDayRecord extends Equatable {
  final DateTime date;
  final int sessionCount;
  final int totalMinutes;
  final bool hasSession;

  const MeditationDayRecord({
    required this.date,
    required this.sessionCount,
    required this.totalMinutes,
    required this.hasSession,
  });

  MeditationDayRecord copyWith({
    DateTime? date,
    int? sessionCount,
    int? totalMinutes,
    bool? hasSession,
  }) {
    return MeditationDayRecord(
      date: date ?? this.date,
      sessionCount: sessionCount ?? this.sessionCount,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      hasSession: hasSession ?? this.hasSession,
    );
  }

  @override
  List<Object?> get props => [date, sessionCount, totalMinutes, hasSession];
}

// 预定义的成就
class AchievementDefinitions {
  static const List<Achievement> defaultAchievements = [
    Achievement(
      id: 'first_meditation',
      title: '冥想新手',
      description: '完成第一次冥想',
      iconName: 'spa',
      isEarned: false,
    ),
    Achievement(
      id: 'week_streak',
      title: '连续一周',
      description: '连续7天进行冥想',
      iconName: 'calendar_view_week',
      isEarned: false,
    ),
    Achievement(
      id: 'focus_master',
      title: '专注大师',
      description: '完成30分钟以上的冥想',
      iconName: 'psychology',
      isEarned: false,
    ),
    Achievement(
      id: 'meditation_expert',
      title: '冥想达人',
      description: '累计冥想时长达到10小时',
      iconName: 'workspace_premium',
      isEarned: false,
    ),
    Achievement(
      id: 'consistency_champion',
      title: '坚持之王',
      description: '连续30天进行冥想',
      iconName: 'military_tech',
      isEarned: false,
    ),
    Achievement(
      id: 'variety_seeker',
      title: '多样体验',
      description: '尝试5种不同类型的冥想',
      iconName: 'explore',
      isEarned: false,
    ),
  ];
}