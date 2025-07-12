import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mindra/core/localization/app_localizations.dart';
import 'package:mindra/features/splash/presentation/pages/splash_page.dart';

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
          home: const SplashPage(),
        ),
      );

      // 等待 localization 加载完成
      await tester.pumpAndSettle();

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
          home: const SplashPage(),
        ),
      );

      // 等待 localization 加载完成
      await tester.pumpAndSettle();

      // 验证英文文本
      expect(find.text('Begin Your Meditation Journey'), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
      expect(find.text('Mindra'), findsOneWidget);
    });

    testWidgets('should have fallback text when localizations not available', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashPage(),
        ),
      );

      await tester.pumpAndSettle();

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
          home: const SplashPage(),
        ),
      );

      await tester.pumpAndSettle();

      // 验证UI元素
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Mindra'), findsOneWidget);
      
      // 验证layout结构
      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);
    });
  });
}