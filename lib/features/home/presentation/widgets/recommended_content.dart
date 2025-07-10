import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/animated_media_card.dart';

class RecommendedContent extends StatelessWidget {
  final double? cardSpacing; // 卡片间距控制
  final int? crossAxisCount; // 列数控制
  final double? childAspectRatio; // 宽高比控制

  const RecommendedContent({
    super.key,
    this.cardSpacing, // 默认为 null，使用内置默认值 16
    this.crossAxisCount, // 默认为 null，使用内置默认值 2
    this.childAspectRatio, // 默认为 null，使用内置默认值 1.12
  });

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

    // 响应式设计：根据屏幕宽度计算列数和间距
    final screenWidth = MediaQuery.of(context).size.width;
    final effectiveSpacing = cardSpacing ?? 16.0;

    // 计算响应式列数
    int responsiveCrossAxisCount;
    if (crossAxisCount != null) {
      responsiveCrossAxisCount = crossAxisCount!;
    } else {
      // 根据屏幕宽度自动计算列数
      if (screenWidth < 600) {
        responsiveCrossAxisCount = 2; // 小屏幕 2 列
      } else if (screenWidth < 900) {
        responsiveCrossAxisCount = 3; // 中屏幕 3 列
      } else if (screenWidth < 1200) {
        responsiveCrossAxisCount = 4; // 大屏幕 4 列
      } else {
        responsiveCrossAxisCount = 5; // 超大屏幕 5 列
      }
    }

    // 计算响应式宽高比
    double responsiveChildAspectRatio;
    if (childAspectRatio != null) {
      responsiveChildAspectRatio = childAspectRatio!;
    } else {
      // 根据列数调整宽高比，确保2列时有最小高度
      if (responsiveCrossAxisCount == 2) {
        responsiveChildAspectRatio = 1.2; // 2列时更高，确保卡片有足够高度
      } else if (responsiveCrossAxisCount == 3) {
        responsiveChildAspectRatio = 0.9; // 3列时稍微高一点
      } else if (responsiveCrossAxisCount == 4) {
        responsiveChildAspectRatio = 0.95; // 4列时
      } else {
        responsiveChildAspectRatio = 1.0; // 5列时接近正方形
      }
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveCrossAxisCount,
        childAspectRatio: responsiveChildAspectRatio,
        crossAxisSpacing: effectiveSpacing,
        mainAxisSpacing: effectiveSpacing,
      ),
      itemCount: recommendations.length,
      itemBuilder: (context, index) {
        final item = recommendations[index];
        return AnimatedMediaCard(
          title: item['title']!,
          category: item['category']!,
          duration: item['duration']!,
          imageUrl: item['image']!,
          isListView: false,
          onTap: () => context.go('${AppRouter.player}?mediaId=$index'),
        );
      },
    );
  }
}
