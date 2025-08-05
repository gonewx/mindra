import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../widgets/player_controls.dart';
import '../widgets/progress_bar.dart';
import '../widgets/sound_effects_panel.dart';
import '../../services/global_player_service.dart';
import '../../../../features/media/domain/entities/media_item.dart';
import '../../../../features/media/presentation/bloc/media_bloc.dart';
import '../../../../features/media/presentation/bloc/media_event.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/constants/media_category.dart';
import '../../../../shared/widgets/timer_dialog.dart';

class PlayerPage extends StatefulWidget {
  final String? mediaId;
  final int? timerMinutes;

  const PlayerPage({super.key, this.mediaId, this.timerMinutes});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late GlobalPlayerService _playerService;
  Timer? _sessionCompleteTimer;

  // Media data getters that use the global service
  String get _title => _playerService.title;
  bool get _isPlaying => _playerService.isPlaying;
  bool get _isFavorited => _playerService.isFavorited;
  bool get _isShuffled => _playerService.isShuffled;
  RepeatMode get _repeatMode => _playerService.repeatMode;
  double get _currentPosition => _playerService.currentPosition;
  double get _totalDuration => _playerService.totalDuration;
  MediaItem? get _currentMedia => _playerService.currentMedia;

  @override
  void initState() {
    super.initState();
    _playerService = getIt<GlobalPlayerService>();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // 确保全局播放服务已初始化
      if (!_playerService.isInitialized) {
        debugPrint('PlayerPage: Initializing global player service...');
        await _playerService.initialize();
      }

      // 首先监听服务变化
      _playerService.addListener(_onPlayerServiceChanged);

      // 处理媒体加载逻辑（使用优化的方法）
      await _playerService.prepareMediaForPlayer(
        widget.mediaId,
        autoPlay: false,
      );

      // 设置定时器（如果URL参数中指定）
      if (widget.timerMinutes != null) {
        _playerService.setSleepTimer(widget.timerMinutes!);
        if (mounted) {
          final localizations = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.timerSetMessage(widget.timerMinutes!),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }

      debugPrint('PlayerPage: Initialization completed successfully');
    } catch (e) {
      debugPrint('PlayerPage: Error during initialization: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;

        // 显示更友好的错误信息
        String errorMessage;
        if (e.toString().contains('audio player')) {
          errorMessage = '音频播放器初始化失败，请重试';
        } else if (e.toString().contains('media')) {
          errorMessage = '加载媒体文件失败，请检查文件是否存在';
        } else {
          errorMessage = localizations.playerInitializationFailed(e.toString());
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: '重试',
              onPressed: () {
                // 重新初始化
                _initializePlayer();
              },
            ),
          ),
        );
      }
    }
  }

  void _onPlayerServiceChanged() {
    if (mounted) {
      setState(() {}); // Trigger rebuild when player service state changes
    }
  }

  @override
  void dispose() {
    _sessionCompleteTimer?.cancel();
    _playerService.removeListener(_onPlayerServiceChanged);
    // Don't dispose the global player service here as it should persist
    super.dispose();
  }

  Widget _buildCoverImage(ThemeData theme) {
    // 如果有缩略图路径，尝试显示
    if (_currentMedia?.thumbnailPath != null &&
        _currentMedia!.thumbnailPath!.isNotEmpty) {
      return Image.network(
        _currentMedia!.thumbnailPath!,
        width: 300,
        height: 300,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultCover(theme);
        },
      );
    }

    // 否则显示默认封面
    return _buildDefaultCover(theme);
  }

  Widget _buildDefaultCover(ThemeData theme) {
    // 根据类别选择不同的图标和颜色
    IconData iconData;
    List<Color> gradientColors;

    final category = _currentMedia?.category;
    if (category == MediaCategory.meditation ||
        category == MediaCategory.mindfulness) {
      iconData = Icons.self_improvement;
      gradientColors = [const Color(0xFF6B73FF), const Color(0xFF9B59B6)];
    } else if (category == MediaCategory.sleep) {
      iconData = Icons.bedtime;
      gradientColors = [const Color(0xFF667eea), const Color(0xFF764ba2)];
    } else if (category == MediaCategory.focus ||
        category == MediaCategory.study) {
      iconData = Icons.psychology;
      gradientColors = [const Color(0xFF11998e), const Color(0xFF38ef7d)];
    } else if (category == MediaCategory.relaxation ||
        category == MediaCategory.soothing) {
      iconData = Icons.spa;
      gradientColors = [const Color(0xFFa8edea), const Color(0xFFfed6e3)];
    } else if (category == MediaCategory.nature ||
        category == MediaCategory.environment) {
      iconData = Icons.nature;
      gradientColors = [const Color(0xFF56ab2f), const Color(0xFFa8e6cf)];
    } else if (category == MediaCategory.breathing) {
      iconData = Icons.air;
      gradientColors = [const Color(0xFF9B59B6), const Color(0xFF8E44AD)];
    } else {
      iconData = Icons.music_note;
      gradientColors = [theme.colorScheme.primary, theme.colorScheme.secondary];
    }

    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(iconData, size: 80, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // 占位符，保持标题居中
                  Text(
                    localizations.playerNowPlaying,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_currentMedia != null)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surface,
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: IconButton(
                        onPressed: _showMoreOptions,
                        icon: Icon(
                          Icons.more_vert,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48), // 占位符，保持标题居中
                ],
              ),
            ),

            // Content
            Expanded(
              child: _currentMedia == null
                  ? _buildEmptyState(theme, localizations)
                  : _buildPlayerContent(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.music_note,
              size: 80,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            localizations.playerNoMaterialSelected,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            localizations.playerSelectMaterialMessage,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/media'),
            icon: const Icon(Icons.library_music),
            label: Text(localizations.navigationGoToMediaLibrary),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerContent(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 8), // 减小间距
          // Album Art
          Container(
            width: 300,
            height: 300,
            margin: const EdgeInsets.symmetric(vertical: 8), // 减小间距
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildCoverImage(theme),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                    child: IconButton(
                      onPressed: _toggleFavorite,
                      icon: Icon(
                        _isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorited ? Colors.red : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Track Info
          Column(
            children: [
              Text(
                _title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _currentMedia?.category.getDisplayName(context) ?? '',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Bar with proper width
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: ProgressBar(
              currentPosition: _currentPosition,
              totalDuration: _totalDuration,
              bufferProgress: _playerService.bufferProgress,
              onSeek: (position) async {
                await _playerService.seek(Duration(seconds: position.toInt()));
              },
            ),
          ),
          const SizedBox(height: 12),

          // Player Controls
          PlayerControls(
            isPlaying: _isPlaying,
            playerState: _playerService.playerState,
            onPlayPause: () async {
              debugPrint(
                'PlayPause button pressed: isPlaying=$_isPlaying, playerState=${_playerService.playerState}',
              );

              if (_isPlaying) {
                debugPrint('Currently playing - pausing');
                await _playerService.pause();
              } else {
                debugPrint('Currently not playing - starting playback');
                await _playerService.play();
              }
            },
            onPrevious: () => _playerService.playPrevious(),
            onNext: () => _playerService.playNext(),
          ),
          const SizedBox(height: 24),

          // Bottom Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.shuffle,
                isActive: _isShuffled,
                onTap: () {
                  final localizations = AppLocalizations.of(context)!;
                  _playerService.toggleShuffle();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isShuffled
                            ? localizations.playerShuffleEnabled
                            : localizations.playerShuffleDisabled,
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: _getRepeatIcon(),
                isActive: _repeatMode != RepeatMode.none,
                onTap: () {
                  final localizations = AppLocalizations.of(context)!;
                  _playerService.toggleRepeatMode();
                  final modeText = _getRepeatModeText(localizations);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.playerRepeatMode(modeText)),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              _buildTimerButton(),
              const SizedBox(width: 16),
              _buildActionButton(
                icon: Icons.equalizer,
                isActive: _playerService.hasActiveSoundEffects,
                onTap: () => _showSoundEffectsDialog(),
              ),
            ],
          ),
          const SizedBox(height: 32),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surface,
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: IconButton(
        iconSize: 16,
        onPressed: onTap,
        icon: Icon(
          icon,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildTimerButton() {
    final theme = Theme.of(context);
    final isActive = _playerService.hasActiveTimer;
    final timerMinutes = _playerService.sleepTimerMinutes;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surface,
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Stack(
        children: [
          IconButton(
            iconSize: 16,
            onPressed: _showTimerDialog,
            icon: Icon(
              Icons.timer,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (isActive && timerMinutes > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$timerMinutes',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    final localizations = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.actionMoreOptions,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildOptionTile(
                    icon: Icons.share,
                    title: localizations.actionShare,
                    onTap: () {
                      Navigator.pop(context);
                      _shareCurrentMedia();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  String _getRepeatModeText(AppLocalizations localizations) {
    switch (_repeatMode) {
      case RepeatMode.none:
        return localizations.repeatModeOff;
      case RepeatMode.all:
        return localizations.repeatModeAll;
      case RepeatMode.one:
        return localizations.repeatModeOne;
    }
  }

  IconData _getRepeatIcon() {
    switch (_repeatMode) {
      case RepeatMode.none:
        return Icons.repeat;
      case RepeatMode.all:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
    }
  }

  void _toggleFavorite() async {
    if (_currentMedia == null) return;

    await _playerService.toggleFavorite();

    // Use MediaBloc to update favorite status in database
    if (mounted) {
      final localizations = AppLocalizations.of(context)!;

      context.read<MediaBloc>().add(
        ToggleFavorite(_currentMedia!.id, _isFavorited),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorited
                ? localizations.favoritesAdded
                : localizations.favoritesRemoved,
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _shareCurrentMedia() {
    if (_currentMedia == null) return;

    final localizations = AppLocalizations.of(context)!;

    final shareText =
        '''
${localizations.shareListeningTo(_currentMedia!.title)}
  ${localizations.shareCategory(_currentMedia!.category.getDisplayName(context))}
${_currentMedia!.description?.isNotEmpty == true ? localizations.shareDescription(_currentMedia!.description!) : ''}

${localizations.shareAppSignature}
''';

    // For Flutter web and mobile platforms, you would typically use the share_plus package
    // For now, we'll copy to clipboard and show a message
    _copyToClipboard(shareText);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.actionShare),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localizations.shareCopiedToClipboard),
            const SizedBox(height: 16),
            Text(shareText, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.actionConfirm),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    // TODO: Implement clipboard copy functionality
    // This would typically use the clipboard package
    debugPrint('Copying to clipboard: $text');
  }

  void _showTimerDialog() {
    TimerDialog.show(
      context,
      onTimerSet: () {
        // 定时器设置后刷新UI
        setState(() {});
      },
    );
  }

  void _showSoundEffectsDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16), // 添加外边距防止溢出
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 根据屏幕大小动态调整弹出框尺寸
            final maxWidth = constraints.maxWidth > 450
                ? 400.0
                : constraints.maxWidth - 32;
            final maxHeight = constraints.maxHeight > 600
                ? 500.0
                : constraints.maxHeight - 100;

            return Container(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A3441)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with title and close button
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.2,
                                ),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            localizations.soundEffectsSettings,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: isDark
                                  ? const Color(0xFF32B8C6)
                                  : theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: isDark
                                ? Colors.white70
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Content - 使用Flexible让内容可以收缩
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: const SingleChildScrollView(
                        child: SoundEffectsPanel(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
