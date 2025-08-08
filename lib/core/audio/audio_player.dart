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
      // 延迟配置音频上下文，增加更多错误处理
      Future.microtask(() => _configureAudioContextSafely());
    } catch (e) {
      debugPrint('Failed to initialize audio player: $e');
      _currentState = MindraPlayerState.error;
      // 不重新抛出异常，允许应用继续运行
    }
  }

  Future<void> _configureAudioContextSafely() async {
    if (_audioPlayer == null) return;

    try {
      // 增加延迟以确保音频播放器完全初始化
      await Future.delayed(const Duration(milliseconds: 500));

      // 检查播放器是否仍然有效
      if (_audioPlayer == null) {
        debugPrint('Audio player was disposed before configuration');
        return;
      }

      final audioContext = _audioFocusManager.getMainAudioContext();
      await _audioPlayer!.setAudioContext(audioContext);
      debugPrint('Audio player context configured successfully');
    } catch (e) {
      debugPrint('Failed to configure audio context: $e');
      // 如果配置失败，尝试使用默认上下文
      try {
        if (_audioPlayer != null) {
          // 使用简化的音频上下文配置，但仍然请求音频焦点以支持中断
          final fallbackContext = AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: false,
              stayAwake: true,
              contentType: AndroidContentType.music,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.gain, // 请求完整音频焦点以支持中断
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {AVAudioSessionOptions.defaultToSpeaker}, // 保留扬声器选项
            ),
          );
          await _audioPlayer!.setAudioContext(fallbackContext);
          debugPrint('Fallback audio context configured');
        }
      } catch (fallbackError) {
        debugPrint(
          'Fallback audio context configuration also failed: $fallbackError',
        );
        // 继续运行，不抛出异常
      }
    }
  }

  void _setupListeners() {
    if (_audioPlayer == null) return;

    try {
      // 监听播放状态变化
      _audioPlayer!.onPlayerStateChanged.listen(
        (state) {
          debugPrint('Audio player state changed to: $state');
          try {
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
          } catch (e) {
            debugPrint('Error handling player state change: $e');
          }
        },
        onError: (error) {
          debugPrint('Player state stream error: $error');
          _currentState = MindraPlayerState.error;
          _playerStateController.add(MindraPlayerState.error);
        },
      );

      // 监听时长变化
      _audioPlayer!.onDurationChanged.listen(
        (duration) {
          try {
            _durationController.add(duration);
          } catch (e) {
            debugPrint('Error handling duration change: $e');
          }
        },
        onError: (error) {
          debugPrint('Duration stream error: $error');
        },
      );

      // 监听播放位置变化
      _audioPlayer!.onPositionChanged.listen(
        (position) {
          try {
            _positionController.add(position);

            // 计算缓冲进度（对于网络音频）
            if (_isNetworkSource) {
              _updateBufferProgress(position);
            }
          } catch (e) {
            debugPrint('Error handling position change: $e');
          }
        },
        onError: (error) {
          debugPrint('Position stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error setting up audio player listeners: $e');
      _currentState = MindraPlayerState.error;
      _playerStateController.add(MindraPlayerState.error);
    }

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
    if (_audioPlayer == null) {
      debugPrint('Cannot play: Audio player not initialized');
      _currentState = MindraPlayerState.error;
      _playerStateController.add(MindraPlayerState.error);
      return;
    }

    debugPrint('Play called, current state: $_currentState');

    try {
      // 只有在真正需要加载时才显示缓冲状态
      if (_currentState == MindraPlayerState.loading) {
        _currentState = MindraPlayerState.buffering;
        _playerStateController.add(MindraPlayerState.buffering);
      }

      // 根据 audioplayers 官方文档，对于 completed 状态需要特殊处理
      if (_currentState == MindraPlayerState.completed) {
        debugPrint(
          'Handling completed state - using seek then resume approach',
        );
        try {
          // 根据官方文档，当 ReleaseMode.stop 时，音频源仍然可用
          // 但 resume() 在 completed 状态下不会重新开始播放
          // 需要先 seek 到开头，然后 resume
          await _audioPlayer!.seek(Duration.zero);
          debugPrint('Seeked to beginning for completed state');

          // 等待一小段时间确保 seek 操作完成
          await Future.delayed(const Duration(milliseconds: 50));

          // 然后 resume 从开头开始播放
          await _audioPlayer!.resume();
          debugPrint('Resume() call completed for completed state');
        } catch (e) {
          debugPrint('Error in completed state handling: $e');
          rethrow;
        }
      } else {
        // 对于其他状态，直接调用 resume()
        debugPrint('Calling resume() for current state: $_currentState');
        await _audioPlayer!.resume();
        debugPrint('Resume() call completed');
      }

      _audioFocusManager.notifyMainAudioStarted();
      debugPrint('Audio focus notified, play operation completed successfully');
    } catch (e) {
      debugPrint('Error during play: $e');
      _currentState = MindraPlayerState.error;
      _playerStateController.add(MindraPlayerState.error);
    }
  }

  Future<void> pause() async {
    if (_audioPlayer == null) {
      debugPrint('Cannot pause: Audio player not initialized');
      return;
    }

    debugPrint('Pause called');
    try {
      await _audioPlayer!.pause();
      _audioFocusManager.notifyMainAudioStopped();
    } catch (e) {
      debugPrint('Error during pause: $e');
    }
  }

  Future<void> stop() async {
    if (_audioPlayer == null) {
      debugPrint('Cannot stop: Audio player not initialized');
      return;
    }

    debugPrint('Stop called');
    try {
      await _audioPlayer!.stop();
      _audioFocusManager.notifyMainAudioStopped();
    } catch (e) {
      debugPrint('Error during stop: $e');
    }
  }

  Future<void> seek(Duration position, {bool showBuffering = false}) async {
    if (_audioPlayer == null) {
      debugPrint('Cannot seek: Audio player not initialized');
      return;
    }

    debugPrint(
      'Seek to ${position.inSeconds}s (showBuffering: $showBuffering)',
    );

    try {
      // 只有在明确需要时才显示缓冲状态（比如用户拖拽进度条）
      if (showBuffering && _isNetworkSource) {
        _currentState = MindraPlayerState.buffering;
        _playerStateController.add(MindraPlayerState.buffering);
      }

      await _audioPlayer!.seek(position);
      debugPrint('Seek operation completed successfully');
    } catch (e) {
      debugPrint('Error during seek: $e');
      // 重新抛出错误，让调用者知道 seek 失败了
      rethrow;
    }
  }

  Future<void> setVolume(double volume) async {
    if (_audioPlayer == null) {
      debugPrint('Cannot set volume: Audio player not initialized');
      return;
    }
    try {
      await _audioPlayer!.setVolume(volume);
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    if (_audioPlayer == null) {
      debugPrint('Cannot set release mode: Audio player not initialized');
      return;
    }
    try {
      await _audioPlayer!.setReleaseMode(releaseMode);
      debugPrint('Release mode set to: $releaseMode');
    } catch (e) {
      debugPrint('Error setting release mode: $e');
    }
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

  /// 获取当前播放位置
  Future<Duration?> getCurrentPosition() async {
    if (_audioPlayer == null) return null;
    try {
      return await _audioPlayer!.getCurrentPosition();
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
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
