import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// Android平台数据库连接管理器
/// 专门用于解决Android平台数据库连接丢失和数据持久化问题
class DatabaseConnectionManager {
  static Timer? _connectionCheckTimer;
  static bool _isEnabled = false;
  static const Duration _checkInterval = Duration(minutes: 1);

  /// 启动连接监控（仅Android平台）
  static void startConnectionMonitoring() {
    if (kIsWeb || _isEnabled) return;

    _isEnabled = true;
    debugPrint('Starting database connection monitoring...');

    _connectionCheckTimer = Timer.periodic(_checkInterval, (timer) async {
      await _checkDatabaseConnection();
    });
  }

  /// 停止连接监控
  static void stopConnectionMonitoring() {
    if (!_isEnabled) return;

    _isEnabled = false;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    debugPrint('Stopped database connection monitoring');
  }

  /// 检查数据库连接状态
  static Future<void> _checkDatabaseConnection() async {
    try {
      final db = await DatabaseHelper.database;
      await db.rawQuery('SELECT 1');
      // 连接正常，无需操作
    } catch (e) {
      debugPrint('Database connection check failed: $e');
      await _attemptReconnection();
    }
  }

  /// 尝试重新连接数据库
  static Future<void> _attemptReconnection() async {
    try {
      debugPrint('Attempting database reconnection...');
      await DatabaseHelper.forceReinitialize();

      // 验证重连是否成功
      final db = await DatabaseHelper.database;
      await db.rawQuery('SELECT 1');

      debugPrint('Database reconnection successful');
    } catch (e) {
      debugPrint('Database reconnection failed: $e');
      // 可以在这里发送通知给用户或记录错误
    }
  }

  /// 手动触发连接检查
  static Future<bool> checkConnection() async {
    try {
      await _checkDatabaseConnection();
      return true;
    } catch (e) {
      debugPrint('Manual connection check failed: $e');
      return false;
    }
  }

  /// 获取连接状态
  static bool get isMonitoring => _isEnabled;
}
