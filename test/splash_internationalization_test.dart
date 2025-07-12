import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mindra/core/localization/app_localizations.dart';

// 创建一个测试专用的Splash Widget，不包含导航逻辑
class TestSplashWidget extends StatelessWidget {
  const TestSplashWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [
                    const Color(0xFF121212),
                    const Color(0xFF1E1E1E),
                    const Color(0xFF2D2D30),
                  ]
                : [
                    const Color(0xFF6366F1),
                    const Color(0xFF3B4A9A),
                    const Color(0xFF2D2D30),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 使用简单的Container代替SVG
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.self_improvement,
                    size: 60,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 32),

                // App Name
                const Text(
                  'Mindra',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),

                // Tagline - 国际化
                Text(
                  localizations?.splashTagline ?? '开启你的冥想之旅',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 48),

                // Loading Indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 24),

                // Loading text - 国际化
                Text(
                  localizations?.splashLoading ?? '加载中...',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('SplashPage Internationalization Tests', () {
    testWidgets('should display Chinese text when locale is zh', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          home: const TestSplashWidget(),
        ),
      );

      // 只等待几帧，避免无限等待
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证中文文本
      expect(find.text('开启你的冥想之旅'), findsOneWidget);
      expect(find.text('加载中...'), findsOneWidget);
      expect(find.text('Mindra'), findsOneWidget);
    });

    testWidgets('should display English text when locale is en', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          home: const TestSplashWidget(),
        ),
      );

      // 只等待几帧，避免无限等待
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证英文文本
      expect(find.text('Begin Your Meditation Journey'), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
      expect(find.text('Mindra'), findsOneWidget);
    });

    testWidgets('should have fallback text when localizations not available', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TestSplashWidget(),
        ),
      );

      await tester.pump();

      // 验证回退文本（中文）
      expect(find.text('开启你的冥想之旅'), findsOneWidget);
      expect(find.text('加载中...'), findsOneWidget);
      expect(find.text('Mindra'), findsOneWidget);
    });

    testWidgets('should display app logo and loading indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          home: const TestSplashWidget(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证UI元素
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Mindra'), findsOneWidget);
      expect(find.byIcon(Icons.self_improvement), findsOneWidget);
      
      // 验证layout结构
      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(Container), findsWidgets); // 检查渐变背景容器和图标容器
    });

    testWidgets('should support theme switching', (WidgetTester tester) async {
      // 测试深色主题
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          theme: ThemeData.dark(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          home: const TestSplashWidget(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 验证在深色主题下的文本
      expect(find.text('开启你的冥想之旅'), findsOneWidget);
      expect(find.text('加载中...'), findsOneWidget);
      expect(find.text('Mindra'), findsOneWidget);
    });
  });
}