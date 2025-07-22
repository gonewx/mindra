import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../../features/player/services/audio_focus_manager.dart';

enum MindraPlayerState {
  stopped,
  loading,
  buffering,
  playing,
  paused,
  completed,
  disposed,
  error,
}

/// 统一的音频播放器，基于 AudioPlayers
class MindraAudioPlayer {
  AudioPlayer? _audioPlayer;
  final AudioFocusManager _audioFocusManager = AudioFocusManager();

  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<MindraPlayerState> _playerStateController =
      StreamController<MindraPlayerState>.broadcast();
  final StreamController<double> _bufferProgressController =
      StreamController<double>.broadcast();

  MindraPlayerState _currentState = MindraPlayerState.stopped;
  double _bufferProgress = 0.0;
  bool _isNetworkSource = false;

  MindraAudioPlayer() {
    try {
      _audioPlayer = AudioPlayer();
      _setupListeners();
      // 延迟配置音频上下文
      Future.microtask(() => _configureAudioContextSafely());
    } catch (e) {
      debugPrint('Failed to initialize audio player: $e');
      rethrow;
    }
  }

  Future<void> _configureAudioContextSafely() async {
    if (_audioPlayer == null) return;

    try {
      // 增加延迟以确保音频播放器完全初始化
      await Future.delayed(const Duration(milliseconds: 200));

      final audioContext = _audioFocusManager.getMainAudioContext();
      await _audioPlayer!.setAudioContext(audioContext);
      debugPrint('Audio player context configured successfully');
    } catch (e) {
      debugPrint('Failed to configure audio context: $e');
      // 继续运行，不抛出异常
    }
  }

  void _setupListeners() {
    if (_audioPlayer == null) return;

    // 监听播放状态变化
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      debugPrint('Audio player state changed to: $state');
      switch (state) {
        case PlayerState.playing:
          _currentState = MindraPlayerState.playing;
          _playingController.add(true);
          _playerStateController.add(MindraPlayerState.playing);
          _audioFocusManager.notifyMainAudioStarted();
          break;
        case PlayerState.paused:
          _currentState = MindraPlayerState.paused;
          _playingController.add(false);
          _playerStateController.add(MindraPlayerState.paused);
          _audioFocusManager.notifyMainAudioStopped();
          break;
        case PlayerState.stopped:
          _currentState = MindraPlayerState.stopped;
          _playingController.add(false);
          _positionController.add(Duration.zero);
          _playerStateController.add(MindraPlayerState.stopped);
          _audioFocusManager.notifyMainAudioStopped();
          break;
        case PlayerState.completed:
          _currentState = MindraPlayerState.completed;
          _playingController.add(false);
          _positionController.add(Duration.zero);
          _playerStateController.add(MindraPlayerState.completed);
          _audioFocusManager.notifyMainAudioStopped();
          break;
        case PlayerState.disposed:
          _currentState = MindraPlayerState.disposed;
          _playingController.add(false);
          _playerStateController.add(MindraPlayerState.disposed);
          _audioFocusManager.notifyMainAudioStopped();
          break;
      }
    });

    // 监听时长变化
    _audioPlayer!.onDurationChanged.listen((duration) {
      _durationController.add(duration);
    });

    // 监听播放位置变化
    _audioPlayer!.onPositionChanged.listen((position) {
      _positionController.add(position);

      // 计算缓冲进度（对于网络音频）
      if (_isNetworkSource) {
        _updateBufferProgress(position);
      }
    });

    // 注意：不需要重复监听 onPlayerStateChanged，上面已经处理了所有状态转换
  }

  void _updateBufferProgress(Duration currentPosition) {
    // 简单的缓冲进度估算
    // 对于网络音频，假设缓冲总是比当前播放位置稍微领先
    if (_audioPlayer != null) {
      _audioPlayer!.getDuration().then((duration) {
        if (duration != null && duration.inSeconds > 0) {
          final currentSeconds = currentPosition.inSeconds;
          final totalSeconds = duration.inSeconds;

          // 模拟缓冲进度，通常比播放进度稍微领先
          final estimatedBufferSeconds = (currentSeconds + 30).clamp(
            0,
            totalSeconds,
          );
          _bufferProgress = estimatedBufferSeconds / totalSeconds;
          _bufferProgressController.add(_bufferProgress);
        }
      });
    }
  }

  Future<void> setFilePath(String filePath) async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');

    debugPrint('Setting file path: $filePath');
    _isNetworkSource = false;
    _currentState = MindraPlayerState.loading;
    _playerStateController.add(MindraPlayerState.loading);

    try {
      await _audioPlayer!.setSourceDeviceFile(filePath);
      debugPrint('File loaded successfully');

      // 文件加载完成，重置为停止状态
      _currentState = MindraPlayerState.stopped;
      _playerStateController.add(MindraPlayerState.stopped);
    } catch (e) {
      _currentState = MindraPlayerState.error;
      _playerStateController.add(MindraPlayerState.error);
      rethrow;
    }
  }

  Future<void> setUrl(String url) async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');

    debugPrint('Setting URL: $url');
    _isNetworkSource = true;
    _currentState = MindraPlayerState.loading;
    _playerStateController.add(MindraPlayerState.loading);

    try {
      await _audioPlayer!.setSourceUrl(url);
      debugPrint('URL loaded successfully');

      // URL加载完成，重置为停止状态
      _currentState = MindraPlayerState.stopped;
      _playerStateController.add(MindraPlayerState.stopped);

      // 对于网络音频，开始监听缓冲进度
      _startBufferProgressMonitoring();
    } catch (e) {
      debugPrint('Failed to load URL: $e');
      _currentState = MindraPlayerState.error;
      _playerStateController.add(MindraPlayerState.error);

      // 提供更友好的错误信息，但不做平台特殊处理
      if (e.toString().contains('gst-resource-error')) {
        throw Exception('网络音频播放失败，请检查网络连接或尝试下载到本地播放');
      }
      rethrow;
    }
  }

  void _startBufferProgressMonitoring() {
    // 定期更新缓冲进度
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_audioPlayer == null || _currentState == MindraPlayerState.disposed) {
        timer.cancel();
        return;
      }

      if (_isNetworkSource && _currentState != MindraPlayerState.stopped) {
        _audioPlayer!.getCurrentPosition().then((position) {
          if (position != null) {
            _updateBufferProgress(position);
          }
        });
      }
    });
  }

  Future<void> play() async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');

    debugPrint('Play called');

    // 只有在真正需要加载时才显示缓冲状态
    if (_currentState == MindraPlayerState.loading) {
      _currentState = MindraPlayerState.buffering;
      _playerStateController.add(MindraPlayerState.buffering);
    }

    // 重新配置音频上下文以确保最新的混音设置
    await _configureAudioContextSafely();
    await _audioPlayer!.resume();
    _audioFocusManager.notifyMainAudioStarted();
  }

  Future<void> pause() async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');

    debugPrint('Pause called');
    await _audioPlayer!.pause();
    _audioFocusManager.notifyMainAudioStopped();
  }

  Future<void> stop() async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');

    debugPrint('Stop called');
    await _audioPlayer!.stop();
    _audioFocusManager.notifyMainAudioStopped();
  }

  Future<void> seek(Duration position, {bool showBuffering = false}) async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');

    debugPrint(
      'Seek to ${position.inSeconds}s (showBuffering: $showBuffering)',
    );

    // 只有在明确需要时才显示缓冲状态（比如用户拖拽进度条）
    if (showBuffering && _isNetworkSource) {
      _currentState = MindraPlayerState.buffering;
      _playerStateController.add(MindraPlayerState.buffering);
    }

    await _audioPlayer!.seek(position);
  }

  Future<void> setVolume(double volume) async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');
    await _audioPlayer!.setVolume(volume);
  }

  // Getters
  MindraPlayerState get currentState => _currentState;
  double get bufferProgress => _bufferProgress;
  bool get isNetworkSource => _isNetworkSource;

  // Streams
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<MindraPlayerState> get playerStateStream =>
      _playerStateController.stream;
  Stream<double> get bufferProgressStream => _bufferProgressController.stream;

  Future<Duration?> getDuration() async {
    if (_audioPlayer == null) return null;
    return _audioPlayer!.getDuration();
  }

  /// 获取媒体文件时长而不加载
  static Future<Duration?> getMediaDuration(String path) async {
    try {
      final tempPlayer = AudioPlayer();
      Duration? duration;

      if (path.startsWith('http://') || path.startsWith('https://')) {
        await tempPlayer.setSourceUrl(path);
      } else {
        await tempPlayer.setSourceDeviceFile(path);
      }

      duration = await tempPlayer.getDuration();
      await tempPlayer.dispose();
      return duration;
    } catch (e) {
      debugPrint('Error getting media duration: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      // 首先停止播放
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
      }

      // 通知音频焦点管理器停止
      _audioFocusManager.notifyMainAudioStopped();

      // 释放音频播放器
      if (_audioPlayer != null) {
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }

      // 关闭所有流控制器
      await _playingController.close();
      await _positionController.close();
      await _durationController.close();
      await _playerStateController.close();
      await _bufferProgressController.close();

      debugPrint('MindraAudioPlayer disposed successfully');
    } catch (e) {
      debugPrint('Error during audio player disposal: $e');
      // 即使出错也要尝试清理基本资源
      _audioPlayer = null;
    }
  }
}
