import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/web_storage_helper.dart';
import '../../domain/entities/meditation_session.dart';
import '../../../media/domain/entities/media_item.dart';

class MeditationSessionManager {
  static const Uuid _uuid = Uuid();
  static MeditationSession? _currentSession;
  static DateTime? _sessionStartTime;
  static int _actualDuration = 0; // in seconds

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
      );

      _sessionStartTime = startTime;
      _actualDuration = 0;

      // 立即保存会话记录（状态为未完成）
      await _saveSessionToDatabase(_currentSession!);

      debugPrint(
        'Started meditation session: ${_currentSession!.id} for ${_currentSession!.title}',
      );
      debugPrint(
        'Session details: Media ID: ${mediaItem.id}, Duration: ${mediaItem.duration}s, Start time: $startTime',
      );
      return sessionId;
    } catch (e) {
      debugPrint('Error starting meditation session: $e');
      throw Exception('Failed to start meditation session: $e');
    }
  }

  /// 更新会话进度（播放时间）
  static void updateSessionProgress(int currentPositionSeconds) {
    if (_sessionStartTime != null) {
      _actualDuration = currentPositionSeconds;
    }
  }

  /// 暂停会话
  static Future<void> pauseSession() async {
    if (_currentSession != null && _sessionStartTime != null) {
      try {
        // 更新实际播放时长
        final updatedSession = _currentSession!.copyWith(
          actualDuration: _actualDuration,
        );

        await _updateSessionInDatabase(updatedSession);
        debugPrint('Paused meditation session: ${_currentSession!.id}');
      } catch (e) {
        debugPrint('Error pausing meditation session: $e');
      }
    }
  }

  /// 恢复会话
  static Future<void> resumeSession() async {
    if (_currentSession != null) {
      debugPrint('Resumed meditation session: ${_currentSession!.id}');
    }
  }

  /// 完成会话
  static Future<void> completeSession({
    double rating = 0.0,
    String? notes,
  }) async {
    if (_currentSession != null && _sessionStartTime != null) {
      try {
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
          'Completed meditation session: ${completedSession.id}, duration: ${_actualDuration}s',
        );

        // 清理当前会话状态
        _currentSession = null;
        _sessionStartTime = null;
        _actualDuration = 0;
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
          'Stopped meditation session: ${stoppedSession.id} for ${stoppedSession.title}, duration: ${_actualDuration}s',
        );

        // 清理当前会话状态
        _currentSession = null;
        _sessionStartTime = null;
        _actualDuration = 0;
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
    _currentSession = null;
    _sessionStartTime = null;
    _actualDuration = 0;
  }
}
