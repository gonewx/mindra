import 'package:flutter/material.dart';
import 'dart:async';
import '../../../meditation/presentation/widgets/goal_settings_dialog.dart';
import '../../../../features/goals/data/services/goal_service.dart';
import '../../../../features/goals/domain/entities/user_goal.dart';
import '../../../../features/meditation/data/services/meditation_statistics_service.dart';
import '../../../../features/meditation/domain/entities/meditation_statistics.dart';
import '../../../../features/meditation/data/services/meditation_session_manager.dart';
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
  StreamSubscription? _dataUpdateSubscription;
  StreamSubscription? _realTimeUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadGoalAndProgress();

    // 监听数据更新
    _dataUpdateSubscription = MeditationSessionManager.dataUpdateStream.listen((
      _,
    ) {
      if (mounted) {
        _loadGoalAndProgress();
      }
    });

    // 监听实时进度更新
    _realTimeUpdateSubscription = MeditationSessionManager.realTimeUpdateStream
        .listen((updateData) {
          if (mounted) {
            _handleRealTimeUpdate(updateData);
          }
        });
  }

  @override
  void dispose() {
    _dataUpdateSubscription?.cancel();
    _realTimeUpdateSubscription?.cancel();
    super.dispose();
  }

  /// 处理实时进度更新
  void _handleRealTimeUpdate(Map<String, dynamic> updateData) {
    // 实时更新不需要重新加载完整数据，只更新进度显示
    // 这样可以提供更流畅的用户体验
    if (_currentGoal != null && _statistics != null) {
      setState(() {
        _calculateProgressWithRealTimeData(updateData);
      });
    }
  }

  /// 使用实时数据计算进度
  void _calculateProgressWithRealTimeData(Map<String, dynamic> updateData) {
    if (_currentGoal == null) {
      _progressValue = 0.0;
      return;
    }

    // 获取每日目标时长（分钟）
    final goalMinutes = _getGoalMinutes();

    // 获取今日实际冥想时长（包括当前正在进行的会话）
    final today = DateTime.now();
    var todayMinutes = _getTodayMinutes(today);

    // 如果有实时会话数据，添加当前会话的时长
    if (updateData['actualDuration'] != null) {
      final currentSessionMinutes =
          (updateData['actualDuration'] as int) / 60.0;
      todayMinutes += currentSessionMinutes.round();
    }

    // 计算进度
    _progressValue = (todayMinutes / goalMinutes).clamp(0.0, 1.0);
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
        debugPrint('日常目标卡片数据已刷新');
      }
    } catch (e) {
      debugPrint('Error loading goal and progress: $e');
    }
  }

  void _calculateProgress() {
    if (_currentGoal == null || _statistics == null) {
      _progressValue = 0.0;
      return;
    }

    // 获取每日目标时长（分钟）
    final goalMinutes = _getGoalMinutes();

    // 获取今日实际冥想时长
    final today = DateTime.now();
    final todayMinutes = _getTodayMinutes(today);

    // 计算进度
    _progressValue = (todayMinutes / goalMinutes).clamp(0.0, 1.0);
  }

  /// 获取格式化的进度详情文本
  /// 使用本地化配置显示当前进度的百分比
  String _getProgressDetailText(AppLocalizations localizations) {
    if (_currentGoal == null || _statistics == null) {
      return '0%';
    }

    final progressPercentage = (_progressValue * 100).round();
    return '$progressPercentage%';
  }

  /// 从 UserGoal 实体中获取目标分钟数
  int _getGoalMinutes() {
    if (_currentGoal == null) return 20;

    return _currentGoal!.dailyGoalMinutes;
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

  /// 获取格式化的目标文本
  /// 使用本地化配置统一格式化数值显示
  String _getFormattedGoalText(AppLocalizations localizations) {
    if (_currentGoal == null) {
      return localizations.dailyGoalDefault;
    }

    // 使用新的结构化方法
    try {
      final formattedGoal = _currentGoal!.getDailyGoalText(localizations);
      return '$formattedGoal${localizations.dailyGoalMeditationSuffix}';
    } catch (e) {
      // 如果新方法失败，使用备用方法
      final goalMinutes = _getGoalMinutes();
      final formattedMinutes = localizations.statsMinutesFormat(goalMinutes);
      return '$formattedMinutes${localizations.dailyGoalMeditationSuffix}';
    }
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
                        _getFormattedGoalText(localizations),
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
                      _getProgressDetailText(localizations),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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
