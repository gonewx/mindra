import 'package:flutter/material.dart';

class AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const AnimatedActionButton({
    super.key,
    required this.icon,
    required this.label,
    this.isPrimary = false,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150), // --duration-fast
      vsync: this,
    );

    _scaleAnimation =
        Tween<double>(
          begin: 1.0,
          end: 1.05, // scale(1.05) from CSS
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOut, // --ease-standard
          ),
        );

    _elevationAnimation =
        Tween<double>(
          begin: 4.0,
          end: 8.0, // Enhanced shadow on hover
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

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
  }

  void _onTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

  Color _getBackgroundColor(ThemeData theme) {
    if (widget.isPrimary) {
      if (_isPressed) {
        return theme.brightness == Brightness.dark
            ? const Color(0xFF2996A1) // darkPrimaryActive
            : const Color(0xFF1A6873); // primaryActive
      } else if (_isHovered) {
        return theme.brightness == Brightness.dark
            ? const Color(0xFF2DA6B2) // darkPrimaryHover
            : const Color(0xFF1D7480); // primaryHover
      }
      return theme.colorScheme.primary;
    } else {
      if (_isPressed) {
        return theme.brightness == Brightness.dark
            ? const Color(0x4D777C7C) // darkSecondaryActive
            : const Color(0x405E5240); // secondaryActive
      } else if (_isHovered) {
        return theme.brightness == Brightness.dark
            ? const Color(0x40777C7C) // darkSecondaryHover
            : const Color(0x335E5240); // secondaryHover
      }
      return theme.colorScheme.surface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click, // 添加手形光标
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 250,
                ), // --duration-normal
                curve: Curves.easeOut,
                width: widget.width,
                height: widget.height,
                constraints: const BoxConstraints(
                  minHeight: 60, // 确保最小高度
                  maxHeight: 120, // 限制最大高度避免过度拉伸
                ),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(theme),
                  borderRadius: BorderRadius.circular(12), // --radius-lg: 12px
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.1),
                      blurRadius: _elevationAnimation.value * 2,
                      offset: Offset(0, _elevationAnimation.value / 2),
                    ),
                  ],
                  border: !widget.isPrimary
                      ? Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        )
                      : null,
                ),
                padding: const EdgeInsets.all(12), // 减小padding避免溢出
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 防止Column占用过多空间
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Icon(
                        widget.icon,
                        size: 34,
                        color: widget.isPrimary
                            ? Colors.white
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        widget.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.isPrimary
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight
                              .w500, // --font-weight-medium: 500 匹配原型按钮
                          fontSize: 12, // 减小字体避免溢出
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2, // 允许文本换行
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
