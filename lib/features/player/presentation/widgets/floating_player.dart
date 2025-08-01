import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/global_player_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/audio/audio_player.dart'; // 导入MindraPlayerState

class FloatingPlayer extends StatefulWidget {
  const FloatingPlayer({super.key});

  @override
  State<FloatingPlayer> createState() => _FloatingPlayerState();
}

class _FloatingPlayerState extends State<FloatingPlayer>
    with TickerProviderStateMixin {
  late GlobalPlayerService _playerService;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  Offset _position = const Offset(0, 0); // 初始位置，将在 initState 中设置
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _playerService = getIt<GlobalPlayerService>();

    // 创建动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 监听播放器状态变化
    _playerService.addListener(_onPlayerServiceChanged);

    // 异步初始化位置
    _initializePosition();
  }

  Future<void> _initializePosition() async {
    await _loadSavedPosition();
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _loadSavedPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedX = prefs.getDouble('floating_player_x');
      final savedY = prefs.getDouble('floating_player_y');

      if (savedX != null && savedY != null) {
        // 直接设置保存的位置，不需要 setState，因为这在 initState 期间调用
        _position = Offset(savedX, savedY);
        debugPrint('Loaded saved floating player position: $_position');
      } else {
        // 设置默认位置：右下角导航栏上面
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _setDefaultPosition();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading floating player position: $e');
      // 设置默认位置
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setDefaultPosition();
        }
      });
    }
  }

  void _setDefaultPosition() {
    final screenSize = MediaQuery.of(context).size;
    // 调整默认位置，确保不干扰导航栏
    // 导航栏现在高度为68px + SafeArea，预留更多空间
    final defaultX = screenSize.width - 80.0; // 60(浮动球宽度) + 20(边距)
    final defaultY =
        screenSize.height - 180.0; // 增加间距：68(导航栏) + 52(SafeArea+间距) + 60(浮动球高度)

    setState(() {
      _position = Offset(defaultX, defaultY);
    });

    // 保存默认位置，这样下次就不需要重新计算了
    _savePosition();
    debugPrint('Set and saved default floating player position: $_position');
  }

  Future<void> _savePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('floating_player_x', _position.dx);
      await prefs.setDouble('floating_player_y', _position.dy);
      debugPrint('Saved floating player position: $_position');
    } catch (e) {
      debugPrint('Error saving floating player position: $e');
    }
  }

  @override
  void dispose() {
    _playerService.removeListener(_onPlayerServiceChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onPlayerServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有当前媒体或还未初始化位置，不显示浮动球
    if (_playerService.currentMedia == null || !_isInitialized) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (_) {
          _animationController.forward();
        },
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;

            // 增强边界限制，确保不会干扰导航栏
            final navBarHeight = 68 + 20; // 导航栏高度 + 安全间距
            _position = Offset(
              _position.dx.clamp(0, screenSize.width - 60),
              _position.dy.clamp(
                0,
                screenSize.height - 60 - navBarHeight,
              ), // 限制在导航栏之上
            );
          });
        },
        onPanEnd: (_) {
          _animationController.reverse();

          // 自动吸附到屏幕边缘
          final centerX = screenSize.width / 2;
          final targetX = _position.dx < centerX ? 0.0 : screenSize.width - 60;

          setState(() {
            _position = Offset(targetX, _position.dy);
          });

          // 保存新位置（包括吸附后的位置）
          _savePosition();
        },
        onTap: _togglePlayPause,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // 播放/暂停按钮
                    Center(child: _buildFloatingButtonContent(theme)),

                    // 进度环
                    if (_playerService.totalDuration > 0)
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value:
                              _playerService.currentPosition /
                              _playerService.totalDuration,
                          backgroundColor: theme.colorScheme.onPrimary
                              .withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                          strokeWidth: 2,
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

  void _togglePlayPause() async {
    try {
      if (_playerService.isPlaying) {
        await _playerService.pause();
      } else {
        await _playerService.play();
      }
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
    }
  }

  Widget _buildFloatingButtonContent(ThemeData theme) {
    final isLoading =
        _playerService.playerState == MindraPlayerState.loading ||
        _playerService.playerState == MindraPlayerState.buffering;

    if (isLoading) {
      // 显示简单的加载指示器
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.onPrimary,
          ),
        ),
      );
    } else {
      // 显示正常的播放/暂停图标
      return Icon(
        _playerService.isPlaying ? Icons.pause : Icons.play_arrow,
        color: theme.colorScheme.onPrimary,
        size: 28,
      );
    }
  }
}

class FloatingPlayerOverlay extends StatelessWidget {
  final Widget child;

  const FloatingPlayerOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [child, const FloatingPlayer()]);
  }
}
