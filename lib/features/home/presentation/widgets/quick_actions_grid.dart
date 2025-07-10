import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/animated_action_button.dart';

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
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A3441) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A3441)
                      : theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.timerDialogTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: isDark
                            ? const Color(0xFF32B8C6)
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(shape: const CircleBorder()),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.timerDialogSubtitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time Options
                    Column(
                      children: [
                        _buildTimeOption(context, l10n.timerOption5Min, 5, isDark),
                        const SizedBox(height: 8),
                        _buildTimeOption(context, l10n.timerOption10Min, 10, isDark),
                        const SizedBox(height: 8),
                        _buildTimeOption(context, l10n.timerOption15Min, 15, isDark),
                        const SizedBox(height: 8),
                        _buildTimeOption(context, l10n.timerOption20Min, 20, isDark),
                        const SizedBox(height: 8),
                        _buildTimeOption(context, l10n.timerOption30Min, 30, isDark),
                      ],
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

  Widget _buildTimeOption(
    BuildContext context,
    String label,
    int minutes,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      child: OutlinedButton(
        onPressed: () {
          Navigator.pop(context);
          context.go('${AppRouter.player}?duration=$minutes');
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF3A3F47)
                : theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          foregroundColor: isDark
              ? Colors.white70
              : theme.colorScheme.onSurface,
          backgroundColor: isDark
              ? const Color(0xFF1E2329)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              color: isDark
                  ? const Color(0xFF32B8C6)
                  : theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: isDark
                  ? Colors.white54
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
