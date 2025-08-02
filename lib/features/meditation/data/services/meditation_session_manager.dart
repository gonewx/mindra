import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/web_storage_helper.dart';
import '../../domain/entities/meditation_session.dart';
import '../../../media/domain/entities/media_item.dart';
import 'dart:async';

class MeditationSessionManager {
  static const Uuid _uuid = Uuid();
  static MeditationSession? _currentSession;
  static DateTime? _sessionStartTime;
  static DateTime? _lastPauseTime;
  static int _totalPausedDuration = 0; // 总暂停时长(秒)
  static int _actualDuration = 0; // 实际播放时长(秒)
  static bool _isPaused = false;

  // 定期保存定时器
  static Timer? _autoSaveTimer;
  static const int _autoSaveIntervalSeconds = 10; // 每10秒自动保存一次

  // 数据更新通知流
  static final StreamController<void> _dataUpdateController =
      StreamController<void>.broadcast();
  static final StreamController<Map<String, dynamic>>
  _realTimeUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// 数据更新通知流，其他组件可以监听此流来刷新数据
  static Stream<void> get dataUpdateStream => _dataUpdateController.stream;

  /// 实时进度更新流，包含详细的进度信息
  static Stream<Map<String, dynamic>> get realTimeUpdateStream =>
      _realTimeUpdateController.stream;

  /// 开始新的冥想会话
  static Future<String> startSession({
    required MediaItem mediaItem,
    SessionType sessionType = SessionType.meditation,
    List<String> soundEffects = const [],
  }) async {
    try {
      final sessionId = _uuid.v4();
      final startTime = DateTime.now();

      _currentSession = MeditationSession(
        id: sessionId,
        mediaItemId: mediaItem.id,
        title: mediaItem.title,
        duration: mediaItem.duration,
        actualDuration: 0,
        startTime: startTime,
        type: sessionType,
        soundEffects: soundEffects,
        isCompleted: false,
        defaultImageIndex: Random().nextInt(5) + 1, // 随机选择1-5之间的图片索引
      );

      _sessionStartTime = startTime;
      _actualDuration = 0;
      _totalPausedDuration = 0;
      _isPaused = false;
      _lastPauseTime = null;

      // 立即保存会话记录（状态为未完成）
      await _saveSessionToDatabase(_currentSession!);

      // 启动自动保存定时器
      _startAutoSaveTimer();

      debugPrint(
        'Started meditation session: ${_currentSession!.id} for ${_currentSession!.title}',
      );
      debugPrint(
        'Session details: Media ID: ${mediaItem.id}, Duration: ${mediaItem.duration}s, Start time: $startTime',
      );

      // 通知实时更新
      _notifyRealTimeUpdate();

      return sessionId;
    } catch (e) {
      debugPrint('Error starting meditation session: $e');
      throw Exception('Failed to start meditation session: $e');
    }
  }

  /// 更新会话进度（播放时间）
  static void updateSessionProgress(int currentPositionSeconds) {
    if (_sessionStartTime != null && _currentSession != null) {
      // 如果不是暂停状态，更新实际播放时长
      if (!_isPaused) {
        _actualDuration = currentPositionSeconds;

        // 通知实时更新
        _notifyRealTimeUpdate();
      }
    }
  }

  /// 通知实时进度更新
  static void _notifyRealTimeUpdate() {
    if (_currentSession == null) return;

    final updateData = {
      'sessionId': _currentSession!.id,
      'mediaItemId': _currentSession!.mediaItemId,
      'title': _currentSession!.title,
      'actualDuration': _actualDuration,
      'totalDuration': _currentSession!.duration,
      'progress': _currentSession!.duration > 0
          ? _actualDuration / _currentSession!.duration
          : 0.0,
      'isPlaying': !_isPaused,
      'startTime': _sessionStartTime?.toIso8601String(),
    };

    _realTimeUpdateController.add(updateData);
  }

  /// 暂停会话
  static Future<void> pauseSession() async {
    if (_currentSession != null && _sessionStartTime != null && !_isPaused) {
      try {
        _isPaused = true;
        _lastPauseTime = DateTime.now();

        // 立即保存当前进度
        await _saveCurrentProgress();

        debugPrint(
          'Paused meditation session: ${_currentSession!.id}, position: ${_actualDuration}s',
        );
        _notifyRealTimeUpdate();
      } catch (e) {
        debugPrint('Error pausing meditation session: $e');
      }
    }
  }

  /// 恢复会话
  static Future<void> resumeSession() async {
    if (_currentSession != null && _isPaused) {
      try {
        // 计算暂停时长
        if (_lastPauseTime != null) {
          final pauseDuration = DateTime.now()
              .difference(_lastPauseTime!)
              .inSeconds;
          _totalPausedDuration += pauseDuration;
        }

        _isPaused = false;
        _lastPauseTime = null;

        debugPrint(
          'Resumed meditation session: ${_currentSession!.id}, total paused: ${_totalPausedDuration}s',
        );
        _notifyRealTimeUpdate();
      } catch (e) {
        debugPrint('Error resuming meditation session: $e');
      }
    }
  }

  /// 完成会话
  static Future<void> completeSession({
    double rating = 0.0,
    String? notes,
  }) async {
    if (_currentSession != null && _sessionStartTime != null) {
      try {
        // 停止自动保存定时器
        _stopAutoSaveTimer();

        final endTime = DateTime.now();
        final completedSession = _currentSession!.copyWith(
          actualDuration: _actualDuration,
          endTime: endTime,
          rating: rating,
          notes: notes,
          isCompleted: true,
        );

        await _updateSessionInDatabase(completedSession);

        debugPrint(
          'Completed meditation session: ${completedSession.id}, duration: ${_actualDuration}s, paused: ${_totalPausedDuration}s',
        );

        // 清理当前会话状态
        _clearSessionState();

        // 通知数据更新
        _dataUpdateController.add(null);
      } catch (e) {
        debugPrint('Error completing meditation session: $e');
        throw Exception('Failed to complete meditation session: $e');
      }
    }
  }

  /// 停止会话（未完成但保存进度）
  static Future<void> stopSession({double rating = 0.0, String? notes}) async {
    if (_currentSession != null && _sessionStartTime != null) {
      try {
        // 停止自动保存定时器
        _stopAutoSaveTimer();

        final endTime = DateTime.now();
        final stoppedSession = _currentSession!.copyWith(
          actualDuration: _actualDuration,
          endTime: endTime,
          rating: rating,
          notes: notes,
          isCompleted: false, // 标记为未完成
        );

        await _updateSessionInDatabase(stoppedSession);

        debugPrint(
          'Stopped meditation session: ${stoppedSession.id} for ${stoppedSession.title}, duration: ${_actualDuration}s, paused: ${_totalPausedDuration}s',
        );

        // 清理当前会话状态
        _clearSessionState();

        // 通知数据更新
        _dataUpdateController.add(null);
      } catch (e) {
        debugPrint('Error stopping meditation session: $e');
        throw Exception('Failed to stop meditation session: $e');
      }
    }
  }

  /// 获取当前会话
  static MeditationSession? get currentSession => _currentSession;

  /// 获取当前会话时长
  static int get currentSessionDuration => _actualDuration;

  /// 获取当前会话是否暂停
  static bool get isCurrentSessionPaused => _isPaused;

  /// 获取当前会话总暂停时长
  static int get currentSessionPausedDuration => _totalPausedDuration;

  /// 是否有活跃会话
  static bool get hasActiveSession => _currentSession != null;

  /// 保存会话到数据库
  static Future<void> _saveSessionToDatabase(MeditationSession session) async {
    try {
      if (kIsWeb) {
        await WebStorageHelper.insertMeditationSession(session);
      } else {
        await DatabaseHelper.insertMeditationSession(session.toMap());
      }
    } catch (e) {
      debugPrint('Error saving session to database: $e');
      rethrow;
    }
  }

  /// 更新数据库中的会话
  static Future<void> _updateSessionInDatabase(
    MeditationSession session,
  ) async {
    try {
      if (kIsWeb) {
        await WebStorageHelper.updateMeditationSession(
          session.id,
          session.toMap(),
        );
      } else {
        await DatabaseHelper.updateMeditationSession(
          session.id,
          session.toMap(),
        );
      }

      // 更新当前会话状态
      _currentSession = session;
    } catch (e) {
      debugPrint('Error updating session in database: $e');
      rethrow;
    }
  }

  /// 获取会话类型基于媒体类别
  static SessionType getSessionTypeFromCategory(String category) {
    final lowerCategory = category.toLowerCase();

    // 支持中文和英文
    if (lowerCategory.contains('呼吸') || lowerCategory.contains('breathing')) {
      return SessionType.breathing;
    } else if (lowerCategory.contains('睡眠') ||
        lowerCategory.contains('睡前') ||
        lowerCategory.contains('sleep') ||
        lowerCategory.contains('bedtime')) {
      return SessionType.sleep;
    } else if (lowerCategory.contains('专注') ||
        lowerCategory.contains('focus') ||
        lowerCategory.contains('学习') ||
        lowerCategory.contains('study')) {
      return SessionType.focus;
    } else if (lowerCategory.contains('放松') ||
        lowerCategory.contains('舒缓') ||
        lowerCategory.contains('relaxation') ||
        lowerCategory.contains('relax')) {
      return SessionType.relaxation;
    } else {
      return SessionType.meditation;
    }
  }

  /// 清理会话状态（用于测试或重置）
  static void clearSession() {
    _stopAutoSaveTimer();
    _clearSessionState();
  }

  /// 内部清理会话状态
  static void _clearSessionState() {
    _currentSession = null;
    _sessionStartTime = null;
    _lastPauseTime = null;
    _actualDuration = 0;
    _totalPausedDuration = 0;
    _isPaused = false;
  }

  /// 启动自动保存定时器
  static void _startAutoSaveTimer() {
    _stopAutoSaveTimer(); // 先停止现有定时器

    _autoSaveTimer = Timer.periodic(
      Duration(seconds: _autoSaveIntervalSeconds),
      (timer) async {
        if (_currentSession != null) {
          try {
            await _saveCurrentProgress();
            debugPrint('Auto-saved session progress: ${_actualDuration}s');
          } catch (e) {
            debugPrint('Error auto-saving session progress: $e');
          }
        }
      },
    );
  }

  /// 停止自动保存定时器
  static void _stopAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  /// 保存当前进度到数据库
  static Future<void> _saveCurrentProgress() async {
    if (_currentSession == null) return;

    final updatedSession = _currentSession!.copyWith(
      actualDuration: _actualDuration,
    );

    await _updateSessionInDatabase(updatedSession);
  }

  /// 强制保存当前会话状态（用于应用后台切换等场景）
  static Future<void> forceSaveCurrentState() async {
    if (_currentSession != null) {
      try {
        await _saveCurrentProgress();
        debugPrint('Force-saved current session state: ${_actualDuration}s');
      } catch (e) {
        debugPrint('Error force-saving session state: $e');
      }
    }
  }

  /// 获取当前会话的详细状态信息
  static Map<String, dynamic>? getCurrentSessionInfo() {
    if (_currentSession == null) return null;

    return {
      'session': _currentSession!,
      'actualDuration': _actualDuration,
      'totalPausedDuration': _totalPausedDuration,
      'isPaused': _isPaused,
      'startTime': _sessionStartTime?.toIso8601String(),
      'lastPauseTime': _lastPauseTime?.toIso8601String(),
    };
  }

  /// 手动触发数据更新通知
  static void notifyDataUpdate() {
    _dataUpdateController.add(null);
  }

  /// 关闭流控制器（应用退出时调用）
  static Future<void> dispose() async {
    // 保存当前状态
    await forceSaveCurrentState();

    // 停止定时器
    _stopAutoSaveTimer();

    // 关闭流控制器
    await _dataUpdateController.close();
    await _realTimeUpdateController.close();
  }
}
