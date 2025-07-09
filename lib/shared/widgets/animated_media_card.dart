import 'package:flutter/material.dart';

class AnimatedMediaCard extends StatefulWidget {
  final String title;
  final String duration;
  final String category;
  final String? imageUrl;
  final bool isFavorite;
  final bool isListView;
  final bool showActions; // 新增：是否显示收藏和更多选项按钮
  final bool showDurationBadge; // 新增：是否在图片上显示时长标签
  final double? thumbnailSize; // 新增：缩略图尺寸（列表视图时使用）
  final EdgeInsets? cardPadding; // 新增：卡片内边距
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMoreOptions;

  const AnimatedMediaCard({
    super.key,
    required this.title,
    required this.duration,
    required this.category,
    this.imageUrl,
    this.isFavorite = false,
    this.isListView = false,
    this.showActions = true, // 默认显示收藏和更多选项按钮
    this.showDurationBadge = true, // 默认在图片上显示时长标签
    this.thumbnailSize, // 默认为 null，使用内置默认值
    this.cardPadding, // 默认为 null，使用内置默认值
    this.onTap,
    this.onFavoriteToggle,
    this.onMoreOptions,
  });

  @override
  State<AnimatedMediaCard> createState() => _AnimatedMediaCardState();
}

class _AnimatedMediaCardState extends State<AnimatedMediaCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;

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
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
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
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;

    // 响应式图片高度
    final imageHeight = isSmallScreen
        ? 120.0
        : (isMediumScreen ? 130.0 : 140.0);

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
                                      return Icon(
                                        Icons.music_note,
                                        size: isSmallScreen ? 36 : 48,
                                        color: Colors.white,
                                      );
                                    },
                                  )
                                : Icon(
                                    Icons.music_note,
                                    size: isSmallScreen ? 36 : 48,
                                    color: Colors.white,
                                  ),

                            // Duration Badge - 只在需要时显示
                            if (widget.showDurationBadge)
                              Positioned(
                                bottom: isSmallScreen ? 6 : 8,
                                right: isSmallScreen ? 6 : 8,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 6 : 8,
                                    vertical: isSmallScreen ? 3 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    widget.duration,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: durationFontSize,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),

                            // Animated Favorite Button - 只在需要时显示
                            if (widget.showActions)
                              Positioned(
                                top: isSmallScreen ? 6 : 8,
                                right: isSmallScreen ? 6 : 8,
                                child: _AnimatedFavoriteButton(
                                  isFavorite: widget.isFavorite,
                                  onTap: widget.onFavoriteToggle,
                                ),
                              ),
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
                                    fontWeight: FontWeight.w100,
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
                                    return Icon(
                                      Icons.music_note,
                                      color: Colors.white,
                                      size: isSmallScreen ? 24 : 32,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.music_note,
                                color: Colors.white,
                                size: isSmallScreen ? 24 : 32,
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
                                    fontWeight: FontWeight.w100,
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

                      // Actions - 只在需要时显示
                      if (widget.showActions)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AnimatedFavoriteButton(
                              isFavorite: widget.isFavorite,
                              onTap: widget.onFavoriteToggle,
                              showBackground: false,
                            ),
                            _AnimatedIconButton(
                              icon: Icons.more_vert,
                              onTap:
                                  widget.onMoreOptions ??
                                  () => _showMoreOptions(context),
                            ),
                          ],
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

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AnimatedBottomSheet(
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('编辑信息'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Edit media item
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('分享'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Share media item
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('删除'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Delete media item
            },
          ),
        ],
      ),
    );
  }
}

class _AnimatedFavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback? onTap;
  final bool showBackground;

  const _AnimatedFavoriteButton({
    required this.isFavorite,
    this.onTap,
    this.showBackground = true,
  });

  @override
  State<_AnimatedFavoriteButton> createState() =>
      _AnimatedFavoriteButtonState();
}

class _AnimatedFavoriteButtonState extends State<_AnimatedFavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoverChange(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: InkWell(
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: widget.showBackground
                    ? BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Icon(
                  widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: widget.isFavorite
                      ? Colors.red
                      : widget.showBackground
                      ? Colors.white
                      : null,
                  size: 20,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _AnimatedIconButton({required this.icon, this.onTap});

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: IconButton(icon: Icon(widget.icon), onPressed: widget.onTap),
          );
        },
      ),
    );
  }
}

class _AnimatedBottomSheet extends StatefulWidget {
  final List<Widget> children;

  const _AnimatedBottomSheet({required this.children});

  @override
  State<_AnimatedBottomSheet> createState() => _AnimatedBottomSheetState();
}

class _AnimatedBottomSheetState extends State<_AnimatedBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300), // slideUp 0.3s ease
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.children,
        ),
      ),
    );
  }
}
