import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../widgets/player_controls.dart';
import '../widgets/progress_bar.dart';
import '../widgets/sound_effects_panel.dart';
import '../../../../features/media/data/datasources/media_local_datasource.dart';
import '../../../../features/media/domain/entities/media_item.dart';
import '../../../../core/audio/cross_platform_audio_player.dart';

class PlayerPage extends StatefulWidget {
  final String? mediaId;

  const PlayerPage({super.key, this.mediaId});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late CrossPlatformAudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _showSoundEffects = false;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;

  // Subscription management
  late StreamSubscription _playingSubscription;
  late StreamSubscription _positionSubscription;
  late StreamSubscription _durationSubscription;

  // Media data
  MediaItem? _currentMedia;
  final MediaLocalDataSource _mediaDataSource = MediaLocalDataSource();

  // Mock data - TODO: Replace with actual media data
  String get _title => _currentMedia?.title ?? '加载中...';
  String get _category => _currentMedia?.category ?? '未知';
  String get _description => _currentMedia?.description ?? '正在加载媒体信息...';

  @override
  void initState() {
    super.initState();
    _audioPlayer = CrossPlatformAudioPlayer();
    _setupAudioPlayer();
    _loadMediaData();
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
        final mediaItems = await _mediaDataSource.getMediaItems();
        final media = mediaItems.firstWhere(
          (item) => item.id == widget.mediaId,
        );
        setState(() {
          _currentMedia = media;
        });

        // Load audio file
        await _loadAudioFile(media.filePath);
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
    _audioPlayer.dispose();
    super.dispose();
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
                    const SizedBox(height: 40),

                    // Album Art
                    Container(
                      width: 300,
                      height: 300,
                      margin: const EdgeInsets.symmetric(vertical: 32),
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
                            child: Image.network(
                              'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=400&fit=crop',
                              width: 300,
                              height: 300,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 300,
                                  height: 300,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.secondary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.music_note,
                                    size: 80,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
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
                                onPressed: () {
                                  // TODO: Toggle favorite
                                },
                                icon: const Icon(
                                  Icons.favorite_border,
                                  color: Colors.white,
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
                    const SizedBox(height: 48),

                    // Progress Bar
                    ProgressBar(
                      currentPosition: _currentPosition,
                      totalDuration: _totalDuration,
                      onSeek: (position) async {
                        await _audioPlayer.seek(
                          Duration(seconds: position.toInt()),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

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
                      onPrevious: () {
                        // TODO: Previous track
                      },
                      onNext: () {
                        // TODO: Next track
                      },
                      onShuffle: () {
                        // TODO: Toggle shuffle
                      },
                      onRepeat: () {
                        // TODO: Toggle repeat
                      },
                    ),
                    const SizedBox(height: 48),

                    // Bottom Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildActionButton(
                          icon: Icons.repeat,
                          onTap: () {
                            // TODO: Toggle repeat
                          },
                        ),
                        SizedBox(width: 16),
                        _buildActionButton(
                          icon: Icons.timer,
                          onTap: _showTimerDialog,
                        ),
                        SizedBox(width: 16),
                        _buildActionButton(
                          icon: Icons.equalizer,
                          onTap: () {
                            setState(() {
                              _showSoundEffects = !_showSoundEffects;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Sound Effects Panel
                    if (_showSoundEffects) const SoundEffectsPanel(),

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
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: IconButton(
        iconSize: 16,
        onPressed: onTap,
        icon: Icon(
          icon,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                    icon: Icons.share,
                    title: '分享',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Share functionality
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.download,
                    title: '下载',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Download functionality
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.playlist_add,
                    title: '添加到播放列表',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Add to playlist functionality
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('已设置 $minutes 分钟定时')));
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
}
