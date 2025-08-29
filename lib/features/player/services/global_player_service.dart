import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import '../../../core/audio/audio_player.dart';
import '../../../features/media/domain/entities/media_item.dart';
import '../../../features/meditation/data/services/meditation_session_manager.dart';
import '../../media/data/datasources/media_local_datasource.dart';
import '../../media/domain/usecases/media_usecases.dart';
import '../../../core/di/injection_container.dart';
import '../presentation/widgets/player_controls.dart';
import 'sound_effects_player.dart';
import 'audio_focus_manager.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/web_storage_helper.dart';
import '../../../main.dart' show audioHandler;

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

  // 音频中断处理状态
  bool _wasUserInitiatedPause = false;

  // 后台状态跟踪
  bool _wasPlayingBeforeBackground = false;
  bool _isInBackground = false;
  bool _audioInterruptedWhileInBackground = false; // 标记音频是否在后台被中断

  // 后台完成兜底监控（仅用于 RepeatMode.all）
  Timer? _backgroundCompletionTimer;
  bool _backgroundAutoAdvanceTriggered = false;
  double _backgroundLastKnownPosSeconds = 0.0;
  String? _backgroundLastMediaId; // 记录上次处理的媒体ID
  // 内部切歌标记：用于抑制"被中断"误判
  bool _isInternalTrackSwitch = false;

  // 防止重复触发playNext的标记
  bool _isPlayNextInProgress = false;

  // 播放时长统计定时器 - 优化为1分钟间隔
  Timer? _playTimeTrackingTimer;
  static const int _playTimeTrackingIntervalSeconds = 60; // 1分钟统计间隔

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

      // 播放状态监控已禁用以避免崩溃
      debugPrint('Playback monitoring disabled for stability');

      // 配置音频上下文以支持中断检测
      await _configureAudioContext();

      // 设置音频中断回调
      _setupAudioInterruptionHandling();

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

        // 设置 ReleaseMode 为 stop，避免音频源在播放完成后被释放
        await _audioPlayer.setReleaseMode(ReleaseMode.stop);
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

  /// 配置音频上下文以支持中断检测和后台播放
  Future<void> _configureAudioContext() async {
    try {
      debugPrint(
        'Configuring audio context for interruption support and background playback...',
      );

      // 获取支持中断和后台播放的音频上下文
      final audioContext = AudioFocusManager().getMainAudioContext();

      // 同时设置全局和实例级别的音频上下文
      await AudioPlayer.global.setAudioContext(audioContext);
      debugPrint(
        'Global audio context configured for interruption support and background playback',
      );

      // 等待一下确保MindraAudioPlayer初始化完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 注意：MindraAudioPlayer会在自己的初始化过程中设置音频上下文
      // 这里我们确保全局设置是正确的
    } catch (e) {
      debugPrint('Error configuring audio context: $e');
      // 不抛出异常，让初始化继续
    }
  }

  // 定时器监控已移除以避免崩溃

  /// 设置音频中断处理
  void _setupAudioInterruptionHandling() {
    try {
      AudioFocusManager().setAudioInterruptionCallback((bool isInterrupted) {
        debugPrint(
          'Audio interruption callback triggered: isInterrupted=$isInterrupted',
        );

        // 安全检查：确保服务仍然初始化
        if (!_isInitialized) {
          debugPrint(
            'Service not initialized, ignoring audio interruption callback',
          );
          return;
        }

        // 内部切歌流程中产生的 stop 触发，不视为外部中断
        if (_isInternalTrackSwitch) {
          debugPrint('Interruption ignored due to internal track switch');
          return;
        }

        if (isInterrupted) {
          // 音频被其他应用中断，暂停播放
          debugPrint(
            'Audio interrupted by other app, updating UI state immediately',
          );

          // 立即更新状态，不等待异步操作
          _isPlaying = false;
          _playerState = MindraPlayerState.paused;
          notifyListeners();
          debugPrint('UI state updated immediately for interruption');

          // 注意：不需要调用 _audioPlayer.pause()，因为音频已经被系统中断了
          // 调用 pause() 可能会导致状态混乱或重复处理
          debugPrint(
            'Audio interruption handling completed - UI should show play button',
          );
        } else {
          // 音频中断结束，可以考虑恢复播放
          debugPrint(
            'Audio interruption ended - keeping paused state for user control',
          );
          // 这里可以根据应用的策略决定是否自动恢复播放
          // 目前我们不自动恢复，让用户手动控制
        }
      });

      debugPrint('Audio interruption handling setup completed');
    } catch (e) {
      debugPrint('Error setting up audio interruption handling: $e');
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
      debugPrint(
        '🎵 Playing state changed: $isPlaying (previous: $_isPlaying, wasUserInitiated: $_wasUserInitiatedPause)',
      );

      // 检测音频中断：如果从播放变为暂停，且不是用户主动操作
      if (_isPlaying &&
          !isPlaying &&
          !_wasUserInitiatedPause &&
          !_isInternalTrackSwitch) {
        debugPrint(
          '🔴 AUDIO INTERRUPTION DETECTED via playingStream: from playing to not playing',
        );

        // 如果在后台，标记为后台中断
        if (_isInBackground) {
          _audioInterruptedWhileInBackground = true;
          debugPrint(
            '🔴 Audio interrupted while in background - marked for resume detection (playingStream)',
          );
        }

        // 立即更新状态
        _isPlaying = false;
        _playerState = MindraPlayerState.paused;

        // 立即通知UI更新
        notifyListeners();

        // 通知音频焦点管理器（这会触发中断回调，但回调中不会再次调用pause）
        debugPrint(
          '🔴 Calling AudioFocusManager().notifyAudioInterrupted() from playingStream',
        );
        AudioFocusManager().notifyAudioInterrupted();

        debugPrint(
          '🔴 Audio interruption via playingStream completed - UI should show play button',
        );
      } else {
        _isPlaying = isPlaying;
        notifyListeners();
      }

      _handlePlayingStateChange(isPlaying);
    });

    // Listen to position changes with enhanced progress tracking
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      final newPosition = position.inSeconds.toDouble();
      final positionDiff = (newPosition - _currentPosition).abs();

      _currentPosition = newPosition;

      // 减少 AudioHandler 同步频率，只在位置有明显变化时同步
      if (positionDiff > 1.0) {
        // 只有当位置变化超过1秒时才同步
        try {
          audioHandler.updatePlaybackState(
            isPlaying: _isPlaying,
            position: position,
            duration: Duration(seconds: _totalDuration.toInt()),
            processingState: _mapPlayerStateToAudioProcessingState(
              _playerState,
            ),
          );
        } catch (e) {
          debugPrint('Error syncing position to AudioHandler: $e');
        }
      }

      notifyListeners();

      // 移除每秒的进度更新调用 - 改为定时器统计
      // 只保留位置记录用于UI显示和保存

      // 减少保存频率：只在位置变化较大时保存
      if (positionDiff > 10.0) {
        _saveLastPlayedPosition();
      }
    });

    // Listen to duration changes
    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        final previousDuration = _totalDuration;
        _totalDuration = duration.inSeconds.toDouble();

        // 只在时长真正变化时同步到 AudioHandler
        if ((previousDuration - _totalDuration).abs() > 1.0) {
          try {
            audioHandler.updatePlaybackState(
              isPlaying: _isPlaying,
              position: Duration(seconds: _currentPosition.toInt()),
              duration: duration,
              processingState: _mapPlayerStateToAudioProcessingState(
                _playerState,
              ),
            );
          } catch (e) {
            debugPrint('Error syncing duration to AudioHandler: $e');
          }
        }

        notifyListeners();

        // 检查并更新媒体项的时长数据
        _checkAndUpdateMediaDuration(duration.inSeconds);
      }
    });

    // Listen to player state changes with enhanced handling
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      debugPrint(
        '🎵 Player state stream changed: $state (previous: $_playerState, wasUserInitiated: $_wasUserInitiatedPause)',
      );

      final previousState = _playerState;
      _playerState = state;
      _isLoading =
          (state == MindraPlayerState.loading ||
          state == MindraPlayerState.buffering);

      // 只在状态真正变化时同步到 AudioHandler
      if (previousState != state) {
        try {
          audioHandler.updatePlaybackState(
            isPlaying: _isPlaying,
            position: Duration(seconds: _currentPosition.toInt()),
            duration: Duration(seconds: _totalDuration.toInt()),
            processingState: _mapPlayerStateToAudioProcessingState(state),
          );
        } catch (e) {
          debugPrint('Error syncing player state to AudioHandler: $e');
        }
      }

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
    // 同步状态到 AudioHandler（只在状态变化时）
    if (_isPlaying != isPlaying) {
      try {
        audioHandler.updatePlaybackState(
          isPlaying: isPlaying,
          position: Duration(seconds: _currentPosition.toInt()),
          duration: Duration(seconds: _totalDuration.toInt()),
          processingState: _mapPlayerStateToAudioProcessingState(_playerState),
        );
      } catch (e) {
        debugPrint('Error syncing state to AudioHandler: $e');
      }
    }

    if (isPlaying) {
      // 使用统一的会话管理器
      if (!MeditationSessionManager.hasActiveSession && _currentMedia != null) {
        _startMeditationSession();
      } else if (MeditationSessionManager.hasActiveSession) {
        MeditationSessionManager.resumeSession();
      }

      // 启动播放时长统计定时器
      _startPlayTimeTracking();
    } else {
      // 使用统一的会话管理器
      if (MeditationSessionManager.hasActiveSession) {
        MeditationSessionManager.pauseSession();
      }

      // 停止播放时长统计定时器
      _stopPlayTimeTracking();
    }
  }

  /// 将 MindraPlayerState 映射到 AudioProcessingState
  audio_service.AudioProcessingState _mapPlayerStateToAudioProcessingState(
    MindraPlayerState state,
  ) {
    switch (state) {
      case MindraPlayerState.stopped:
        return audio_service.AudioProcessingState.idle;
      case MindraPlayerState.loading:
        return audio_service.AudioProcessingState.loading;
      case MindraPlayerState.buffering:
        return audio_service.AudioProcessingState.buffering;
      case MindraPlayerState.playing:
      case MindraPlayerState.paused:
        return audio_service.AudioProcessingState.ready;
      case MindraPlayerState.completed:
        return audio_service.AudioProcessingState.completed;
      case MindraPlayerState.disposed:
      case MindraPlayerState.error:
        return audio_service.AudioProcessingState.error;
    }
  }

  void _handlePlayerStateChange(MindraPlayerState state) {
    debugPrint(
      'Player state changed from $_playerState to $state (wasUserInitiatedPause: $_wasUserInitiatedPause)',
    );

    // 检测音频中断：如果从播放状态突然变为暂停，且不是用户主动操作
    if (_playerState == MindraPlayerState.playing &&
        state == MindraPlayerState.paused &&
        !_wasUserInitiatedPause &&
        !_isInternalTrackSwitch) {
      debugPrint(
        '🔴 AUDIO INTERRUPTION DETECTED via playerStateStream: from playing to paused without user action',
      );

      // 如果在后台，标记为后台中断
      if (_isInBackground) {
        _audioInterruptedWhileInBackground = true;
        debugPrint(
          '🔴 Audio interrupted while in background - marked for resume detection',
        );
      }

      // 立即更新状态
      _isPlaying = false;
      _playerState = MindraPlayerState.paused;

      // 立即通知UI更新
      notifyListeners();

      // 通知音频焦点管理器和触发中断回调
      debugPrint(
        '🔴 Calling AudioFocusManager().notifyAudioInterrupted() from playerStateStream',
      );
      AudioFocusManager().notifyAudioInterrupted();

      debugPrint(
        '🔴 Audio interruption via playerStateStream completed - UI should show play button',
      );
      return; // 提前返回，避免重复处理
    }

    switch (state) {
      case MindraPlayerState.completed:
        // 确保UI状态正确更新
        _isPlaying = false;
        _playerState = MindraPlayerState.completed;

        // 播放完成时，强制更新会话进度为完整的音频时长
        // 这解决了播放器可能没有发送最后位置更新导致统计不准确的问题
        if (_totalDuration > 0) {
          final completeDuration = _totalDuration.toInt();
          debugPrint(
            'Updating session progress to full duration: ${completeDuration}s on completion',
          );
          // 播放完成时强制更新到完整时长（保留此逻辑）
          MeditationSessionManager.updateSessionProgress(completeDuration);
          MeditationSessionManager.updateSessionProgress(completeDuration);
        }

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

        notifyListeners();
        break;
      case MindraPlayerState.playing:
        _isPlaying = true;
        _playerState = MindraPlayerState.playing;
        _wasUserInitiatedPause = false; // 重置用户暂停标记

        // 通知音频焦点管理器音频开始播放
        AudioFocusManager().notifyMainAudioStarted();

        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.resumeSession();
        }
        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.resumeSession();
        }
        notifyListeners();
        break;
      case MindraPlayerState.paused:
        _isPlaying = false;
        _playerState = MindraPlayerState.paused;

        // 如果不是用户主动暂停，则通知音频焦点管理器音频停止
        if (!_wasUserInitiatedPause) {
          AudioFocusManager().notifyMainAudioStopped();
        }

        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.pauseSession();
        }
        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.pauseSession();
        }
        notifyListeners();
        break;
      case MindraPlayerState.stopped:
        _isPlaying = false;
        _playerState = MindraPlayerState.stopped;
        _wasUserInitiatedPause = false; // 重置用户暂停标记

        // 通知音频焦点管理器音频停止
        AudioFocusManager().notifyMainAudioStopped();

        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.pauseSession();
        }
        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.pauseSession();
        }
        notifyListeners();
        break;
      case MindraPlayerState.loading:
      case MindraPlayerState.buffering:
        _playerState = state;
        notifyListeners();
        break;
      default:
        _playerState = state;
        notifyListeners();
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
        // 检查是否已经有playNext在执行，避免重复调用
        if (!_isPlayNextInProgress) {
          debugPrint('Track completion triggering playNext for RepeatMode.all');
          playNext();
        } else {
          debugPrint(
            'Track completion detected playNext already in progress, skipping',
          );
        }
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

      // 简化的重启逻辑：直接seek到开头并播放
      debugPrint('Seeking to beginning and restarting playback');

      // 立即更新状态，避免UI状态不一致
      _playerState = MindraPlayerState.loading;
      notifyListeners();

      // Seek到开头
      await _audioPlayer.seek(Duration.zero);
      _currentPosition = 0.0;

      // 等待一下确保seek完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 开始播放
      await _audioPlayer.play();
      debugPrint('Play command sent after seek to beginning');

      // 等待播放状态更新
      await Future.delayed(const Duration(milliseconds: 200));

      if (_audioPlayer.currentState == MindraPlayerState.playing) {
        debugPrint('Track restarted successfully (seek method)');
        _playerState = MindraPlayerState.playing;
        _isPlaying = true;
      } else {
        debugPrint(
          'Warning: Player not playing after restart, retrying with file reload',
        );
        // 如果简单重启失败，回退到重新加载文件的方法
        await _restartWithFileReload();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error restarting track: $e');
      // 发生错误时，尝试文件重新加载的方法
      await _restartWithFileReload();
    }
  }

  /// 通过重新加载文件来重启播放（备用方法）
  Future<void> _restartWithFileReload() async {
    if (_currentMedia == null) return;

    try {
      debugPrint('Using file reload method as fallback');

      // 更稳妥：仅在播放中先暂停，避免 Android MEDIAPLAYER state 错误 (-38)
      try {
        _isInternalTrackSwitch = true;
        if (_playerState == MindraPlayerState.playing) {
          await _audioPlayer.pause();
          debugPrint('Paused current playback (fallback reload)');
        } else {
          debugPrint('Skip pause in fallback: state=$_playerState');
        }
      } catch (e) {
        debugPrint('Fallback pause failed (ignored): $e');
      }

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
        _playerState = MindraPlayerState.playing;
        _isPlaying = true;
      } else {
        debugPrint('Warning: Player still not playing after file reload');
        // 最后尝试：重置状态让用户手动重新播放
        _playerState = MindraPlayerState.stopped;
        _isPlaying = false;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('File reload method also failed: $e');
      // 重置状态让用户手动重新播放
      _playerState = MindraPlayerState.stopped;
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> _startMeditationSession() async {
    if (_currentMedia == null) return;

    try {
      final sessionType = MeditationSessionManager.getSessionTypeFromCategory(
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
        await MeditationSessionManager.startSession(
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
      if (MeditationSessionManager.hasActiveSession) {
        await MeditationSessionManager.completeSession();
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

        // 立即更新 AudioHandler，确保系统媒体控制显示正确信息
        try {
          await audioHandler.loadAudio(media);
          debugPrint('AudioHandler updated with new media: ${media.title}');
        } catch (e) {
          debugPrint('Failed to update AudioHandler: $e');
        }

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

  /// 处理系统媒体控制回调
  void handleSystemMediaControl(String action) async {
    debugPrint('Handling system media control: $action');

    try {
      switch (action) {
        case 'play':
          // 避免重复调用 audioHandler，直接调用本地播放器
          _wasUserInitiatedPause = false;
          await _audioPlayer.play();
          debugPrint('System play executed');
          break;
        case 'pause':
          _wasUserInitiatedPause = true;
          await _audioPlayer.pause();
          await _saveLastPlayedPosition();
          await _pauseSoundEffects();
          AudioFocusManager().notifyMainAudioStopped();
          debugPrint('System pause executed');
          break;
        case 'stop':
          _wasUserInitiatedPause = true;
          await _audioPlayer.stop();
          await _saveLastPlayedPosition();
          await _pauseSoundEffects();
          AudioFocusManager().notifyMainAudioStopped();
          // 停止所有活跃的会话
          if (MeditationSessionManager.hasActiveSession) {
            await MeditationSessionManager.stopSession();
          }
          if (MeditationSessionManager.hasActiveSession) {
            await MeditationSessionManager.stopSession();
          }
          debugPrint('System stop executed');
          break;
        case 'skipToNext':
          await playNext();
          debugPrint('System skip next executed');
          break;
        case 'skipToPrevious':
          await playPrevious();
          debugPrint('System skip previous executed');
          break;
        case 'fastForward':
          const fastForwardInterval = Duration(seconds: 10);
          final newPosition =
              Duration(seconds: _currentPosition.toInt()) + fastForwardInterval;
          final maxPosition = Duration(seconds: _totalDuration.toInt());

          if (newPosition <= maxPosition) {
            await seek(newPosition);
          } else {
            await seek(maxPosition);
          }
          debugPrint('System fast forward executed');
          break;
        case 'rewind':
          const rewindInterval = Duration(seconds: 10);
          final newPosition =
              Duration(seconds: _currentPosition.toInt()) - rewindInterval;

          if (newPosition >= Duration.zero) {
            await seek(newPosition);
          } else {
            await seek(Duration.zero);
          }
          debugPrint('System rewind executed');
          break;
        case 'favorite':
          await toggleFavorite();
          debugPrint('System favorite toggle executed');
          break;
        default:
          if (action.startsWith('seek:')) {
            final seconds = int.tryParse(action.split(':')[1]) ?? 0;
            await seek(Duration(seconds: seconds));
            debugPrint('System seek to ${seconds}s executed');
          }
          break;
      }
    } catch (e) {
      debugPrint('Error handling system media control [$action]: $e');
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
        final sessionType = MeditationSessionManager.getSessionTypeFromCategory(
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

        // 使用智能切换媒体功能
        await MeditationSessionManager.switchToMedia(
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
        _isInternalTrackSwitch = true;
        if (_playerState == MindraPlayerState.playing) {
          await _audioPlayer.pause();
          debugPrint('Paused current audio before loading new file');
        } else {
          debugPrint('Skip stop/pause: current state is $_playerState');
        }
      } catch (e) {
        debugPrint('Could not pause current audio (will continue): $e');
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
    } finally {
      // 小延时后清除内部切歌标记，避免误判为外部中断
      Future.delayed(const Duration(milliseconds: 600), () {
        _isInternalTrackSwitch = false;
      });
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
    debugPrint(
      'GlobalPlayerService.play() called, current state: $_playerState',
    );

    // 安全检查：确保音频播放器已初始化
    if (!_isInitialized) {
      debugPrint('Audio player not initialized, cannot play');
      throw Exception('Audio player not initialized');
    }

    try {
      _wasUserInitiatedPause = false; // 重置用户暂停标记

      // 同时调用 AudioHandler 和本地播放器
      try {
        await audioHandler.play();
        debugPrint('AudioHandler play command sent');
      } catch (e) {
        debugPrint('AudioHandler play failed: $e');
      }

      // 根据 audioplayers 官方文档，直接调用 play() 方法
      // 库会自动处理所有状态转换，包括 completed 状态
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

      // 通知音频焦点管理器音频开始
      AudioFocusManager().notifyMainAudioStarted();
    } catch (e) {
      debugPrint('Error in play() method: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    // 安全检查：确保音频播放器已初始化
    if (!_isInitialized) {
      debugPrint('Audio player not initialized, cannot pause');
      return;
    }

    try {
      _wasUserInitiatedPause = true; // 标记为用户主动暂停

      // 同时调用 AudioHandler 和本地播放器
      try {
        await audioHandler.pause();
        debugPrint('AudioHandler pause command sent');
      } catch (e) {
        debugPrint('AudioHandler pause failed: $e');
      }

      await _audioPlayer.pause();
      await _saveLastPlayedPosition();
      await _pauseSoundEffects();

      // 暂停时停止统计定时器并即时保存进度
      _stopPlayTimeTracking();
      _saveCurrentProgressImmediately();

      // 通知音频焦点管理器音频停止
      AudioFocusManager().notifyMainAudioStopped();
    } catch (e) {
      debugPrint('Error in pause() method: $e');
      // 即使暂停失败，也要更新状态
      _isPlaying = false;
      _playerState = MindraPlayerState.paused;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _wasUserInitiatedPause = true; // 标记为用户主动停止

    // 同时调用 AudioHandler 和本地播放器
    try {
      await audioHandler.stop();
      debugPrint('AudioHandler stop command sent');
    } catch (e) {
      debugPrint('AudioHandler stop failed: $e');
    }

    await _audioPlayer.stop();
    await _saveLastPlayedPosition();
    await _pauseSoundEffects();

    // 停止时停止统计定时器并即时保存进度
    _stopPlayTimeTracking();
    _saveCurrentProgressImmediately();

    // 通知音频焦点管理器音频停止
    AudioFocusManager().notifyMainAudioStopped();

    // 停止所有活跃的会话
    if (MeditationSessionManager.hasActiveSession) {
      await MeditationSessionManager.stopSession();
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
    // 防止重复调用：如果已经有playNext在执行，直接返回
    if (_isPlayNextInProgress) {
      debugPrint('playNext already in progress, skipping duplicate call');
      return;
    }

    final playlist = _currentPlaylist;
    if (playlist.isEmpty) {
      debugPrint('playNext called but playlist is empty');
      return;
    }

    // 设置执行标记，防止重复调用
    _isPlayNextInProgress = true;

    // 对于全部循环模式，总是自动播放下一首
    final shouldAutoPlay = _repeatMode == RepeatMode.all ? true : _isPlaying;
    final oldIndex = _currentIndex;

    try {
      debugPrint(
        'playNext called: _isPlaying=$_isPlaying, shouldAutoPlay=$shouldAutoPlay, '
        'currentIndex=$_currentIndex, playlistLength=${playlist.length}',
      );

      // 计算下一个索引
      if (_currentIndex < playlist.length - 1) {
        _currentIndex++;
      } else {
        // 到达播放列表末尾，重置到开头
        _currentIndex = 0;
        debugPrint('Reached end of playlist, cycling back to start');
      }

      debugPrint(
        'Moving from index $oldIndex to $_currentIndex, shouldAutoPlay=$shouldAutoPlay',
      );

      // 确保新索引有效
      if (_currentIndex < 0 || _currentIndex >= playlist.length) {
        debugPrint(
          'Invalid index after calculation: $_currentIndex, resetting to 0',
        );
        _currentIndex = 0;
      }

      _isInternalTrackSwitch = true; // 标记内部切歌，抑制中断误判
      // 使用增强版会话管理器切换媒体，避免数据丢失
      await _switchToMediaAtIndex(
        _currentIndex,
        shouldAutoPlay: shouldAutoPlay,
      );
      debugPrint('Successfully switched to next track at index $_currentIndex');

      // 额外保险：800ms 后校验是否真的在播放，否则强制重启
      Future.delayed(const Duration(milliseconds: 800), () async {
        final posDur = await _audioPlayer.getCurrentPosition();
        final before =
            posDur?.inMilliseconds ?? (_currentPosition * 1000).toInt();
        await Future.delayed(const Duration(milliseconds: 500));
        final posDur2 = await _audioPlayer.getCurrentPosition();
        final after =
            posDur2?.inMilliseconds ?? (_currentPosition * 1000).toInt();
        final progressed = (after - before) > 300; // >0.3s 认为在推进
        if (!progressed) {
          try {
            debugPrint('🔧 Auto-fix: no progress detected, forcing restart');
            await _audioPlayer.seek(Duration.zero);
            await _audioPlayer.play();
          } catch (e) {
            debugPrint('🔧 Auto-fix failed: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('Error switching to next track: $e');
      // 发生错误时，恢复之前的索引
      _currentIndex = oldIndex;
      debugPrint('Reverted to previous index due to error: $_currentIndex');

      // 尝试重新加载当前媲体项目的列表
      try {
        await _refreshMediaList();
        // 重新尝试切换
        if (_currentIndex < _currentPlaylist.length) {
          await _switchToMediaAtIndex(
            _currentIndex,
            shouldAutoPlay: shouldAutoPlay,
          );
        }
      } catch (refreshError) {
        debugPrint('Error refreshing media list: $refreshError');
      }
    } finally {
      // 给底层一点时间完成状态切换，再释放标记
      Future.delayed(const Duration(milliseconds: 800), () {
        _isInternalTrackSwitch = false;
      });

      // 清除playNext执行标记
      _isPlayNextInProgress = false;
      debugPrint('playNext execution completed, flag cleared');

      // 最终状态验证：确保UI状态与实际播放状态一致
      Future.delayed(const Duration(milliseconds: 500), () {
        final actualIsPlaying =
            _audioPlayer.currentState == MindraPlayerState.playing;
        if (_isPlaying != actualIsPlaying) {
          debugPrint(
            '🔧 Final state correction: UI was $_isPlaying, actual is $actualIsPlaying',
          );
          _isPlaying = actualIsPlaying;
          _playerState = actualIsPlaying
              ? MindraPlayerState.playing
              : MindraPlayerState.stopped;
          notifyListeners();
          debugPrint('🔧 UI state corrected after playNext completion');

          // 同时修正AudioHandler状态
          try {
            audioHandler.updatePlaybackState(
              isPlaying: actualIsPlaying,
              position: Duration(seconds: _currentPosition.toInt()),
              duration: Duration(seconds: _totalDuration.toInt()),
              processingState: _mapPlayerStateToAudioProcessingState(
                _playerState,
              ),
            );
            debugPrint(
              '🔧 AudioHandler state also corrected in final verification',
            );
          } catch (e) {
            debugPrint(
              'Error correcting AudioHandler state in final verification: $e',
            );
          }
        }
      });
    }
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
      final sessionType = MeditationSessionManager.getSessionTypeFromCategory(
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

      // 立即更新 AudioHandler，确保系统媒体控制显示正确信息
      try {
        await audioHandler.loadAudio(media);
        debugPrint('AudioHandler updated with enhanced media: ${media.title}');
      } catch (e) {
        debugPrint('Failed to update AudioHandler in enhanced mode: $e');
      }

      notifyListeners();

      // 加载音频文件
      await _loadAudioFile(media.filePath);
      await _saveLastPlayedMedia();

      // 使用增强版会话管理器切换
      await MeditationSessionManager.switchToMedia(
        newMediaItem: media,
        sessionType: sessionType,
        soundEffects: soundEffects,
      );

      debugPrint(
        'Successfully switched to new media with enhanced session manager',
      );

      if (shouldAutoPlay) {
        debugPrint('Auto-playing after enhanced media switch');
        await _audioPlayer.play();
        debugPrint('Enhanced auto-play command sent');

        // 立即同步UI状态，确保播放按钮显示正确
        _isPlaying = true;
        _playerState = MindraPlayerState.playing;
        notifyListeners();
        debugPrint('UI state synchronized after auto-play');

        // 立即同步AudioHandler状态，确保系统媒体控制正确
        try {
          audioHandler.updatePlaybackState(
            isPlaying: true,
            position: Duration.zero, // 新歌从头开始
            duration: Duration(seconds: _totalDuration.toInt()),
            processingState: _mapPlayerStateToAudioProcessingState(
              MindraPlayerState.playing,
            ),
          );
          debugPrint('AudioHandler state synchronized after auto-play');
        } catch (e) {
          debugPrint('Error syncing AudioHandler state after auto-play: $e');
        }

        // 小延迟后再次确认状态，防止异步监听器覆盖
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_audioPlayer.currentState == MindraPlayerState.playing) {
            _isPlaying = true;
            _playerState = MindraPlayerState.playing;
            notifyListeners();
            debugPrint('UI state confirmed after delay');

            // 再次同步AudioHandler确保系统媒体控制状态正确
            try {
              audioHandler.updatePlaybackState(
                isPlaying: true,
                position: Duration(seconds: _currentPosition.toInt()),
                duration: Duration(seconds: _totalDuration.toInt()),
                processingState: _mapPlayerStateToAudioProcessingState(
                  MindraPlayerState.playing,
                ),
              );
              debugPrint('AudioHandler state re-confirmed after delay');
            } catch (e) {
              debugPrint('Error re-syncing AudioHandler state after delay: $e');
            }
          }
        });
      } else {
        debugPrint('Not auto-playing: shouldAutoPlay=$shouldAutoPlay');
        // 确保停止状态的UI同步
        _isPlaying = false;
        _playerState = MindraPlayerState.stopped;
        notifyListeners();
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

    // 立即更新 AudioHandler，确保系统媒体控制显示正确信息
    try {
      await audioHandler.loadAudio(media);
      debugPrint('AudioHandler updated with fallback media: ${media.title}');
    } catch (e) {
      debugPrint('Failed to update AudioHandler in fallback mode: $e');
    }

    // 通知UI更新媒体信息（标题、封面等）
    notifyListeners();

    try {
      await _loadAudioFile(media.filePath);
      await _saveLastPlayedMedia();

      if (shouldAutoPlay) {
        debugPrint('Auto-playing after fallback media switch');
        await _audioPlayer.play();
        debugPrint('Fallback auto-play command sent');

        // 立即同步UI状态，确保播放按钮显示正确
        _isPlaying = true;
        _playerState = MindraPlayerState.playing;
        notifyListeners();
        debugPrint('UI state synchronized after fallback auto-play');

        // 立即同步AudioHandler状态，确保系统媒体控制正确
        try {
          audioHandler.updatePlaybackState(
            isPlaying: true,
            position: Duration.zero, // 新歌从头开始
            duration: Duration(seconds: _totalDuration.toInt()),
            processingState: _mapPlayerStateToAudioProcessingState(
              MindraPlayerState.playing,
            ),
          );
          debugPrint(
            'AudioHandler state synchronized after fallback auto-play',
          );
        } catch (e) {
          debugPrint(
            'Error syncing AudioHandler state after fallback auto-play: $e',
          );
        }

        // 小延迟后再次确认状态，防止异步监听器覆盖
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_audioPlayer.currentState == MindraPlayerState.playing) {
            _isPlaying = true;
            _playerState = MindraPlayerState.playing;
            notifyListeners();
            debugPrint('Fallback UI state confirmed after delay');

            // 再次同步AudioHandler确保系统媒体控制状态正确
            try {
              audioHandler.updatePlaybackState(
                isPlaying: true,
                position: Duration(seconds: _currentPosition.toInt()),
                duration: Duration(seconds: _totalDuration.toInt()),
                processingState: _mapPlayerStateToAudioProcessingState(
                  MindraPlayerState.playing,
                ),
              );
              debugPrint(
                'AudioHandler state re-confirmed after fallback delay',
              );
            } catch (e) {
              debugPrint(
                'Error re-syncing AudioHandler state after fallback delay: $e',
              );
            }
          }
        });
      } else {
        debugPrint('Fallback not auto-playing: shouldAutoPlay=$shouldAutoPlay');
        // 确保停止状态的UI同步
        _isPlaying = false;
        _playerState = MindraPlayerState.stopped;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error in fallback loading media at index $index: $e');
      rethrow;
    }
  }

  /// 刷新媒体列表，确保数据最新
  Future<void> _refreshMediaList() async {
    try {
      debugPrint('Refreshing media list...');
      final freshMediaItems = await _mediaDataSource.getMediaItems();

      if (freshMediaItems.isNotEmpty) {
        _mediaItems = freshMediaItems;
        debugPrint('Media list refreshed: ${_mediaItems.length} items');

        // 如果在随机模式下，重新洗牌
        if (_isShuffled) {
          _shufflePlaylist();
        }

        // 确保当前索引仍然有效
        if (_currentMedia != null) {
          final currentPlaylist = _currentPlaylist;
          _currentIndex = currentPlaylist.indexWhere(
            (item) => item.id == _currentMedia!.id,
          );

          if (_currentIndex == -1) {
            debugPrint(
              'Current media not found in refreshed list, resetting to 0',
            );
            _currentIndex = 0;
          }
        }
      }
    } catch (e) {
      debugPrint('Error refreshing media list: $e');
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

    // 同步底层播放器的 ReleaseMode，以提升后台场景下的可靠性
    // 单曲循环：使用原生层的 loop，可在后台自动循环而无需依赖 Dart 回调
    // 其它模式：使用 stop，完成后停止以便我们在 Dart 层做切歌逻辑
    try {
      if (_repeatMode == RepeatMode.one) {
        _audioPlayer.setReleaseMode(ReleaseMode.loop);
        // 切换到单曲循环时无需后台兜底
        _stopBackgroundCompletionWatchdog();
      } else {
        _audioPlayer.setReleaseMode(ReleaseMode.stop);
        // 如果进入全部循环并处于后台播放，开启兜底
        if (_repeatMode == RepeatMode.all && _isInBackground && _isPlaying) {
          _startBackgroundCompletionWatchdog();
        } else {
          _stopBackgroundCompletionWatchdog();
        }
      }
    } catch (_) {
      // 忽略设置失败以避免影响主流程
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
    if (_currentMedia == null) {
      debugPrint('toggleFavorite: No current media, skipping');
      return;
    }

    final oldFavoriteStatus = _isFavorited;
    debugPrint(
      'toggleFavorite: Before - Media: ${_currentMedia!.title}, isFavorited: $oldFavoriteStatus',
    );

    _isFavorited = !_isFavorited;
    _currentMedia = _currentMedia!.copyWith(isFavorite: _isFavorited);

    debugPrint(
      'toggleFavorite: After state update - isFavorited: $_isFavorited',
    );

    // 保存到数据库
    try {
      await _mediaDataSource.updateMediaItem(_currentMedia!);
      debugPrint(
        '✓ Favorite status saved to database: ${_currentMedia!.title} -> $_isFavorited',
      );
    } catch (e) {
      debugPrint('✗ Failed to save favorite status to database: $e');
      // 如果保存失败，回滚状态
      _isFavorited = !_isFavorited;
      _currentMedia = _currentMedia!.copyWith(isFavorite: _isFavorited);
      debugPrint('Rolled back favorite status to: $_isFavorited');
    }

    // 更新 AudioHandler 的收藏状态
    debugPrint('Updating AudioHandler with favorite status: $_isFavorited');
    audioHandler.updateFavoriteStatus(_isFavorited);

    notifyListeners();
    debugPrint('toggleFavorite: Complete - notifyListeners() called');
  }

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimerMinutes = minutes;

    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      if (_isPlaying) {
        await pause();
      }

      // 完成冥想会话以确保统计数据被正确记录
      try {
        if (MeditationSessionManager.hasActiveSession) {
          await MeditationSessionManager.completeSession();
          debugPrint(
            'Sleep timer completed: Enhanced meditation session completed',
          );
        } else if (MeditationSessionManager.hasActiveSession) {
          await MeditationSessionManager.completeSession();
          debugPrint(
            'Sleep timer completed: Traditional meditation session completed',
          );
        }
      } catch (e) {
        debugPrint('Error completing session after sleep timer: $e');
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
      debugPrint('🌙 App going to background - recording current state');
      debugPrint(
        '🌙 Current state: _isPlaying=$_isPlaying, _playerState=$_playerState, wasUserInitiated=$_wasUserInitiatedPause',
      );

      // 记录后台前的播放状态
      _wasPlayingBeforeBackground = _isPlaying;
      _isInBackground = true;
      _audioInterruptedWhileInBackground = false; // 重置中断标记

      // 启动后台完成兜底监控（仅全部循环模式需要跨曲目自动播放）
      _startBackgroundCompletionWatchdog();

      await MeditationSessionManager.forceSaveCurrentState();
      await MeditationSessionManager.forceSaveCurrentState();
      await _saveLastPlayedPosition();

      debugPrint(
        '🌙 Background state recorded: wasPlayingBeforeBackground=$_wasPlayingBeforeBackground',
      );
      debugPrint('Saved player state before going to background');
    } catch (e) {
      debugPrint('Error saving state before background: $e');
    }
  }

  Future<void> resumeFromBackground() async {
    // 从后台返回时验证并恢复状态
    try {
      debugPrint('☀️ App resuming from background');
      _isInBackground = false;

      // 停止后台监控
      _stopBackgroundCompletionWatchdog();

      // 验证当前会话是否仍然有效
      if (MeditationSessionManager.hasActiveSession) {
        debugPrint('Resumed from background with active enhanced session');
      } else if (MeditationSessionManager.hasActiveSession) {
        debugPrint('Resumed from background with active traditional session');
      }

      // 检查音频状态是否与预期一致
      await _checkAudioStateAfterResume();

      // 延迟100ms后再次强制刷新UI，确保状态同步
      Future.delayed(const Duration(milliseconds: 100), () {
        debugPrint('🎨 Force UI refresh after background resume');
        notifyListeners();
      });

      // 重要：不要自动恢复播放，让用户手动控制
      // 如果音频因为中断而暂停，应该保持暂停状态
      debugPrint('Background resume completed - audio state preserved');
    } catch (e) {
      debugPrint('Error resuming from background: $e');
    }
  }

  /// 从后台恢复后检查音频状态
  Future<void> _checkAudioStateAfterResume() async {
    try {
      debugPrint('🔍 Checking audio state after background resume...');
      debugPrint(
        '🔍 Background state: wasPlayingBeforeBackground=$_wasPlayingBeforeBackground, audioInterruptedWhileInBackground=$_audioInterruptedWhileInBackground',
      );
      debugPrint(
        '🔍 Current state: _isPlaying=$_isPlaying, _playerState=$_playerState',
      );

      // 情况1：如果在后台期间已经检测到音频中断，确保UI状态正确
      if (_audioInterruptedWhileInBackground) {
        debugPrint('✅ Audio interruption already detected while in background');
        // 确保UI状态正确
        if (_isPlaying) {
          debugPrint(
            '🔴 Fixing UI state: was showing playing but should be paused',
          );
          _isPlaying = false;
          _playerState = MindraPlayerState.paused;
          notifyListeners();
        }
        debugPrint(
          '🔍 Audio interruption case handled, skipping further checks',
        );
      }
      // 情况2：如果没有检测到中断，需要更仔细地验证状态
      else {
        debugPrint(
          '🔍 No interruption detected during background, verifying state...',
        );

        // 等待一下让状态稳定
        await Future.delayed(const Duration(milliseconds: 500));

        // 使用位置变化检测音频是否真的在播放（最可靠的方法）
        final currentPosition = _currentPosition;
        debugPrint('🔍 Current position before check: ${currentPosition}s');

        // 等待1秒检查位置是否变化
        await Future.delayed(const Duration(milliseconds: 1000));
        final newPosition = _currentPosition;
        debugPrint('🔍 Position after 1 second: ${newPosition}s');

        final positionChanged =
            (newPosition - currentPosition).abs() > 0.5; // 0.5秒的变化阈值
        debugPrint(
          '🔍 Position changed: $positionChanged (${currentPosition}s → ${newPosition}s)',
        );

        // 获取其他状态信息作为辅助判断
        final actualPlayerState = _audioPlayer.currentState;
        debugPrint('🔍 Actual audio player state: $actualPlayerState');

        bool actualIsPlaying = false;
        try {
          actualIsPlaying = await _audioPlayer.playingStream.first.timeout(
            const Duration(milliseconds: 200),
            onTimeout: () => false,
          );
          debugPrint('🔍 Playing stream state: $actualIsPlaying');
        } catch (e) {
          debugPrint('🔍 Could not get playing stream state: $e');
        }

        final stateIsPlaying = actualPlayerState == MindraPlayerState.playing;
        debugPrint('🔍 Player state is playing: $stateIsPlaying');

        // 最终判断：位置变化是最可靠的指标
        final isActuallyPlaying = positionChanged;
        debugPrint(
          '🔍 Final determination - actually playing: $isActuallyPlaying',
        );

        // 检测状态不一致的情况
        if (_wasPlayingBeforeBackground && _isPlaying && !isActuallyPlaying) {
          debugPrint(
            '🔴 CONFIRMED STATE MISMATCH: UI shows playing but audio position not moving',
          );
          debugPrint(
            '🔴 This indicates audio was silently interrupted in background',
          );

          // 立即更新状态以匹配实际情况
          _isPlaying = false;
          _playerState = MindraPlayerState.paused;

          // 强制通知UI更新
          notifyListeners();

          // 触发中断处理
          AudioFocusManager().notifyAudioInterrupted();

          debugPrint('🔴 State synchronized - UI should now show play button');
        }
        // 正常情况：音频确实在播放
        else if (_wasPlayingBeforeBackground &&
            _isPlaying &&
            isActuallyPlaying) {
          debugPrint(
            '✅ Audio state consistent - audio continued playing normally in background',
          );
          debugPrint('✅ Position is moving, audio is actually playing');

          // 确保UI状态正确显示为播放中
          if (_playerState != MindraPlayerState.playing) {
            _playerState = MindraPlayerState.playing;
            notifyListeners();
            debugPrint('🔧 Corrected UI state to match playing audio');
          }
        }
        // 音频确实被暂停了（可能是正常的中断）
        else if (_wasPlayingBeforeBackground &&
            _isPlaying &&
            !isActuallyPlaying) {
          debugPrint(
            '🔴 Audio was interrupted: position not moving despite UI showing playing',
          );

          // 更新状态匹配实际情况
          _isPlaying = false;
          _playerState = MindraPlayerState.paused;
          notifyListeners();

          debugPrint('🔴 Updated UI to reflect paused audio');
        }
        // 其他情况
        else {
          debugPrint('ℹ️ Audio state check completed, no correction needed');
          debugPrint(
            'ℹ️ wasPlayingBefore: $_wasPlayingBeforeBackground, currentlyPlaying: $_isPlaying, positionMoving: $isActuallyPlaying',
          );
        }
      }

      // 重置后台状态标记
      _isInBackground = false;
      _wasPlayingBeforeBackground = false;
      _audioInterruptedWhileInBackground = false;

      // 保险：确保监控已停止
      _stopBackgroundCompletionWatchdog();
    } catch (e) {
      debugPrint('Error checking audio state after resume: $e');
    }
  }

  /// 启动后台完成兜底监控
  void _startBackgroundCompletionWatchdog() {
    try {
      _stopBackgroundCompletionWatchdog();

      // 仅在全部循环模式、且当前确实在播放时监控
      if (_repeatMode != RepeatMode.all || !_isPlaying) {
        return;
      }

      _backgroundAutoAdvanceTriggered = false;
      _backgroundLastKnownPosSeconds = _currentPosition;
      // 记录当前媒体ID便于未来扩展（例如跨媒体校验）
      _backgroundCompletionTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (timer) async {
          // 前台或模式变更，停止
          if (!_isInBackground || _repeatMode != RepeatMode.all) {
            _stopBackgroundCompletionWatchdog();
            return;
          }

          // 正在内部切歌期间，跳过检测
          if (_isInternalTrackSwitch) {
            return;
          }

          // 如果已经触发过一次自动切歌，等待状态稳定
          if (_backgroundAutoAdvanceTriggered) {
            return;
          }

          // 如果playNext正在执行中，跳过后台触发，避免重复调用
          if (_isPlayNextInProgress) {
            debugPrint(
              '⏭️ Background watchdog detected playNext in progress, skipping',
            );
            return;
          }

          // 优先从底层读取位置与时长，避免前台流在后台不更新
          final posDur = await _audioPlayer.getCurrentPosition();
          final dur = await _audioPlayer.getDuration();
          final pos = (posDur ?? Duration(seconds: _currentPosition.toInt()))
              .inSeconds
              .toDouble();
          final total = (dur ?? Duration(seconds: _totalDuration.toInt()))
              .inSeconds
              .toDouble();

          if (total > 0 && pos >= 0) {
            final remaining = total - pos;
            final progressPercent = pos / total;

            // 更严格的结束判断：
            // 1. 剩余时间 <= 0.5秒 (更严格的时间窗口)
            // 2. 或者进度超过98%且剩余时间 <= 2秒 (避免网络音频的时长不准确问题)
            final isNearEnd =
                remaining <= 0.5 ||
                (progressPercent >= 0.98 && remaining <= 2.0);

            // 检测从接近结尾位置重置到开头（用于检测已完成但未检测到的情况）
            final resetToZeroAfterEnd =
                (pos <= 1.0 && _backgroundLastKnownPosSeconds >= total - 2.0);

            if (isNearEnd || resetToZeroAfterEnd) {
              // 额外检查：避免同一首歌重复触发
              final currentMediaId = _currentMedia?.id;
              if (currentMediaId != null &&
                  currentMediaId == _backgroundLastMediaId) {
                debugPrint(
                  '⏭️ Background watchdog skipping: same media already processed ($currentMediaId)',
                );
                return;
              }

              debugPrint(
                '⏭️ Background trigger conditions: remaining=$remaining, progressPercent=$progressPercent, resetToZero=$resetToZeroAfterEnd',
              );
              _backgroundAutoAdvanceTriggered = true;
              _backgroundLastMediaId = currentMediaId; // 记录当前处理的媒体
              debugPrint('⏭️ Background watchdog advancing to next track');
              try {
                await playNext();
                debugPrint(
                  '⏭️ Background watchdog playNext completed successfully',
                );

                // 延迟重置标记，确保playNext完全完成且新歌开始播放
                Future.delayed(const Duration(seconds: 3), () {
                  _backgroundAutoAdvanceTriggered = false;
                  _backgroundLastKnownPosSeconds = 0.0;
                  _backgroundLastMediaId = null; // 清除媒体ID记录
                  debugPrint('⏭️ Background watchdog flags reset after delay');
                });
              } catch (e) {
                debugPrint('⏭️ Background watchdog playNext failed: $e');
                // 出错时立即重置，允许重试
                _backgroundAutoAdvanceTriggered = false;
                _backgroundLastKnownPosSeconds = 0.0;
                _backgroundLastMediaId = null; // 清除媒体ID记录，允许重试
              }
            }
          }
          // 更新上一次位置与媒体ID
          _backgroundLastKnownPosSeconds = pos;
          // 保持媒体ID记录留作扩展
        },
      );
    } catch (e) {
      debugPrint('Failed to start background watchdog: $e');
    }
  }

  /// 停止后台完成兜底监控
  void _stopBackgroundCompletionWatchdog() {
    try {
      _backgroundCompletionTimer?.cancel();
      _backgroundCompletionTimer = null;
      _backgroundAutoAdvanceTriggered = false;
      _backgroundLastKnownPosSeconds = 0.0;
      _backgroundLastMediaId = null; // 清除媒体ID记录
      debugPrint('⏭️ Background watchdog stopped and cleaned up');
    } catch (_) {}
  }

  /// 处理应用即将终止的情况
  Future<void> prepareForTermination() async {
    try {
      // 强制保存所有状态
      await MeditationSessionManager.forceSaveCurrentState();
      await MeditationSessionManager.forceSaveCurrentState();
      await _saveLastPlayedPosition();

      // 如果有活跃会话，标记为停止（而不是完成）
      if (MeditationSessionManager.hasActiveSession) {
        await MeditationSessionManager.stopSession();
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
    // 首先标记为未初始化，防止其他操作访问
    _isInitialized = false;

    // 停止播放时长统计定时器
    _stopPlayTimeTracking();

    // 停止后台完成兜底监控
    _stopBackgroundCompletionWatchdog();

    // 清理音频回调
    try {
      AudioFocusManager().setAudioInterruptionCallback(null);
      AudioFocusManager().setMainAudioStateCallback(null);
      debugPrint('Audio callbacks cleared');
    } catch (e) {
      debugPrint('Error clearing audio callbacks: $e');
    }

    _sleepTimer?.cancel();
    await _playingSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playerStateSubscription?.cancel();
    await _bufferProgressSubscription?.cancel();

    // 在dispose前保存状态
    try {
      await MeditationSessionManager.forceSaveCurrentState();
      await MeditationSessionManager.forceSaveCurrentState();
      await _saveLastPlayedPosition();
    } catch (e) {
      debugPrint('Error saving state during dispose: $e');
    }

    // 停止所有活跃会话
    if (MeditationSessionManager.hasActiveSession) {
      await MeditationSessionManager.stopSession();
    }
    if (MeditationSessionManager.hasActiveSession) {
      await MeditationSessionManager.stopSession();
    }

    // 安全释放音频播放器
    try {
      await _audioPlayer.dispose();
      debugPrint('Audio player disposed successfully');
    } catch (e) {
      debugPrint('Error disposing audio player: $e');
    }

    try {
      await _soundEffectsPlayer.dispose();
      debugPrint('Sound effects player disposed successfully');
    } catch (e) {
      debugPrint('Error disposing sound effects player: $e');
    }
  }

  Future<void> shutdown() async {
    await _disposeInternal();
  }

  /// 启动播放时长统计定时器
  void _startPlayTimeTracking() {
    // 防止重复启动：如果已经有定时器在运行，直接返回
    if (_playTimeTrackingTimer != null) {
      debugPrint('🕒 定时器已在运行，跳过重复启动');
      return;
    }

    debugPrint('🕒 启动播放时长统计定时器 ($_playTimeTrackingIntervalSeconds秒间隔)');

    _playTimeTrackingTimer = Timer.periodic(
      Duration(seconds: _playTimeTrackingIntervalSeconds),
      (timer) {
        debugPrint(
          '🕒 定时器触发 - isPlaying: $_isPlaying, position: $_currentPosition',
        );

        // 只在播放状态时统计时长
        if (_isPlaying && _currentPosition > 0) {
          // 更新统一管理器的进度
          MeditationSessionManager.updateSessionProgress(
            _currentPosition.toInt(),
          );

          // 触发UI更新通知（1分钟一次）
          MeditationSessionManager.triggerRealTimeUpdate();

          debugPrint('播放时长统计更新: ${_currentPosition.toInt()}秒');
        } else {
          debugPrint(
            '🕒 跳过统计更新 - isPlaying: $_isPlaying, position: $_currentPosition',
          );
        }
      },
    );
  }

  /// 停止播放时长统计定时器
  void _stopPlayTimeTracking() {
    if (_playTimeTrackingTimer != null) {
      debugPrint('🕒 停止播放时长统计定时器');
      _playTimeTrackingTimer?.cancel();
      _playTimeTrackingTimer = null;
    }
  }

  /// 即时保存当前进度（用于暂停/停止/切换时）
  void _saveCurrentProgressImmediately() {
    if (_currentPosition > 0) {
      // 即时更新统一管理器的进度
      MeditationSessionManager.updateSessionProgress(_currentPosition.toInt());

      // 触发UI更新通知
      MeditationSessionManager.triggerRealTimeUpdate();

      debugPrint('即时保存播放进度: ${_currentPosition.toInt()}秒');
    }
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
