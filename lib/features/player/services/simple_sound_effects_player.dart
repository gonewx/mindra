import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_focus_manager.dart';

class SimpleSoundEffectsPlayer {
  static final SimpleSoundEffectsPlayer _instance =
      SimpleSoundEffectsPlayer._internal();
  factory SimpleSoundEffectsPlayer() => _instance;
  SimpleSoundEffectsPlayer._internal();

  final Map<String, AudioPlayer> _players = {};
  final Map<String, double> _volumes = {};
  double _masterVolume = 1.0; // 默认主音量设为1.0
  final AudioFocusManager _audioFocusManager = AudioFocusManager();
  
  // 状态变化回调
  VoidCallback? _onStateChanged;

  // 音效文件路径映射
  final Map<String, String> _soundPaths = {
    'rain': 'audio/effects/rain.mp3',
    'ocean': 'audio/effects/ocean.mp3',
    'wind_chimes': 'audio/effects/wind_chimes.mp3', // 统一使用wind_chimes
    'birds': 'audio/effects/birds.mp3',
  };

  // 设置状态变化回调
  void setStateChangeCallback(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  // 初始化音效播放器
  Future<void> initialize() async {
    debugPrint('Initializing sound effects player...');

    // 设置主音频状态变化回调
    _audioFocusManager.setMainAudioStateCallback(_onMainAudioStateChanged);

    // 先加载保存的设置
    await _loadSettings();

    for (final effectId in _soundPaths.keys) {
      debugPrint('Creating player for $effectId...');
      _players[effectId] = AudioPlayer();
      // 不在这里重置音量，保持从设置加载的值
      if (!_volumes.containsKey(effectId)) {
        _volumes[effectId] = 0.0;
      }

      try {
        debugPrint(
          'Loading sound effect: $effectId from ${_soundPaths[effectId]}',
        );

        // 使用音频焦点管理器获取音效播放器的配置
        final audioContext = _audioFocusManager.getSoundEffectContext();
        await _players[effectId]!.setAudioContext(audioContext);

        await _players[effectId]!.setSource(
          AssetSource(_soundPaths[effectId]!),
        );
        await _players[effectId]!.setReleaseMode(ReleaseMode.loop);

        // 等待音频文件完全加载
        await Future.delayed(const Duration(milliseconds: 500));

        // 验证音效文件是否正确加载
        final duration = await _players[effectId]!.getDuration();
        debugPrint(
          'Sound effect $effectId duration: ${duration?.inMilliseconds}ms',
        );

        if (duration == null) {
          debugPrint(
            'WARNING: Sound effect $effectId failed to load - duration is null',
          );
        } else {
          debugPrint('Sound effect $effectId loaded successfully');
        }

        // 设置较低的初始音量
        await _players[effectId]!.setVolume(0.0);
        debugPrint('Successfully configured sound effect: $effectId');
      } catch (e) {
        debugPrint('Failed to load sound effect $effectId: $e');
        debugPrint('Error details: ${e.toString()}');
      }
    }

    // 恢复之前保存的播放状态
    await _restorePlaybackState();

    debugPrint('Sound effects player initialization complete');
  }

  // 加载保存的设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载主音量
      _masterVolume = prefs.getDouble('sound_effects_master_volume') ?? 1.0;

      // 加载各个音效的音量
      for (final effectId in _soundPaths.keys) {
        final volume = prefs.getDouble('sound_effect_volume_$effectId') ?? 0.0;
        _volumes[effectId] = volume;
      }

      debugPrint(
        'Loaded sound effects settings: master=$_masterVolume, volumes=$_volumes',
      );
    } catch (e) {
      debugPrint('Failed to load sound effects settings: $e');
    }
  }

  // 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 保存主音量
      await prefs.setDouble('sound_effects_master_volume', _masterVolume);

      // 保存各个音效的音量
      for (final entry in _volumes.entries) {
        await prefs.setDouble('sound_effect_volume_${entry.key}', entry.value);
      }

      debugPrint('Saved sound effects settings');
    } catch (e) {
      debugPrint('Failed to save sound effects settings: $e');
    }
  }

  // 恢复播放状态
  Future<void> _restorePlaybackState() async {
    debugPrint('Restoring sound effects playback state...');

    for (final entry in _volumes.entries) {
      if (entry.value > 0) {
        debugPrint(
          'Restoring playback for ${entry.key} at volume ${entry.value}',
        );
        await toggleEffect(entry.key, entry.value);
      }
    }
  }

  // 切换音效开关
  Future<void> toggleEffect(String effectId, double volume) async {
    if (!_players.containsKey(effectId)) {
      debugPrint(
        'Sound effect $effectId not found, attempting to reinitialize...',
      );
      // 如果音效播放器不存在，尝试重新初始化
      await _initializeEffect(effectId);
      if (!_players.containsKey(effectId)) {
        debugPrint('Failed to reinitialize sound effect $effectId');
        return;
      }
    }

    final player = _players[effectId]!;
    _volumes[effectId] = volume;

    try {
      if (volume > 0) {
        // 开启音效 - 检查是否可以播放背景音效
        if (!_audioFocusManager.canPlaySoundEffects()) {
          debugPrint('Cannot play sound effects - main audio not playing');
          // 仍然保存音量设置，但不实际播放
          await _saveSettings();
          _audioFocusManager.notifySoundEffectsChanged(hasActiveEffects());
          return;
        }

        // 使用音频焦点管理器建议的音量
        final suggestedVolume = _audioFocusManager
            .getSuggestedSoundEffectVolume();
        final finalVolume = (volume * _masterVolume * suggestedVolume).clamp(
          0.0,
          1.0,
        ); // 提高最大音量限制到1.0

        debugPrint(
          'Setting volume for $effectId: $finalVolume (input: $volume, master: $_masterVolume, suggested: $suggestedVolume)',
        );

        // 检查音频文件是否已加载
        final duration = await player.getDuration();
        if (duration == null) {
          debugPrint('ERROR: Cannot play $effectId - audio file not loaded');
          // 尝试重新加载音频文件
          debugPrint('Attempting to reload audio file for $effectId...');
          try {
            await player.setSource(AssetSource(_soundPaths[effectId]!));
            await Future.delayed(const Duration(milliseconds: 1000));
            final retryDuration = await player.getDuration();
            if (retryDuration == null) {
              debugPrint(
                'ERROR: Retry failed for $effectId - audio file may be corrupted',
              );
              return;
            } else {
              debugPrint(
                'Successfully reloaded $effectId, duration: ${retryDuration.inMilliseconds}ms',
              );
            }
          } catch (e) {
            debugPrint('Failed to reload $effectId: $e');
            return;
          }
        } else {
          debugPrint(
            'Audio file $effectId duration: ${duration.inMilliseconds}ms',
          );
        }

        // 设置音量并开始播放
        await player.setVolume(finalVolume);
        debugPrint('Starting playback for $effectId...');

        try {
          // 尝试使用 play() 而不是 resume()
          await player.play(AssetSource(_soundPaths[effectId]!));

          // 等待一小段时间让播放开始
          await Future.delayed(const Duration(milliseconds: 200));

          // 检查播放状态
          final position = await player.getCurrentPosition();
          final currentDuration = await player.getDuration();
          debugPrint(
            'Sound effect $effectId status: position=${position?.inMilliseconds}ms, duration=${currentDuration?.inMilliseconds}ms',
          );

          debugPrint('Started playing $effectId at volume $finalVolume');
        } catch (e) {
          debugPrint('Error starting playback for $effectId: $e');
        }
      } else {
        // 关闭音效
        debugPrint('Stopping $effectId...');
        await player.pause();
        debugPrint('Stopped playing $effectId');
      }

      // 保存状态更改
      await _saveSettings();

      // 通知音频焦点管理器背景音效状态变化
      _audioFocusManager.notifySoundEffectsChanged(hasActiveEffects());
      
      // 通知状态变化
      _onStateChanged?.call();
    } catch (e) {
      debugPrint('Error toggling sound effect $effectId: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  // 初始化单个音效
  Future<void> _initializeEffect(String effectId) async {
    if (!_soundPaths.containsKey(effectId)) {
      debugPrint('Unknown effect ID: $effectId');
      return;
    }

    try {
      debugPrint('Initializing effect: $effectId');
      _players[effectId] = AudioPlayer();
      _volumes[effectId] = 0.0;

      // 使用音频焦点管理器获取音效播放器的配置
      final audioContext = _audioFocusManager.getSoundEffectContext();
      await _players[effectId]!.setAudioContext(audioContext);

      await _players[effectId]!.setSource(AssetSource(_soundPaths[effectId]!));
      await _players[effectId]!.setReleaseMode(ReleaseMode.loop);

      // 等待音频文件完全加载
      await Future.delayed(const Duration(milliseconds: 500));

      // 验证音效文件是否正确加载
      final duration = await _players[effectId]!.getDuration();
      debugPrint(
        'Sound effect $effectId duration: ${duration?.inMilliseconds}ms',
      );

      if (duration == null) {
        debugPrint(
          'WARNING: Sound effect $effectId failed to load - duration is null',
        );
      } else {
        debugPrint('Sound effect $effectId loaded successfully');
      }

      // 设置较低的初始音量
      await _players[effectId]!.setVolume(0.0);
      debugPrint('Successfully configured sound effect: $effectId');
    } catch (e) {
      debugPrint('Failed to initialize sound effect $effectId: $e');
      debugPrint('Error details: ${e.toString()}');
    }
  }

  // 主音频状态变化回调
  void _onMainAudioStateChanged(bool isPlaying) {
    debugPrint('Main audio state changed: $isPlaying');

    if (isPlaying) {
      // 主音频开始播放，恢复所有已选择的背景音效
      _resumeSelectedEffects();
    } else {
      // 主音频停止播放，暂停所有背景音效（但不改变选择状态）
      _pauseAllEffects();
    }
  }

  // 恢复所有已选择的背景音效
  Future<void> _resumeSelectedEffects() async {
    for (final entry in _volumes.entries) {
      if (entry.value > 0) {
        await resumeEffect(entry.key);
      }
    }
  }

  // 暂停所有背景音效（不改变音量设置）
  Future<void> _pauseAllEffects() async {
    for (final effectId in _volumes.keys) {
      await pauseEffect(effectId);
    }
  }

  // 设置主音量
  Future<void> setMasterVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);

    // 获取音频焦点管理器建议的音量
    final suggestedVolume = _audioFocusManager.getSuggestedSoundEffectVolume();

    // 更新所有正在播放的音效音量
    for (final effectId in _volumes.keys) {
      if (_volumes[effectId]! > 0) {
        final player = _players[effectId];
        if (player != null) {
          // 使用建议的音量计算，确保不影响主音频
          final effectVolume = _volumes[effectId]!;
          final finalVolume = (effectVolume * _masterVolume * suggestedVolume)
              .clamp(0.0, 1.0); // 提高最大音量限制到1.0
          await player.setVolume(finalVolume);
        }
      }
    }
    debugPrint('Sound effects master volume set to: $_masterVolume');

    // 保存主音量设置
    await _saveSettings();
    
    // 通知状态变化
    _onStateChanged?.call();
  }

  // 暂停音效（不改变音量设置）
  Future<void> pauseEffect(String effectId) async {
    if (!_players.containsKey(effectId)) return;

    final player = _players[effectId]!;
    try {
      debugPrint('Pausing effect: $effectId');
      await player.pause();
    } catch (e) {
      debugPrint('Failed to pause sound effect $effectId: $e');
    }
  }

  // 恢复音效播放
  Future<void> resumeEffect(String effectId) async {
    if (!_players.containsKey(effectId)) return;

    final player = _players[effectId]!;
    final volume = _volumes[effectId] ?? 0.0;

    if (volume > 0) {
      try {
        // 获取音频焦点管理器建议的音量
        final suggestedVolume = _audioFocusManager
            .getSuggestedSoundEffectVolume();
        final finalVolume = (volume * _masterVolume * suggestedVolume).clamp(
          0.0,
          1.0,
        );

        debugPrint('Resuming effect: $effectId with volume $finalVolume');
        await player.setVolume(finalVolume);
        await player.resume();
      } catch (e) {
        debugPrint('Failed to resume sound effect $effectId: $e');
      }
    }
  }

  // 测试音效播放（使用最大音量）
  Future<void> testEffect(String effectId) async {
    if (!_players.containsKey(effectId)) {
      debugPrint('Effect $effectId not found');
      return;
    }

    final player = _players[effectId]!;
    try {
      debugPrint('Testing effect $effectId with full volume');
      await player.setVolume(0.8); // 设置适中的试听音量
      await player.play(AssetSource(_soundPaths[effectId]!));

      // 等待一下让播放开始
      await Future.delayed(const Duration(milliseconds: 500));

      // 获取播放状态
      final position = await player.getCurrentPosition();
      final duration = await player.getDuration();
      debugPrint(
        'Test playback status: position=${position?.inMilliseconds}ms, duration=${duration?.inMilliseconds}ms',
      );
    } catch (e) {
      debugPrint('Error testing effect $effectId: $e');
    }
  }

    // 预览音效播放（临时播放，不保存状态）
  Future<void> previewEffect(String effectId) async {
    if (!_players.containsKey(effectId)) {
      debugPrint('Effect $effectId not found for preview');
      return;
    }
    
    // 检查是否可以预览音效
    if (!_audioFocusManager.canPreviewSoundEffects()) {
      debugPrint('Cannot preview sound effects at this time');
      return;
    }
    
    final player = _players[effectId]!;
    try {
      debugPrint('Previewing effect $effectId');
      // 使用适中的预览音量
      await player.setVolume(0.6);
      await player.play(AssetSource(_soundPaths[effectId]!));
      debugPrint('Started previewing effect $effectId');
    } catch (e) {
      debugPrint('Error previewing effect $effectId: $e');
    }
  }

  // 停止所有音效
  Future<void> stopAllEffects() async {
    for (final effectId in _volumes.keys) {
      await toggleEffect(effectId, 0.0);
    }
  }

  // 获取当前音量设置
  Map<String, double> get currentVolumes => Map.from(_volumes);
  double get masterVolume => _masterVolume;

  // 检查是否有任何背景音效正在播放
  bool hasActiveEffects() {
    return _volumes.values.any((volume) => volume > 0);
  }

  // 释放资源
  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
    _volumes.clear();
  }
}
