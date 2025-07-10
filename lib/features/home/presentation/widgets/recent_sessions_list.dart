import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/animated_media_card.dart';
import '../../../../features/meditation/domain/entities/meditation_session.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/web_storage_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:flutter/foundation.dart';

class RecentSessionsList extends StatefulWidget {
  const RecentSessionsList({super.key});

  @override
  State<RecentSessionsList> createState() => _RecentSessionsListState();
}

class _RecentSessionsListState extends State<RecentSessionsList> {
  List<MeditationSession> _recentSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentSessions();
  }

  Future<void> _loadRecentSessions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      List<MeditationSession> sessions;

      if (kIsWeb) {
        sessions = await WebStorageHelper.getAllMeditationSessions();
      } else {
        final rawSessions = await DatabaseHelper.getAllMeditationSessions();
        sessions = rawSessions
            .map((data) => MeditationSession.fromMap(data))
            .toList();
      }

      // 按开始时间排序，取最近的3个
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      final recentSessions = sessions.take(3).toList();

      if (mounted) {
        setState(() {
          _recentSessions = recentSessions;
          _isLoading = false;
        });
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
    final minutes = seconds ~/ 60;
    final localizations = AppLocalizations.of(context);
    if (localizations?.locale.languageCode == 'zh') {
      return '$minutes分钟';
    } else {
      return '${minutes}min';
    }
  }

  String _getImageUrl(String title) {
    // 根据标题生成默认图片URL
    if (title.contains('晨间') || title.contains('早晨')) {
      return 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=80&h=80&fit=crop';
    } else if (title.contains('睡眠') || title.contains('晚上')) {
      return 'https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=80&h=80&fit=crop';
    } else {
      return 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=80&h=80&fit=crop';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recentSessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.self_improvement_outlined,
              size: 48,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)?.recentSessionsNoRecords ?? 'No recent meditation records yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)?.recentSessionsStartMeditating ?? 'Start your first meditation journey!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentSessions.asMap().entries.map((entry) {
        final index = entry.key;
        final session = entry.value;

        return Padding(
          padding: EdgeInsets.only(
            bottom: index < _recentSessions.length - 1 ? 4 : 0,
          ),
          child: AnimatedMediaCard(
            title: session.title,
            category: session.type.displayName,
            duration: _formatDuration(session.actualDuration),
            imageUrl: _getImageUrl(session.title),
            isListView: true,
            thumbnailSize: 52.0,
            cardPadding: const EdgeInsets.all(10),
            onTap: () => context.go(
              '${AppRouter.player}?mediaId=${session.mediaItemId}',
            ),
          ),
        );
      }).toList(),
    );
  }
}
