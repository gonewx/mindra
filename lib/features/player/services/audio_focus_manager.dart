import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// 音频焦点管理器 - 协调主音频和背景音效的播放
class AudioFocusManager {
  static final AudioFocusManager _instance = AudioFocusManager._internal();
  factory AudioFocusManager() => _instance;
  AudioFocusManager._internal();

  bool _isMainAudioPlaying = false;
  bool _isSoundEffectsEnabled = false;

  /// 配置主音频播放器的音频上下文
  AudioContext getMainAudioContext() {
    return AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers, // 允许与其他音频混合
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        // 主音频使用 gain，获得音频焦点但允许背景音效混合
        audioFocus: AndroidAudioFocus.gain,
      ),
    );
  }

  /// 配置背景音效播放器的音频上下文
  AudioContext getSoundEffectContext() {
    return AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback, // 使用播放类别以支持 mixWithOthers
        options: {
          AVAudioSessionOptions.mixWithOthers, // 允许与其他音频混合
          AVAudioSessionOptions.duckOthers, // 降低其他音频音量
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music, // 改为音乐类型
        usageType: AndroidUsageType.media, // 改为媒体类型
        // 背景音效使用 gainTransientMayDuck，允许与主音频混合
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
    );
  }

  /// 通知主音频开始播放
  void notifyMainAudioStarted() {
    _isMainAudioPlaying = true;
    debugPrint('AudioFocusManager: Main audio started');
  }

  /// 通知主音频停止播放
  void notifyMainAudioStopped() {
    _isMainAudioPlaying = false;
    debugPrint('AudioFocusManager: Main audio stopped');
  }

  /// 通知背景音效状态改变
  void notifySoundEffectsChanged(bool enabled) {
    _isSoundEffectsEnabled = enabled;
    debugPrint(
      'AudioFocusManager: Sound effects ${enabled ? "enabled" : "disabled"}',
    );
  }

  /// 检查是否可以播放背景音效
  bool canPlaySoundEffects() {
    // 总是允许播放背景音效，不管主音频是否在播放
    return true;
  }

  /// 获取背景音效的建议音量
  double getSuggestedSoundEffectVolume() {
    // 如果主音频正在播放，稍微降低背景音效音量，但不要太低
    return _isMainAudioPlaying ? 0.6 : 0.8;
  }
}
