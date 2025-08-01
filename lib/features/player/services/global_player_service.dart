import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../core/audio/audio_player.dart';
import '../../../features/media/domain/entities/media_item.dart';
import '../../../features/meditation/data/services/meditation_session_manager.dart';
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

      // 更新会话进度，让MeditationSessionManager处理实时更新
      MeditationSessionManager.updateSessionProgress(position.inSeconds);

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
    if (isPlaying &&
        !MeditationSessionManager.hasActiveSession &&
        _currentMedia != null) {
      _startMeditationSession();
    } else if (!isPlaying && MeditationSessionManager.hasActiveSession) {
      MeditationSessionManager.pauseSession();
    }
  }

  void _handlePlayerStateChange(MindraPlayerState state) {
    switch (state) {
      case MindraPlayerState.completed:
        _completeMeditationSession();
        _clearLastPlayedRecord();
        _handleTrackCompletion();
        break;
      case MindraPlayerState.playing:
        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.resumeSession();
        }
        break;
      case MindraPlayerState.paused:
      case MindraPlayerState.stopped:
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
        _audioPlayer.seek(Duration.zero); // 自动seek，不显示缓冲
        _audioPlayer.play();
        break;
      case RepeatMode.all:
        playNext();
        break;
      case RepeatMode.none:
        break;
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

      await MeditationSessionManager.startSession(
        mediaItem: _currentMedia!,
        sessionType: sessionType,
        soundEffects: soundEffects,
      );
      debugPrint('Started meditation session for: ${_currentMedia!.title}');
    } catch (e) {
      debugPrint('Error starting meditation session: $e');
    }
  }

  Future<void> _completeMeditationSession() async {
    if (!MeditationSessionManager.hasActiveSession) return;

    try {
      await MeditationSessionManager.completeSession();
      debugPrint('Completed meditation session');
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

        // 通知UI更新媒体信息（标题、封面等）
        notifyListeners();

        await _loadAudioFile(media.filePath);
        await _saveLastPlayedMedia();

        if (autoPlay) {
          await play();
        }
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
    // 检查是否是不同的音频
    final isDifferentMedia = _currentMedia?.id != mediaId;

    if (isDifferentMedia) {
      // 如果切换到不同的音频，需要先结束当前的session
      if (MeditationSessionManager.hasActiveSession) {
        try {
          await MeditationSessionManager.stopSession();
          debugPrint(
            'Stopped previous meditation session when switching media',
          );
        } catch (e) {
          debugPrint('Error stopping previous session: $e');
        }
      }

      // 只在切换不同音频时重置位置，相同音频保持当前状态
      debugPrint('切换到不同音频: $mediaId');
    } else {
      debugPrint('播放相同音频，保持当前状态: ${_currentPosition}s');
    }

    await _loadMediaById(mediaId, autoPlay: autoPlay);
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

    await _loadMediaAtIndex(_currentIndex, shouldAutoPlay: wasPlaying);
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

    await _loadMediaAtIndex(_currentIndex, shouldAutoPlay: wasPlaying);
  }

  Future<void> _loadMediaAtIndex(
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
      debugPrint('Error loading media at index $index: $e');
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
      if (MeditationSessionManager.hasActiveSession) {
        debugPrint('Resumed from background with active session');
        // 可以在这里添加额外的状态验证逻辑
      }
    } catch (e) {
      debugPrint('Error resuming from background: $e');
    }
  }

  /// 处理应用即将终止的情况
  Future<void> prepareForTermination() async {
    try {
      // 强制保存所有状态
      await MeditationSessionManager.forceSaveCurrentState();
      await _saveLastPlayedPosition();

      // 如果有活跃会话，标记为停止（而不是完成）
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
      await MeditationSessionManager.forceSaveCurrentState();
      await _saveLastPlayedPosition();
    } catch (e) {
      debugPrint('Error saving state during dispose: $e');
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
