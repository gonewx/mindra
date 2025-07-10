import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';

class RecentSessionsCard extends StatelessWidget {
  const RecentSessionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.recentSessionsTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                TextButton(
                  onPressed: () {
                    context.push(AppRouter.meditationHistory);
                  },
                  child: Text(l10n.recentSessionsViewAll),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // TODO: Replace with actual recent sessions data
            _RecentSessionItem(
              title: l10n.recentSessionMorning,
              duration: l10n.timerOption10Min,
              date: l10n.recentSessionToday,
              onTap: () {
                // TODO: Resume session or show details
              },
            ),
            const SizedBox(height: 12),
            _RecentSessionItem(
              title: l10n.recentSessionRelaxation,
              duration: l10n.timerOption15Min,
              date: l10n.recentSessionYesterday,
              onTap: () {
                // TODO: Resume session or show details
              },
            ),
            const SizedBox(height: 12),
            _RecentSessionItem(
              title: l10n.recentSessionBedtime,
              duration: l10n.timerOption20Min,
              date: l10n.recentSessionDaysAgo(2),
              onTap: () {
                // TODO: Resume session or show details
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSessionItem extends StatelessWidget {
  final String title;
  final String duration;
  final String date;
  final VoidCallback onTap;

  const _RecentSessionItem({
    required this.title,
    required this.duration,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.self_improvement,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        duration,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              date,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
