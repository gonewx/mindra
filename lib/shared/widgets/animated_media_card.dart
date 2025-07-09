import 'package:flutter/material.dart';

class AnimatedMediaCard extends StatefulWidget {
  final String title;
  final String duration;
  final String category;
  final String? imageUrl;
  final bool isFavorite;
  final bool isListView;
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
                borderRadius: BorderRadius.circular(12), // --radius-lg: 12px
              ),
              child: InkWell(
                onTap: widget.onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image/Thumbnail - 固定高度匹配原型
                    Container(
                      height:
                          120, // 固定高度120px匹配原型 .session-card img { height: 120px; }
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
                                    return const Icon(
                                      Icons.music_note,
                                      size: 48,
                                      color: Colors.white,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.music_note,
                                  size: 48,
                                  color: Colors.white,
                                ),

                          // Duration Badge
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.duration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          // Animated Favorite Button
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _AnimatedFavoriteButton(
                              isFavorite: widget.isFavorite,
                              onTap: widget.onFavoriteToggle,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content - 匹配原型布局
                    Container(
                      height: 72, // 固定内容区域高度，总高度192px - 120px图片 = 72px
                      padding: const EdgeInsets.all(
                        12,
                      ), // --space-12: 12px 匹配原型
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w100,
                                  fontSize: 14, // --font-size-md: 14px 匹配原型
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4), // --space-4: 4px
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Category badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, // --space-8: 8px
                                  vertical: 2, // --space-2: 2px
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(
                                    6,
                                  ), // --radius-sm: 6px
                                ),
                                child: Text(
                                  widget.category,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontSize:
                                            11, // --font-size-xs: 11px 匹配原型
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                              // Duration
                              Text(
                                widget.duration,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                      fontSize: 12, // --font-size-sm: 12px 匹配原型
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
          );
        },
      ),
    );
  }

  Widget _buildAnimatedListView(BuildContext context) {
    // 使用传入的参数或默认值
    final thumbnailSize = widget.thumbnailSize ?? 64.0;
    final cardPadding = widget.cardPadding ?? const EdgeInsets.all(12);

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
                  padding: cardPadding,
                  child: Row(
                    children: [
                      // Thumbnail
                      Container(
                        width: thumbnailSize,
                        height: thumbnailSize,
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
                                    return const Icon(
                                      Icons.music_note,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                              )
                            : const Icon(Icons.music_note, color: Colors.white),
                      ),

                      const SizedBox(width: 12),

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
                                    fontSize: 15,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    widget.category,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.duration,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Actions
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
