import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../media/domain/entities/media_item.dart' as mindra;

/// 处理系统媒体控制的AudioHandler实现
class MindraAudioHandler extends BaseAudioHandler
    with SeekHandler, QueueHandler {
  // 当前播放的媒体信息
  mindra.MediaItem? _currentMindraMedia;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isFavorited = false;
  AudioProcessingState _processingState = AudioProcessingState.idle;

  // 回调函数，用于通知外部控制器
  Function(String action)? _onSystemControlCallback;

  MindraAudioHandler() {
    // 不在构造函数中广播状态，等待媒体加载
  }

  // 设置系统控制回调
  void setSystemControlCallback(Function(String action)? callback) {
    _onSystemControlCallback = callback;
  }

  /// 广播当前播放状态给系统
  void _broadcastState() {
    playbackState.add(
      PlaybackState(
        controls: _getControls(),
        systemActions: const {
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [1, 2, 3], // 上一首、播放/暂停、下一首
        processingState: _processingState,
        playing: _isPlaying,
        updatePosition: _position,
        bufferedPosition: _position,
        speed: _isPlaying ? 1.0 : 0.0, // 播放时速度为1.0，暂停时为0.0
        queueIndex: 0,
        // 添加更多状态信息
        repeatMode: AudioServiceRepeatMode.none,
        shuffleMode: AudioServiceShuffleMode.none,
        // 系统更新时间
        updateTime: DateTime.now(),
      ),
    );
  }

  /// 根据播放状态获取控制按钮
  List<MediaControl> _getControls() {
    final favoriteIcon = _isFavorited
        ? 'drawable/ic_heart_filled'
        : 'drawable/ic_heart_empty';
    debugPrint(
      '_getControls: _isFavorited=$_isFavorited, using icon: $favoriteIcon',
    );

    return [
      // 收藏按钮
      MediaControl.custom(
        androidIcon: favoriteIcon,
        label: _isFavorited ? '取消收藏' : '收藏',
        name: 'favorite',
      ),
      MediaControl.skipToPrevious,
      _isPlaying ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
    ];
  }

  /// 加载音频媒体
  Future<void> loadAudio(mindra.MediaItem media) async {
    try {
      _currentMindraMedia = media;
      _isFavorited = media.isFavorite;

      // 创建 AudioService 的 MediaItem
      final audioServiceMediaItem = MediaItem(
        id: media.id,
        album: media.category.name,
        title: media.title,
        artist: '正念冥想',
        duration: Duration(seconds: media.duration),
        artUri: Uri.parse(
          'android.resource://com.mindra.app/mipmap/launcher_icon',
        ), // 使用 Android 应用图标
        extras: {'filePath': media.filePath, 'category': media.category.name},
      );

      // 强制更新媒体信息和队列 - 这是关键！
      mediaItem.add(audioServiceMediaItem);
      queue.add([audioServiceMediaItem]); // 重置队列为当前单曲

      // 重置播放状态
      _position = Duration.zero; // 重置位置
      _duration = Duration(seconds: media.duration);

      // 立即广播新的状态以确保系统媒体控制更新
      _broadcastState();

      debugPrint(
        'Audio loaded in handler: ${media.title} with icon - MediaItem updated',
      );
    } catch (e) {
      debugPrint('Error loading audio in handler: $e');
      rethrow;
    }
  }

  // 系统媒体控制回调实现
  @override
  Future<void> play() async {
    debugPrint('AudioHandler: Play command received from system');
    _onSystemControlCallback?.call('play');
  }

  @override
  Future<void> pause() async {
    debugPrint('AudioHandler: Pause command received from system');
    _onSystemControlCallback?.call('pause');
  }

  @override
  Future<void> stop() async {
    debugPrint('AudioHandler: Stop command received from system');
    _onSystemControlCallback?.call('stop');
  }

  @override
  Future<void> seek(Duration position) async {
    debugPrint(
      'AudioHandler: Seek to ${position.inSeconds}s received from system',
    );
    _onSystemControlCallback?.call('seek:${position.inSeconds}');
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('AudioHandler: Skip to next received from system');
    _onSystemControlCallback?.call('skipToNext');
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('AudioHandler: Skip to previous received from system');
    _onSystemControlCallback?.call('skipToPrevious');
  }

  @override
  Future<void> fastForward() async {
    debugPrint('AudioHandler: Fast forward received from system');
    _onSystemControlCallback?.call('fastForward');
  }

  @override
  Future<void> rewind() async {
    debugPrint('AudioHandler: Rewind received from system');
    _onSystemControlCallback?.call('rewind');
  }

  /// 从外部更新播放状态（由 GlobalPlayerService 调用）
  void updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    AudioProcessingState? processingState,
  }) {
    _isPlaying = isPlaying;
    _position = position;

    // 只有时长发生显著变化时才更新 MediaItem
    bool needUpdateMediaItem = false;
    if ((duration.inSeconds - _duration.inSeconds).abs() > 2) {
      _duration = duration;
      needUpdateMediaItem = true;
    }

    if (processingState != null) {
      _processingState = processingState;
    }

    // 更新 MediaItem（只在需要时）
    if (needUpdateMediaItem && _currentMindraMedia != null) {
      final updatedMediaItem = MediaItem(
        id: _currentMindraMedia!.id,
        album: _currentMindraMedia!.category.name,
        title: _currentMindraMedia!.title,
        artist: '正念冥想',
        duration: duration, // 使用最新的时长
        artUri: Uri.parse(
          'android.resource://com.mindra.app/mipmap/launcher_icon',
        ), // 使用 Android 应用图标
        extras: {
          'filePath': _currentMindraMedia!.filePath,
          'category': _currentMindraMedia!.category.name,
        },
      );
      mediaItem.add(updatedMediaItem);
    }

    _broadcastState();
  }

  // 获取当前播放状态（供外部调用）
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  mindra.MediaItem? get currentMedia => _currentMindraMedia;

  @override
  Future<void> onTaskRemoved() async {
    // 当应用从最近任务中移除时的处理
    await stop();
  }

  /// 处理自定义动作（如收藏）
  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'favorite') {
      debugPrint(
        'System favorite toggle requested, current state: $_isFavorited',
      );
      _onSystemControlCallback?.call('favorite');
    }
    return super.customAction(name, extras);
  }

  /// 更新收藏状态并刷新控制按钮
  void updateFavoriteStatus(bool isFavorited) {
    debugPrint(
      'AudioHandler: Updating favorite status from $_isFavorited to $isFavorited',
    );
    _isFavorited = isFavorited;
    _broadcastState(); // 立即更新系统媒体控制显示
    debugPrint('AudioHandler: Favorite status updated and state broadcasted');
  }

  void dispose() {
    // AudioHandler 不再有独立的播放器，无需清理
  }
}
