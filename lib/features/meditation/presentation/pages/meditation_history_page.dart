import 'package:flutter/material.dart';

class MeditationHistoryPage extends StatelessWidget {
  const MeditationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
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
                  '我的进度',
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
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () {
                        showProgressSettings(context); // 修复点击功能
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
                    title: '连续天数',
                    value: '7天',
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    icon: Icons.schedule_rounded,
                    title: '本周时长',
                    value: '125分钟',
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    icon: Icons.emoji_events_rounded,
                    title: '总次数',
                    value: '23次',
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
                    '本周冥想时长',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(height: 200, child: _WeeklyChart()),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Achievements
            Text(
              '成就徽章',
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
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _AchievementBadge(
                  icon: Icons.spa_rounded,
                  label: '冥想新手',
                  isEarned: true,
                  color: theme.colorScheme.secondary,
                ),
                _AchievementBadge(
                  icon: Icons.calendar_view_week_rounded,
                  label: '连续一周',
                  isEarned: true,
                  color: theme.colorScheme.secondary,
                ),
                _AchievementBadge(
                  icon: Icons.psychology_rounded,
                  label: '专注大师',
                  isEarned: true,
                  color: theme.colorScheme.secondary,
                ),
                _AchievementBadge(
                  icon: Icons.workspace_premium_rounded,
                  label: '冥想达人',
                  isEarned: false,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
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
                    '冥想历史',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CalendarGrid(),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mock data for weekly meditation minutes
    final weeklyData = [20, 15, 30, 25, 0, 35, 20];
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    final maxValue = weeklyData.reduce((a, b) => a > b ? a : b);

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
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final firstDayWeekday = DateTime(today.year, today.month, 1).weekday;

    // 模拟冥想记录数据
    final meditationDays = [
      1,
      2,
      4,
      7,
      9,
      11,
      12,
      14,
      17,
      18,
      20,
      21,
      23,
      26,
      28,
      29,
    ];

    return Column(
      children: [
        // 星期标题
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['日', '一', '二', '三', '四', '五', '六'].map((day) {
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
            final dayNumber = index - firstDayWeekday + 2;
            final isCurrentMonth = dayNumber > 0 && dayNumber <= daysInMonth;
            final isToday = isCurrentMonth && dayNumber == today.day;
            final hasSession =
                isCurrentMonth && meditationDays.contains(dayNumber);

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

void showProgressSettings(BuildContext context) {
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
            '进度设置',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),

          // Options
          buildSettingOption(
            context,
            icon: Icons.track_changes,
            title: '设置目标',
            subtitle: '调整每日冥想目标',
            onTap: () {
              Navigator.pop(context);
              // TODO: 打开目标设置对话框
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('目标设置功能开发中')));
            },
          ),
          buildSettingOption(
            context,
            icon: Icons.notifications,
            title: '提醒设置',
            subtitle: '设置冥想提醒时间',
            onTap: () {
              Navigator.pop(context);
              // TODO: 打开提醒设置
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('提醒设置功能开发中')));
            },
          ),
          buildSettingOption(
            context,
            icon: Icons.analytics,
            title: '统计偏好',
            subtitle: '自定义统计显示方式',
            onTap: () {
              Navigator.pop(context);
              // TODO: 打开统计偏好设置
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('统计偏好设置功能开发中')));
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
