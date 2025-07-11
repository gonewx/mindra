import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/animated_action_button.dart';
import '../../../goals/data/services/goal_service.dart';

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    final actions = [
      AnimatedActionButton(
        icon: Icons.play_arrow_rounded,
        label: l10n.quickActionStartMeditation,
        isPrimary: true,
        onTap: () => context.go('${AppRouter.player}?autoStart=true'),
      ),
      AnimatedActionButton(
        icon: Icons.music_note_rounded,
        label: l10n.quickActionBrowseMedia,
        onTap: () => context.go(AppRouter.mediaLibrary),
      ),
      AnimatedActionButton(
        icon: Icons.show_chart_rounded,
        label: l10n.quickActionViewProgress,
        onTap: () => context.go(AppRouter.meditationHistory),
      ),
      AnimatedActionButton(
        icon: Icons.schedule_rounded,
        label: l10n.quickActionTimedMeditation,
        onTap: () => _showTimerDialog(context),
      ),
    ];

    // 使用简单可靠的响应式布局，避免复杂计算和溢出问题
    return LayoutBuilder(
      builder: (context, constraints) {
        // 简单的响应式逻辑，避免复杂计算
        final screenWidth = constraints.maxWidth;
        final isWideScreen = screenWidth > 600;

        if (isWideScreen) {
          // 宽屏使用 Wrap 布局，更灵活
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: actions.map((action) {
              return SizedBox(
                width: (screenWidth - 32) / 3, // 三列布局
                child: action,
              );
            }).toList(),
          );
        } else {
          // 窄屏使用固定的 GridView，避免计算错误
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.3, // 增大比例使卡片更矮
            children: actions,
          );
        }
      },
    );
  }

  void _showTimerDialog(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.timerDialogTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 定时选择器
                _buildTimerSelector(context, theme, l10n),
                const SizedBox(height: 24),

                // 取消按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        l10n.cancel,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerSelector(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.timerDialogSubtitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GoalService.getDailyGoalMinuteOptions().map((minutes) {
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  context.go('${AppRouter.player}?duration=$minutes');
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    l10n.statsMinutesFormat(minutes),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
