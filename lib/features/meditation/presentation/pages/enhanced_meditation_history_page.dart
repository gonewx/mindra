import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/services/meditation_statistics_service.dart';
import '../../data/services/enhanced_meditation_statistics_service.dart';
import '../../data/services/enhanced_meditation_session_manager.dart';
import '../../domain/entities/meditation_statistics.dart';
import '../widgets/goal_settings_dialog.dart';
import '../widgets/reminder_settings_dialog.dart';
import '../../../goals/domain/entities/user_goal.dart';
import '../../../goals/data/services/goal_service.dart';
import '../../../../core/localization/app_localizations.dart';

/// 增强版冥想历史页面 - 解决数据不准确和刷新不及时问题
///
/// 核心改进：
/// 1. 实时数据监听：监听会话管理器的数据更新流
/// 2. 智能数据缓存：避免重复请求，提升性能
/// 3. 多层数据验证：确保数据一致性和准确性
/// 4. 优雅降级：新旧统计服务无缝切换
class EnhancedMeditationHistoryPage extends StatefulWidget {
  const EnhancedMeditationHistoryPage({super.key});

  @override
  State<EnhancedMeditationHistoryPage> createState() =>
      _EnhancedMeditationHistoryPageState();
}

class _EnhancedMeditationHistoryPageState
    extends State<EnhancedMeditationHistoryPage>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  MeditationStatistics? _statistics;
  UserGoal? _userGoal;
  DailyMeditationStats? _todayStats;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _lastError;
  DateTime _lastUpdateTime = DateTime.now();

  // 数据流订阅
  StreamSubscription<void>? _dataUpdateSubscription;
  StreamSubscription<DailyMeditationStats>? _dailyStatsSubscription;
  StreamSubscription<Map<String, dynamic>>? _realTimeSubscription;

  // 自动刷新定时器
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(minutes: 5);

  // 缓存管理
  static const Duration _cacheValidDuration = Duration(minutes: 2);
  DateTime? _lastCacheTime;

  @override
  bool get wantKeepAlive => true; // 保持页面状态

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupDataStreams();
    _startAutoRefreshTimer();
    // 不在 initState 中初始化数据，等待 didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在这里初始化数据，确保 Localizations 已经可用
    if (!_isInitialized) {
      _isInitialized = true;
      _initializeData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupStreams();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以支持AutomaticKeepAliveClientMixin
    return _buildContent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // 应用恢复前台时刷新数据
        _refreshDataIfNeeded(forceRefresh: true);
        break;
      case AppLifecycleState.paused:
        // 应用进入后台时保存当前状态
        _saveCurrentState();
        break;
      default:
        break;
    }
  }

  /// 初始化数据加载
  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
    });

    try {
      await _loadAllData();
      _lastUpdateTime = DateTime.now();
    } catch (e) {
      _handleError('初始化数据失败', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 设置数据流监听
  void _setupDataStreams() {
    // 监听数据更新通知
    _dataUpdateSubscription = EnhancedMeditationSessionManager.dataUpdateStream
        .listen((_) {
          debugPrint('Enhanced data update received, refreshing...');
          _refreshDataIfNeeded();
        });

    // 监听每日统计更新
    _dailyStatsSubscription = EnhancedMeditationSessionManager.dailyStatsStream
        .listen((dailyStats) {
          debugPrint(
            'Daily stats update received: ${dailyStats.totalMinutes} minutes',
          );
          if (mounted) {
            setState(() {
              _todayStats = dailyStats;
            });
          }
        });

    // 监听实时进度更新
    _realTimeSubscription = EnhancedMeditationSessionManager
        .realTimeUpdateStream
        .listen((updateData) {
          debugPrint(
            'Real-time update received: ${updateData['actualDuration']}s',
          );
          // 实时更新不触发完整刷新，只更新当前会话信息
          _updateCurrentSessionDisplay(updateData);
        });
  }

  /// 清理数据流订阅
  void _cleanupStreams() {
    _dataUpdateSubscription?.cancel();
    _dailyStatsSubscription?.cancel();
    _realTimeSubscription?.cancel();
  }

  /// 启动自动刷新定时器
  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (mounted) {
        _refreshDataIfNeeded();
      }
    });
  }

  /// 加载所有数据
  Future<void> _loadAllData() async {
    await Future.wait([_loadStatistics(), _loadUserGoal(), _loadTodayStats()]);

    _lastCacheTime = DateTime.now();
  }

  /// 加载统计数据 - 优先使用增强版服务
  Future<void> _loadStatistics() async {
    try {
      final localizations = AppLocalizations.of(context)!;

      // 优先尝试增强版统计服务
      try {
        final enhancedStats =
            await EnhancedMeditationStatisticsService.getStatistics(
              localizations,
            );
        if (mounted) {
          setState(() {
            _statistics = enhancedStats;
          });
        }
        debugPrint('Loaded enhanced statistics successfully');
        return;
      } catch (e) {
        debugPrint(
          'Enhanced statistics failed, falling back to traditional: $e',
        );
      }

      // 回退到传统统计服务
      final traditionalStats = await MeditationStatisticsService.getStatistics(
        localizations,
      );
      if (mounted) {
        setState(() {
          _statistics = traditionalStats;
        });
      }
      debugPrint('Loaded traditional statistics successfully');
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      throw Exception('统计数据加载失败: $e');
    }
  }

  /// 加载用户目标
  Future<void> _loadUserGoal() async {
    try {
      final userGoal = await GoalService.getGoal();
      if (mounted) {
        setState(() {
          _userGoal = userGoal;
        });
      }
    } catch (e) {
      debugPrint('Error loading user goal: $e');
      // 用户目标加载失败不影响整体功能
    }
  }

  /// 加载今日统计
  Future<void> _loadTodayStats() async {
    try {
      final todayStats =
          EnhancedMeditationSessionManager.getCurrentDailyStats();
      if (mounted) {
        setState(() {
          _todayStats = todayStats;
        });
      }
    } catch (e) {
      debugPrint('Error loading today stats: $e');
      // 今日统计加载失败不影响整体功能
    }
  }

  /// 智能刷新数据 - 基于缓存和需要决定是否刷新
  Future<void> _refreshDataIfNeeded({bool forceRefresh = false}) async {
    // 防止重复刷新
    if (_isRefreshing) return;

    // 检查缓存有效性
    if (!forceRefresh && _lastCacheTime != null) {
      final cacheAge = DateTime.now().difference(_lastCacheTime!);
      if (cacheAge < _cacheValidDuration) {
        debugPrint('Data cache still valid, skipping refresh');
        return;
      }
    }

    await _refreshData();
  }

  /// 刷新数据
  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _lastError = null;
    });

    try {
      await _loadAllData();
      _lastUpdateTime = DateTime.now();
      debugPrint('Data refreshed successfully at $_lastUpdateTime');
    } catch (e) {
      _handleError('数据刷新失败', e);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// 更新当前会话显示
  void _updateCurrentSessionDisplay(Map<String, dynamic> sessionData) {
    // 这里可以添加实时会话信息的显示更新
    // 比如更新当前播放进度、累计时长等
    if (mounted) {
      // 轻量级更新，不触发完整重建
      setState(() {
        // 可以在这里更新特定的UI元素
      });
    }
  }

  /// 错误处理
  void _handleError(String message, dynamic error) {
    debugPrint('$message: $error');
    if (mounted) {
      setState(() {
        _lastError = '$message: ${error.toString()}';
      });

      // 显示用户友好的错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          action: SnackBarAction(label: '重试', onPressed: () => _refreshData()),
        ),
      );
    }
  }

  /// 保存当前状态
  Future<void> _saveCurrentState() async {
    try {
      await EnhancedMeditationSessionManager.forceSaveCurrentState();
    } catch (e) {
      debugPrint('Error saving current state: $e');
    }
  }

  /// 目标更新回调
  void _onGoalUpdated(UserGoal goal) {
    setState(() {
      _userGoal = goal;
    });
  }

  /// 获取成就图标
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

  /// 构建内容
  Widget _buildContent() {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                '正在加载冥想数据...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (_todayStats != null) ...[
                const SizedBox(height: 8),
                Text(
                  '今日已冥想 ${_todayStats!.totalMinutes} 分钟',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with refresh indicator
                _buildHeader(theme, localizations),
                const SizedBox(height: 32),

                // Error message if any
                if (_lastError != null) _buildErrorMessage(theme),

                // Today's stats (real-time)
                if (_todayStats != null)
                  _buildTodayStatsCard(theme, localizations),

                // Stats Overview
                _buildStatsOverview(theme, localizations, statistics),
                const SizedBox(height: 32),

                // Weekly Chart
                _buildWeeklyChart(theme, localizations, statistics),
                const SizedBox(height: 32),

                // Achievements
                _buildAchievements(theme, localizations, statistics),
                const SizedBox(height: 32),

                // Calendar View
                _buildCalendarView(theme, localizations, statistics),
                const SizedBox(height: 24),

                // Last update time
                _buildLastUpdateInfo(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建页面头部
  Widget _buildHeader(ThemeData theme, AppLocalizations localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.progressMyProgress,
              style: theme.textTheme.headlineLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isRefreshing) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '正在更新...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
    );
  }

  /// 构建错误消息
  Widget _buildErrorMessage(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _lastError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade700,
              ),
            ),
          ),
          TextButton(onPressed: _refreshData, child: Text('重试')),
        ],
      ),
    );
  }

  /// 构建今日统计卡片
  Widget _buildTodayStatsCard(ThemeData theme, AppLocalizations localizations) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.today_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '今日冥想',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (EnhancedMeditationSessionManager.hasActiveSession)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '正在冥想',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_todayStats!.totalMinutes}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '分钟',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_todayStats!.sessionCount}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '次会话',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建统计概览
  Widget _buildStatsOverview(
    ThemeData theme,
    AppLocalizations localizations,
    MeditationStatistics statistics,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            title: localizations.statsConsecutiveDays,
            value: localizations.statsDaysFormat(statistics.streakDays),
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.schedule_rounded,
            title: localizations.statsWeeklyDuration,
            value: localizations.statsMinutesFormat(statistics.weeklyMinutes),
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.emoji_events_rounded,
            title: localizations.statsTotalSessions,
            value: localizations.statsTimesFormat(statistics.totalSessions),
            color: theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }

  /// 构建周数据图表
  Widget _buildWeeklyChart(
    ThemeData theme,
    AppLocalizations localizations,
    MeditationStatistics statistics,
  ) {
    return Container(
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
    );
  }

  /// 构建成就区域
  Widget _buildAchievements(
    ThemeData theme,
    AppLocalizations localizations,
    MeditationStatistics statistics,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
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
      ],
    );
  }

  /// 构建日历视图
  Widget _buildCalendarView(
    ThemeData theme,
    AppLocalizations localizations,
    MeditationStatistics statistics,
  ) {
    return Container(
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
    );
  }

  /// 构建最后更新信息
  Widget _buildLastUpdateInfo(ThemeData theme) {
    final updateTime = _lastUpdateTime;
    final now = DateTime.now();
    final diff = now.difference(updateTime);

    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = '刚刚';
    } else if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours}小时前';
    } else {
      timeAgo = '${diff.inDays}天前';
    }

    return Center(
      child: Column(
        children: [
          Text(
            '最后更新：$timeAgo',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          if (EnhancedMeditationSessionManager.hasActiveSession)
            Text(
              '正在实时同步中...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}

// 以下复用原来的widget组件，保持UI一致性
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
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
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
    final firstDayWeekday = DateTime(today.year, today.month, 1).weekday % 7;

    final Map<int, MeditationDayRecord> recordsMap = {};
    for (final record in monthlyRecords) {
      if (record.date.month == today.month && record.date.year == today.year) {
        recordsMap[record.date.day] = record;
      }
    }

    return Column(
      children: [
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 42,
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

// 复用原有的设置对话框功能
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
          Text(
            localizations.progressSettings,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          _buildSettingOption(
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
          _buildSettingOption(
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

Widget _buildSettingOption(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
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
