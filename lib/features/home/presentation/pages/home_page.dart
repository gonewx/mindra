import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme_provider.dart';
import '../widgets/daily_goal_card.dart';
import '../widgets/quick_actions_grid.dart';
import '../widgets/recommended_content.dart';
import '../widgets/recent_sessions_list.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '早上好！';
    } else if (hour < 18) {
      return '下午好！';
    } else {
      return '晚上好！';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20), // --space-20: 20px
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with greeting and avatar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          // 移除额外的fontWeight，使用主题默认的w600
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '准备好开始今天的冥想之旅吗？',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: IconButton(
                    onPressed: () => context.go(AppRouter.settings),
                    icon: Icon(
                      Icons.person_outline,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24), // --space-24: 24px
            // Daily Goal Card
            DailyGoalCard(
              cardPadding: themeProvider.cardPadding, // 使用主题提供者中的卡片内边距
            ),
            const SizedBox(height: 32), // --space-32: 32px
            // Quick Actions
            const QuickActionsGrid(),
            const SizedBox(height: 32), // --space-32: 32px
            // Recommended Content
            Text(
              '推荐内容',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                // 移除额外的fontWeight，使用主题默认的w500
              ),
            ),
            const SizedBox(height: 16),
            RecommendedContent(
              cardSpacing: themeProvider.cardSpacing, // 使用主题提供者中的卡片间距
            ),
            const SizedBox(height: 32),

            // Recent Sessions
            Text(
              '最近播放',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                // 移除额外的fontWeight，使用主题默认的w500
              ),
            ),
            const SizedBox(height: 16),
            const RecentSessionsList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
