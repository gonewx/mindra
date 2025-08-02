import 'package:flutter/foundation.dart';
import '../../../../core/database/database_helper.dart';
import '../../domain/entities/meditation_session.dart';
import 'enhanced_meditation_session_manager.dart';
import 'dart:async';

/// 数据一致性检查和错误恢复机制 - 简化版本
///
/// 功能：
/// 1. 基础数据完整性验证
/// 2. 自动错误恢复
/// 3. 定期健康检查
class MeditationDataIntegrityManager {
  static const String _logTag = 'DataIntegrity';
  static Timer? _healthCheckTimer;
  static bool _isRunningCheck = false;

  // 健康检查间隔（每小时检查一次）
  static const Duration _healthCheckInterval = Duration(hours: 1);

  /// 启动数据完整性监控
  static void startIntegrityMonitoring() {
    if (_healthCheckTimer != null) return;

    debugPrint('[$_logTag] Starting data integrity monitoring...');

    // 立即执行一次检查
    _performHealthCheck();

    // 启动定期检查
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }

  /// 停止数据完整性监控
  static void stopIntegrityMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    debugPrint('[$_logTag] Stopped data integrity monitoring');
  }

  /// 执行简化的数据健康检查
  static Future<DataIntegrityReport> performComprehensiveCheck() async {
    debugPrint('[$_logTag] Starting comprehensive data integrity check...');

    try {
      final report = DataIntegrityReport();

      // 检查当前会话状态
      await _checkCurrentSessionHealth(report);

      // 检查基础数据完整性
      await _checkBasicDataIntegrity(report);

      report.completedAt = DateTime.now();
      debugPrint('[$_logTag] Comprehensive check completed: ${report.summary}');

      return report;
    } catch (e) {
      debugPrint('[$_logTag] Error during comprehensive check: $e');
      return DataIntegrityReport()..addError('检查过程发生错误', e.toString());
    }
  }

  /// 定期健康检查（轻量级）
  static Future<void> _performHealthCheck() async {
    if (_isRunningCheck) return;

    _isRunningCheck = true;
    try {
      debugPrint('[$_logTag] Performing periodic health check...');

      // 检查当前会话状态
      await _checkCurrentSessionState();

      // 强制保存当前状态
      if (EnhancedMeditationSessionManager.hasActiveSession) {
        await EnhancedMeditationSessionManager.forceSaveCurrentState();
      }

      debugPrint('[$_logTag] Periodic health check completed');
    } catch (e) {
      debugPrint('[$_logTag] Error during health check: $e');
    } finally {
      _isRunningCheck = false;
    }
  }

  /// 检查当前会话健康状态
  static Future<void> _checkCurrentSessionHealth(
    DataIntegrityReport report,
  ) async {
    try {
      if (!EnhancedMeditationSessionManager.hasActiveSession) {
        report.addInfo('会话状态', '当前无活跃会话');
        return;
      }

      final sessionInfo =
          EnhancedMeditationSessionManager.getCurrentSessionInfo();
      if (sessionInfo == null) {
        report.addWarning('会话状态异常', '活跃会话但无法获取详细信息');
        return;
      }

      final currentDuration = sessionInfo['actualDuration'] as int;
      final startTimeStr = sessionInfo['startTime'] as String?;

      if (startTimeStr != null) {
        final sessionStart = DateTime.parse(startTimeStr);
        final realTimeElapsed = DateTime.now()
            .difference(sessionStart)
            .inSeconds;

        // 检查时间偏差
        final timeDiff = (realTimeElapsed - currentDuration).abs();
        if (timeDiff > 300) {
          // 超过5分钟偏差
          report.addWarning('会话时间不一致', '实际经过时间与记录时间相差$timeDiff秒');
        } else {
          report.addInfo('会话状态', '时间记录正常');
        }
      }

      // 检查每日累计数据
      final dailyDuration = sessionInfo['dailyCumulativeDuration'] as int;
      final dailySessionCount = sessionInfo['dailySessionCount'] as int;

      if (dailyDuration < 0) {
        report.addError('数据异常', '每日累计时长为负数');
      }

      if (dailySessionCount < 0) {
        report.addError('数据异常', '每日会话数为负数');
      }

      if (dailySessionCount > 0 && dailyDuration == 0) {
        report.addWarning('统计不一致', '有会话记录但总时长为0');
      }
    } catch (e) {
      report.addError('会话健康检查失败', e.toString());
    }
  }

  /// 检查基础数据完整性
  static Future<void> _checkBasicDataIntegrity(
    DataIntegrityReport report,
  ) async {
    try {
      // 获取最近的会话数据进行基础检查
      List<Map<String, dynamic>> recentSessions;

      if (kIsWeb) {
        // Web平台暂时跳过详细检查
        report.addInfo('平台检查', 'Web平台基础检查完成');
        return;
      } else {
        // 获取最近的会话记录
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final dayStart = DateTime(
          yesterday.year,
          yesterday.month,
          yesterday.day,
        );
        recentSessions = await DatabaseHelper.getMeditationSessionsByDateRange(
          dayStart,
          DateTime.now(),
        );
      }

      // 基础数据验证
      int validSessions = 0;
      int invalidSessions = 0;

      for (final sessionData in recentSessions) {
        try {
          final session = MeditationSession.fromMap(sessionData);

          // 基础字段验证
          if (session.id.isEmpty) {
            invalidSessions++;
            report.addWarning('数据问题', '发现空ID的会话记录');
            continue;
          }

          if (session.actualDuration < 0) {
            invalidSessions++;
            report.addWarning('数据问题', '会话${session.id}的播放时长为负数');
            continue;
          }

          validSessions++;
        } catch (e) {
          invalidSessions++;
          report.addWarning('数据解析失败', '会话数据解析错误: ${e.toString()}');
        }
      }

      report.addInfo('数据统计', '有效会话: $validSessions, 无效会话: $invalidSessions');
    } catch (e) {
      report.addError('基础数据检查失败', e.toString());
    }
  }

  /// 检查当前会话状态
  static Future<void> _checkCurrentSessionState() async {
    try {
      if (!EnhancedMeditationSessionManager.hasActiveSession) return;

      final sessionInfo =
          EnhancedMeditationSessionManager.getCurrentSessionInfo();
      if (sessionInfo == null) return;

      final currentDuration = sessionInfo['actualDuration'] as int;
      final startTimeStr = sessionInfo['startTime'] as String?;

      if (startTimeStr != null) {
        final sessionStart = DateTime.parse(startTimeStr);
        final realTimeElapsed = DateTime.now()
            .difference(sessionStart)
            .inSeconds;

        // 检查时间偏差
        final timeDiff = (realTimeElapsed - currentDuration).abs();
        if (timeDiff > 300) {
          // 超过5分钟偏差
          debugPrint('[$_logTag] Warning: Session time inconsistency detected');
          await EnhancedMeditationSessionManager.forceSaveCurrentState();
        }
      }
    } catch (e) {
      debugPrint('[$_logTag] Error checking current session state: $e');
    }
  }
}

/// 数据完整性报告
class DataIntegrityReport {
  final List<DataIntegrityIssue> errors = [];
  final List<DataIntegrityIssue> warnings = [];
  final List<DataIntegrityIssue> info = [];
  DateTime? completedAt;

  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;

  String get summary =>
      '错误: ${errors.length}, 警告: ${warnings.length}, 信息: ${info.length}';

  void addError(String category, String message) {
    errors.add(
      DataIntegrityIssue(
        category: category,
        message: message,
        severity: IssueSeverity.error,
        timestamp: DateTime.now(),
      ),
    );
  }

  void addWarning(String category, String message) {
    warnings.add(
      DataIntegrityIssue(
        category: category,
        message: message,
        severity: IssueSeverity.warning,
        timestamp: DateTime.now(),
      ),
    );
  }

  void addInfo(String category, String message) {
    info.add(
      DataIntegrityIssue(
        category: category,
        message: message,
        severity: IssueSeverity.info,
        timestamp: DateTime.now(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'errors': errors.map((e) => e.toJson()).toList(),
      'warnings': warnings.map((e) => e.toJson()).toList(),
      'info': info.map((e) => e.toJson()).toList(),
      'completedAt': completedAt?.toIso8601String(),
      'summary': summary,
    };
  }
}

/// 数据完整性问题
class DataIntegrityIssue {
  final String category;
  final String message;
  final IssueSeverity severity;
  final DateTime timestamp;

  const DataIntegrityIssue({
    required this.category,
    required this.message,
    required this.severity,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'message': message,
      'severity': severity.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// 问题严重程度
enum IssueSeverity { error, warning, info }
