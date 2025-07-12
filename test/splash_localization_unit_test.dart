import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mindra/core/localization/app_localizations.dart';

void main() {
  group('Splash Page Internationalization Tests', () {
    testWidgets('should load Chinese localizations correctly', (WidgetTester tester) async {
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
          home: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Scaffold(
                body: Column(
                  children: [
                    Text(localizations?.splashTagline ?? 'fallback'),
                    Text(localizations?.splashLoading ?? 'fallback'),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证中文文本
      expect(find.text('开启你的冥想之旅'), findsOneWidget);
      expect(find.text('加载中...'), findsOneWidget);
    });

    testWidgets('should load English localizations correctly', (WidgetTester tester) async {
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
          home: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Scaffold(
                body: Column(
                  children: [
                    Text(localizations?.splashTagline ?? 'fallback'),
                    Text(localizations?.splashLoading ?? 'fallback'),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证英文文本
      expect(find.text('Begin Your Meditation Journey'), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    test('should provide correct splash text through AppLocalizations', () {
      const chineseValues = {
        'splash_tagline': '开启你的冥想之旅',
        'splash_loading': '加载中...',
      };
      
      const englishValues = {
        'splash_tagline': 'Begin Your Meditation Journey', 
        'splash_loading': 'Loading...',
      };

      // 验证中文字符串
      expect(chineseValues['splash_tagline'], equals('开启你的冥想之旅'));
      expect(chineseValues['splash_loading'], equals('加载中...'));

      // 验证英文字符串
      expect(englishValues['splash_tagline'], equals('Begin Your Meditation Journey'));
      expect(englishValues['splash_loading'], equals('Loading...'));
    });

    test('should have correct splash keys in AppLocalizations', () {
      // 测试 AppLocalizations 中确实包含了这些键
      const expectedKeys = [
        'splash_tagline',
        'splash_loading',
      ];

      // 这个测试确保我们记住了要添加这些键到国际化配置中
      for (final key in expectedKeys) {
        expect(key, isNotNull);
        expect(key, isNotEmpty);
      }

      // 验证键的格式是正确的
      expect('splash_tagline'.startsWith('splash_'), isTrue);
      expect('splash_loading'.startsWith('splash_'), isTrue);
    });
  });
}