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
    
    // Handle hover animation: transform: translate(-50%, -50%) scale(1.2)
    _handleScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _handleController,
      curve: Curves.easeOut,
    ));
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
    
    if (isHovered || _isDragging) {
      _handleController.forward();
    } else {
      _handleController.reverse();
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
    _handleController.forward();
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (widget.totalDuration <= 0) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);
    final double percentage = (localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final double newPosition = percentage * widget.totalDuration;
    
    widget.onSeek?.call(newPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    
    if (!_isHovered) {
      _handleController.reverse();
    }
  }

  void _onTap(TapUpDetails details, BoxConstraints constraints) {
    if (widget.totalDuration <= 0) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPosition = box.globalToLocal(details.globalPosition);
    final double percentage = (localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final double newPosition = percentage * widget.totalDuration;
    
    widget.onSeek?.call(newPosition);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveColor = widget.inactiveColor ?? 
        theme.colorScheme.outline.withValues(alpha: 0.3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final progress = widget.totalDuration > 0 
            ? (widget.currentPosition / widget.totalDuration).clamp(0.0, 1.0)
            : 0.0;
        
        return MouseRegion(
          onEnter: (_) => _onHoverChange(true),
          onExit: (_) => _onHoverChange(false),
          child: GestureDetector(
            onTapUp: (details) => _onTap(details, constraints),
            onPanStart: _onPanStart,
            onPanUpdate: (details) => _onPanUpdate(details, constraints),
            onPanEnd: _onPanEnd,
            child: Container(
              width: double.infinity,
              height: 24, // Larger touch area
              alignment: Alignment.center,
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: inactiveColor,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
                child: Stack(
                  children: [
                    // Progress fill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      width: constraints.maxWidth * progress,
                      height: widget.height,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(widget.height / 2),
                      ),
                    ),
                    
                    // Handle
                    AnimatedBuilder(
                      animation: _handleScaleAnimation,
                      builder: (context, child) {
                        return Positioned(
                          left: (constraints.maxWidth * progress) - 8, // Center the handle
                          top: (widget.height - 16) / 2, // Center vertically
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: (_isHovered || _isDragging) ? 1.0 : 0.0,
                            child: Transform.scale(
                              scale: _handleScaleAnimation.value,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: activeColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
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
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _formatTime(currentPosition),
              key: ValueKey(currentPosition.floor()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _formatTime(totalDuration),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}