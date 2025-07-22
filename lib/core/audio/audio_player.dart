import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../../features/player/services/audio_focus_manager.dart';

enum MindraPlayerState { stopped, playing, paused, completed, disposed }

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
          _playingController.add(true);
          _playerStateController.add(MindraPlayerState.playing);
          _audioFocusManager.notifyMainAudioStarted();
          break;
        case PlayerState.paused:
          _playingController.add(false);
          _playerStateController.add(MindraPlayerState.paused);
          _audioFocusManager.notifyMainAudioStopped();
          break;
        case PlayerState.stopped:
          _playingController.add(false);
          _positionController.add(Duration.zero);
          _playerStateController.add(MindraPlayerState.stopped);
          _audioFocusManager.notifyMainAudioStopped();
          break;
        case PlayerState.completed:
          _playingController.add(false);
          _positionController.add(Duration.zero);
          _playerStateController.add(MindraPlayerState.completed);
          _audioFocusManager.notifyMainAudioStopped();
          break;
        case PlayerState.disposed:
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
    });
  }

  Future<void> setFilePath(String filePath) async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');

    debugPrint('Setting file path: $filePath');
    await _audioPlayer!.setSourceDeviceFile(filePath);
    debugPrint('File loaded successfully');
  }

  Future<void> setUrl(String url) async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');

    debugPrint('Setting URL: $url');
    try {
      await _audioPlayer!.setSourceUrl(url);
      debugPrint('URL loaded successfully');
    } catch (e) {
      debugPrint('Failed to load URL: $e');
      // 提供更友好的错误信息，但不做平台特殊处理
      if (e.toString().contains('gst-resource-error')) {
        throw Exception('网络音频播放失败，请检查网络连接或尝试下载到本地播放');
      }
      rethrow;
    }
  }

  Future<void> play() async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');

    debugPrint('Play called');
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

  Future<void> seek(Duration position) async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');

    debugPrint('Seek to ${position.inSeconds}s');
    await _audioPlayer!.seek(position);
  }

  Future<void> setVolume(double volume) async {
    if (_audioPlayer == null) throw Exception('Audio player not initialized');
    await _audioPlayer!.setVolume(volume);
  }

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<MindraPlayerState> get playerStateStream =>
      _playerStateController.stream;

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

      debugPrint('MindraAudioPlayer disposed successfully');
    } catch (e) {
      debugPrint('Error during audio player disposal: $e');
      // 即使出错也要尝试清理基本资源
      _audioPlayer = null;
    }
  }
}
