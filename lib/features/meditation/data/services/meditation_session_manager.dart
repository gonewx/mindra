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

  // 每日累计数据 - 来自Enhanced管理器的核心功能
  static DateTime? _currentMeditationDate;
  static int _dailyCumulativeDuration = 0; // 当天累计冥想时长
  static int _dailySessionCount = 0; // 当天会话数量
  static final Set<String> _dailyMediaIds = {}; // 当天播放的媒体ID
  static final Set<String> _dailySoundEffects = {}; // 当天使用的音效

  // 数据更新通知流
  static final StreamController<void> _dataUpdateController =
      StreamController<void>.broadcast();
  static final StreamController<Map<String, dynamic>>
  _realTimeUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<DailyMeditationStats> _dailyStatsController =
      StreamController<DailyMeditationStats>.broadcast();

  /// 数据更新通知流，其他组件可以监听此流来刷新数据
  static Stream<void> get dataUpdateStream => _dataUpdateController.stream;

  /// 实时进度更新流，包含详细的进度信息
  static Stream<Map<String, dynamic>> get realTimeUpdateStream =>
      _realTimeUpdateController.stream;

  /// 每日统计更新流
  static Stream<DailyMeditationStats> get dailyStatsStream =>
      _dailyStatsController.stream;

  /// 开始新的冥想会话
  static Future<String> startSession({
    required MediaItem mediaItem,
    SessionType sessionType = SessionType.meditation,
    List<String> soundEffects = const [],
  }) async {
    try {
      final sessionId = _uuid.v4();
      final startTime = DateTime.now();
      final today = DateTime(startTime.year, startTime.month, startTime.day);

      // 智能处理每日统计
      if (_currentMeditationDate == null ||
          !_isSameDay(_currentMeditationDate!, today)) {
        await _initializeDailyStats(today);
      }

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

      // 更新每日统计
      _dailySessionCount++;
      _dailyMediaIds.add(mediaItem.id);
      _dailySoundEffects.addAll(soundEffects);

      // 立即保存会话记录（状态为未完成）
      await _saveSessionToDatabase(_currentSession!);

      debugPrint(
        'Started meditation session: ${_currentSession!.id} for ${_currentSession!.title}',
      );
      debugPrint(
        'Session details: Media ID: ${mediaItem.id}, Duration: ${mediaItem.duration}s, Start time: $startTime',
      );

      // 通知更新
      _notifyRealTimeUpdate();
      _notifyDailyStatsUpdate();

      return sessionId;
    } catch (e) {
      debugPrint('Error starting meditation session: $e');
      throw Exception('Failed to start meditation session: $e');
    }
  }

  /// 更新会话进度 - 增强版本，包含每日累计
  static void updateSessionProgress(int currentPositionSeconds) {
    if (_sessionStartTime != null && _currentSession != null && !_isPaused) {
      final previousDuration = _actualDuration;
      _actualDuration = currentPositionSeconds;

      // 更新每日累计时长（增量更新）
      final increment = _actualDuration - previousDuration;
      if (increment > 0) {
        _dailyCumulativeDuration += increment;
      }
    }
  }

  /// 手动触发实时更新通知（用于关键时刻）
  static void triggerRealTimeUpdate() {
    _notifyRealTimeUpdate();
  }

  /// 智能切换媒体 - 来自Enhanced管理器的核心功能
  static Future<String> switchToMedia({
    required MediaItem newMediaItem,
    SessionType? sessionType,
    List<String> soundEffects = const [],
  }) async {
    try {
      // 保存当前会话的进度（如果存在）
      if (_currentSession != null) {
        await _saveCurrentProgressWithoutStopping();
        debugPrint(
          '保存切换前进度: ${_actualDuration}s for ${_currentSession!.title}',
        );
      }

      // 开始新会话，但继续累计到当天的统计中
      final newSessionId = await startSession(
        mediaItem: newMediaItem,
        sessionType: sessionType ?? SessionType.meditation,
        soundEffects: soundEffects,
      );

      debugPrint('切换到新媒体: ${newMediaItem.title}, 继续每日累计');
      return newSessionId;
    } catch (e) {
      debugPrint('切换媒体错误: $e');
      rethrow;
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
      'dailyCumulativeDuration': _dailyCumulativeDuration,
      'dailySessionCount': _dailySessionCount,
    };

    _realTimeUpdateController.add(updateData);
  }

  /// 通知每日统计更新
  static void _notifyDailyStatsUpdate() {
    if (_currentMeditationDate == null) return;

    final dailyStats = DailyMeditationStats(
      date: _currentMeditationDate!,
      totalDurationSeconds: _dailyCumulativeDuration,
      sessionCount: _dailySessionCount,
      mediaIds: _dailyMediaIds.toList(),
      soundEffects: _dailySoundEffects.toList(),
      lastUpdated: DateTime.now(),
    );

    _dailyStatsController.add(dailyStats);
  }

  /// 暂停会话
  static Future<void> pauseSession() async {
    if (_currentSession != null && _sessionStartTime != null && !_isPaused) {
      try {
        _isPaused = true;
        _lastPauseTime = DateTime.now();

        // 立即保存当前进度和每日统计
        await _saveCurrentProgressWithDailyStats();

        debugPrint(
          'Paused meditation session: ${_currentSession!.id}, position: ${_actualDuration}s',
        );
        _notifyRealTimeUpdate();
        _notifyDailyStatsUpdate();
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
        // 检查并确保对应的MediaItem存在，避免外键约束错误
        await _ensureMediaItemExists(session);
        await DatabaseHelper.insertMeditationSession(session.toMap());
      }
    } catch (e) {
      debugPrint('Error saving session to database: $e');
      rethrow;
    }
  }

  /// 确保MediaItem存在，如果不存在则创建一个临时记录
  static Future<void> _ensureMediaItemExists(MeditationSession session) async {
    try {
      // 检查MediaItem是否存在
      final existingItem = await DatabaseHelper.getMediaItemById(
        session.mediaItemId,
      );

      if (existingItem == null) {
        debugPrint(
          'MediaItem ${session.mediaItemId} not found, creating temporary record',
        );

        // 创建临时MediaItem记录
        final tempMediaItem = {
          'id': session.mediaItemId,
          'title': session.title,
          'description': '临时创建的媒体记录（由会话管理器自动生成）',
          'file_path': 'temp://placeholder',
          'type': 'audio',
          'category': session.type.name,
          'duration': session.duration,
          'created_at': session.startTime.millisecondsSinceEpoch,
          'play_count': 0,
          'tags': '',
          'is_favorite': 0,
          'sort_index': 0,
        };

        await DatabaseHelper.insertMediaItem(tempMediaItem);
        debugPrint('Created temporary MediaItem for session ${session.id}');
      }
    } catch (e) {
      debugPrint('Error ensuring MediaItem exists: $e');
      // 不重新抛出错误，让会话保存继续尝试
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

  // 移除自动保存定时器相关方法

  /// 保存当前进度到数据库
  static Future<void> _saveCurrentProgress() async {
    if (_currentSession == null) return;

    final updatedSession = _currentSession!.copyWith(
      actualDuration: _actualDuration,
    );

    await _updateSessionInDatabase(updatedSession);
  }

  /// 保存当前进度但不停止会话 - Enhanced功能
  static Future<void> _saveCurrentProgressWithoutStopping() async {
    if (_currentSession == null) return;

    final updatedSession = _currentSession!.copyWith(
      actualDuration: _actualDuration,
    );

    await _updateSessionInDatabase(updatedSession);
    await _saveDailyStatsToDatabase();
  }

  /// 保存当前进度和每日统计
  static Future<void> _saveCurrentProgressWithDailyStats() async {
    await _saveCurrentProgressWithoutStopping();
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
      'dailyCumulativeDuration': _dailyCumulativeDuration,
      'dailySessionCount': _dailySessionCount,
    };
  }

  /// 手动触发数据更新通知
  static void notifyDataUpdate() {
    _dataUpdateController.add(null);
  }

  /// 初始化每日统计
  static Future<void> _initializeDailyStats(DateTime date) async {
    _currentMeditationDate = date;

    try {
      final existingStats = await _loadDailyStatsFromDatabase(date);
      if (existingStats != null) {
        _dailyCumulativeDuration = existingStats.totalDurationSeconds;
        _dailySessionCount = existingStats.sessionCount;
        _dailyMediaIds.clear();
        _dailyMediaIds.addAll(existingStats.mediaIds);
        _dailySoundEffects.clear();
        _dailySoundEffects.addAll(existingStats.soundEffects);

        debugPrint(
          '恢复每日统计: duration=${_dailyCumulativeDuration}s, sessions=$_dailySessionCount',
        );
      } else {
        _dailyCumulativeDuration = 0;
        _dailySessionCount = 0;
        _dailyMediaIds.clear();
        _dailySoundEffects.clear();
        debugPrint('初始化新的每日统计');
      }
    } catch (e) {
      debugPrint('初始化每日统计错误: $e');
      _dailyCumulativeDuration = 0;
      _dailySessionCount = 0;
      _dailyMediaIds.clear();
      _dailySoundEffects.clear();
    }
  }

  /// 保存每日统计到数据库
  static Future<void> _saveDailyStatsToDatabase() async {
    if (_currentMeditationDate == null) return;

    try {
      final dailyStats = DailyMeditationStats(
        date: _currentMeditationDate!,
        totalDurationSeconds: _dailyCumulativeDuration,
        sessionCount: _dailySessionCount,
        mediaIds: _dailyMediaIds.toList(),
        soundEffects: _dailySoundEffects.toList(),
        lastUpdated: DateTime.now(),
      );

      await _saveDailyStatsData(dailyStats);
    } catch (e) {
      debugPrint('保存每日统计错误: $e');
    }
  }

  /// 从数据库加载每日统计
  static Future<DailyMeditationStats?> _loadDailyStatsFromDatabase(
    DateTime date,
  ) async {
    try {
      return await _loadDailyStatsData(date);
    } catch (e) {
      debugPrint('加载每日统计错误: $e');
      return null;
    }
  }

  static Future<void> _saveDailyStatsData(DailyMeditationStats stats) async {
    final key = 'daily_stats_${_getDateKey(stats.date)}';
    final value = stats.toJson();

    if (kIsWeb) {
      await WebStorageHelper.setPreference(key, value);
    } else {
      await DatabaseHelper.setPreference(key, value);
    }
  }

  static Future<DailyMeditationStats?> _loadDailyStatsData(
    DateTime date,
  ) async {
    final key = 'daily_stats_${_getDateKey(date)}';

    String? value;
    if (kIsWeb) {
      value = await WebStorageHelper.getPreference(key);
    } else {
      value = await DatabaseHelper.getPreference(key);
    }

    if (value != null && value.isNotEmpty) {
      return DailyMeditationStats.fromJson(value);
    }
    return null;
  }

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 新增：每日统计访问器
  static int get dailyCumulativeDuration => _dailyCumulativeDuration;
  static int get dailySessionCount => _dailySessionCount;
  static DateTime? get currentMeditationDate => _currentMeditationDate;

  /// 获取当前每日统计
  static DailyMeditationStats? getCurrentDailyStats() {
    if (_currentMeditationDate == null) return null;

    return DailyMeditationStats(
      date: _currentMeditationDate!,
      totalDurationSeconds: _dailyCumulativeDuration,
      sessionCount: _dailySessionCount,
      mediaIds: _dailyMediaIds.toList(),
      soundEffects: _dailySoundEffects.toList(),
      lastUpdated: DateTime.now(),
    );
  }

  /// 关闭流控制器（应用退出时调用）
  static Future<void> dispose() async {
    // 保存当前状态
    await forceSaveCurrentState();

    // 关闭流控制器
    await _dataUpdateController.close();
    await _realTimeUpdateController.close();
    await _dailyStatsController.close();
  }
}

/// 每日冥想统计数据模型 - 来自Enhanced管理器
class DailyMeditationStats {
  final DateTime date;
  final int totalDurationSeconds;
  final int sessionCount;
  final List<String> mediaIds;
  final List<String> soundEffects;
  final DateTime lastUpdated;

  const DailyMeditationStats({
    required this.date,
    required this.totalDurationSeconds,
    required this.sessionCount,
    required this.mediaIds,
    required this.soundEffects,
    required this.lastUpdated,
  });

  int get totalMinutes => totalDurationSeconds ~/ 60;

  String toJson() {
    return '{"date":"${date.toIso8601String()}","totalDurationSeconds":$totalDurationSeconds,"sessionCount":$sessionCount,"mediaIds":${_listToJsonArray(mediaIds)},"soundEffects":${_listToJsonArray(soundEffects)},"lastUpdated":"${lastUpdated.toIso8601String()}"}';
  }

  static DailyMeditationStats fromJson(String json) {
    final regex = RegExp(r'"([^"]+)":(\[[^\]]*\]|"[^"]*"|\d+)');
    final matches = regex.allMatches(json);
    final map = <String, String>{};

    for (final match in matches) {
      map[match.group(1)!] = match.group(2)!;
    }

    return DailyMeditationStats(
      date: DateTime.parse(map['date']!.replaceAll('"', '')),
      totalDurationSeconds: int.parse(map['totalDurationSeconds']!),
      sessionCount: int.parse(map['sessionCount']!),
      mediaIds: _parseJsonArray(map['mediaIds']!),
      soundEffects: _parseJsonArray(map['soundEffects']!),
      lastUpdated: DateTime.parse(map['lastUpdated']!.replaceAll('"', '')),
    );
  }

  static String _listToJsonArray(List<String> list) {
    return '[${list.map((item) => '"$item"').join(',')}]';
  }

  static List<String> _parseJsonArray(String jsonArray) {
    if (jsonArray == '[]') return [];
    final content = jsonArray.substring(1, jsonArray.length - 1);
    return content
        .split(',')
        .map((item) => item.replaceAll('"', '').trim())
        .toList();
  }
}
