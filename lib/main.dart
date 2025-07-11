import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/di/injection_container.dart';
import 'core/database/database_helper.dart';
import 'core/services/reminder_scheduler_service.dart';
import 'core/localization/app_localizations.dart';
import 'features/player/services/simple_sound_effects_player.dart';
import 'features/player/services/global_player_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize sqflite factory for different platforms
    if (kIsWeb) {
      // For web platform - use in-memory database for now
      // Note: Web storage will be handled differently
      print('Running on web platform - using alternative storage');
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
        print('Running on mobile platform - using standard sqflite');
        // Don't set databaseFactory - let sqflite use its default
        // Initialize database for mobile platforms
        await DatabaseHelper.database;
      } else {
        // For desktop platforms - use FFI
        print('Running on desktop platform - using sqflite FFI');
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        // Initialize database for desktop platforms
        await DatabaseHelper.database;
      }
    }

    // Initialize dependencies
    await configureDependencies();

    // Initialize theme provider first (lightweight)
    final themeProvider = ThemeProvider();
    await themeProvider.initialize();

    // Initialize services with better error handling for Huawei devices
    await _initializeServicesWithFallback();

    runApp(MindraApp(themeProvider: themeProvider));
  } catch (e) {
    debugPrint('Critical initialization error: $e');
    // If there's an error during initialization, show error app
    runApp(ErrorApp(error: e.toString()));
  }
}

Future<void> _initializeServicesWithFallback() async {
  // Initialize global player service with fallback
  try {
    final globalPlayerService = getIt<GlobalPlayerService>();
    await globalPlayerService.initialize();
    debugPrint('Global player service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize global player service: $e');
    // Continue without audio services for now
  }

  // Initialize sound effects service with fallback
  try {
    await SimpleSoundEffectsPlayer().initialize();
    debugPrint('Sound effects service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize sound effects service: $e');
    // Continue without sound effects
  }

  // Initialize reminder scheduler service with fallback
  try {
    final reminderService = ReminderSchedulerService();
    await reminderService.initialize();
    debugPrint('Reminder scheduler service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize reminder scheduler service: $e');
    // Continue without reminder service
  }
}

class MindraApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const MindraApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: themeProvider,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'Mindra',
            debugShowCheckedModeBanner: false,

            // Theme
            theme: themeProvider.themeData,

            // Localization
            locale: themeProvider.locale,
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
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  '应用初始化失败',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
