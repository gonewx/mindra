import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/database/web_storage_helper.dart';
import '../../domain/entities/meditation_session.dart';
import '../../../media/domain/entities/media_item.dart';
import 'dart:async';

/// 增强版冥想会话管理器 - 解决数据丢失和统计不准确问题
///
/// 核心改进：
/// 1. 智能会话切换：切换媒体时自动保存进度而非停止会话
/// 2. 连续播放累计：多个媒体播放自动累计到当天的总冥想时间
/// 3. 防丢失机制：多重保护确保播放数据不会丢失
/// 4. 实时同步：确保统计数据实时准确更新
class EnhancedMeditationSessionManager {
  static const Uuid _uuid = Uuid();

  // 当前活跃会话
  static MeditationSession? _currentSession;
  static DateTime? _sessionStartTime;
  static DateTime? _lastPauseTime;
  static int _totalPausedDuration = 0;
  static int _actualDuration = 0;
  static bool _isPaused = false;

  // 每日累计数据 - 核心改进
  static DateTime? _currentMeditationDate;
  static int _dailyCumulativeDuration = 0; // 当天累计冥想时长
  static int _dailySessionCount = 0; // 当天会话数量
  static final Set<String> _dailyMediaIds = {}; // 当天播放的媒体ID
  static final Set<String> _dailySoundEffects = {}; // 当天使用的音效

  // 定期保存和同步
  static Timer? _autoSaveTimer;
  static Timer? _dailyStatsUpdateTimer;
  static const int _autoSaveIntervalSeconds = 5; // 更频繁的保存间隔
  static const int _dailyStatsUpdateIntervalSeconds = 30; // 定期更新每日统计

  // 数据更新通知流
  static final StreamController<void> _dataUpdateController =
      StreamController<void>.broadcast();
  static final StreamController<Map<String, dynamic>>
  _realTimeUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<DailyMeditationStats> _dailyStatsController =
      StreamController<DailyMeditationStats>.broadcast();

  /// 数据更新通知流
  static Stream<void> get dataUpdateStream => _dataUpdateController.stream;

  /// 实时进度更新流
  static Stream<Map<String, dynamic>> get realTimeUpdateStream =>
      _realTimeUpdateController.stream;

  /// 每日统计更新流 - 新增
  static Stream<DailyMeditationStats> get dailyStatsStream =>
      _dailyStatsController.stream;

  /// 开始新的冥想会话 - 增强版本
  static Future<String> startSession({
    required MediaItem mediaItem,
    SessionType sessionType = SessionType.meditation,
    List<String> soundEffects = const [],
  }) async {
    try {
      final sessionId = _uuid.v4();
      final startTime = DateTime.now();
      final today = DateTime(startTime.year, startTime.month, startTime.day);

      // 智能处理：如果是同一天，继续累计；如果是新的一天，重置计数
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

      // 立即保存会话记录
      await _saveSessionToDatabase(_currentSession!);

      // 启动定时器
      _startTimers();

      debugPrint('Enhanced session started: $sessionId for ${mediaItem.title}');
      debugPrint(
        'Today stats: sessions=$_dailySessionCount, duration=${_dailyCumulativeDuration}s',
      );

      // 通知更新
      _notifyRealTimeUpdate();
      _notifyDailyStatsUpdate();

      return sessionId;
    } catch (e) {
      debugPrint('Error starting enhanced session: $e');
      throw Exception('Failed to start enhanced session: $e');
    }
  }

  /// 智能切换媒体 - 核心改进
  /// 不再停止当前会话，而是保存进度并继续累计
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
          'Saved progress before switching: ${_actualDuration}s for ${_currentSession!.title}',
        );
      }

      // 开始新会话，但继续累计到当天的统计中
      final newSessionId = await startSession(
        mediaItem: newMediaItem,
        sessionType: sessionType ?? SessionType.meditation,
        soundEffects: soundEffects,
      );

      debugPrint(
        'Switched to new media: ${newMediaItem.title}, continuing daily accumulation',
      );

      return newSessionId;
    } catch (e) {
      debugPrint('Error switching media: $e');
      rethrow;
    }
  }

  /// 更新会话进度 - 同时更新每日累计
  static void updateSessionProgress(int currentPositionSeconds) {
    if (_sessionStartTime != null && _currentSession != null && !_isPaused) {
      final previousDuration = _actualDuration;
      _actualDuration = currentPositionSeconds;

      // 更新每日累计时长（增量更新）
      final increment = _actualDuration - previousDuration;
      if (increment > 0) {
        _dailyCumulativeDuration += increment;
      }

      // 通知更新
      _notifyRealTimeUpdate();

      // 每分钟通知一次每日统计更新
      if (_actualDuration > 0 && _actualDuration % 60 == 0) {
        _notifyDailyStatsUpdate();
      }
    }
  }

  /// 暂停会话 - 增强版本
  static Future<void> pauseSession() async {
    if (_currentSession != null && !_isPaused) {
      try {
        _isPaused = true;
        _lastPauseTime = DateTime.now();

        // 立即保存进度，包括每日累计数据
        await _saveCurrentProgressWithDailyStats();

        debugPrint(
          'Enhanced pause: position=${_actualDuration}s, daily total=${_dailyCumulativeDuration}s',
        );
        _notifyRealTimeUpdate();
        _notifyDailyStatsUpdate();
      } catch (e) {
        debugPrint('Error in enhanced pause: $e');
      }
    }
  }

  /// 恢复会话 - 增强版本
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

        debugPrint('Enhanced resume: total paused=${_totalPausedDuration}s');
        _notifyRealTimeUpdate();
      } catch (e) {
        debugPrint('Error in enhanced resume: $e');
      }
    }
  }

  /// 完成会话 - 确保数据完整保存
  static Future<void> completeSession({
    double rating = 0.0,
    String? notes,
  }) async {
    if (_currentSession != null) {
      try {
        _stopTimers();

        final endTime = DateTime.now();
        final completedSession = _currentSession!.copyWith(
          actualDuration: _actualDuration,
          endTime: endTime,
          rating: rating,
          notes: notes,
          isCompleted: true,
        );

        await _updateSessionInDatabase(completedSession);
        await _saveDailyStatsToDatabase();

        debugPrint(
          'Enhanced session completed: duration=${_actualDuration}s, daily total=${_dailyCumulativeDuration}s',
        );

        _clearCurrentSession();
        _notifyDataUpdate();
        _notifyDailyStatsUpdate();
      } catch (e) {
        debugPrint('Error in enhanced complete: $e');
        throw Exception('Failed to complete enhanced session: $e');
      }
    }
  }

  /// 停止会话 - 保存所有进度数据
  static Future<void> stopSession({double rating = 0.0, String? notes}) async {
    if (_currentSession != null) {
      try {
        _stopTimers();

        final endTime = DateTime.now();
        final stoppedSession = _currentSession!.copyWith(
          actualDuration: _actualDuration,
          endTime: endTime,
          rating: rating,
          notes: notes,
          isCompleted: false, // 未完成，但数据仍然有效
        );

        await _updateSessionInDatabase(stoppedSession);
        await _saveDailyStatsToDatabase();

        debugPrint(
          'Enhanced session stopped: duration=${_actualDuration}s, daily total=${_dailyCumulativeDuration}s',
        );

        _clearCurrentSession();
        _notifyDataUpdate();
        _notifyDailyStatsUpdate();
      } catch (e) {
        debugPrint('Error in enhanced stop: $e');
        throw Exception('Failed to stop enhanced session: $e');
      }
    }
  }

  /// 初始化每日统计
  static Future<void> _initializeDailyStats(DateTime date) async {
    _currentMeditationDate = date;

    // 从数据库恢复当天已有的统计数据
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
          'Restored daily stats: duration=${_dailyCumulativeDuration}s, sessions=$_dailySessionCount',
        );
      } else {
        // 新的一天，重置统计
        _dailyCumulativeDuration = 0;
        _dailySessionCount = 0;
        _dailyMediaIds.clear();
        _dailySoundEffects.clear();

        debugPrint('Initialized new daily stats for ${_getDateKey(date)}');
      }
    } catch (e) {
      debugPrint('Error initializing daily stats: $e');
      // 出错时重置为安全状态
      _dailyCumulativeDuration = 0;
      _dailySessionCount = 0;
      _dailyMediaIds.clear();
      _dailySoundEffects.clear();
    }
  }

  /// 保存当前进度但不停止会话 - 核心改进
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
    await _saveDailyStatsToDatabase();
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
      debugPrint('Saved daily stats: ${dailyStats.totalDurationSeconds}s');
    } catch (e) {
      debugPrint('Error saving daily stats: $e');
    }
  }

  /// 从数据库加载每日统计
  static Future<DailyMeditationStats?> _loadDailyStatsFromDatabase(
    DateTime date,
  ) async {
    try {
      return await _loadDailyStatsData(date);
    } catch (e) {
      debugPrint('Error loading daily stats: $e');
      return null;
    }
  }

  /// 启动定时器
  static void _startTimers() {
    _stopTimers();

    // 自动保存定时器 - 更频繁
    _autoSaveTimer = Timer.periodic(
      Duration(seconds: _autoSaveIntervalSeconds),
      (timer) async {
        if (_currentSession != null) {
          try {
            await _saveCurrentProgressWithDailyStats();
          } catch (e) {
            debugPrint('Error in auto-save: $e');
          }
        }
      },
    );

    // 每日统计更新定时器
    _dailyStatsUpdateTimer = Timer.periodic(
      Duration(seconds: _dailyStatsUpdateIntervalSeconds),
      (timer) async {
        try {
          await _saveDailyStatsToDatabase();
          _notifyDailyStatsUpdate();
        } catch (e) {
          debugPrint('Error in daily stats update: $e');
        }
      },
    );
  }

  /// 停止定时器
  static void _stopTimers() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _dailyStatsUpdateTimer?.cancel();
    _dailyStatsUpdateTimer = null;
  }

  /// 清理当前会话状态
  static void _clearCurrentSession() {
    _currentSession = null;
    _sessionStartTime = null;
    _lastPauseTime = null;
    _actualDuration = 0;
    _totalPausedDuration = 0;
    _isPaused = false;
  }

  /// 通知实时更新
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

  /// 通知每日统计更新 - 新增
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

  /// 通知数据更新
  static void _notifyDataUpdate() {
    _dataUpdateController.add(null);
  }

  // 以下是原有方法的保留，确保兼容性
  static MeditationSession? get currentSession => _currentSession;
  static int get currentSessionDuration => _actualDuration;
  static bool get isCurrentSessionPaused => _isPaused;
  static int get currentSessionPausedDuration => _totalPausedDuration;
  static bool get hasActiveSession => _currentSession != null;

  // 新增：每日统计访问器
  static int get dailyCumulativeDuration => _dailyCumulativeDuration;
  static int get dailySessionCount => _dailySessionCount;
  static DateTime? get currentMeditationDate => _currentMeditationDate;

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

  // 辅助方法
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 数据库操作方法（需要实现）
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
      _currentSession = session;
    } catch (e) {
      debugPrint('Error updating session in database: $e');
      rethrow;
    }
  }

  static Future<void> _saveDailyStatsData(DailyMeditationStats stats) async {
    // 实现每日统计数据的保存逻辑
    // 可以使用用户偏好存储或创建专门的统计表
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

  /// 手动触发数据更新通知
  static void notifyDataUpdate() {
    _notifyDataUpdate();
  }

  /// 强制保存当前状态
  static Future<void> forceSaveCurrentState() async {
    if (_currentSession != null) {
      try {
        await _saveCurrentProgressWithDailyStats();
        debugPrint(
          'Force-saved current state: session=${_actualDuration}s, daily=${_dailyCumulativeDuration}s',
        );
      } catch (e) {
        debugPrint('Error force-saving state: $e');
      }
    }
  }

  /// 获取会话类型
  static SessionType getSessionTypeFromCategory(String category) {
    final lowerCategory = category.toLowerCase();

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

  /// 清理会话状态
  static void clearSession() {
    _stopTimers();
    _clearCurrentSession();
  }

  /// 关闭流控制器
  static Future<void> dispose() async {
    await forceSaveCurrentState();
    _stopTimers();

    await _dataUpdateController.close();
    await _realTimeUpdateController.close();
    await _dailyStatsController.close();
  }
}

/// 每日冥想统计数据模型 - 新增
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
    // 简单的JSON解析（生产环境建议使用proper JSON库）
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
