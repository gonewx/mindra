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

class _MindraAppState extends State<MindraApp> {
  late ThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    // 使用默认主题立即启动
    _themeProvider = ThemeProvider();

    // 后台初始化所有服务
    _initializeBackgroundServices();
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
    // Initialize sqflite factory for different platforms
    if (kIsWeb) {
      // For web platform - use in-memory database for now
      debugPrint('Running on web platform - using alternative storage');
    } else {
      // Check if we're on mobile or desktop
      bool isMobile = false;
      try {
        isMobile = Platform.isAndroid || Platform.isIOS;
      } catch (e) {
        // If Platform is not available, assume desktop
        isMobile = false;
      }

      if (isMobile) {
        // For mobile platforms - use standard sqflite (no FFI needed)
        debugPrint('Running on mobile platform - using standard sqflite');
        // Initialize database for mobile platforms
        await DatabaseHelper.database;
      } else {
        // For desktop platforms - use FFI
        debugPrint('Running on desktop platform - using sqflite FFI');
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        // Initialize database for desktop platforms
        await DatabaseHelper.database;
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
