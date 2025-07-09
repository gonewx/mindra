import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/animated_media_card.dart';

class RecommendedContent extends StatelessWidget {
  const RecommendedContent({super.key});

  @override
  Widget build(BuildContext context) {
    final recommendations = [
      {
        'title': '晨间正念冥想',
        'category': '专注',
        'duration': '10分钟',
        'image':
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=400&fit=crop',
      },
      {
        'title': '深度睡眠引导',
        'category': '睡前',
        'duration': '20分钟',
        'image':
            'https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=400&h=400&fit=crop',
      },
      {
        'title': '工作压力缓解',
        'category': '放松',
        'duration': '15分钟',
        'image':
            'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=400&fit=crop',
      },
      {
        'title': '自然森林音效',
        'category': '自然音效',
        'duration': '30分钟',
        'image':
            'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=400&fit=crop',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio:
            1.12, // 匹配原型: minmax(150px, 1fr) 高度约192px (120px图片 + 72px内容)
        crossAxisSpacing: 16, // --space-16: 16px
        mainAxisSpacing: 16, // --space-16: 16px
      ),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final item = recommendations[index];
        return AnimatedMediaCard(
          title: item['title']!,
          category: item['category']!,
          duration: item['duration']!,
          imageUrl: item['image']!,
          isListView: false, // 网格视图
          onTap: () => context.go('${AppRouter.player}?mediaId=$index'),
        );
      },
    );
  }
}
