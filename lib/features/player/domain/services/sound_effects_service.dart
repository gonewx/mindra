import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../player/data/models/sound_effect.dart';

class SoundEffectsService {
  static final SoundEffectsService _instance = SoundEffectsService._internal();
  factory SoundEffectsService() => _instance;
  SoundEffectsService._internal();

  final Map<String, AudioPlayer> _players = {};
  final Map<String, double> _volumes = {};
  double _masterVolume = 0.5;

  // 获取所有可用音效
  List<SoundEffect> get availableEffects => BuiltInSoundEffects.effects;

  // 获取当前音量设置
  Map<String, double> get currentVolumes => Map.from(_volumes);
  double get masterVolume => _masterVolume;

  // 初始化音效服务
  Future<void> initialize() async {
    for (final effect in availableEffects) {
      _players[effect.id] = AudioPlayer();
      _volumes[effect.id] = 0.0;

      // 预加载音效文件
      if (effect.assetPath != null) {
        try {
          await _players[effect.id]!.setSource(AssetSource(effect.assetPath!));
          await _players[effect.id]!.setReleaseMode(ReleaseMode.loop);
        } catch (e) {
          debugPrint('Failed to load sound effect ${effect.id}: $e');
        }
      }
    }
  }

  // 播放音效
  Future<void> playEffect(String effectId, {double? volume}) async {
    final player = _players[effectId];
    if (player == null) return;

    final effectVolume = volume ?? _volumes[effectId] ?? 0.0;
    final finalVolume = effectVolume * _masterVolume;

    try {
      await player.setVolume(finalVolume);
      if (finalVolume > 0) {
        await player.resume();
      } else {
        await player.pause();
      }

      _volumes[effectId] = effectVolume;
    } catch (e) {
      debugPrint('Failed to play sound effect $effectId: $e');
    }
  }

  // 停止音效
  Future<void> stopEffect(String effectId) async {
    final player = _players[effectId];
    if (player == null) return;

    try {
      await player.pause();
      _volumes[effectId] = 0.0;
    } catch (e) {
      debugPrint('Failed to stop sound effect $effectId: $e');
    }
  }

  // 设置音效音量
  Future<void> setEffectVolume(String effectId, double volume) async {
    _volumes[effectId] = volume.clamp(0.0, 1.0);
    await playEffect(effectId, volume: _volumes[effectId]);
  }

  // 设置主音量
  Future<void> setMasterVolume(double volume) async {
    _masterVolume = volume.clamp(0.0, 1.0);

    // 更新所有正在播放的音效音量
    for (final effectId in _volumes.keys) {
      if (_volumes[effectId]! > 0) {
        await playEffect(effectId);
      }
    }
  }

  // 切换音效开关
  Future<void> toggleEffect(String effectId) async {
    final currentVolume = _volumes[effectId] ?? 0.0;
    final newVolume = currentVolume > 0 ? 0.0 : 0.5;
    await setEffectVolume(effectId, newVolume);
  }

  // 停止所有音效
  Future<void> stopAllEffects() async {
    for (final effectId in _volumes.keys) {
      await stopEffect(effectId);
    }
  }

  // 应用预设
  Future<void> applyPreset(Map<String, double> preset) async {
    // 先停止所有音效
    await stopAllEffects();

    // 应用预设音量
    for (final entry in preset.entries) {
      await setEffectVolume(entry.key, entry.value);
    }
  }

  // 预设配置
  static const Map<String, Map<String, double>> presets = {
    'rainy_night': {'rain': 0.7, 'wind_chimes': 0.3},
    'ocean_breeze': {'ocean': 0.8, 'birds': 0.2},
    'forest_walk': {'forest': 0.6, 'birds': 0.4},
    'focus_mode': {'whitenoise': 0.6},
  };

  // 获取当前激活的音效列表
  List<String> getActiveSoundEffects() {
    return _volumes.entries
        .where((entry) => entry.value > 0.0)
        .map((entry) => entry.key)
        .toList();
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
