import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:just_audio/just_audio.dart' as just_audio;
import 'dart:io';
import 'dart:async';
import '../../features/player/services/audio_focus_manager.dart';

enum CrossPlatformPlayerState { stopped, playing, paused, completed, disposed }

class CrossPlatformAudioPlayer {
  audioplayers.AudioPlayer? _audioPlayersInstance;
  just_audio.AudioPlayer? _justAudioInstance;
  final AudioFocusManager _audioFocusManager = AudioFocusManager();

  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<CrossPlatformPlayerState> _playerStateController =
      StreamController<CrossPlatformPlayerState>.broadcast();

  Timer? _positionTimer;

  bool get _useAudioPlayers =>
      !kIsWeb && (Platform.isAndroid || Platform.isLinux);

  CrossPlatformAudioPlayer() {
    if (_useAudioPlayers) {
      _audioPlayersInstance = audioplayers.AudioPlayer();
      _setupAudioPlayersListeners();
      _configureAudioContext();
    } else {
      _justAudioInstance = just_audio.AudioPlayer();
    }
  }

  void _configureAudioContext() async {
    if (_audioPlayersInstance == null) return;

    try {
      // 使用音频焦点管理器获取配置
      final audioContext = _audioFocusManager.getMainAudioContext();
      await _audioPlayersInstance!.setAudioContext(audioContext);
      debugPrint('Main audio player context configured for primary playback');
    } catch (e) {
      debugPrint('Failed to configure main audio context: $e');
    }
  }

  void _setupAudioPlayersListeners() {
    if (_audioPlayersInstance == null) return;

    // Listen to player state changes
    _audioPlayersInstance!.onPlayerStateChanged.listen((state) {
      debugPrint('AudioPlayers: State changed to: $state');
      switch (state) {
        case audioplayers.PlayerState.playing:
          _playingController.add(true);
          _playerStateController.add(CrossPlatformPlayerState.playing);
          _audioFocusManager.notifyMainAudioStarted();
          break;
        case audioplayers.PlayerState.paused:
          _playingController.add(false);
          _playerStateController.add(CrossPlatformPlayerState.paused);
          _audioFocusManager.notifyMainAudioStopped();
          break;
        case audioplayers.PlayerState.stopped:
          _playingController.add(false);
          _positionController.add(Duration.zero);
          _playerStateController.add(CrossPlatformPlayerState.stopped);
          _audioFocusManager.notifyMainAudioStopped();
          break;
        case audioplayers.PlayerState.completed:
          _playingController.add(false);
          _positionController.add(Duration.zero);
          _playerStateController.add(CrossPlatformPlayerState.completed);
          _audioFocusManager.notifyMainAudioStopped();
          break;
        case audioplayers.PlayerState.disposed:
          _playingController.add(false);
          _playerStateController.add(CrossPlatformPlayerState.disposed);
          _audioFocusManager.notifyMainAudioStopped();
          break;
      }
    });

    // Listen to duration changes
    _audioPlayersInstance!.onDurationChanged.listen((duration) {
      // debugPrint('AudioPlayers: Duration changed: ${duration.inSeconds}s');
      _durationController.add(duration);
    });

    // Listen to position changes
    _audioPlayersInstance!.onPositionChanged.listen((position) {
      // debugPrint('AudioPlayers: Position changed: ${position.inSeconds}s');
      _positionController.add(position);
    });
  }

  Future<void> setFilePath(String filePath) async {
    if (_useAudioPlayers) {
      debugPrint('AudioPlayers: Setting file path: $filePath');
      await _audioPlayersInstance!.setSourceDeviceFile(filePath);
      debugPrint('AudioPlayers: File loaded successfully');
    } else {
      if (kIsWeb && filePath.startsWith('web://')) {
        // Handle web blob URLs separately
        throw UnsupportedError('Web blob URL handling needs to be implemented');
      } else {
        await _justAudioInstance!.setFilePath(filePath);
      }
    }
  }

  Future<void> setUrl(String url) async {
    if (_useAudioPlayers) {
      debugPrint('AudioPlayers: Setting URL: $url');
      await _audioPlayersInstance!.setSourceUrl(url);
    } else {
      await _justAudioInstance!.setUrl(url);
    }
  }

  Future<void> play() async {
    if (_useAudioPlayers) {
      debugPrint('AudioPlayers: Play called');
      await _audioPlayersInstance?.resume();
    } else {
      await _justAudioInstance?.play();
    }
  }

  Future<void> pause() async {
    if (_useAudioPlayers) {
      debugPrint('AudioPlayers: Pause called');
      await _audioPlayersInstance?.pause();
    } else {
      await _justAudioInstance?.pause();
    }
  }

  Future<void> stop() async {
    if (_useAudioPlayers) {
      debugPrint('AudioPlayers: Stop called');
      await _audioPlayersInstance?.stop();
    } else {
      await _justAudioInstance?.stop();
    }
  }

  Future<void> seek(Duration position) async {
    if (_useAudioPlayers) {
      debugPrint('AudioPlayers: Seek to ${position.inSeconds}s');
      await _audioPlayersInstance?.seek(position);
    } else {
      await _justAudioInstance?.seek(position);
    }
  }

  Future<void> setVolume(double volume) async {
    if (_useAudioPlayers) {
      await _audioPlayersInstance?.setVolume(volume);
    } else {
      await _justAudioInstance?.setVolume(volume);
    }
  }

  Stream<Duration> get positionStream {
    if (_useAudioPlayers) {
      return _positionController.stream;
    } else {
      return _justAudioInstance?.positionStream ?? Stream.empty();
    }
  }

  Stream<Duration?> get durationStream {
    if (_useAudioPlayers) {
      return _durationController.stream;
    } else {
      return _justAudioInstance?.durationStream ?? Stream.empty();
    }
  }

  Stream<bool> get playingStream {
    if (_useAudioPlayers) {
      return _playingController.stream;
    } else {
      return _justAudioInstance?.playingStream ?? Stream.empty();
    }
  }

  Stream<CrossPlatformPlayerState> get playerStateStream {
    if (_useAudioPlayers) {
      return _playerStateController.stream;
    } else {
      // For just_audio, we need to map its player state to our enum
      return _justAudioInstance?.playerStateStream.map((state) {
            switch (state.playing) {
              case true:
                return CrossPlatformPlayerState.playing;
              case false:
                if (state.processingState ==
                    just_audio.ProcessingState.completed) {
                  return CrossPlatformPlayerState.completed;
                } else if (state.processingState ==
                    just_audio.ProcessingState.idle) {
                  return CrossPlatformPlayerState.stopped;
                } else {
                  return CrossPlatformPlayerState.paused;
                }
            }
          }) ??
          Stream.empty();
    }
  }

  Future<Duration?> getDuration() async {
    if (_useAudioPlayers) {
      return _audioPlayersInstance?.getDuration();
    } else {
      return _justAudioInstance?.duration;
    }
  }

  /// Get duration of a media file without keeping it loaded
  static Future<Duration?> getMediaDuration(String filePath) async {
    try {
      final tempPlayer = CrossPlatformAudioPlayer();

      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        await tempPlayer.setUrl(filePath);
      } else {
        await tempPlayer.setFilePath(filePath);
      }

      // Wait a bit for the duration to be loaded
      await Future.delayed(const Duration(milliseconds: 500));

      final duration = await tempPlayer.getDuration();
      await tempPlayer.dispose();

      return duration;
    } catch (e) {
      debugPrint('Failed to get media duration: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _positionTimer?.cancel();
    await _audioPlayersInstance?.dispose();
    await _justAudioInstance?.dispose();
    await _playingController.close();
    await _positionController.close();
    await _durationController.close();
    await _playerStateController.close();
  }
}
