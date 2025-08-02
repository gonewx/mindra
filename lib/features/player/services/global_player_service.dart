import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../core/audio/audio_player.dart';
import '../../../features/media/domain/entities/media_item.dart';
import '../../../features/meditation/data/services/meditation_session_manager.dart';
import '../../../features/meditation/data/services/enhanced_meditation_session_manager.dart';
import '../../media/data/datasources/media_local_datasource.dart';
import '../../media/domain/usecases/media_usecases.dart';
import '../../../core/di/injection_container.dart';
import '../presentation/widgets/player_controls.dart';
import 'sound_effects_player.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/web_storage_helper.dart';

class GlobalPlayerService extends ChangeNotifier {
  late final MindraAudioPlayer _audioPlayer;
  final SoundEffectsPlayer _soundEffectsPlayer = SoundEffectsPlayer();
  final MediaLocalDataSource _mediaDataSource = MediaLocalDataSource();

  // Subscription management
  StreamSubscription? _playingSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _bufferProgressSubscription;

  // Playback state
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;
  bool _isInitialized = false;
  bool _isInitializing = false;
  Completer<void>? _initializationCompleter;

  // New state properties
  MindraPlayerState _playerState = MindraPlayerState.stopped;
  double _bufferProgress = 0.0;
  bool _isLoading = false;

  // Media state
  MediaItem? _currentMedia;
  List<MediaItem> _mediaItems = [];
  List<MediaItem> _shuffledItems = [];
  int _currentIndex = 0;

  // Player controls state
  bool _isFavorited = false;
  bool _isShuffled = false;
  RepeatMode _repeatMode = RepeatMode.none;
  Timer? _sleepTimer;
  int _sleepTimerMinutes = 0;

  // 添加保存上次播放媒体的常量
  static const String _lastPlayedMediaIdKey = 'last_played_media_id';
  static const String _lastPlayedPositionKey = 'last_played_position';

  // Getters
  bool get isPlaying => _isPlaying;
  double get currentPosition => _currentPosition;
  double get totalDuration => _totalDuration;
  MediaItem? get currentMedia => _currentMedia;
  bool get isFavorited => _isFavorited;
  bool get isShuffled => _isShuffled;
  RepeatMode get repeatMode => _repeatMode;
  bool get hasActiveTimer => _sleepTimer != null;
  int get sleepTimerMinutes => _sleepTimerMinutes;
  bool get isInitialized => _isInitialized;

  // New getters for enhanced state
  MindraPlayerState get playerState => _playerState;
  double get bufferProgress => _bufferProgress;
  bool get isLoading => _isLoading;
  bool get isNetworkSource => _audioPlayer.isNetworkSource;

  String get title => _currentMedia?.title ?? '未选择素材';
  String get category => _currentMedia?.category.name ?? '';

  /// 检查是否已加载指定的媒体
  bool isMediaLoaded(String mediaId) {
    return _currentMedia?.id == mediaId;
  }

  /// 获取当前媒体的详细状态
  Map<String, dynamic> getCurrentMediaStatus() {
    return {
      'mediaId': _currentMedia?.id,
      'title': _currentMedia?.title,
      'isPlaying': _isPlaying,
      'currentPosition': _currentPosition,
      'totalDuration': _totalDuration,
      'playerState': _playerState.name,
      'isLoading': _isLoading,
    };
  }

  /// 为播放页面准备媒体，优化的加载策略
  Future<void> prepareMediaForPlayer(
    String? mediaId, {
    bool autoPlay = false,
  }) async {
    if (mediaId == null) {
      debugPrint(
        'PrepareMediaForPlayer: No mediaId provided, using current media',
      );
      return;
    }

    // 检查是否是相同的媒体
    if (isMediaLoaded(mediaId)) {
      final status = getCurrentMediaStatus();
      debugPrint(
        'PrepareMediaForPlayer: Same media already loaded and ready. '
        'Status: $status',
      );

      // 相同媒体，不重新加载，只处理播放逻辑
      if (autoPlay &&
          !_isPlaying &&
          _playerState != MindraPlayerState.loading) {
        await play();
      }
      return;
    }

    // 不同媒体，需要加载
    debugPrint('PrepareMediaForPlayer: Loading new media: $mediaId');
    await loadMedia(mediaId, autoPlay: autoPlay);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (_isInitializing && _initializationCompleter != null) {
      return _initializationCompleter!.future;
    }

    _isInitializing = true;
    _initializationCompleter = Completer<void>();

    try {
      debugPrint('Starting GlobalPlayerService initialization...');

      // 初始化音频播放器
      await _initializeAudioPlayerWithRetry();

      // 设置音频播放器监听器
      await _setupAudioPlayer();

      // 初始化音效播放器
      await _initializeSoundEffectsPlayer();

      // 恢复上次播放的媒体
      await _restoreLastPlayedMedia();

      _isInitialized = true;
      _initializationCompleter!.complete();
      debugPrint('GlobalPlayerService initialized successfully');
    } catch (e) {
      _initializationCompleter!.completeError(e);
      debugPrint('Failed to initialize GlobalPlayerService: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _initializeAudioPlayerWithRetry() async {
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 200);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
          'Initializing audio player (attempt $attempt/$maxRetries)...',
        );
        _audioPlayer = MindraAudioPlayer();
        await Future.delayed(const Duration(milliseconds: 100));
        debugPrint('Audio player initialized successfully on attempt $attempt');
        return;
      } catch (e) {
        debugPrint('Audio player initialization attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          throw Exception(
            'Failed to initialize audio player after $maxRetries attempts: $e',
          );
        }

        await Future.delayed(retryDelay);
      }
    }
  }

  Future<void> _initializeSoundEffectsPlayer() async {
    try {
      debugPrint('Initializing sound effects player...');
      await _soundEffectsPlayer.initialize();

      _soundEffectsPlayer.setStateChangeCallback(() {
        notifyListeners();
      });

      debugPrint('Sound effects player initialized successfully');
    } catch (e) {
      debugPrint('Warning: Sound effects player initialization failed: $e');
    }
  }

  Future<void> _setupAudioPlayer() async {
    // Listen to playing state changes
    _playingSubscription = _audioPlayer.playingStream.listen((isPlaying) {
      _isPlaying = isPlaying;
      notifyListeners();
      _handlePlayingStateChange(isPlaying);
    });

    // Listen to position changes with enhanced progress tracking
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      final newPosition = position.inSeconds.toDouble();
      final positionDiff = (newPosition - _currentPosition).abs();

      _currentPosition = newPosition;
      notifyListeners();

      // 更新会话进度，让两个管理器都处理实时更新
      MeditationSessionManager.updateSessionProgress(position.inSeconds);
      EnhancedMeditationSessionManager.updateSessionProgress(
        position.inSeconds,
      );

      // 减少保存频率：只在位置变化较大时保存
      if (positionDiff > 10.0) {
        _saveLastPlayedPosition();
      }
    });

    // Listen to duration changes
    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _totalDuration = duration.inSeconds.toDouble();
        notifyListeners();

        // 检查并更新媒体项的时长数据
        _checkAndUpdateMediaDuration(duration.inSeconds);
      }
    });

    // Listen to player state changes with enhanced handling
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      _playerState = state;
      _isLoading =
          (state == MindraPlayerState.loading ||
          state == MindraPlayerState.buffering);
      notifyListeners();
      _handlePlayerStateChange(state);
    });

    // Listen to buffer progress changes
    _bufferProgressSubscription = _audioPlayer.bufferProgressStream.listen((
      progress,
    ) {
      _bufferProgress = progress;
      notifyListeners();
    });
  }

  void _handlePlayingStateChange(bool isPlaying) {
    if (isPlaying) {
      // 优先使用增强版会话管理器
      if (!EnhancedMeditationSessionManager.hasActiveSession &&
          !MeditationSessionManager.hasActiveSession &&
          _currentMedia != null) {
        _startMeditationSession();
      } else if (EnhancedMeditationSessionManager.hasActiveSession) {
        EnhancedMeditationSessionManager.resumeSession();
      } else if (MeditationSessionManager.hasActiveSession) {
        MeditationSessionManager.resumeSession();
      }
    } else {
      // 暂停时同时处理两个管理器
      if (EnhancedMeditationSessionManager.hasActiveSession) {
        EnhancedMeditationSessionManager.pauseSession();
      }
      if (MeditationSessionManager.hasActiveSession) {
        MeditationSessionManager.pauseSession();
      }
    }
  }

  void _handlePlayerStateChange(MindraPlayerState state) {
    switch (state) {
      case MindraPlayerState.completed:
        // 检查是否需要循环播放
        if (_repeatMode == RepeatMode.one) {
          // 单曲循环：不结束会话，直接重新开始
          debugPrint(
            'Single repeat mode: preparing to restart without ending session',
          );
          _handleTrackCompletion();
        } else {
          // 非循环模式：正常结束会话
          _completeMeditationSession();
          _clearLastPlayedRecord();
          _handleTrackCompletion();
        }
        break;
      case MindraPlayerState.playing:
        if (EnhancedMeditationSessionManager.hasActiveSession) {
          EnhancedMeditationSessionManager.resumeSession();
        }
        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.resumeSession();
        }
        break;
      case MindraPlayerState.paused:
      case MindraPlayerState.stopped:
        if (EnhancedMeditationSessionManager.hasActiveSession) {
          EnhancedMeditationSessionManager.pauseSession();
        }
        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.pauseSession();
        }
        break;
      default:
        break;
    }
  }

  void _handleTrackCompletion() {
    switch (_repeatMode) {
      case RepeatMode.one:
        // 单曲循环：异步重新开始播放
        _restartCurrentTrack();
        break;
      case RepeatMode.all:
        playNext();
        break;
      case RepeatMode.none:
        break;
    }
  }

  /// 重新开始播放当前曲目（用于单曲循环）
  Future<void> _restartCurrentTrack() async {
    if (_currentMedia == null) {
      debugPrint('Cannot restart: no current media');
      return;
    }

    try {
      debugPrint(
        'Restarting current track for repeat mode: ${_currentMedia!.title}',
      );
      debugPrint(
        'Current player state before restart: ${_audioPlayer.currentState}',
      );

      // 最可靠的方法：重新加载音频文件
      debugPrint('Reloading audio file for guaranteed restart');

      // 先停止当前播放
      await _audioPlayer.stop();
      debugPrint('Stopped current playback');

      // 等待停止完成
      await Future.delayed(const Duration(milliseconds: 200));

      // 重新加载音频文件
      await _loadAudioFile(_currentMedia!.filePath);
      debugPrint('Audio file reloaded successfully');

      // 等待加载完成
      await Future.delayed(const Duration(milliseconds: 200));

      // 开始播放
      await _audioPlayer.play();
      debugPrint('Play command sent after reload');

      // 等待一下检查播放状态
      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint(
        'Player state after reload and restart: ${_audioPlayer.currentState}',
      );

      if (_audioPlayer.currentState == MindraPlayerState.playing) {
        debugPrint('Track restarted successfully (file reload method)');
      } else {
        debugPrint('Warning: Player still not playing after file reload');
      }
    } catch (e) {
      debugPrint('Error restarting track with file reload: $e');

      // 最后的尝试：等待更长时间再重试
      try {
        debugPrint('Final retry with longer delays');
        await Future.delayed(const Duration(milliseconds: 500));

        if (_currentMedia!.filePath.startsWith('http')) {
          await _audioPlayer.setUrl(_currentMedia!.filePath);
        } else {
          await _audioPlayer.setFilePath(_currentMedia!.filePath);
        }

        await Future.delayed(const Duration(milliseconds: 300));
        await _audioPlayer.play();

        debugPrint('Final retry completed');
      } catch (finalError) {
        debugPrint('All restart attempts failed: $finalError');
        notifyListeners();
      }
    }
  }

  Future<void> _startMeditationSession() async {
    if (_currentMedia == null) return;

    try {
      final sessionType =
          EnhancedMeditationSessionManager.getSessionTypeFromCategory(
            _currentMedia!.category.name,
          );

      List<String> soundEffects = [];
      try {
        soundEffects = _soundEffectsPlayer.currentVolumes.entries
            .where((entry) => entry.value > 0.0)
            .map((entry) => entry.key)
            .toList();
      } catch (e) {
        debugPrint('Error getting active sound effects: $e');
        soundEffects = [];
      }

      // 优先使用增强版会话管理器
      try {
        await EnhancedMeditationSessionManager.startSession(
          mediaItem: _currentMedia!,
          sessionType: sessionType,
          soundEffects: soundEffects,
        );
        debugPrint(
          'Started enhanced meditation session for: ${_currentMedia!.title}',
        );
      } catch (e) {
        debugPrint(
          'Enhanced session manager failed, falling back to traditional: $e',
        );

        // 回退到传统会话管理器
        await MeditationSessionManager.startSession(
          mediaItem: _currentMedia!,
          sessionType: sessionType,
          soundEffects: soundEffects,
        );
        debugPrint(
          'Started traditional meditation session for: ${_currentMedia!.title}',
        );
      }
    } catch (e) {
      debugPrint('Error starting meditation session: $e');
    }
  }

  Future<void> _completeMeditationSession() async {
    try {
      // 优先完成增强版会话管理器的会话
      if (EnhancedMeditationSessionManager.hasActiveSession) {
        await EnhancedMeditationSessionManager.completeSession();
        debugPrint('Completed enhanced meditation session');
      }

      // 如果还有传统管理器的会话，也完成它
      if (MeditationSessionManager.hasActiveSession) {
        await MeditationSessionManager.completeSession();
        debugPrint('Completed traditional meditation session');
      }
    } catch (e) {
      debugPrint('Error completing meditation session: $e');
    }
  }

  Future<void> _restoreLastPlayedMedia() async {
    try {
      String? lastPlayedMediaId;

      if (kIsWeb) {
        lastPlayedMediaId = await WebStorageHelper.getPreference(
          _lastPlayedMediaIdKey,
        );
      } else {
        lastPlayedMediaId = await DatabaseHelper.getPreference(
          _lastPlayedMediaIdKey,
        );
      }

      if (lastPlayedMediaId != null && lastPlayedMediaId.isNotEmpty) {
        debugPrint('Restoring last played media: $lastPlayedMediaId');
        await _loadMediaById(lastPlayedMediaId, autoPlay: false);
        // 只在应用启动时恢复播放位置，播放过程中不恢复
        await _restoreLastPlayedPosition();
        debugPrint('Successfully restored last played media');
      } else {
        debugPrint('No last played media found');
      }
    } catch (e) {
      debugPrint('Error restoring last played media: $e');
    }
  }

  Future<void> _loadMediaById(String mediaId, {bool autoPlay = false}) async {
    try {
      _mediaItems = await _mediaDataSource.getMediaItems();
      _currentIndex = _mediaItems.indexWhere((item) => item.id == mediaId);

      if (_currentIndex >= 0) {
        final media = _mediaItems[_currentIndex];

        _currentMedia = media;
        _isFavorited = media.isFavorite;

        // 通矵UI更新媒体信息（标题、封面等）
        notifyListeners();

        // 只有在真正需要加载不同文件时才加载音频
        await _loadAudioFile(media.filePath);
        await _saveLastPlayedMedia();

        if (autoPlay) {
          await play();
        }

        debugPrint(
          'Media loaded: ${media.title} (ID: ${media.id}), '
          'AutoPlay: $autoPlay',
        );
      } else {
        throw Exception('Media with ID $mediaId not found');
      }
    } catch (e) {
      debugPrint('Error loading media: $e');
      rethrow;
    }
  }

  Future<void> _restoreLastPlayedPosition() async {
    try {
      String? positionString;

      if (kIsWeb) {
        positionString = await WebStorageHelper.getPreference(
          _lastPlayedPositionKey,
        );
      } else {
        positionString = await DatabaseHelper.getPreference(
          _lastPlayedPositionKey,
        );
      }

      if (positionString != null && positionString.isNotEmpty) {
        final position = double.tryParse(positionString) ?? 0.0;
        if (position > 0) {
          await _audioPlayer.seek(
            Duration(seconds: position.toInt()),
          ); // 恢复位置，不显示缓冲
          debugPrint('Restored playback position: ${position}s');
        }
      }
    } catch (e) {
      debugPrint('Error restoring playback position: $e');
    }
  }

  Future<void> _saveLastPlayedMedia() async {
    if (_currentMedia == null) return;

    try {
      if (kIsWeb) {
        await WebStorageHelper.setPreference(
          _lastPlayedMediaIdKey,
          _currentMedia!.id,
        );
      } else {
        await DatabaseHelper.setPreference(
          _lastPlayedMediaIdKey,
          _currentMedia!.id,
        );
      }
      debugPrint('Saved last played media: ${_currentMedia!.id}');
    } catch (e) {
      debugPrint('Error saving last played media: $e');
    }
  }

  Future<void> _saveLastPlayedPosition() async {
    try {
      final positionString = _currentPosition.toString();
      if (kIsWeb) {
        await WebStorageHelper.setPreference(
          _lastPlayedPositionKey,
          positionString,
        );
      } else {
        await DatabaseHelper.setPreference(
          _lastPlayedPositionKey,
          positionString,
        );
      }
    } catch (e) {
      debugPrint('Error saving last played position: $e');
    }
  }

  Future<void> _clearLastPlayedRecord() async {
    try {
      if (kIsWeb) {
        await WebStorageHelper.setPreference(_lastPlayedPositionKey, '0');
      } else {
        await DatabaseHelper.setPreference(_lastPlayedPositionKey, '0');
      }
      debugPrint('Cleared last played position');
    } catch (e) {
      debugPrint('Error clearing last played record: $e');
    }
  }

  Future<void> loadMedia(String mediaId, {bool autoPlay = true}) async {
    // 检查是否是相同的素材
    final isSameMedia = _currentMedia?.id == mediaId;

    if (isSameMedia) {
      debugPrint(
        '加载相同素材，保持当前状态: ${_currentMedia!.title} at ${_currentPosition}s',
      );

      // 对于相同素材，只需要处理autoPlay逻辑，不重新加载
      if (autoPlay && !_isPlaying) {
        await play();
      }

      // 确保UI状态正确
      notifyListeners();
      return;
    }

    // 不同素材，需要切换
    debugPrint('切换到不同音频: $mediaId');

    // 先加载媒体信息，准备切换
    await _loadMediaById(mediaId, autoPlay: false);

    // 使用增强版会话管理器智能切换媒体
    // 这将保存当前进度并继续累计到当天的统计中
    if (_currentMedia != null) {
      try {
        final sessionType =
            EnhancedMeditationSessionManager.getSessionTypeFromCategory(
              _currentMedia!.category.name,
            );

        List<String> soundEffects = [];
        try {
          soundEffects = _soundEffectsPlayer.currentVolumes.entries
              .where((entry) => entry.value > 0.0)
              .map((entry) => entry.key)
              .toList();
        } catch (e) {
          debugPrint('Error getting active sound effects: $e');
          soundEffects = [];
        }

        await EnhancedMeditationSessionManager.switchToMedia(
          newMediaItem: _currentMedia!,
          sessionType: sessionType,
          soundEffects: soundEffects,
        );

        debugPrint(
          'Successfully switched to new media with enhanced session manager',
        );
      } catch (e) {
        debugPrint('Error switching media with enhanced session manager: $e');
        // 回退到传统方式
        if (MeditationSessionManager.hasActiveSession) {
          await MeditationSessionManager.stopSession();
        }
      }
    }

    if (autoPlay) {
      await play();
    }
  }

  Future<void> _loadAudioFile(String filePath) async {
    try {
      // 先停止当前音频播放，确保播放状态正确重置
      try {
        await _audioPlayer.stop();
        debugPrint('Stopped current audio before loading new file');
      } catch (e) {
        debugPrint('Could not stop current audio: $e');
        // 继续执行，不阻塞新音频的加载
      }

      final isNetworkUrl =
          filePath.startsWith('http://') || filePath.startsWith('https://');

      if (kIsWeb && filePath.startsWith('web://')) {
        if (_currentMedia != null) {
          final mimeType = _getMimeType(_currentMedia!.filePath);
          final blobUrl = _mediaDataSource.createAudioBlobUrl(
            _currentMedia!.id,
            mimeType,
          );

          if (blobUrl != null) {
            await _audioPlayer.setUrl(blobUrl);
            debugPrint('Web audio loaded from blob URL successfully');
          } else {
            throw Exception('Failed to create blob URL for media');
          }
        }
      } else if (isNetworkUrl) {
        // 对于网络音频，立即设置加载状态
        debugPrint('Loading network audio: $filePath');
        await _audioPlayer.setUrl(filePath);
        debugPrint('Network audio loaded: $filePath');

        // 网络音频可能需要更长时间来获取完整信息
        // 让音频播放器的 durationStream 来处理时长更新
      } else {
        await _audioPlayer.setFilePath(filePath);
        debugPrint('Local audio file loaded: $filePath');
      }

      // 主动获取音频时长
      try {
        // 对于网络音频，给更多时间来加载
        final delayMs = isNetworkUrl ? 500 : 100;
        await Future.delayed(Duration(milliseconds: delayMs));

        final duration = await _audioPlayer.getDuration();
        if (duration != null) {
          _totalDuration = duration.inSeconds.toDouble();
          debugPrint('Updated duration: ${_totalDuration}s');
          notifyListeners();
          debugPrint('Audio duration loaded: ${_totalDuration}s');

          // 检查并更新媒体项的时长数据
          await _checkAndUpdateMediaDuration(duration.inSeconds);
        } else if (isNetworkUrl) {
          // 对于网络音频，如果无法立即获取时长，设置为未知状态
          debugPrint(
            'Network audio duration not available yet, will be updated via stream',
          );
        }

        // 根据是否是新音频决定是否重置位置
        final shouldResetPosition = _currentMedia?.filePath != filePath;
        if (shouldResetPosition) {
          await _audioPlayer.seek(Duration.zero);
          _currentPosition = 0.0;
          debugPrint('Reset position to 0 for new audio file');
        } else {
          debugPrint(
            'Keeping existing position: ${_currentPosition}s for same file',
          );
        }

        debugPrint(
          'Updated position and duration: ${_currentPosition}s / ${_totalDuration}s',
        );
        notifyListeners();
      } catch (e) {
        debugPrint('Could not get audio duration immediately: $e');
        // 不抛出异常，让durationStream处理
      }
    } catch (e) {
      debugPrint('Error loading audio file: $e');
      rethrow;
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
        return 'audio/mpeg';
    }
  }

  Future<void> play() async {
    await _audioPlayer.play();

    if (_currentMedia != null) {
      try {
        await _mediaDataSource.updatePlayCount(_currentMedia!.id);
        debugPrint('Updated play count for: ${_currentMedia!.title}');
      } catch (e) {
        debugPrint('Error updating play count: $e');
      }
    }

    await _restoreSoundEffects();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    await _saveLastPlayedPosition();
    await _pauseSoundEffects();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    await _saveLastPlayedPosition();
    await _pauseSoundEffects();

    // 停止所有活跃的会话
    if (EnhancedMeditationSessionManager.hasActiveSession) {
      await EnhancedMeditationSessionManager.stopSession();
    }
    if (MeditationSessionManager.hasActiveSession) {
      await MeditationSessionManager.stopSession();
    }
  }

  Future<void> _restoreSoundEffects() async {
    try {
      // 音效播放器现在会自动根据主音频状态恢复播放
      // 不需要手动恢复每个音效
      debugPrint('Sound effects will auto-resume based on main audio state');
    } catch (e) {
      debugPrint('Error restoring sound effects: $e');
    }
  }

  Future<void> _pauseSoundEffects() async {
    try {
      // 音效播放器现在会自动根据主音频状态暂停播放
      // 不需要手动暂停每个音效
      debugPrint('Sound effects will auto-pause based on main audio state');
    } catch (e) {
      debugPrint('Error pausing sound effects: $e');
    }
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position, showBuffering: true); // 用户拖拽显示缓冲
    _currentPosition = position.inSeconds.toDouble();
    await _saveLastPlayedPosition();
  }

  Future<void> playNext() async {
    final playlist = _currentPlaylist;
    if (playlist.isEmpty) return;

    // 保存之前的播放状态
    final wasPlaying = _isPlaying;

    if (_currentIndex < playlist.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }

    // 使用增强版会话管理器切换媒体，避免数据丢失
    await _switchToMediaAtIndex(_currentIndex, shouldAutoPlay: wasPlaying);
  }

  Future<void> playPrevious() async {
    final playlist = _currentPlaylist;
    if (playlist.isEmpty) return;

    // 保存之前的播放状态
    final wasPlaying = _isPlaying;

    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = playlist.length - 1;
    }

    // 使用增强版会话管理器切换媒体，避免数据丢失
    await _switchToMediaAtIndex(_currentIndex, shouldAutoPlay: wasPlaying);
  }

  /// 使用增强版会话管理器切换到指定索引的媒体
  Future<void> _switchToMediaAtIndex(
    int index, {
    bool shouldAutoPlay = false,
  }) async {
    final playlist = _currentPlaylist;
    if (index < 0 || index >= playlist.length) return;

    final media = playlist[index];

    debugPrint('Switching to media at index $index: ${media.title}');

    try {
      // 使用增强版会话管理器智能切换媒体
      // 这将保存当前进度并继续累计到当天的统计中
      final sessionType =
          EnhancedMeditationSessionManager.getSessionTypeFromCategory(
            media.category.name,
          );

      List<String> soundEffects = [];
      try {
        soundEffects = _soundEffectsPlayer.currentVolumes.entries
            .where((entry) => entry.value > 0.0)
            .map((entry) => entry.key)
            .toList();
      } catch (e) {
        debugPrint('Error getting active sound effects: $e');
        soundEffects = [];
      }

      // 先更新UI显示的媒体信息
      _currentMedia = media;
      _isFavorited = media.isFavorite;
      notifyListeners();

      // 加载音频文件
      await _loadAudioFile(media.filePath);
      await _saveLastPlayedMedia();

      // 使用增强版会话管理器切换
      await EnhancedMeditationSessionManager.switchToMedia(
        newMediaItem: media,
        sessionType: sessionType,
        soundEffects: soundEffects,
      );

      debugPrint(
        'Successfully switched to new media with enhanced session manager',
      );

      if (shouldAutoPlay) {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint(
        'Error switching to media at index $index with enhanced session: $e',
      );

      // 回退到传统方式，但仍然避免会话数据丢失
      try {
        await _loadMediaAtIndexFallback(index, shouldAutoPlay: shouldAutoPlay);
      } catch (fallbackError) {
        debugPrint('Fallback also failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// 回退方案：传统的媒体切换方式（保留原有逻辑）
  Future<void> _loadMediaAtIndexFallback(
    int index, {
    bool shouldAutoPlay = false,
  }) async {
    final playlist = _currentPlaylist;
    if (index < 0 || index >= playlist.length) return;

    final media = playlist[index];
    _currentMedia = media;
    _isFavorited = media.isFavorite;

    // 通知UI更新媒体信息（标题、封面等）
    notifyListeners();

    try {
      await _loadAudioFile(media.filePath);
      await _saveLastPlayedMedia();

      if (shouldAutoPlay) {
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint('Error in fallback loading media at index $index: $e');
      rethrow;
    }
  }

  List<MediaItem> get _currentPlaylist =>
      _isShuffled ? _shuffledItems : _mediaItems;

  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    notifyListeners();

    if (_isShuffled) {
      _shufflePlaylist();
    } else {
      _currentIndex = _mediaItems.indexOf(_currentMedia!);
    }
  }

  void _shufflePlaylist() {
    _shuffledItems = List.from(_mediaItems);
    _shuffledItems.shuffle();

    if (_currentMedia != null) {
      _shuffledItems.remove(_currentMedia!);
      _shuffledItems.insert(0, _currentMedia!);
      _currentIndex = 0;
    }
  }

  void toggleRepeatMode() {
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
    notifyListeners();
  }

  String getRepeatModeText() {
    switch (_repeatMode) {
      case RepeatMode.none:
        return '关闭';
      case RepeatMode.all:
        return '全部重复';
      case RepeatMode.one:
        return '单曲重复';
    }
  }

  Future<void> toggleFavorite() async {
    if (_currentMedia == null) return;

    _isFavorited = !_isFavorited;
    _currentMedia = _currentMedia!.copyWith(isFavorite: _isFavorited);
    notifyListeners();
  }

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimerMinutes = minutes;

    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      if (_isPlaying) {
        await pause();
      }
      _sleepTimerMinutes = 0;
      notifyListeners();
    });

    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerMinutes = 0;
    notifyListeners();
  }

  SoundEffectsPlayer get soundEffectsPlayer => _soundEffectsPlayer;

  bool get hasActiveSoundEffects {
    return _soundEffectsPlayer.hasActiveEffects();
  }

  Future<void> pauseForBackground() async {
    // 保存当前会话状态到数据库，防止数据丢失
    try {
      await EnhancedMeditationSessionManager.forceSaveCurrentState();
      await MeditationSessionManager.forceSaveCurrentState();
      await _saveLastPlayedPosition();
      debugPrint('Saved player state before going to background');
    } catch (e) {
      debugPrint('Error saving state before background: $e');
    }
  }

  Future<void> resumeFromBackground() async {
    // 从后台返回时验证并恢复状态
    try {
      // 验证当前会话是否仍然有效
      if (EnhancedMeditationSessionManager.hasActiveSession) {
        debugPrint('Resumed from background with active enhanced session');
      } else if (MeditationSessionManager.hasActiveSession) {
        debugPrint('Resumed from background with active traditional session');
      }
    } catch (e) {
      debugPrint('Error resuming from background: $e');
    }
  }

  /// 处理应用即将终止的情况
  Future<void> prepareForTermination() async {
    try {
      // 强制保存所有状态
      await EnhancedMeditationSessionManager.forceSaveCurrentState();
      await MeditationSessionManager.forceSaveCurrentState();
      await _saveLastPlayedPosition();

      // 如果有活跃会话，标记为停止（而不是完成）
      if (EnhancedMeditationSessionManager.hasActiveSession) {
        await EnhancedMeditationSessionManager.stopSession();
      }
      if (MeditationSessionManager.hasActiveSession) {
        await MeditationSessionManager.stopSession();
      }

      debugPrint('Prepared for app termination');
    } catch (e) {
      debugPrint('Error preparing for termination: $e');
    }
  }

  @override
  void dispose() {
    _disposeInternal();
    super.dispose();
  }

  Future<void> _disposeInternal() async {
    _sleepTimer?.cancel();
    await _playingSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _bufferProgressSubscription?.cancel();

    // 在dispose前保存状态
    try {
      await EnhancedMeditationSessionManager.forceSaveCurrentState();
      await MeditationSessionManager.forceSaveCurrentState();
      await _saveLastPlayedPosition();
    } catch (e) {
      debugPrint('Error saving state during dispose: $e');
    }

    // 停止所有活跃会话
    if (EnhancedMeditationSessionManager.hasActiveSession) {
      await EnhancedMeditationSessionManager.stopSession();
    }
    if (MeditationSessionManager.hasActiveSession) {
      await MeditationSessionManager.stopSession();
    }

    await _audioPlayer.dispose();
    await _soundEffectsPlayer.dispose();
    _isInitialized = false;
  }

  Future<void> shutdown() async {
    await _disposeInternal();
  }

  /// 检查并更新媒体项的时长数据
  /// 如果当前媒体项的时长为0或无效，则更新数据库中的时长数据
  Future<void> _checkAndUpdateMediaDuration(int actualDurationSeconds) async {
    if (_currentMedia == null) return;

    // 只有当存储的时长为0或明显错误时才更新
    if (_currentMedia!.duration <= 0 ||
        (_currentMedia!.duration > 0 &&
            (actualDurationSeconds - _currentMedia!.duration).abs() > 5)) {
      try {
        debugPrint(
          'Updating media duration: ${_currentMedia!.title} '
          'from ${_currentMedia!.duration}s to ${actualDurationSeconds}s',
        );

        // 更新数据库中的时长
        final updateDurationUseCase = getIt<UpdateMediaDurationUseCase>();
        await updateDurationUseCase(_currentMedia!.id, actualDurationSeconds);

        // 更新当前媒体项的时长
        _currentMedia = _currentMedia!.copyWith(
          duration: actualDurationSeconds,
        );

        debugPrint('Media duration updated successfully');
      } catch (e) {
        debugPrint('Failed to update media duration: $e');
      }
    }
  }
}
