import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/web_storage_helper.dart';
import '../../../meditation/domain/entities/meditation_session.dart';

class RecentSessionsCard extends StatefulWidget {
  const RecentSessionsCard({super.key});

  @override
  State<RecentSessionsCard> createState() => _RecentSessionsCardState();
}

class _RecentSessionsCardState extends State<RecentSessionsCard> {
  List<MeditationSession> _recentSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentSessions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当依赖变化时重新加载，比如从其他页面返回时
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('RecentSessionsCard: didChangeDependencies triggered, refreshing...');
        _loadRecentSessions();
      }
    });
  }

  @override
  void didUpdateWidget(RecentSessionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当widget更新时也重新加载数据
    _loadRecentSessions();
  }

  Future<void> _loadRecentSessions() async {
    if (!mounted) return;
    
    try {
      debugPrint('RecentSessionsCard: Loading recent sessions...');
      List<MeditationSession> sessions;
      
      if (kIsWeb) {
        sessions = await WebStorageHelper.getRecentMeditationSessions(limit: 3);
        debugPrint('RecentSessionsCard: Loaded ${sessions.length} sessions from web storage');
      } else {
        final sessionMaps = await DatabaseHelper.getRecentMeditationSessions(limit: 3);
        sessions = sessionMaps.map((map) => MeditationSession.fromMap(map)).toList();
        debugPrint('RecentSessionsCard: Loaded ${sessions.length} sessions from database');
      }
      
      // 打印session信息用于调试
      for (int i = 0; i < sessions.length; i++) {
        final session = sessions[i];
        debugPrint('Session $i: ${session.title} (${session.id}) - ${session.startTime}');
      }
      
      if (mounted) {
        setState(() {
          _recentSessions = sessions;
          _isLoading = false;
        });
        debugPrint('RecentSessionsCard: UI updated with ${sessions.length} sessions');
      }
    } catch (e) {
      debugPrint('Error loading recent sessions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).round();
    return '${minutes}分钟';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    final difference = today.difference(sessionDate).inDays;
    
    if (difference == 0) {
      return '今天';
    } else if (difference == 1) {
      return '昨天';
    } else if (difference <= 7) {
      return '$difference天前';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

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
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_recentSessions.isEmpty)
              _buildEmptyState(l10n)
            else
              ..._recentSessions.asMap().entries.map((entry) {
                final session = entry.value;
                return Column(
                  children: [
                    if (entry.key > 0) const SizedBox(height: 12),
                    _RecentSessionItem(
                      title: session.title,
                      duration: _formatDuration(session.actualDuration > 0 
                        ? session.actualDuration 
                        : session.duration),
                      date: _formatDate(session.startTime),
                      sessionType: session.type,
                      onTap: () {
                        // TODO: Resume session or show details
                      },
                    ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.self_improvement,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有冥想记录',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '开始你的第一次冥想之旅吧',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSessionItem extends StatelessWidget {
  final String title;
  final String duration;
  final String date;
  final SessionType sessionType;
  final VoidCallback onTap;

  const _RecentSessionItem({
    required this.title,
    required this.duration,
    required this.date,
    required this.sessionType,
    required this.onTap,
  });

  IconData _getIconForSessionType(SessionType type) {
    switch (type) {
      case SessionType.meditation:
        return Icons.self_improvement;
      case SessionType.breathing:
        return Icons.air;
      case SessionType.sleep:
        return Icons.bedtime;
      case SessionType.focus:
        return Icons.psychology;
      case SessionType.relaxation:
        return Icons.spa;
    }
  }

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
                _getIconForSessionType(sessionType),
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
