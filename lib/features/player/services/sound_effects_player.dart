import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_focus_manager.dart';

/// 统一的音效播放器，使用单一AudioPlayer实例管理所有音效
class SoundEffectsPlayer {
  static final SoundEffectsPlayer _instance = SoundEffectsPlayer._internal();
  factory SoundEffectsPlayer() => _instance;
  SoundEffectsPlayer._internal();

  // 使用单一音频播放器实例来减少系统音量控制条
  AudioPlayer? _audioPlayer;
  final Map<String, double> _volumes = {};
  double _masterVolume = 0.5; // 默认主音量设为0.5，更合理的初始值
  final AudioFocusManager _audioFocusManager = AudioFocusManager();

  // 当前正在播放的音效
  String? _currentPlayingEffect;
  bool _isPreviewMode = false;

  // 状态变化回调
  VoidCallback? _onStateChanged;

  // 音效文件路径映射
  final Map<String, String> _soundPaths = {
    'rain': 'audio/effects/rain.mp3',
    'ocean': 'audio/effects/ocean.mp3',
    'wind_chimes': 'audio/effects/wind_chimes.mp3',
    'birds': 'audio/effects/birds.mp3',
  };

  // 设置状态变化回调
  void setStateChangeCallback(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  // 初始化音效播放器
  Future<void> initialize() async {
    debugPrint('Initializing sound effects player...');

    try {
      // 创建单一音频播放器实例
      _audioPlayer = AudioPlayer();

      // 配置音频上下文
      await _configureAudioContext();

      // 设置播放器监听器
      _setupPlayerListeners();

      // 设置主音频状态变化回调
      _audioFocusManager.setMainAudioStateCallback(_onMainAudioStateChanged);

      // 加载保存的设置
      await _loadSettings();

      debugPrint('Sound effects player initialization complete');
    } catch (e) {
      debugPrint('Error initializing sound effects player: $e');
      rethrow;
    }
  }

  // 配置音频上下文
  Future<void> _configureAudioContext() async {
    if (_audioPlayer == null) return;

    try {
      final audioContext = _audioFocusManager.getSoundEffectContext();
      await _audioPlayer!.setAudioContext(audioContext);
      debugPrint('Sound effects audio context configured');
    } catch (e) {
      debugPrint('Warning - Failed to configure audio context: $e');
    }
  }

  // 设置播放器监听器
  void _setupPlayerListeners() {
    if (_audioPlayer == null) return;

    _audioPlayer!.onPlayerStateChanged.listen((state) {
      debugPrint('Sound effects player state: $state');
      if (state == PlayerState.completed) {
        // 音效播放完成，如果是循环模式则重新开始
        _handlePlaybackCompleted();
      }
    });
  }

  // 处理播放完成
  Future<void> _handlePlaybackCompleted() async {
    if (_currentPlayingEffect != null && !_isPreviewMode) {
      // 正常播放模式下，重新开始播放当前音效
      final effectId = _currentPlayingEffect!;
      final volume = _volumes[effectId] ?? 0.0;
      if (volume > 0) {
        await _playEffect(effectId, volume);
      }
    }
  }

  // 主音频状态变化回调
  void _onMainAudioStateChanged(bool isMainAudioPlaying) {
    debugPrint('Main audio state changed: $isMainAudioPlaying');
    if (isMainAudioPlaying) {
      _resumeActiveEffects();
    } else {
      _pauseCurrentEffect();
    }
  }

  // 恢复激活的音效
  Future<void> _resumeActiveEffects() async {
    // 找到当前应该播放的音效（音量最高的）
    String? effectToPlay;
    double maxVolume = 0.0;

    for (final entry in _volumes.entries) {
      if (entry.value > maxVolume) {
        maxVolume = entry.value;
        effectToPlay = entry.key;
      }
    }

    if (effectToPlay != null && maxVolume > 0) {
      await _playEffect(effectToPlay, maxVolume);
    }
  }

  // 暂停当前音效
  Future<void> _pauseCurrentEffect() async {
    if (_audioPlayer != null && _currentPlayingEffect != null) {
      try {
        await _audioPlayer!.pause();
        debugPrint('Paused current sound effect: $_currentPlayingEffect');
      } catch (e) {
        debugPrint('Error pausing current effect: $e');
      }
    }
  }

  // 播放指定音效
  Future<void> _playEffect(String effectId, double volume) async {
    if (_audioPlayer == null || !_soundPaths.containsKey(effectId)) {
      return;
    }

    try {
      // 如果当前正在播放其他音效，先停止
      if (_currentPlayingEffect != effectId) {
        await _audioPlayer!.stop();
      }

      // 设置音效文件
      final assetPath = _soundPaths[effectId]!;
      await _audioPlayer!.setSource(AssetSource(assetPath));
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);

      // 设置音量
      final finalVolume = volume * _masterVolume;
      await _audioPlayer!.setVolume(finalVolume);

      // 只有在主音频播放时或预览模式下才开始播放
      if (_audioFocusManager.canPlaySoundEffects() || _isPreviewMode) {
        await _audioPlayer!.resume();
        _currentPlayingEffect = effectId;
        debugPrint('Playing effect $effectId with volume $finalVolume');
      } else {
        _currentPlayingEffect = effectId;
        debugPrint('Effect $effectId ready but waiting for main audio');
      }
    } catch (e) {
      debugPrint('Error playing effect $effectId: $e');
    }
  }

  // 停止当前音效
  Future<void> _stopCurrentEffect() async {
    if (_audioPlayer != null) {
      try {
        await _audioPlayer!.stop();
        _currentPlayingEffect = null;
        debugPrint('Stopped current sound effect');
      } catch (e) {
        debugPrint('Error stopping current effect: $e');
      }
    }
  }

  // 切换音效
  Future<void> toggleEffect(String effectId, double volume) async {
    if (!_soundPaths.containsKey(effectId)) {
      debugPrint('Unknown effect ID: $effectId');
      return;
    }

    _volumes[effectId] = volume;

    try {
      if (volume > 0) {
        // 停止其他音效，播放当前音效
        for (final otherEffect in _volumes.keys) {
          if (otherEffect != effectId) {
            _volumes[otherEffect] = 0.0;
          }
        }
        await _playEffect(effectId, volume);
      } else {
        // 停止当前音效
        if (_currentPlayingEffect == effectId) {
          await _stopCurrentEffect();
        }
      }

      await _saveSettings();
      _onStateChanged?.call();
    } catch (e) {
      debugPrint('Error toggling effect $effectId: $e');
    }
  }

  // 设置主音量
  Future<void> setMasterVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);

    // 更新当前播放音效的音量
    if (_audioPlayer != null && _currentPlayingEffect != null) {
      final effectVolume = _volumes[_currentPlayingEffect!] ?? 0.0;
      final finalVolume = effectVolume * _masterVolume;
      try {
        await _audioPlayer!.setVolume(finalVolume);
      } catch (e) {
        debugPrint('Error updating master volume: $e');
      }
    }

    await _saveSettings();
    _onStateChanged?.call();
  }

  // 检查是否有激活的音效
  bool hasActiveEffects() {
    return _volumes.values.any((volume) => volume > 0);
  }

  // 预览音效（临时播放）
  Future<void> previewEffect(String effectId, double volume) async {
    if (!_soundPaths.containsKey(effectId)) {
      debugPrint('Unknown effect ID for preview: $effectId');
      return;
    }

    try {
      _isPreviewMode = true;
      await _playEffect(effectId, volume);
      debugPrint('Started preview for effect $effectId with volume $volume');
    } catch (e) {
      debugPrint('Error previewing effect $effectId: $e');
    }
  }

  // 停止预览
  Future<void> stopPreview() async {
    try {
      _isPreviewMode = false;
      await _stopCurrentEffect();

      // 恢复正常播放状态
      await _resumeActiveEffects();
      debugPrint('Stopped preview mode');
    } catch (e) {
      debugPrint('Error stopping preview: $e');
    }
  }

  // 获取当前音量设置
  Map<String, double> get currentVolumes => Map.from(_volumes);
  double get masterVolume => _masterVolume;

  // 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载主音量
      _masterVolume = prefs.getDouble('sound_effects_master_volume') ?? 0.5;

      // 加载各音效音量
      for (final effectId in _soundPaths.keys) {
        _volumes[effectId] =
            prefs.getDouble('sound_effect_volume_$effectId') ?? 0.0;
      }

      debugPrint('Settings loaded: volumes=$_volumes, master=$_masterVolume');
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 保存主音量
      await prefs.setDouble('sound_effects_master_volume', _masterVolume);

      // 保存各音效音量
      for (final entry in _volumes.entries) {
        await prefs.setDouble('sound_effect_volume_${entry.key}', entry.value);
      }

      debugPrint('Settings saved successfully');
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  // 释放资源
  Future<void> dispose() async {
    try {
      // 停止当前播放
      await _stopCurrentEffect();

      // 释放音频播放器
      if (_audioPlayer != null) {
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }

      _volumes.clear();
      _currentPlayingEffect = null;

      debugPrint('SoundEffectsPlayer disposed successfully');
    } catch (e) {
      debugPrint('Error during disposal: $e');
    }
  }
}
