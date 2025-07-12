import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../core/audio/cross_platform_audio_player.dart';
import '../../../features/media/domain/entities/media_item.dart';
import '../../../features/meditation/data/services/meditation_session_manager.dart';
import '../../media/data/datasources/media_local_datasource.dart';
import '../domain/services/sound_effects_service.dart';
import '../presentation/widgets/player_controls.dart';
import 'simple_sound_effects_player.dart';

class GlobalPlayerService extends ChangeNotifier {
  late final CrossPlatformAudioPlayer _audioPlayer;
  final SoundEffectsService _soundEffectsService = SoundEffectsService();
  final SimpleSoundEffectsPlayer _simpleSoundEffectsPlayer =
      SimpleSoundEffectsPlayer();
  final MediaLocalDataSource _mediaDataSource = MediaLocalDataSource();

  // Subscription management
  StreamSubscription? _playingSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;

  // Playback state
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  double _totalDuration = 0.0;
  bool _isInitialized = false;

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
  int _sleepTimerMinutes = 0; // 保存当前设置的定时器时长

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

  String get title => _currentMedia?.title ?? '未选择素材';
  String get category => _currentMedia?.category.name ?? '';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _audioPlayer = CrossPlatformAudioPlayer();
      await _setupAudioPlayer();
      await _soundEffectsService.initialize();
      await _simpleSoundEffectsPlayer.initialize();

      // 设置音效状态变化回调
      _simpleSoundEffectsPlayer.setStateChangeCallback(() {
        notifyListeners();
      });

      _isInitialized = true;
      debugPrint('Global player service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize global player service: $e');
      rethrow;
    }
  }

  Future<void> _setupAudioPlayer() async {
    // Listen to playing state changes
    _playingSubscription = _audioPlayer.playingStream.listen((isPlaying) {
      _isPlaying = isPlaying;
      notifyListeners();
      _handlePlayingStateChange(isPlaying);
    });

    // Listen to position changes
    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      _currentPosition = position.inSeconds.toDouble();
      notifyListeners();
      MeditationSessionManager.updateSessionProgress(position.inSeconds);
    });

    // Listen to duration changes
    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _totalDuration = duration.inSeconds.toDouble();
        notifyListeners();
      }
    });

    // Listen to player state changes
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      _handlePlayerStateChange(state);
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

  void _handlePlayerStateChange(CrossPlatformPlayerState state) {
    switch (state) {
      case CrossPlatformPlayerState.completed:
        _completeMeditationSession();
        _handleTrackCompletion();
        break;
      case CrossPlatformPlayerState.playing:
        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.resumeSession();
        }
        break;
      case CrossPlatformPlayerState.paused:
      case CrossPlatformPlayerState.stopped:
        if (MeditationSessionManager.hasActiveSession) {
          MeditationSessionManager.pauseSession();
        }
        break;
      default:
        break;
    }
  }

  void _handleTrackCompletion() {
    // Handle repeat mode
    switch (_repeatMode) {
      case RepeatMode.one:
        // Repeat current track
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.play();
        break;
      case RepeatMode.all:
        // Play next track, loop to beginning if at end
        playNext();
        break;
      case RepeatMode.none:
        // Stop playback
        break;
    }
  }

  Future<void> _startMeditationSession() async {
    if (_currentMedia == null) return;

    try {
      final sessionType = MeditationSessionManager.getSessionTypeFromCategory(
        _currentMedia!.category.name,
      );
      final soundEffects = _soundEffectsService.getActiveSoundEffects();

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

  Future<void> loadMedia(String mediaId) async {
    try {
      _mediaItems = await _mediaDataSource.getMediaItems();
      _currentIndex = _mediaItems.indexWhere((item) => item.id == mediaId);

      if (_currentIndex >= 0) {
        final media = _mediaItems[_currentIndex];
        _currentMedia = media;
        _isFavorited = media.isFavorite;
        notifyListeners();

        await _loadAudioFile(media.filePath);
      }
    } catch (e) {
      debugPrint('Error loading media: $e');
      rethrow;
    }
  }

  Future<void> _loadAudioFile(String filePath) async {
    try {
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
            return;
          } else {
            throw Exception('Failed to create blob URL for media');
          }
        }
      }

      await _audioPlayer.setFilePath(filePath);
      debugPrint('Audio file loaded: $filePath');
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

    // 恢复背景音效播放
    await _restoreSoundEffects();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();

    // 暂停背景音效
    await _pauseSoundEffects();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();

    // 停止背景音效
    await _pauseSoundEffects();

    if (MeditationSessionManager.hasActiveSession) {
      await MeditationSessionManager.stopSession();
    }
  }

  // 恢复背景音效播放
  Future<void> _restoreSoundEffects() async {
    try {
      final activeEffects = _simpleSoundEffectsPlayer.currentVolumes;
      for (final entry in activeEffects.entries) {
        if (entry.value > 0) {
          debugPrint('Resuming sound effect: ${entry.key}');
          await _simpleSoundEffectsPlayer.resumeEffect(entry.key);
        }
      }
    } catch (e) {
      debugPrint('Error restoring sound effects: $e');
    }
  }

  // 暂停背景音效
  Future<void> _pauseSoundEffects() async {
    try {
      // 保存当前音效状态但暂停播放
      final activeEffects = _simpleSoundEffectsPlayer.currentVolumes;
      for (final entry in activeEffects.entries) {
        if (entry.value > 0) {
          debugPrint('Pausing sound effect: ${entry.key}');
          // 暂停音效但不改变音量设置
          await _simpleSoundEffectsPlayer.pauseEffect(entry.key);
        }
      }
    } catch (e) {
      debugPrint('Error pausing sound effects: $e');
    }
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> playNext() async {
    final playlist = _currentPlaylist;
    if (playlist.isEmpty) return;

    if (_currentIndex < playlist.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0; // Loop to first
    }

    await _loadMediaAtIndex(_currentIndex);
  }

  Future<void> playPrevious() async {
    final playlist = _currentPlaylist;
    if (playlist.isEmpty) return;

    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = playlist.length - 1; // Loop to last
    }

    await _loadMediaAtIndex(_currentIndex);
  }

  Future<void> _loadMediaAtIndex(int index) async {
    final playlist = _currentPlaylist;
    if (index < 0 || index >= playlist.length) return;

    final media = playlist[index];
    _currentMedia = media;
    _isFavorited = media.isFavorite;
    notifyListeners();

    try {
      await _loadAudioFile(media.filePath);
      // Auto-play the new track if currently playing
      if (_isPlaying) {
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

    // Ensure current media is at the beginning of shuffled list
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

    // Update in database via MediaBloc would happen in the UI layer
  }

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimerMinutes = minutes;

    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      if (_isPlaying) {
        await pause();
      }
      // 定时器触发后重置时长
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

  SoundEffectsService get soundEffectsService => _soundEffectsService;
  SimpleSoundEffectsPlayer get simpleSoundEffectsPlayer =>
      _simpleSoundEffectsPlayer;

  // 检查是否有激活的背景音效
  bool get hasActiveSoundEffects {
    return _simpleSoundEffectsPlayer.hasActiveEffects();
  }

  // Lifecycle management
  Future<void> pauseForBackground() async {
    // This method can be called when app goes to background
    // We want to keep playing in background for meditation apps
    // So we don't pause here unless explicitly requested
  }

  Future<void> resumeFromBackground() async {
    // This method can be called when app returns from background
    // Nothing special needed as audio continues in background
  }

  @override
  void dispose() {
    // Don't dispose in normal circumstances as this is a singleton
    // Only dispose when app is completely shutting down
    _disposeInternal();
    super.dispose();
  }

  Future<void> _disposeInternal() async {
    _sleepTimer?.cancel();
    await _playingSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playerStateSubscription?.cancel();

    if (MeditationSessionManager.hasActiveSession) {
      await MeditationSessionManager.stopSession();
    }

    await _audioPlayer.dispose();
    _soundEffectsService.dispose();
    _isInitialized = false;
  }

  // Method to properly shutdown when app is closing
  Future<void> shutdown() async {
    await _disposeInternal();
  }
}
