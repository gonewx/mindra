import 'package:flutter/material.dart';
import '../../../meditation/presentation/widgets/goal_settings_dialog.dart';
import '../../../../features/goals/data/services/goal_service.dart';
import '../../../../features/goals/domain/entities/user_goal.dart';
import '../../../../features/meditation/data/services/meditation_statistics_service.dart';
import '../../../../features/meditation/domain/entities/meditation_statistics.dart';
import '../../../../core/localization/app_localizations.dart';

class DailyGoalCard extends StatefulWidget {
  final double? cardPadding; // 卡片内边距控制
  final double? borderRadius; // 圆角控制

  const DailyGoalCard({
    super.key,
    this.cardPadding, // 默认为 null，使用内置默认值 20
    this.borderRadius, // 默认为 null，使用内置默认值 12
  });

  @override
  State<DailyGoalCard> createState() => _DailyGoalCardState();
}

class _DailyGoalCardState extends State<DailyGoalCard> {
  UserGoal? _currentGoal;
  MeditationStatistics? _statistics;
  double _progressValue = 0.0;
  String _progressText = '0%';

  @override
  void initState() {
    super.initState();
    _loadGoalAndProgress();
  }

  Future<void> _loadGoalAndProgress() async {
    try {
      final goal = await GoalService.getGoal();
      final statistics = await MeditationStatisticsService.getStatistics();

      if (mounted) {
        setState(() {
          _currentGoal = goal;
          _statistics = statistics;
          _calculateProgress();
        });
      }
    } catch (e) {
      debugPrint('Error loading goal and progress: $e');
    }
  }

  void _calculateProgress() {
    if (_currentGoal == null || _statistics == null) {
      _progressValue = 0.0;
      _progressText = '0%';
      return;
    }

    // 解析每日目标时长（分钟）
    final goalText = _currentGoal!.dailyGoal;
    final goalMinutes = int.tryParse(goalText.replaceAll('分钟', '')) ?? 20;

    // 获取今日实际冥想时长
    final today = DateTime.now();
    final todayMinutes = _getTodayMinutes(today);

    // 计算进度
    _progressValue = (todayMinutes / goalMinutes).clamp(0.0, 1.0);
    _progressText = '${(_progressValue * 100).round()}%';
  }

  int _getTodayMinutes(DateTime today) {
    if (_statistics == null || _statistics!.monthlyRecords.isEmpty) return 0;

    // 获取今日冥想时长
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // 从月度记录中查找今日数据
    try {
      final todayRecord = _statistics!.monthlyRecords.firstWhere(
        (record) => _getDateKey(record.date) == todayKey,
      );
      return todayRecord.totalMinutes;
    } catch (e) {
      // 如果找不到今日记录，返回0
      return 0;
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _showGoalDialog() async {
    await showGoalSettingsDialog(
      context,
      currentGoal: _currentGoal,
      onGoalUpdated: (goal) {
        setState(() {
          _currentGoal = goal;
          _calculateProgress();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    // 使用可配置的参数，如果没有提供则使用默认值
    final effectivePadding = widget.cardPadding ?? 20.0; // 默认 20px 匹配原型
    final effectiveBorderRadius = widget.borderRadius ?? 12.0; // 默认 12px 匹配原型

    return InkWell(
      onTap: _showGoalDialog,
      borderRadius: BorderRadius.circular(effectiveBorderRadius),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 100, // 确保最小高度，避免内容挤压
        ),
        padding: EdgeInsets.all(effectivePadding), // 可配置的内边距
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          ),
          borderRadius: BorderRadius.circular(effectiveBorderRadius), // 可配置的圆角
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // 防止 Column 占用过多空间
                  children: [
                    Flexible(
                      child: Text(
                        localizations.dailyGoalTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          // 移除额外的fontWeight，使用主题默认的w500
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(
                        _currentGoal != null
                            ? '${_currentGoal!.dailyGoal}${localizations.dailyGoalMeditationSuffix}'
                            : localizations.dailyGoalDefault,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16), // 添加间距避免挤压
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: _progressValue,
                        strokeWidth: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      _progressText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
