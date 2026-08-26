import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mindra/core/database/database_helper.dart';

/// 数据库类测试的统一初始化。
///
/// 做三件事：
///  1. 初始化 FFI databaseFactory（测试环境没有平台通道）
///  2. 删除上一个测试套件留下的 mindra.db —— 残留库的数据会污染断言
///     （比如 expect(数量, 1) 实际读到 128），残留的半成品库还会缺表
///  3. 重置 DatabaseHelper 单例状态，确保本套件从全新数据库开始
///
/// 各测试文件的 setUpAll 里调用：
/// ```dart
/// setUpAll(() async {
///   await TestDatabaseSetup.setup();
/// });
/// ```
Future<void> setupTestDatabase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // DatabaseHelper 关闭并清空单例（不删文件）
  await DatabaseHelper.closeDatabase();

  // 删除共享路径下的残留库文件（含 -journal/-wal/-shm 边车文件）
  try {
    final dbDir = Directory('.dart_tool/sqflite_common_ffi/databases');
    if (dbDir.existsSync()) {
      for (final entity in dbDir.listSync()) {
        if (entity is File) {
          entity.deleteSync();
        }
      }
    }
  } catch (_) {
    // 目录不存在或删除失败都不影响测试 —— 全新初始化会重建
  }
}
