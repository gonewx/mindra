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
  double _masterVolume = 0.5;
  final AudioFocusManager _audioFocusManager = AudioFocusManager();

  // 音效文件路径映射
  final Map<String, String> _soundPaths = {
    'rain': 'audio/effects/rain.mp3',
    'ocean': 'audio/effects/ocean.mp3',
    'wind_chimes': 'audio/effects/wind_chimes.mp3', // 统一使用wind_chimes
    'birds': 'audio/effects/birds.mp3',
  };

  // 初始化音效播放器
  Future<void> initialize() async {
    debugPrint('Initializing sound effects player...');

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
      _masterVolume = prefs.getDouble('sound_effects_master_volume') ?? 0.5;

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
        // 开启音效 - 使用音频焦点管理器建议的音量
        final suggestedVolume = _audioFocusManager
            .getSuggestedSoundEffectVolume();
        final finalVolume = (volume * _masterVolume * suggestedVolume).clamp(
          0.0,
          0.5,
        ); // 限制最大音量为0.5，确保不会过响

        debugPrint(
          'Setting volume for $effectId: $finalVolume (input: $volume, master: $_masterVolume)',
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
              .clamp(0.0, 0.5); // 限制最大音量为0.5，避免过响
          await player.setVolume(finalVolume);
        }
      }
    }
    debugPrint('Sound effects master volume set to: $_masterVolume');

    // 保存主音量设置
    await _saveSettings();
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
