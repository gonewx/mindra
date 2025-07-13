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

  bool _useAudioPlayersFlag = true;
  bool get _useAudioPlayers =>
      _useAudioPlayersFlag &&
      !kIsWeb &&
      (Platform.isAndroid || Platform.isLinux);

  CrossPlatformAudioPlayer() {
    try {
      if (_useAudioPlayers) {
        _audioPlayersInstance = audioplayers.AudioPlayer();
        _setupAudioPlayersListeners();
        // 延迟配置音频上下文，特别是华为设备
        Future.microtask(() => _configureAudioContextSafely());
      } else {
        _justAudioInstance = just_audio.AudioPlayer();
      }
    } catch (e) {
      debugPrint('Failed to initialize audio player: $e');
      // 如果初始化失败，尝试使用备用方案
      _initializeFallbackPlayer();
    }
  }

  void _initializeFallbackPlayer() {
    try {
      // 尝试使用just_audio作为备用
      _useAudioPlayersFlag = false;
      _justAudioInstance = just_audio.AudioPlayer();
      debugPrint('Fallback to just_audio player');
    } catch (e) {
      debugPrint('Failed to initialize fallback player: $e');
    }
  }

  Future<void> _configureAudioContext() async {
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

  Future<void> _configureAudioContextSafely() async {
    if (_audioPlayersInstance == null) return;

    try {
      // 添加延迟以确保华为设备有足够时间初始化
      await Future.delayed(const Duration(milliseconds: 100));

      // 使用音频焦点管理器获取配置
      final audioContext = _audioFocusManager.getMainAudioContext();
      await _audioPlayersInstance!.setAudioContext(audioContext);
      debugPrint(
        'Main audio player context configured safely for Huawei devices',
      );
    } catch (e) {
      debugPrint('Failed to configure main audio context safely: $e');
      // 如果配置失败，尝试不设置音频上下文
      debugPrint('Continuing without audio context configuration');
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
      try {
        await _audioPlayersInstance!.setSourceUrl(url);
      } catch (e) {
        if (Platform.isLinux && e.toString().contains('gst-resource-error')) {
          debugPrint('Linux网络音频播放失败，audioplayers在Linux平台对某些网络音频格式支持有限');
          // 抛出更友好的错误信息
          throw Exception('Linux平台暂不支持此网络音频格式，请尝试下载到本地播放');
        }
        rethrow;
      }
    } else {
      debugPrint('JustAudio: Setting URL: $url');
      await _justAudioInstance!.setUrl(url);
    }
  }

  Future<void> play() async {
    if (_useAudioPlayers) {
      debugPrint('AudioPlayers: Play called');
      // 重新配置音频上下文以确保最新的混音设置
      await _configureAudioContext();
      await _audioPlayersInstance?.resume();
      _audioFocusManager.notifyMainAudioStarted();
    } else {
      await _justAudioInstance?.play();
      _audioFocusManager.notifyMainAudioStarted();
    }
  }

  Future<void> pause() async {
    if (_useAudioPlayers) {
      debugPrint('AudioPlayers: Pause called');
      await _audioPlayersInstance?.pause();
      _audioFocusManager.notifyMainAudioStopped();
    } else {
      await _justAudioInstance?.pause();
      _audioFocusManager.notifyMainAudioStopped();
    }
  }

  Future<void> stop() async {
    if (_useAudioPlayers) {
      debugPrint('AudioPlayers: Stop called');
      await _audioPlayersInstance?.stop();
      _audioFocusManager.notifyMainAudioStopped();
    } else {
      await _justAudioInstance?.stop();
      _audioFocusManager.notifyMainAudioStopped();
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
    CrossPlatformAudioPlayer? tempPlayer;
    try {
      tempPlayer = CrossPlatformAudioPlayer();

      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        await tempPlayer.setUrl(filePath);
      } else {
        await tempPlayer.setFilePath(filePath);
      }

      // Wait a bit for the duration to be loaded
      await Future.delayed(const Duration(milliseconds: 500));

      final duration = await tempPlayer.getDuration();
      return duration;
    } catch (e) {
      debugPrint('Failed to get media duration: $e');
      return null;
    } finally {
      // 确保在 finally 块中清理，无论是否出现异常
      if (tempPlayer != null) {
        try {
          await tempPlayer.dispose();
          debugPrint('Temporary audio player disposed successfully');
        } catch (e) {
          debugPrint('Error disposing temporary audio player: $e');
        }
      }
    }
  }

  Future<void> dispose() async {
    try {
      // 首先停止播放
      await stop();
      
      // 取消定时器
      _positionTimer?.cancel();
      
      // 通知音频焦点管理器停止
      _audioFocusManager.notifyMainAudioStopped();
      
      // 处理音频播放器实例
      if (_audioPlayersInstance != null) {
        await _audioPlayersInstance!.dispose();
        _audioPlayersInstance = null;
      }
      
      if (_justAudioInstance != null) {
        await _justAudioInstance!.dispose();
        _justAudioInstance = null;
      }
      
      // 关闭所有流控制器
      await _playingController.close();
      await _positionController.close();
      await _durationController.close();
      await _playerStateController.close();
      
      debugPrint('CrossPlatformAudioPlayer disposed successfully');
    } catch (e) {
      debugPrint('Error during audio player disposal: $e');
      // 即使出错也要尝试清理基本资源
      _positionTimer?.cancel();
      _audioPlayersInstance = null;
      _justAudioInstance = null;
    }
  }
}
