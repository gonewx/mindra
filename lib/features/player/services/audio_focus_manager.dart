import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// 音频焦点管理器 - 协调主音频和背景音效的播放，并处理其他应用的音频中断
class AudioFocusManager {
  static final AudioFocusManager _instance = AudioFocusManager._internal();
  factory AudioFocusManager() => _instance;
  AudioFocusManager._internal();

  bool _isMainAudioPlaying = false;
  bool _isSoundEffectsEnabled = false;
  bool _wasInterruptedByOtherApp = false; // 标记是否被其他应用中断

  // 回调函数，用于通知背景音效播放状态变化
  Function(bool)? _onMainAudioStateChanged;

  // 回调函数，用于通知音频中断状态变化
  Function(bool)? _onAudioInterruptionChanged;

  /// 配置主音频播放器的音频上下文 - 请求完整音频焦点以处理中断并支持后台播放
  AudioContext getMainAudioContext() {
    debugPrint(
      'Creating main audio context with AndroidAudioFocus.gain for interruption support and background playback',
    );

    return AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback, // 支持后台播放的类别
        options: {
          // 移除 mixWithOthers，让我们的音频能够被其他应用中断
          AVAudioSessionOptions.defaultToSpeaker, // 默认使用扬声器
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true, // 关键：保持设备唤醒，支持后台播放
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        // 关键：使用 gain 来请求完整音频焦点，这样当其他应用播放时我们会被中断
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
  void setMainAudioStateCallback(Function(bool)? callback) {
    _onMainAudioStateChanged = callback;
  }

  /// 设置音频中断状态变化回调
  void setAudioInterruptionCallback(Function(bool)? callback) {
    _onAudioInterruptionChanged = callback;
  }

  /// 通知主音频开始播放
  void notifyMainAudioStarted() {
    if (!_isMainAudioPlaying) {
      _isMainAudioPlaying = true;
      _wasInterruptedByOtherApp = false; // 重置中断标记
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

  /// 通知音频被其他应用中断
  void notifyAudioInterrupted() {
    debugPrint('🔴 AudioFocusManager.notifyAudioInterrupted() called');
    debugPrint(
      '🔴 Current state: _isMainAudioPlaying=$_isMainAudioPlaying, _wasInterruptedByOtherApp=$_wasInterruptedByOtherApp',
    );
    debugPrint('🔴 Callback exists: ${_onAudioInterruptionChanged != null}');

    // 更主动的中断处理：无论当前状态如何，都标记为中断并触发回调
    if (!_wasInterruptedByOtherApp) {
      _wasInterruptedByOtherApp = true;
      _isMainAudioPlaying = false; // 确保标记为未播放

      debugPrint(
        '🔴 AudioFocusManager: Audio interrupted - immediately triggering callback',
      );

      // 立即触发中断回调
      _onAudioInterruptionChanged?.call(true);

      debugPrint('🔴 Audio interruption callback triggered successfully');
    } else {
      debugPrint('🔴 Audio interruption already marked - skipping duplicate');
    }
  }

  /// 通知音频中断恢复
  void notifyAudioInterruptionEnded() {
    if (_wasInterruptedByOtherApp) {
      _wasInterruptedByOtherApp = false;
      debugPrint('AudioFocusManager: Audio interruption ended');
      _onAudioInterruptionChanged?.call(false);
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

  /// 检查是否被其他应用中断
  bool get wasInterruptedByOtherApp => _wasInterruptedByOtherApp;

  /// 获取当前状态信息
  Map<String, dynamic> getStatus() {
    return {
      'isMainAudioPlaying': _isMainAudioPlaying,
      'isSoundEffectsEnabled': _isSoundEffectsEnabled,
      'wasInterruptedByOtherApp': _wasInterruptedByOtherApp,
      'canPlaySoundEffects': canPlaySoundEffects(),
      'canPreviewSoundEffects': canPreviewSoundEffects(),
    };
  }
}
