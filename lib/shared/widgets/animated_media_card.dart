import 'package:flutter/material.dart';

class AnimatedMediaCard extends StatefulWidget {
  final String title;
  final String duration;
  final String category;
  final String? imageUrl;
  final bool isListView;
  final double? thumbnailSize; // 新增：缩略图尺寸（列表视图时使用）
  final EdgeInsets? cardPadding; // 新增：卡片内边距
  final VoidCallback? onTap;

  const AnimatedMediaCard({
    super.key,
    required this.title,
    required this.duration,
    required this.category,
    this.imageUrl,
    this.isListView = false,
    this.thumbnailSize, // 默认为 null，使用内置默认值
    this.cardPadding, // 默认为 null，使用内置默认值
    this.onTap,
  });

  @override
  State<AnimatedMediaCard> createState() => _AnimatedMediaCardState();
}

class _AnimatedMediaCardState extends State<AnimatedMediaCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300), // 0.3s ease from CSS
      vsync: this,
    );

    if (widget.isListView) {
      // List view: translateX(4px)
      _slideAnimation = Tween<double>(begin: 0.0, end: 4.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
      );
    } else {
      // Grid view: translateY(-4px)
      _slideAnimation = Tween<double>(begin: 0.0, end: -4.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
      );
    }

    _elevationAnimation =
        Tween<double>(
          begin: 4.0,
          end: 8.0, // Enhanced shadow (0 8px 24px var(--app-shadow))
        ).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHoverChange(bool isHovered) {
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  // 根据分类获取图标和颜色的通用方法
  (IconData, List<Color>) _getIconAndColors(BuildContext context) {
    final category = widget.category.toLowerCase();
    final theme = Theme.of(context);

    if (category.contains('睡前') || category.contains('睡眠')) {
      return (
        Icons.bedtime,
        [const Color(0xFF6B73FF), const Color(0xFF9B59B6)],
      );
    } else if (category.contains('专注') || category.contains('工作')) {
      return (
        Icons.psychology,
        [const Color(0xFF3498DB), const Color(0xFF2980B9)],
      );
    } else if (category.contains('放松') || category.contains('减压')) {
      return (Icons.spa, [const Color(0xFF2ECC71), const Color(0xFF27AE60)]);
    } else if (category.contains('自然') || category.contains('音效')) {
      return (Icons.nature, [const Color(0xFF16A085), const Color(0xFF1ABC9C)]);
    } else if (category.contains('冥想') || category.contains('正念')) {
      return (
        Icons.self_improvement,
        [const Color(0xFFE67E22), const Color(0xFFD35400)],
      );
    } else if (category.contains('呼吸')) {
      return (Icons.air, [const Color(0xFF9B59B6), const Color(0xFF8E44AD)]);
    } else {
      // 默认音乐图标
      return (
        Icons.music_note,
        [theme.colorScheme.primary, theme.colorScheme.secondary],
      );
    }
  }

  Widget _buildDefaultCover(BuildContext context, bool isSmallScreen) {
    final (iconData, gradientColors) = _getIconAndColors(context);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        iconData,
        size: isSmallScreen ? 36 : 48,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  Widget _buildDefaultCoverForList(BuildContext context, bool isSmallScreen) {
    final (iconData, gradientColors) = _getIconAndColors(context);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        iconData,
        size: isSmallScreen ? 24 : 32,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isListView) {
      return _buildAnimatedListView(context);
    } else {
      return _buildAnimatedGridView(context);
    }
  }

  Widget _buildAnimatedGridView(BuildContext context) {
    // 响应式设计：根据屏幕宽度计算组件尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    // 响应式字体大小
    final titleFontSize = isSmallScreen ? 14.0 : 14.0;
    final categoryFontSize = isSmallScreen ? 12.0 : 12.0;
    final durationFontSize = isSmallScreen ? 12.0 : 12.0;

    // 响应式内边距
    final contentPadding = isSmallScreen ? 12.0 : 14.0;

    return MouseRegion(
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: _elevationAnimation.value,
              shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: widget.onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image/Thumbnail - 使用 Flexible 而不是固定高度
                    Flexible(
                      flex: 3, // 图片占据卡片 3/5 的空间
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                              Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            widget.imageUrl != null
                                ? Image.network(
                                    widget.imageUrl!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildDefaultCover(
                                        context,
                                        isSmallScreen,
                                      );
                                    },
                                  )
                                : _buildDefaultCover(context, isSmallScreen),
                          ],
                        ),
                      ),
                    ),

                    // Content - 响应式布局
                    Flexible(
                      flex: 2, // 内容占据卡片 2/5 的空间
                      child: Container(
                        padding: EdgeInsets.all(contentPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w200,
                                    fontSize: titleFontSize,
                                  ),
                              maxLines: isSmallScreen ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Category badge
                                Flexible(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 6 : 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.category,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontSize: categoryFontSize,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Duration
                                Text(
                                  widget.duration,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                        fontSize: durationFontSize,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedListView(BuildContext context) {
    // 响应式设计：根据屏幕宽度计算组件尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    // 响应式缩略图尺寸
    final responsiveThumbnailSize =
        widget.thumbnailSize ?? (isSmallScreen ? 56.0 : 64.0);

    // 响应式内边距
    final responsiveCardPadding =
        widget.cardPadding ?? EdgeInsets.all(isSmallScreen ? 8.0 : 12.0);

    // 响应式字体大小
    final titleFontSize = isSmallScreen ? 14.0 : 15.0;
    final categoryFontSize = isSmallScreen ? 11.0 : 12.0;
    final durationFontSize = isSmallScreen ? 11.0 : 12.0;

    return MouseRegion(
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_slideAnimation.value, 0),
            child: Card(
              elevation: _elevationAnimation.value,
              shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // --radius-lg: 12px
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: responsiveCardPadding,
                  child: Row(
                    children: [
                      // Thumbnail
                      Container(
                        width: responsiveThumbnailSize,
                        height: responsiveThumbnailSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                              Theme.of(
                                context,
                              ).colorScheme.secondary.withValues(alpha: 0.3),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: widget.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  widget.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildDefaultCoverForList(
                                        context,
                                        isSmallScreen,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildDefaultCoverForList(
                                  context,
                                  isSmallScreen,
                                ),
                              ),
                      ),

                      SizedBox(width: isSmallScreen ? 8 : 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w200,
                                    fontSize: titleFontSize,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: isSmallScreen ? 3 : 4),
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 6 : 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      widget.category,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: categoryFontSize,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 6 : 8),
                                Text(
                                  widget.duration,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                        fontSize: durationFontSize,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
