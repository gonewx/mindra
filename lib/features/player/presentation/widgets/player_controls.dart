import 'package:flutter/material.dart';
import '../../../../core/audio/audio_player.dart'; // 导入MindraPlayerState

enum RepeatMode { none, one, all }

class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final MindraPlayerState? playerState; // 新增：播放器状态

  const PlayerControls({
    super.key,
    required this.isPlaying,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.playerState, // 新增：播放器状态
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous
        _AnimatedControlButton(
          icon: Icons.skip_previous,
          onPressed: onPrevious,
          size: 36,
        ),

        const SizedBox(width: 32),

        // Play/Pause - Main Button
        _AnimatedPlayButton(
          isPlaying: isPlaying,
          onPressed: onPlayPause,
          playerState: playerState, // 传递播放器状态
        ),

        const SizedBox(width: 32),

        // Next
        _AnimatedControlButton(
          icon: Icons.skip_next,
          onPressed: onNext,
          size: 36,
        ),
      ],
    );
  }
}

class _AnimatedControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const _AnimatedControlButton({
    required this.icon,
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
    if (_isHovered) {
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
      cursor: SystemMouseCursors.click, // 添加手形光标
      onEnter: (_) => _onHoverChange(true),
      onExit: (_) => _onHoverChange(false),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: widget.onPressed,
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  child: Icon(
                    widget.icon,
                    color: _getIconColor(theme),
                    size: widget.size,
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

class _AnimatedPlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback? onPressed;
  final MindraPlayerState? playerState; // 新增：播放器状态

  const _AnimatedPlayButton({
    required this.isPlaying,
    this.onPressed,
    this.playerState, // 新增：播放器状态
  });

  @override
  State<_AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<_AnimatedPlayButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  AnimationController? _loadingController; // 改为可空：加载动画控制器
  Animation<double>? _rotationAnimation; // 改为可空：旋转动画
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    // 初始化缩放动画控制器
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(_controller);

    // 初始化加载动画控制器
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController!, curve: Curves.linear),
    );

    // 根据初始状态启动加载动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateLoadingAnimation();
    });
  }

  @override
  void didUpdateWidget(_AnimatedPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateLoadingAnimation();
  }

  void _updateLoadingAnimation() {
    // 根据播放器状态控制加载动画
    final isLoading =
        widget.playerState == MindraPlayerState.loading ||
        widget.playerState == MindraPlayerState.buffering;

    debugPrint(
      'PlayButton: State=${widget.playerState}, isLoading=$isLoading, isPlaying=${widget.isPlaying}',
    );

    if (isLoading && !(_loadingController?.isAnimating ?? false)) {
      debugPrint('PlayButton: Starting loading animation');
      _loadingController?.repeat();
    } else if (!isLoading && (_loadingController?.isAnimating ?? false)) {
      debugPrint('PlayButton: Stopping loading animation');
      _loadingController?.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _loadingController?.dispose(); // 清理加载动画控制器
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

  Widget _buildButtonContent() {
    final isLoading =
        widget.playerState == MindraPlayerState.loading ||
        widget.playerState == MindraPlayerState.buffering;

    if (isLoading && _rotationAnimation != null) {
      // 显示加载指示器
      return AnimatedBuilder(
        animation: _rotationAnimation!,
        builder: (context, child) {
          return Transform.rotate(
            angle: (_rotationAnimation?.value ?? 0.0) * 2 * 3.14159,
            child: const Icon(Icons.refresh, color: Colors.white, size: 36),
          );
        },
      );
    } else {
      // 显示正常的播放/暂停图标
      return Icon(
        widget.isPlaying ? Icons.pause : Icons.play_arrow,
        color: Colors.white,
        size: 36,
      );
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
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: 72,
                height: 72,
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
                child: _buildButtonContent(),
              ),
            );
          },
        ),
      ),
    );
  }
}
