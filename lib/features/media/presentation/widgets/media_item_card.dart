import 'package:flutter/material.dart';
import '../../../../shared/widgets/animated_media_card.dart';

class MediaItemCard extends StatelessWidget {
  final String title;
  final String duration;
  final String category;
  final String? imageUrl;
  final bool isFavorite;
  final bool isListView;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMoreOptions;

  const MediaItemCard({
    super.key,
    required this.title,
    required this.duration,
    required this.category,
    this.imageUrl,
    this.isFavorite = false,
    this.isListView = false,
    this.onTap,
    this.onFavoriteToggle,
    this.onMoreOptions,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedMediaCard(
      title: title,
      duration: duration,
      category: category,
      imageUrl: imageUrl,
      isFavorite: isFavorite,
      isListView: isListView,
      onTap: onTap,
      onFavoriteToggle: onFavoriteToggle,
      onMoreOptions: onMoreOptions,
    );
  }
}