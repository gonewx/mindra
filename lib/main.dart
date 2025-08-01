import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/di/injection_container.dart';
import 'core/config/app_config_service.dart';
import 'core/database/database_helper.dart';
import 'core/database/database_health_checker.dart';
import 'core/database/database_connection_manager.dart';
import 'core/services/reminder_scheduler_service.dart';
import 'core/localization/app_localizations.dart';
import 'features/player/services/global_player_service.dart';

void main() async {
  // 保持原生启动画面
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 启动应用
  runApp(const MindraApp());
}

class MindraApp extends StatefulWidget {
  const MindraApp({super.key});

  @override
  State<MindraApp> createState() => _MindraAppState();
}

class _MindraAppState extends State<MindraApp> with WidgetsBindingObserver {
  late ThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // 使用默认主题立即启动
    _themeProvider = ThemeProvider();

    // 后台初始化所有服务
    _initializeBackgroundServices();
  }

  @override
  void dispose() {
    // 移除应用生命周期监听
    WidgetsBinding.instance.removeObserver(this);

    // 停止数据库连接监控
    if (Platform.isAndroid) {
      DatabaseConnectionManager.stopConnectionMonitoring();
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!Platform.isAndroid) return;

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('App resumed - checking database connection');
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        debugPrint('App paused - maintaining database connection');
        break;
      case AppLifecycleState.inactive:
        debugPrint('App inactive');
        break;
      case AppLifecycleState.detached:
        debugPrint('App detached - stopping database monitoring');
        DatabaseConnectionManager.stopConnectionMonitoring();
        break;
      case AppLifecycleState.hidden:
        debugPrint('App hidden');
        break;
    }
  }

  /// 处理应用恢复
  void _handleAppResumed() async {
    try {
      // 检查数据库连接状态
      final isConnected = await DatabaseConnectionManager.checkConnection();
      if (!isConnected) {
        debugPrint('Database connection lost, attempting recovery...');
        await DatabaseHelper.forceReinitialize();
      }

      // 重新启动连接监控
      if (!DatabaseConnectionManager.isMonitoring) {
        DatabaseConnectionManager.startConnectionMonitoring();
      }
    } catch (e) {
      debugPrint('Error handling app resume: $e');
    }
  }

  Future<void> _initializeBackgroundServices() async {
    try {
      // 优先初始化依赖注入，这样音频服务就可以被注册
      await configureDependencies();
      debugPrint('Dependency injection configured');

      // 并行初始化各个服务以提高启动速度
      await Future.wait([
        _initializeTheme(),
        _initializeAppConfig(),
        _initializeDatabaseServices(),
        _initializeAudioServices(),
        _initializeOtherServices(),
      ]);

      debugPrint('Background services initialized');
    } catch (e) {
      debugPrint('Failed to initialize background services: $e');
      // 不影响UI显示
    }
  }

  Future<void> _initializeTheme() async {
    await _themeProvider.initialize();
    debugPrint('Theme initialized');
  }

  Future<void> _initializeAppConfig() async {
    await AppConfigService.initialize();
    debugPrint('App config initialized');
  }

  Future<void> _initializeDatabaseServices() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
          'Database services initialization attempt $attempt/$maxRetries',
        );

        // Initialize sqflite factory for different platforms
        if (kIsWeb) {
          // For web platform - use alternative storage
          debugPrint('Running on web platform - using alternative storage');
          // Web平台不需要数据库初始化，使用WebStorageHelper
          return;
        } else {
          // Check if we're on mobile or desktop
          bool isMobile = false;
          String platformInfo = 'unknown';

          try {
            isMobile = Platform.isAndroid || Platform.isIOS;
            platformInfo = Platform.operatingSystem;
            debugPrint('Detected platform: $platformInfo (mobile: $isMobile)');
          } catch (e) {
            // If Platform is not available, assume desktop
            isMobile = false;
            platformInfo = 'desktop (assumed)';
            debugPrint('Platform detection failed, assuming desktop: $e');
          }

          if (isMobile) {
            // For mobile platforms - use standard sqflite (no FFI needed)
            debugPrint(
              'Initializing standard sqflite for mobile platform: $platformInfo',
            );

            // 移动平台特殊处理
            if (Platform.isAndroid) {
              // Android平台额外检查
              await _initializeAndroidDatabase();
            } else if (Platform.isIOS) {
              // iOS平台额外检查
              await _initializeIOSDatabase();
            } else {
              // 其他移动平台
              await DatabaseHelper.database;
            }
          } else {
            // For desktop platforms - use FFI
            debugPrint(
              'Initializing sqflite FFI for desktop platform: $platformInfo',
            );

            try {
              sqfliteFfiInit();
              databaseFactory = databaseFactoryFfi;
            } catch (e) {
              debugPrint('Failed to initialize sqflite FFI: $e');
              throw Exception('Desktop database initialization failed: $e');
            }

            // Initialize database for desktop platforms
            await DatabaseHelper.database;
          }
        }

        // 验证数据库状态
        final dbStatus = DatabaseHelper.getInitializationStatus();
        debugPrint('Database initialization status: $dbStatus');

        if (dbStatus['isOpen'] == true) {
          debugPrint(
            'Database services initialized successfully on attempt $attempt',
          );

          // 执行数据库健康检查（后台异步执行）
          _performDatabaseHealthCheck();

          // 启动数据库连接监控（仅Android平台）
          if (Platform.isAndroid) {
            DatabaseConnectionManager.startConnectionMonitoring();
            debugPrint('Android database connection monitoring started');
          }

          return;
        } else {
          throw Exception('Database is not open after initialization');
        }
      } catch (e) {
        debugPrint(
          'Database services initialization attempt $attempt failed: $e',
        );

        if (attempt == maxRetries) {
          debugPrint('All database initialization attempts failed');
          // 最后一次尝试失败，但不抛出异常，让应用继续运行
          // 应用可以在需要数据库时再次尝试初始化
          debugPrint(
            'Warning: Database initialization failed, app will continue with limited functionality',
          );
          return;
        }

        // 等待后重试
        debugPrint('Waiting ${retryDelay.inSeconds}s before retry...');
        await Future.delayed(retryDelay * attempt);
      }
    }
  }

  /// Android平台数据库初始化
  Future<void> _initializeAndroidDatabase() async {
    try {
      debugPrint('Initializing Android database...');

      // Android特定的初始化逻辑
      // 检查Android版本和权限
      final androidInfo = Platform.version;
      debugPrint('Android version info: $androidInfo');

      // 检查数据库是否需要恢复
      final dbStatus = DatabaseHelper.getInitializationStatus();
      if (dbStatus['lastError'] != null) {
        debugPrint(
          'Previous database initialization failed, attempting recovery...',
        );
        await DatabaseHelper.forceReinitialize();
      }

      // 初始化数据库
      final db = await DatabaseHelper.database;

      // 验证数据库功能
      final testResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM media_items',
      );
      final mediaCount = testResult.first['count'] as int;
      debugPrint(
        'Android database initialized successfully, media items: $mediaCount',
      );
    } catch (e) {
      debugPrint('Android database initialization failed: $e');

      // 尝试强制重新初始化
      try {
        debugPrint('Attempting Android database recovery...');
        await DatabaseHelper.forceReinitialize();

        // 验证恢复是否成功
        final db = await DatabaseHelper.database;
        await db.rawQuery('SELECT 1');
        debugPrint('Android database recovery successful');
      } catch (recoveryError) {
        debugPrint('Android database recovery failed: $recoveryError');

        // 记录详细错误信息以便调试
        final dbStatus = DatabaseHelper.getInitializationStatus();
        debugPrint('Database status after recovery attempt: $dbStatus');

        rethrow;
      }
    }
  }

  /// 执行数据库健康检查（后台异步执行）
  void _performDatabaseHealthCheck() {
    // 在后台异步执行健康检查，不阻塞UI
    Future.microtask(() async {
      try {
        if (!DatabaseHealthChecker.shouldPerformHealthCheck()) {
          return; // 不需要检查
        }

        debugPrint('Starting background database health check...');
        final report = await DatabaseHealthChecker.performHealthCheck();

        if (!report.isHealthy) {
          debugPrint(
            'Database health issues detected, attempting auto-repair...',
          );
          final repairedIssues = await DatabaseHealthChecker.autoRepairIssues(
            report,
          );

          if (repairedIssues.isNotEmpty) {
            debugPrint(
              'Successfully repaired ${repairedIssues.length} database issues',
            );
          }
        } else {
          debugPrint('Database health check passed - all systems healthy');
        }
      } catch (e) {
        debugPrint('Background database health check failed: $e');
        // 健康检查失败不影响应用正常运行
      }
    });
  }

  /// iOS平台数据库初始化
  Future<void> _initializeIOSDatabase() async {
    try {
      debugPrint('Initializing iOS database...');

      // iOS特定的初始化逻辑
      final iosInfo = Platform.version;
      debugPrint('iOS version info: $iosInfo');

      // 初始化数据库
      await DatabaseHelper.database;

      debugPrint('iOS database initialized successfully');
    } catch (e) {
      debugPrint('iOS database initialization failed: $e');

      // 尝试强制重新初始化
      try {
        debugPrint('Attempting iOS database recovery...');
        await DatabaseHelper.forceReinitialize();
        debugPrint('iOS database recovery successful');
      } catch (recoveryError) {
        debugPrint('iOS database recovery failed: $recoveryError');
        rethrow;
      }
    }
  }

  Future<void> _initializeAudioServices() async {
    // Initialize audio services with fallback and prewarming
    try {
      debugPrint('Starting audio services initialization...');
      final globalPlayerService = getIt<GlobalPlayerService>();

      // 预热音频服务 - 在后台开始初始化但不等待完成
      // 这样可以减少用户首次打开播放器时的等待时间
      await globalPlayerService.initialize();

      debugPrint('Audio services initialization started (background)');
    } catch (e) {
      debugPrint('Failed to start audio services initialization: $e');
      // 即使预热失败，也不影响应用启动
    }
  }

  Future<void> _initializeOtherServices() async {
    // Initialize other services
    try {
      final reminderService = ReminderSchedulerService();
      await reminderService.initialize();
      debugPrint('Reminder scheduler service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize reminder scheduler service: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _themeProvider,
      child: Consumer<ThemeProvider>(
        builder: (context, theme, child) {
          return MaterialApp.router(
            title: 'Mindra',
            debugShowCheckedModeBanner: false,

            // Theme
            theme: theme.themeData,

            // Localization
            locale: theme.locale,
            supportedLocales: const [
              Locale('zh', 'CN'), // 简体中文
              Locale('en', 'US'), // English
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // Routing
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    // 简单的语言检测，用于错误页面
    final isEnglish = _isSystemEnglish();

    return MaterialApp(
      locale: isEnglish ? const Locale('en', 'US') : const Locale('zh', 'CN'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  isEnglish ? 'App Initialization Failed' : '应用初始化失败',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: Text(isEnglish ? 'Retry' : '重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 简单检测系统是否为英文
  bool _isSystemEnglish() {
    try {
      final systemLocale = ui.PlatformDispatcher.instance.locale;
      return systemLocale.languageCode == 'en';
    } catch (e) {
      return false; // 默认中文
    }
  }
}
