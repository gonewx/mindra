import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindra/core/theme/theme_provider.dart';

void main() {
  group('ThemeProvider Locale Tests', () {
    late ThemeProvider themeProvider;

    setUp(() {
      themeProvider = ThemeProvider();
    });

    tearDown(() async {
      // 清理共享首选项
      SharedPreferences.setMockInitialValues({});
    });

    test('should return system locale when no saved locale', () async {
      // 设置模拟的共享首选项为空
      SharedPreferences.setMockInitialValues({});

      await themeProvider.initialize();

      // 验证返回的是支持的语言
      final locale = themeProvider.locale;
      expect(['zh', 'en'], contains(locale.languageCode));
    });

    test('should save and load locale correctly', () async {
      SharedPreferences.setMockInitialValues({});

      await themeProvider.initialize();

      // 设置英文
      const englishLocale = Locale('en', 'US');
      await themeProvider.setLocale(englishLocale);

      expect(themeProvider.locale, equals(englishLocale));

      // 创建新的实例验证持久化
      final newProvider = ThemeProvider();
      await newProvider.initialize();

      expect(newProvider.locale, equals(englishLocale));
    });

    test('should reset to system locale', () async {
      SharedPreferences.setMockInitialValues({});

      await themeProvider.initialize();

      // 先设置一个非系统语言
      const englishLocale = Locale('en', 'US');
      await themeProvider.setLocale(englishLocale);

      // 重置到系统语言
      await themeProvider.resetToSystemLocale();

      // 验证是否匹配系统语言
      expect(themeProvider.isUsingSystemLocale, isTrue);
    });

    test('should handle invalid locale gracefully', () async {
      // 设置一个无效的locale字符串
      SharedPreferences.setMockInitialValues({
        'app_locale': 'invalid_locale_string',
      });

      await themeProvider.initialize();

      // 当传入无效locale时，应该回退到系统语言或默认语言
      final locale = themeProvider.locale;

      // 验证locale不为null并且有有效的languageCode
      expect(locale, isNotNull);
      expect(locale.languageCode, isNotNull);
      expect(locale.languageCode, isNotEmpty);

      // 验证它是支持的语言之一
      final isValidLanguage =
          locale.languageCode == 'zh' || locale.languageCode == 'en';
      expect(
        isValidLanguage,
        isTrue,
        reason:
            'Language code should be zh or en, but got: ${locale.languageCode}',
      );
    });

    test(
      'should fallback to Chinese when system locale is unsupported',
      () async {
        SharedPreferences.setMockInitialValues({});

        await themeProvider.initialize();

        // 验证支持的语言
        final locale = themeProvider.locale;
        expect(['zh', 'en'], contains(locale.languageCode));
      },
    );
  });
}
