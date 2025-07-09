import 'package:flutter/material.dart';

enum RepeatMode { none, one, all }

class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onShuffle;
  final VoidCallback? onRepeat;
  final bool isShuffled;
  final RepeatMode repeatMode;

  const PlayerControls({
    super.key,
    required this.isPlaying,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onShuffle,
    this.onRepeat,
    this.isShuffled = false,
    this.repeatMode = RepeatMode.none,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle
        _AnimatedControlButton(
          icon: Icons.shuffle,
          isActive: isShuffled,
          onPressed: onShuffle,
          size: 24,
        ),

        // Previous
        _AnimatedControlButton(
          icon: Icons.skip_previous,
          onPressed: onPrevious,
          size: 32,
        ),

        // Play/Pause - Main Button
        _AnimatedPlayButton(
          isPlaying: isPlaying,
          onPressed: onPlayPause,
        ),

        // Next
        _AnimatedControlButton(
          icon: Icons.skip_next,
          onPressed: onNext,
          size: 32,
        ),

        // Repeat
        _AnimatedControlButton(
          icon: _getRepeatIcon(),
          isActive: repeatMode != RepeatMode.none,
          onPressed: onRepeat,
          size: 24,
        ),
      ],
    );
  }

  IconData _getRepeatIcon() {
    switch (repeatMode) {
      case RepeatMode.none:
        return Icons.repeat;
      case RepeatMode.all:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
    }
  }
}

class _AnimatedControlButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onPressed;
  final double size;

  const _AnimatedControlButton({
    required this.icon,
    this.isActive = false,
    this.onPressed,
    this.size = 24,
  });

  @override
  State<_AnimatedControlButton> createState() => _AnimatedControlButtonState();
}

class _AnimatedControlButtonState extends State<_AnimatedControlButton>
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

  Color _getIconColor(ThemeData theme) {
    if (widget.isActive) {
      return theme.colorScheme.primary;
    } else if (_isHovered) {
      return theme.brightness == Brightness.dark
          ? const Color(0xFF2DA6B2) // darkPrimaryHover
          : const Color(0xFF1D7480); // primaryHover
    }
    return theme.colorScheme.onSurface.withValues(alpha: 0.6);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: IconButton(
              icon: Icon(widget.icon),
              color: _getIconColor(theme),
              onPressed: widget.onPressed,
              iconSize: widget.size,
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedPlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback? onPressed;

  const _AnimatedPlayButton({
    required this.isPlaying,
    this.onPressed,
  });

  @override
  State<_AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<_AnimatedPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(_controller);
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getBackgroundColor(theme),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.3),
                      blurRadius: _isHovered ? 8 : 4,
                      offset: Offset(0, _isHovered ? 4 : 2),
                    ),
                  ],
                ),
                child: Icon(
                  widget.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}