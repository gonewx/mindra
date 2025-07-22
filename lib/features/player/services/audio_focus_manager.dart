import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// 音频焦点管理器 - 协调主音频和背景音效的播放
class AudioFocusManager {
  static final AudioFocusManager _instance = AudioFocusManager._internal();
  factory AudioFocusManager() => _instance;
  AudioFocusManager._internal();

  bool _isMainAudioPlaying = false;
  bool _isSoundEffectsEnabled = false;

  // 回调函数，用于通知背景音效播放状态变化
  Function(bool)? _onMainAudioStateChanged;

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
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers, // 允许与其他音频混合
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.sonification, // 使用音效类型
        usageType: AndroidUsageType.assistanceAccessibility, // 使用辅助类型
        // 背景音效使用 gainTransientMayDuck，允许与主音频混合
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
    );
  }

  /// 设置主音频状态变化回调
  void setMainAudioStateCallback(Function(bool) callback) {
    _onMainAudioStateChanged = callback;
  }

  /// 通知主音频开始播放
  void notifyMainAudioStarted() {
    if (!_isMainAudioPlaying) {
      _isMainAudioPlaying = true;
      debugPrint('AudioFocusManager: Main audio started');
      _onMainAudioStateChanged?.call(true);
    }
  }

  /// 通知主音频停止播放
  void notifyMainAudioStopped() {
    if (_isMainAudioPlaying) {
      _isMainAudioPlaying = false;
      debugPrint('AudioFocusManager: Main audio stopped');
      _onMainAudioStateChanged?.call(false);
    }
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
    // 只有在主音频播放时才允许播放背景音效
    return _isMainAudioPlaying;
  }

  /// 检查是否可以试听背景音效
  bool canPreviewSoundEffects() {
    // 试听时总是允许，不管主音频是否在播放
    return true;
  }

  /// 获取当前状态信息
  Map<String, dynamic> getStatus() {
    return {
      'isMainAudioPlaying': _isMainAudioPlaying,
      'isSoundEffectsEnabled': _isSoundEffectsEnabled,
      'canPlaySoundEffects': canPlaySoundEffects(),
      'canPreviewSoundEffects': canPreviewSoundEffects(),
    };
  }
}
