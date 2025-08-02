import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// Android平台数据库连接管理器
/// 专门用于解决Android平台数据库连接丢失和数据持久化问题
class DatabaseConnectionManager {
  static Timer? _connectionCheckTimer;
  static Timer? _backupTimer;
  static bool _isEnabled = false;
  static int _consecutiveFailures = 0;
  static DateTime? _lastSuccessfulConnection;
  static const Duration _checkInterval = Duration(minutes: 1);
  static const Duration _backupInterval = Duration(hours: 6);
  static const int _maxConsecutiveFailures = 3;

  /// 启动连接监控（仅Android平台）
  static void startConnectionMonitoring() {
    if (kIsWeb || _isEnabled) return;

    _isEnabled = true;
    _lastSuccessfulConnection = DateTime.now();
    debugPrint('Starting enhanced database connection monitoring...');

    // 定期连接检查
    _connectionCheckTimer = Timer.periodic(_checkInterval, (timer) async {
      await _checkDatabaseConnection();
    });

    // 定期备份
    _backupTimer = Timer.periodic(_backupInterval, (timer) async {
      await _createPeriodicBackup();
    });

    // 初始备份
    _createPeriodicBackup();
  }

  /// 停止连接监控
  static void stopConnectionMonitoring() {
    if (!_isEnabled) return;

    _isEnabled = false;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    _backupTimer?.cancel();
    _backupTimer = null;
    debugPrint('Stopped enhanced database connection monitoring');
  }

  /// 检查数据库连接状态
  static Future<void> _checkDatabaseConnection() async {
    try {
      final db = await DatabaseHelper.database;

      // 执行更全面的连接测试
      await db.rawQuery('SELECT 1');
      await db.rawQuery('SELECT COUNT(*) FROM media_items');

      // 连接成功
      _consecutiveFailures = 0;
      _lastSuccessfulConnection = DateTime.now();

      debugPrint('Database connection check passed');
    } catch (e) {
      _consecutiveFailures++;
      debugPrint(
        'Database connection check failed (attempt $_consecutiveFailures): $e',
      );

      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        debugPrint(
          'Multiple consecutive failures detected, attempting recovery...',
        );
        await _attemptDatabaseRecovery();
      } else {
        await _attemptReconnection();
      }
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
      _consecutiveFailures = 0;
      _lastSuccessfulConnection = DateTime.now();
    } catch (e) {
      debugPrint('Database reconnection failed: $e');
    }
  }

  /// 尝试数据库恢复
  static Future<void> _attemptDatabaseRecovery() async {
    try {
      debugPrint('Attempting database recovery due to persistent failures...');

      // 先尝试备份当前数据库
      final backupSuccess = await DatabaseHelper.createBackup();
      debugPrint('Backup creation: ${backupSuccess ? "successful" : "failed"}');

      // 尝试从备份恢复
      final restoreSuccess = await DatabaseHelper.restoreFromBackup();
      if (restoreSuccess) {
        debugPrint('Database restored from backup successfully');
        _consecutiveFailures = 0;
        _lastSuccessfulConnection = DateTime.now();
        return;
      }

      // 如果恢复失败，尝试强制重新初始化
      debugPrint('Backup restore failed, attempting force reinitialization...');
      await DatabaseHelper.forceReinitialize();

      // 验证恢复结果
      final db = await DatabaseHelper.database;
      await db.rawQuery('SELECT 1');

      debugPrint('Database recovery completed successfully');
      _consecutiveFailures = 0;
      _lastSuccessfulConnection = DateTime.now();
    } catch (e) {
      debugPrint('Database recovery failed: $e');
      // 可以在这里发送通知给用户或记录错误
    }
  }

  /// 创建定期备份
  static Future<void> _createPeriodicBackup() async {
    try {
      debugPrint('Creating periodic database backup...');
      final success = await DatabaseHelper.createBackup();
      debugPrint('Periodic backup: ${success ? "successful" : "failed"}');
    } catch (e) {
      debugPrint('Periodic backup failed: $e');
    }
  }

  /// 手动触发连接检查
  static Future<bool> checkConnection() async {
    try {
      await _checkDatabaseConnection();
      return _consecutiveFailures == 0;
    } catch (e) {
      debugPrint('Manual connection check failed: $e');
      return false;
    }
  }

  /// 获取连接状态信息
  static Map<String, dynamic> getConnectionStatus() {
    return {
      'isMonitoring': _isEnabled,
      'consecutiveFailures': _consecutiveFailures,
      'lastSuccessfulConnection': _lastSuccessfulConnection?.toIso8601String(),
      'isHealthy': _consecutiveFailures < _maxConsecutiveFailures,
    };
  }

  /// 获取连接状态
  static bool get isMonitoring => _isEnabled;

  /// 获取连接是否健康
  static bool get isHealthy => _consecutiveFailures < _maxConsecutiveFailures;
}
