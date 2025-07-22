import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/di/injection_container.dart';
import '../../features/player/services/global_player_service.dart';

class TimerDialog extends StatelessWidget {
  final VoidCallback? onTimerSet; // 可选的回调函数

  const TimerDialog({super.key, this.onTimerSet});

  static Future<void> show(BuildContext context, {VoidCallback? onTimerSet}) {
    return showDialog(
      context: context,
      builder: (context) => TimerDialog(onTimerSet: onTimerSet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    // 获取当前定时器状态
    final playerService = getIt<GlobalPlayerService>();
    final currentTimerMinutes = playerService.sleepTimerMinutes;

    return Dialog(
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
                      localizations.timerDialogTitle,
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
              _buildTimerSelector(
                context,
                theme,
                localizations,
                currentTimerMinutes,
              ),

              const SizedBox(height: 16),
              const Divider(),

              // 取消定时器选项
              ListTile(
                title: Text(localizations.timerCancel),
                leading: Icon(Icons.timer_off, color: theme.colorScheme.error),
                onTap: () {
                  Navigator.pop(context);
                  playerService.cancelSleepTimer();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.timerCancelled),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                  onTimerSet?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerSelector(
    BuildContext context,
    ThemeData theme,
    AppLocalizations localizations,
    int currentTimerMinutes,
  ) {
    return Column(
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
                localizations.timerDialogSubtitle,
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

        // 定时器选项
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [5, 10, 15, 30, 45, 60].map((minutes) {
            final isSelected = currentTimerMinutes == minutes;
            return InkWell(
              onTap: () => _handleTimerSelection(
                context,
                minutes.toDouble(),
                localizations,
              ),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localizations.statsMinutesFormat(minutes),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _handleTimerSelection(
    BuildContext context,
    double minutes,
    AppLocalizations localizations,
  ) {
    Navigator.pop(context);

    final playerService = getIt<GlobalPlayerService>();
    playerService.setSleepTimer(minutes.toInt());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(localizations.timerSetMessage(minutes.toInt())),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    onTimerSet?.call();
  }
}
