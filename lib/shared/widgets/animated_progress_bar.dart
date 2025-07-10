import 'package:flutter/material.dart';

class AnimatedProgressBar extends StatefulWidget {
  final double currentPosition;
  final double totalDuration;
  final Function(double)? onSeek;
  final Color? activeColor;
  final Color? inactiveColor;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    this.onSeek,
    this.activeColor,
    this.inactiveColor,
    this.height = 4.0,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _handleController;
  late Animation<double> _handleScaleAnimation;
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _handleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _handleScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _handleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  void _onHoverChange(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _handleController.forward();
    } else {
      _handleController.reverse();
    }
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _handleController.forward();
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (widget.totalDuration <= 0 || !_isDragging) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);
    final double percentage = (localPosition.dx / constraints.maxWidth).clamp(
      0.0,
      1.0,
    );
    final double newPosition = percentage * widget.totalDuration;

    widget.onSeek?.call(newPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    if (!_isHovered) {
      _handleController.reverse();
    }
  }

  void _onTap(TapUpDetails details, BoxConstraints constraints) {
    if (widget.totalDuration <= 0 || _isDragging) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);
    final double percentage = (localPosition.dx / constraints.maxWidth).clamp(
      0.0,
      1.0,
    );
    final double newPosition = percentage * widget.totalDuration;

    widget.onSeek?.call(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;

    // Use a more visible inactive color based on theme brightness
    final inactiveColor =
        widget.inactiveColor ??
        (theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.15));

    return LayoutBuilder(
      builder: (context, constraints) {
        final progress = widget.totalDuration > 0
            ? (widget.currentPosition / widget.totalDuration).clamp(0.0, 1.0)
            : 0.0;

        return MouseRegion(
          onEnter: (_) => _onHoverChange(true),
          onExit: (_) => _onHoverChange(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _isDragging
                ? null
                : (details) => _onTap(details, constraints),
            onPanStart: _onPanStart,
            onPanUpdate: (details) => _onPanUpdate(details, constraints),
            onPanEnd: _onPanEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              width: double.infinity,
              height: 20, // Larger touch area for better interaction
              alignment: Alignment.center,
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: inactiveColor,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Progress fill
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: constraints.maxWidth * progress,
                        height: widget.height,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(
                            widget.height / 2,
                          ),
                        ),
                      ),
                    ),

                    // Handle - Always visible
                    AnimatedBuilder(
                      animation: _handleScaleAnimation,
                      builder: (context, child) {
                        return Positioned(
                          left:
                              (constraints.maxWidth * progress) -
                              10, // Center the handle
                          top: -8, // Center vertically
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            child: Transform.scale(
                              scale: _handleScaleAnimation.value,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: activeColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedTimeDisplay extends StatelessWidget {
  final double currentPosition;
  final double totalDuration;

  const AnimatedTimeDisplay({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
  });

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).floor();
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0).copyWith(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatTime(currentPosition),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _formatTime(totalDuration),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
