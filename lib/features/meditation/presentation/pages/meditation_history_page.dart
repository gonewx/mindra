import 'package:flutter/material.dart';
import '../../data/services/meditation_statistics_service.dart';
import '../../domain/entities/meditation_statistics.dart';
import '../widgets/goal_settings_dialog.dart';
import '../widgets/reminder_settings_dialog.dart';
import '../../../goals/domain/entities/user_goal.dart';
import '../../../goals/data/services/goal_service.dart';
import '../../../../core/localization/app_localizations.dart';

class MeditationHistoryPage extends StatefulWidget {
  const MeditationHistoryPage({super.key});

  @override
  State<MeditationHistoryPage> createState() => _MeditationHistoryPageState();
}

class _MeditationHistoryPageState extends State<MeditationHistoryPage> {
  MeditationStatistics? _statistics;
  UserGoal? _userGoal;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 不在 initState 中立即加载数据，等待 didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在这里加载数据，确保 Localizations 已经可用
    if (_isLoading) {
      _loadData();
    }
  }

  Future<void> _refreshData() async {
    // 确保 context 已经可用
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    try {
      final localizations = AppLocalizations.of(context)!;
      final statistics = await MeditationStatisticsService.getStatistics(
        localizations,
      );
      final userGoal = await GoalService.getGoal();

      if (mounted) {
        setState(() {
          _statistics = statistics;
          _userGoal = userGoal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error loading data: $e');
    }
  }

  void _onGoalUpdated(UserGoal goal) {
    setState(() {
      _userGoal = goal;
    });
  }

  IconData _getAchievementIcon(String iconName) {
    switch (iconName) {
      case 'spa':
        return Icons.spa_rounded;
      case 'calendar_view_week':
        return Icons.calendar_view_week_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'military_tech':
        return Icons.military_tech_rounded;
      case 'explore':
        return Icons.explore_rounded;
      default:
        return Icons.spa_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final statistics =
        _statistics ??
        const MeditationStatistics(
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

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.progressMyProgress,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click, // 添加手形光标
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          showProgressSettings(
                            context,
                            userGoal: _userGoal,
                            onGoalUpdated: _onGoalUpdated,
                          );
                        },
                        icon: Icon(
                          Icons.settings_outlined,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Stats Overview
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.local_fire_department_rounded,
                      title: localizations.statsConsecutiveDays,
                      value: localizations.statsDaysFormat(
                        statistics.streakDays,
                      ),
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.schedule_rounded,
                      title: localizations.statsWeeklyDuration,
                      value: localizations.statsMinutesFormat(
                        statistics.weeklyMinutes,
                      ),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.emoji_events_rounded,
                      title: localizations.statsTotalSessions,
                      value: localizations.statsTimesFormat(
                        statistics.totalSessions,
                      ),
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Weekly Chart
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.statsWeeklyMeditationDuration,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: _WeeklyChart(weeklyData: statistics.weeklyData),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Achievements
              Text(
                localizations.achievementsTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4, // 改为3列，给更多空间显示文字
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85, // 调整宽高比，给文字更多空间
                children: statistics.achievements.map((achievement) {
                  return _AchievementBadge(
                    icon: _getAchievementIcon(achievement.iconName),
                    label: achievement.title,
                    isEarned: achievement.isEarned,
                    color: achievement.isEarned
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Calendar View
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.historyMeditationHistory,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _CalendarGrid(monthlyRecords: statistics.monthlyRecords),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<int> weeklyData;

  const _WeeklyChart({required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    // Use real data instead of mock data
    final weekDays = [
      localizations.calendarMonday,
      localizations.calendarTuesday,
      localizations.calendarWednesday,
      localizations.calendarThursday,
      localizations.calendarFriday,
      localizations.calendarSaturday,
      localizations.calendarSunday,
    ];
    final maxValue = weeklyData.isNotEmpty
        ? weeklyData.reduce((a, b) => a > b ? a : b)
        : 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final value = weeklyData[index];
        final height = maxValue > 0 ? (value / maxValue) * 150 : 0.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 24,
              height: height,
              decoration: BoxDecoration(
                color: value > 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(weekDays[index], style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              '${value}m',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isEarned;
  final Color color;

  const _AchievementBadge({
    required this.icon,
    required this.label,
    required this.isEarned,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEarned ? color : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEarned
              ? color
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: isEarned ? Colors.white : color),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isEarned
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
              fontSize: 11, // 稍微减小字体以适应更多文字
            ),
            textAlign: TextAlign.center,
            maxLines: 2, // 允许2行文字
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final List<MeditationDayRecord> monthlyRecords;

  const _CalendarGrid({required this.monthlyRecords});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final today = DateTime.now();
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    // Convert weekday to Sunday-based index (0=Sunday, 1=Monday, ..., 6=Saturday)
    final firstDayWeekday = DateTime(today.year, today.month, 1).weekday % 7;

    // Create a map for quick lookup of meditation records
    final Map<int, MeditationDayRecord> recordsMap = {};
    for (final record in monthlyRecords) {
      if (record.date.month == today.month && record.date.year == today.year) {
        recordsMap[record.date.day] = record;
      }
    }

    return Column(
      children: [
        // 星期标题
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children:
              [
                localizations.calendarSunday,
                localizations.calendarMonday,
                localizations.calendarTuesday,
                localizations.calendarWednesday,
                localizations.calendarThursday,
                localizations.calendarFriday,
                localizations.calendarSaturday,
              ].map((day) {
                return Expanded(
                  child: Text(
                    day,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 12),

        // 日历网格
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 42, // 6周 * 7天
          itemBuilder: (context, index) {
            final dayNumber = index - firstDayWeekday + 1;
            final isCurrentMonth = dayNumber > 0 && dayNumber <= daysInMonth;
            final isToday = isCurrentMonth && dayNumber == today.day;
            final dayRecord = recordsMap[dayNumber];
            final hasSession = dayRecord?.hasSession ?? false;

            return Container(
              decoration: BoxDecoration(
                color: hasSession
                    ? theme.colorScheme.primary
                    : isToday
                    ? theme.colorScheme.secondary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isCurrentMonth && !hasSession && !isToday
                    ? Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      )
                    : null,
              ),
              child: Center(
                child: Text(
                  isCurrentMonth ? '$dayNumber' : '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasSession || isToday
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontWeight: hasSession || isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

void showProgressSettings(
  BuildContext context, {
  UserGoal? userGoal,
  Function(UserGoal goal)? onGoalUpdated,
}) {
  final localizations = AppLocalizations.of(context)!;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            localizations.progressSettings,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),

          // Options
          buildSettingOption(
            context,
            icon: Icons.track_changes,
            title: localizations.goalsSetGoals,
            subtitle: localizations.goalsAdjustDailyGoal,
            onTap: () {
              Navigator.pop(context);
              showGoalSettingsDialog(
                context,
                currentGoal: userGoal,
                onGoalUpdated: onGoalUpdated,
              );
            },
          ),
          buildSettingOption(
            context,
            icon: Icons.notifications,
            title: localizations.remindersSettings,
            subtitle: localizations.remindersSetReminderTime,
            onTap: () {
              Navigator.pop(context);
              showReminderSettingsDialog(
                context,
                currentGoal: userGoal,
                onGoalUpdated: onGoalUpdated,
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

Widget buildSettingOption(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return MouseRegion(
    cursor: SystemMouseCursors.click, // 添加手形光标
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    ),
  );
}
