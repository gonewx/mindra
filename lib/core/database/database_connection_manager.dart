import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// 简化的数据库连接管理器
/// 专注于核心功能，避免过度复杂的监控和恢复逻辑
class DatabaseConnectionManager {
  static Timer? _healthCheckTimer;
  static bool _isMonitoring = false;
  static int _failureCount = 0;
  static DateTime? _lastSuccessTime;

  /// 检查连接状态
  static bool get isHealthy => _failureCount < 3;
  static bool get isMonitoring => _isMonitoring;

  /// 启动简化的连接监控
  static void startConnectionMonitoring() {
    if (kIsWeb || _isMonitoring) return;

    _isMonitoring = true;
    _lastSuccessTime = DateTime.now();
    debugPrint('Starting simplified database connection monitoring');

    // 每5分钟检查一次连接健康状态
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performHealthCheck();
    });
  }

  /// 停止连接监控
  static void stopConnectionMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    debugPrint('Stopped database connection monitoring');
  }

  /// 执行健康检查
  static Future<void> _performHealthCheck() async {
    try {
      final db = await DatabaseHelper.database;
      await db.rawQuery('SELECT 1');

      // 重置失败计数
      _failureCount = 0;
      _lastSuccessTime = DateTime.now();
      debugPrint('Database health check passed');
    } catch (e) {
      _failureCount++;
      debugPrint('Database health check failed (attempt $_failureCount): $e');

      // 如果连续失败太多次，停止监控避免资源浪费
      if (_failureCount >= 10) {
        debugPrint('Too many consecutive failures, stopping monitoring');
        stopConnectionMonitoring();
      }
    }
  }

  /// 检查数据库连接
  static Future<bool> checkConnection() async {
    try {
      final db = await DatabaseHelper.database;
      await db.rawQuery('SELECT 1');
      _failureCount = 0;
      _lastSuccessTime = DateTime.now();
      return true;
    } catch (e) {
      _failureCount++;
      debugPrint('Database connection check failed: $e');
      return false;
    }
  }

  /// 获取连接状态信息
  static Map<String, dynamic> getConnectionStatus() {
    return {
      'isMonitoring': _isMonitoring,
      'isHealthy': isHealthy,
      'failureCount': _failureCount,
      'lastSuccessTime': _lastSuccessTime?.toIso8601String(),
    };
  }
}
