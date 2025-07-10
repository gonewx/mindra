import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../widgets/player_controls.dart';
import '../widgets/progress_bar.dart';
import '../widgets/sound_effects_panel.dart';
import '../../domain/services/sound_effects_service.dart';
import '../../../../features/media/data/datasources/media_local_datasource.dart';
import '../../../../features/media/domain/entities/media_item.dart';
import '../../../../features/media/presentation/bloc/media_bloc.dart';
import '../../../../features/media/presentation/bloc/media_event.dart';
import '../../../../features/media/presentation/widgets/add_media_dialog.dart';
import '../../../../core/audio/cross_platform_audio_player.dart';

class PlayerPage extends StatefulWidget {
  final String? mediaId;

  const PlayerPage({super.key, this.mediaId});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late CrossPlatformAudioPlayer _audioPlayer;
  final SoundEffectsService _soundEffectsService = SoundEffectsService();
  bool _isPlaying = false;

  bool _isFavorited = false;
  bool _isShuffled = false;
  RepeatMode _repeatMode = RepeatMode.none;
  Timer? _sleepTimer;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;

  // Subscription management
  late StreamSubscription _playingSubscription;
  late StreamSubscription _positionSubscription;
  late StreamSubscription _durationSubscription;

  // Media data
  MediaItem? _currentMedia;
  List<MediaItem> _mediaItems = [];
  List<MediaItem> _shuffledItems = [];
  int _currentIndex = 0;
  final MediaLocalDataSource _mediaDataSource = MediaLocalDataSource();

  // Media data getters
  String get _title => _currentMedia?.title ?? '加载中...';
  String get _category => _currentMedia?.category ?? '未知';

  @override
  void initState() {
    super.initState();
    _audioPlayer = CrossPlatformAudioPlayer();
    _setupAudioPlayer();
    _loadMediaData();
    _loadFavoriteStatus();
    _initializeSoundEffects();
  }

  void _initializeSoundEffects() async {
    try {
      await _soundEffectsService.initialize();
      debugPrint('Sound effects service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize sound effects service: $e');
    }
  }

  void _setupAudioPlayer() {
    // Listen to playing state changes
    _playingSubscription = _audioPlayer.playingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });

    // Listen to position changes
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position.inSeconds.toDouble();
        });
      }
    });

    // Listen to duration changes
    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (duration != null && mounted) {
        setState(() {
          _totalDuration = duration.inSeconds.toDouble();
        });
      }
    });
  }

  Future<void> _loadMediaData() async {
    if (widget.mediaId != null) {
      try {
        _mediaItems = await _mediaDataSource.getMediaItems();
        _currentIndex = _mediaItems.indexWhere(
          (item) => item.id == widget.mediaId,
        );

        if (_currentIndex >= 0) {
          final media = _mediaItems[_currentIndex];
          setState(() {
            _currentMedia = media;
          });

          // Load favorite status
          _loadFavoriteStatus();

          // Load audio file
          await _loadAudioFile(media.filePath);
        }
      } catch (e) {
        debugPrint('Error loading media: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('加载媒体失败: $e')));
        }
      }
    }
  }

  Future<void> _loadAudioFile(String filePath) async {
    try {
      if (kIsWeb && filePath.startsWith('web://')) {
        // For web platform, create blob URL from stored bytes
        if (_currentMedia != null) {
          debugPrint('Loading web audio for media ID: ${_currentMedia!.id}');
          final mimeType = _getMimeType(_currentMedia!.filePath);
          debugPrint('Using MIME type: $mimeType');

          final blobUrl = _mediaDataSource.createAudioBlobUrl(
            _currentMedia!.id,
            mimeType,
          );

          if (blobUrl != null) {
            debugPrint(
              'Successfully created blob URL, attempting to load audio',
            );
            await _audioPlayer.setUrl(blobUrl);
            debugPrint('Web audio loaded from blob URL successfully');
            return;
          } else {
            debugPrint(
              'Failed to create blob URL for media ID: ${_currentMedia!.id}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('无法创建音频播放链接，请检查文件是否正确上传')),
            );
            return;
          }
        } else {
          debugPrint('No current media available for web playback');
        }
      }

      // For desktop platforms, load from file path
      debugPrint('Loading desktop audio from file path: $filePath');
      await _audioPlayer.setFilePath(filePath);
      debugPrint('Audio file loaded: $filePath');
    } catch (e) {
      debugPrint('Error loading audio file: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载音频文件失败: $e')));
      }
    }
  }

  String _getMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/mpeg'; // Default to mp3
    }
  }

  @override
  void dispose() {
    _playingSubscription.cancel();
    _positionSubscription.cancel();
    _durationSubscription.cancel();
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    _soundEffectsService.dispose();
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

    final category = _currentMedia?.category ?? '';
    if (category.contains('冥想') || category.contains('正念')) {
      iconData = Icons.self_improvement;
      gradientColors = [const Color(0xFF6B73FF), const Color(0xFF9B59B6)];
    } else if (category.contains('睡前') || category.contains('睡眠')) {
      iconData = Icons.bedtime;
      gradientColors = [const Color(0xFF667eea), const Color(0xFF764ba2)];
    } else if (category.contains('专注') || category.contains('学习')) {
      iconData = Icons.psychology;
      gradientColors = [const Color(0xFF11998e), const Color(0xFF38ef7d)];
    } else if (category.contains('放松') || category.contains('舒缓')) {
      iconData = Icons.spa;
      gradientColors = [const Color(0xFFa8edea), const Color(0xFFfed6e3)];
    } else if (category.contains('自然') || category.contains('环境')) {
      iconData = Icons.nature;
      gradientColors = [const Color(0xFF56ab2f), const Color(0xFFa8e6cf)];
    } else if (category.contains('呼吸')) {
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
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                    ),
                    child: IconButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          context.go('/');
                        }
                      },
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  Text(
                    '播放中',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surface,
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: IconButton(
                      onPressed: _showMoreOptions,
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
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
                                  _isFavorited
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: _isFavorited
                                      ? Colors.red
                                      : Colors.white,
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
                          _category,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
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
                        onSeek: (position) async {
                          await _audioPlayer.seek(
                            Duration(seconds: position.toInt()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Player Controls
                    PlayerControls(
                      isPlaying: _isPlaying,
                      onPlayPause: () async {
                        if (_isPlaying) {
                          await _audioPlayer.pause();
                        } else {
                          await _audioPlayer.play();
                        }
                      },
                      onPrevious: _playPrevious,
                      onNext: _playNext,
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
                          onTap: _toggleShuffle,
                        ),
                        SizedBox(width: 16),
                        _buildActionButton(
                          icon: _getRepeatIcon(),
                          isActive: _repeatMode != RepeatMode.none,
                          onTap: _toggleRepeatMode,
                        ),
                        SizedBox(width: 16),
                        _buildActionButton(
                          icon: Icons.timer,
                          onTap: _showTimerDialog,
                        ),
                        SizedBox(width: 16),
                        _buildActionButton(
                          icon: Icons.equalizer,
                          onTap: _showSoundEffectsDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  void _showMoreOptions() {
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
                    '更多选项',
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
                    icon: Icons.edit,
                    title: '编辑',
                    onTap: () {
                      Navigator.pop(context);
                      _editCurrentMedia();
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.share,
                    title: '分享',
                    onTap: () {
                      Navigator.pop(context);
                      _shareCurrentMedia();
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.download,
                    title: '下载',
                    onTap: () {
                      Navigator.pop(context);
                      _downloadCurrentMedia();
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.playlist_add,
                    title: '添加到播放列表',
                    onTap: () {
                      Navigator.pop(context);
                      _showAddToPlaylistDialog();
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.flag,
                    title: '举报',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Report functionality
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

  void _toggleShuffle() {
    setState(() {
      _isShuffled = !_isShuffled;
    });

    if (_isShuffled) {
      _shufflePlaylist();
    } else {
      _currentIndex = _mediaItems.indexOf(_currentMedia!);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isShuffled ? '已开启随机播放' : '已关闭随机播放')),
    );
  }

  void _shufflePlaylist() {
    _shuffledItems = List.from(_mediaItems);
    _shuffledItems.shuffle();

    // Ensure current media is at the beginning of shuffled list
    if (_currentMedia != null) {
      _shuffledItems.remove(_currentMedia!);
      _shuffledItems.insert(0, _currentMedia!);
      _currentIndex = 0;
    }
  }

  List<MediaItem> get _currentPlaylist =>
      _isShuffled ? _shuffledItems : _mediaItems;

  void _playPrevious() async {
    final playlist = _currentPlaylist;
    if (playlist.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = playlist.length - 1; // Loop to last
    }

    await _loadMediaAtIndex(_currentIndex);
  }

  void _playNext() async {
    final playlist = _currentPlaylist;
    if (playlist.isEmpty) return;

    if (_currentIndex < playlist.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0; // Loop to first
    }

    await _loadMediaAtIndex(_currentIndex);
  }

  Future<void> _loadMediaAtIndex(int index) async {
    final playlist = _currentPlaylist;
    if (index < 0 || index >= playlist.length) return;

    final media = playlist[index];
    setState(() {
      _currentMedia = media;
    });

    try {
      await _loadAudioFile(media.filePath);
      // Auto-play the new track
      if (!_isPlaying) {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('Error loading media at index $index: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载音频失败: $e')));
      }
    }
  }

  void _toggleRepeatMode() {
    setState(() {
      switch (_repeatMode) {
        case RepeatMode.none:
          _repeatMode = RepeatMode.all;
          break;
        case RepeatMode.all:
          _repeatMode = RepeatMode.one;
          break;
        case RepeatMode.one:
          _repeatMode = RepeatMode.none;
          break;
      }
    });

    // TODO: Update repeat mode in audio player
    final modeText = _getRepeatModeText();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('重复模式：$modeText')));
  }

  String _getRepeatModeText() {
    switch (_repeatMode) {
      case RepeatMode.none:
        return '关闭';
      case RepeatMode.all:
        return '全部重复';
      case RepeatMode.one:
        return '单曲重复';
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

  void _loadFavoriteStatus() {
    if (_currentMedia != null) {
      setState(() {
        _isFavorited = _currentMedia!.isFavorite;
      });
    }
  }

  void _toggleFavorite() {
    if (_currentMedia == null) return;

    final newFavoriteStatus = !_isFavorited;

    // 立即更新本地状态
    setState(() {
      _isFavorited = newFavoriteStatus;
      _currentMedia = _currentMedia!.copyWith(isFavorite: newFavoriteStatus);
    });

    // 使用MediaBloc更新收藏状态
    context.read<MediaBloc>().add(
      ToggleFavorite(_currentMedia!.id, newFavoriteStatus),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_isFavorited ? '已添加到收藏' : '已取消收藏')));
  }

  void _showAddToPlaylistDialog() {
    if (_currentMedia == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加到播放列表'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('将 "${_currentMedia!.title}" 添加到：'),
            const SizedBox(height: 16),

            // Mock playlist options
            _buildPlaylistOption('我的收藏', Icons.favorite, () {
              Navigator.pop(context);
              _addToPlaylist('我的收藏');
            }),
            _buildPlaylistOption('正念练习', Icons.spa, () {
              Navigator.pop(context);
              _addToPlaylist('正念练习');
            }),
            _buildPlaylistOption('睡眠专辑', Icons.bedtime, () {
              Navigator.pop(context);
              _addToPlaylist('睡眠专辑');
            }),

            const Divider(),

            // Create new playlist option
            _buildPlaylistOption('创建新播放列表', Icons.add, () {
              Navigator.pop(context);
              _showCreatePlaylistDialog();
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistOption(String name, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(name),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _addToPlaylist(String playlistName) {
    if (_currentMedia == null) return;

    // TODO: Implement actual playlist functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加 "${_currentMedia!.title}" 到 "$playlistName"'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    String playlistName = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建播放列表'),
        content: TextField(
          onChanged: (value) => playlistName = value,
          decoration: const InputDecoration(
            labelText: '播放列表名称',
            hintText: '请输入播放列表名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (playlistName.isNotEmpty) {
                Navigator.pop(context);
                _addToPlaylist(playlistName);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _downloadCurrentMedia() {
    if (_currentMedia == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下载'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('是否下载 "${_currentMedia!.title}" 到本地？'),
            const SizedBox(height: 16),
            const Text(
              '注意：此功能需要网络连接，并且会消耗存储空间。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startDownload();
            },
            child: const Text('开始下载'),
          ),
        ],
      ),
    );
  }

  void _startDownload() {
    if (_currentMedia == null) return;

    // TODO: Implement actual download functionality
    // This would typically involve downloading the file to local storage
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在下载 "${_currentMedia!.title}"...'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Simulate download completion
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载完成：${_currentMedia!.title}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _shareCurrentMedia() {
    if (_currentMedia == null) return;

    final shareText =
        '''
正在收听：${_currentMedia!.title}
类别：${_currentMedia!.category}
${_currentMedia!.description?.isNotEmpty == true ? '描述：${_currentMedia!.description}' : ''}

来自 Mindra 冥想应用
''';

    // For Flutter web and mobile platforms, you would typically use the share_plus package
    // For now, we'll copy to clipboard and show a message
    _copyToClipboard(shareText);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('分享'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('分享内容已复制到剪贴板'),
            const SizedBox(height: 16),
            Text(shareText, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
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

  void _editCurrentMedia() {
    if (_currentMedia == null) return;

    AddMediaDialog.showEdit(context, _currentMedia!).then((_) {
      // 重新加载媒体数据以获取更新后的信息
      _loadMediaData();
    });
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();

    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      if (_isPlaying) {
        await _audioPlayer.pause();
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('定时停止已触发')));
      }
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已设置 $minutes 分钟定时停止')));
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已取消定时停止')));
  }

  void _showTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('定时设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int minutes in [5, 10, 15, 30, 45, 60])
              ListTile(
                title: Text('$minutes 分钟后'),
                onTap: () {
                  Navigator.pop(context);
                  _setSleepTimer(minutes);
                },
              ),
            const Divider(),
            ListTile(
              title: const Text('取消定时'),
              onTap: () {
                Navigator.pop(context);
                _cancelSleepTimer();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showSoundEffectsDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A3441) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and close button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : theme.colorScheme.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '音效设置',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: isDark
                            ? const Color(0xFF32B8C6)
                            : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
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
              // Content
              Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(
                  maxHeight: 400, // 限制最大高度
                ),
                child: const SingleChildScrollView(child: SoundEffectsPanel()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
