import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/animated_media_card.dart';

class RecentSessionsList extends StatelessWidget {
  const RecentSessionsList({super.key});

  @override
  Widget build(BuildContext context) {
    final recentSessions = [
      {
        'title': '晨间正念冥想',
        'category': '专注',
        'duration': '10分钟',
        'image':
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=80&h=80&fit=crop',
      },
      {
        'title': '深度睡眠引导',
        'category': '睡前',
        'duration': '20分钟',
        'image':
            'https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=80&h=80&fit=crop',
      },
      {
        'title': '工作压力缓解',
        'category': '放松',
        'duration': '15分钟',
        'image':
            'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=80&h=80&fit=crop',
      },
    ];

    return Column(
      children: recentSessions.asMap().entries.map((entry) {
        final index = entry.key;
        final session = entry.value;

        return Padding(
          padding: EdgeInsets.only(
            bottom: index < recentSessions.length - 1 ? 4 : 0,
          ), // --space-12: 12px
          child: AnimatedMediaCard(
            title: session['title']!,
            category: session['category']!,
            duration: session['duration']!,
            imageUrl: session['image']!,
            isListView: true, // 列表视图
            showActions: false, // 首页最近播放不显示收藏和更多选项按钮
            thumbnailSize: 52.0, // 调整缩略图尺寸，使列表项更紧凑
            cardPadding: const EdgeInsets.all(10), // 调整内边距
            onTap: () => context.go('${AppRouter.player}?mediaId=$index'),
          ),
        );
      }).toList(),
    );
  }
}
