import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/animated_action_button.dart';
import '../../../../shared/widgets/timer_dialog.dart';
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
        onTap: () => TimerDialog.show(
          context,
          onTimerSet: () {
            // 设置定时器后跳转到播放器
            context.go('/player');
          },
        ),
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
}
