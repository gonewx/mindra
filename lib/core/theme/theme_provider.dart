import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  static const String _localeKey = 'app_locale';
  static const String _cardSpacingKey = 'card_spacing';
  static const String _cardPaddingKey = 'card_padding';

  AppThemeMode _themeMode = AppThemeMode.dark; // 默认使用深色主题
  Locale? _locale; // 初始为 null，在 initialize 时设置为系统语言
  double _cardSpacing = 8.0; // 默认卡片间距 16px，匹配原型设计
  double _cardPadding = 20.0; // 默认卡片内边距 20px，匹配原型设计

  AppThemeMode get themeMode => _themeMode;
  Locale get locale => _locale ?? _getSystemLocale(); // 如果 _locale 为 null，返回系统语言
  ThemeData get themeData => _themeMode.themeData;
  double get cardSpacing => _cardSpacing;
  double get cardPadding => _cardPadding;

  /// Initialize theme provider and load saved preferences
  Future<void> initialize() async {
    await _loadThemeMode();
    await _loadLocale();
    await _loadCardSpacing();
    await _loadCardPadding();
  }

  /// Load theme mode from SharedPreferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt(_themeKey) ?? 1; // 默认使用深色主题 (index 1)
      _themeMode = AppThemeMode.values[themeModeIndex];
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
    }
  }

  /// Load locale from SharedPreferences
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String localeString = prefs.getString(_localeKey) ?? '';
      
      // 如果没有保存过语言设置，则使用系统语言
      if (localeString.isEmpty) {
        final systemLocale = _getSystemLocale();
        localeString = '${systemLocale.languageCode}_${systemLocale.countryCode ?? ''}';
        // 保存系统语言作为默认设置
        await prefs.setString(_localeKey, localeString);
      }
      
      final parts = localeString.split('_');
      final languageCode = parts[0];
      
      // 验证解析出的语言代码是否在支持的列表中
      const supportedLanguages = ['zh', 'en'];
      if (supportedLanguages.contains(languageCode)) {
        _locale = Locale(languageCode, parts.length > 1 ? parts[1] : '');
      } else {
        // 如果语言代码无效，回退到系统语言
        debugPrint('Invalid language code: $languageCode, falling back to system locale');
        _locale = _getSystemLocale();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading locale: $e');
      // 出错时回退到系统语言
      _locale = _getSystemLocale();
      notifyListeners();
    }
  }

  /// Get system locale with fallback to supported locales
  Locale _getSystemLocale() {
    try {
      final systemLocale = ui.PlatformDispatcher.instance.locale;
      
      // 检查系统语言是否在支持的语言列表中
      const supportedLanguages = ['zh', 'en'];
      
      if (supportedLanguages.contains(systemLocale.languageCode)) {
        // 如果系统语言是中文，设置为简体中文
        if (systemLocale.languageCode == 'zh') {
          return const Locale('zh', 'CN');
        }
        // 如果系统语言是英文，设置为美式英文
        if (systemLocale.languageCode == 'en') {
          return const Locale('en', 'US');
        }
        return systemLocale;
      } else {
        // 如果系统语言不支持，默认使用简体中文
        return const Locale('zh', 'CN');
      }
    } catch (e) {
      debugPrint('Error getting system locale: $e');
      // 出错时默认使用简体中文
      return const Locale('zh', 'CN');
    }
  }

  /// Load card spacing from SharedPreferences
  Future<void> _loadCardSpacing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cardSpacing = prefs.getDouble(_cardSpacingKey) ?? 16.0; // 默认 16px
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading card spacing: $e');
    }
  }

  /// Load card padding from SharedPreferences
  Future<void> _loadCardPadding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cardPadding = prefs.getDouble(_cardPaddingKey) ?? 20.0; // 默认 20px
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading card padding: $e');
    }
  }

  /// Update theme mode and save to preferences
  Future<void> setThemeMode(AppThemeMode themeMode) async {
    try {
      _themeMode = themeMode;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, themeMode.index);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }

  /// Update locale and save to preferences
  Future<void> setLocale(Locale locale) async {
    try {
      _locale = locale;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localeKey,
        '${locale.languageCode}_${locale.countryCode ?? ''}',
      );
    } catch (e) {
      debugPrint('Error saving locale: $e');
    }
  }

  /// Reset locale to system language
  Future<void> resetToSystemLocale() async {
    try {
      final systemLocale = _getSystemLocale();
      await setLocale(systemLocale);
    } catch (e) {
      debugPrint('Error resetting to system locale: $e');
    }
  }

  /// Check if current locale matches system locale
  bool get isUsingSystemLocale {
    final systemLocale = _getSystemLocale();
    final currentLocale = locale;
    return currentLocale.languageCode == systemLocale.languageCode &&
           currentLocale.countryCode == systemLocale.countryCode;
  }

  /// Update card spacing and save to preferences
  Future<void> setCardSpacing(double spacing) async {
    try {
      _cardSpacing = spacing.clamp(8.0, 32.0); // 限制间距范围在 8-32px 之间
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_cardSpacingKey, _cardSpacing);
    } catch (e) {
      debugPrint('Error saving card spacing: $e');
    }
  }

  /// Update card padding and save to preferences
  Future<void> setCardPadding(double padding) async {
    try {
      _cardPadding = padding.clamp(12.0, 32.0); // 限制内边距范围在 12-32px 之间
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_cardPaddingKey, _cardPadding);
    } catch (e) {
      debugPrint('Error saving card padding: $e');
    }
  }

  /// Toggle between light and dark theme
  Future<void> toggleTheme() async {
    final newTheme = _themeMode == AppThemeMode.light
        ? AppThemeMode.dark
        : AppThemeMode.light;
    await setThemeMode(newTheme);
  }

  /// Check if current theme is dark
  bool get isDarkMode => _themeMode == AppThemeMode.dark;

  /// Check if current theme is nature
  bool get isNatureMode => _themeMode == AppThemeMode.nature;

  /// Get responsive padding based on screen size
  EdgeInsets getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      // Large desktop
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    } else if (screenWidth > 800) {
      // Tablet/small desktop
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    } else {
      // Mobile
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
  }

  /// Get responsive column count for grid layouts
  int getResponsiveColumns(BuildContext context, {int maxColumns = 4}) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return maxColumns;
    } else if (screenWidth > 800) {
      return (maxColumns * 0.75).round().clamp(2, maxColumns);
    } else if (screenWidth > 600) {
      return (maxColumns * 0.5).round().clamp(2, maxColumns);
    } else {
      return 2;
    }
  }

  /// Get responsive font size multiplier
  double getResponsiveFontScale(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth > 1200) {
      return 1.1;
    } else if (screenWidth > 800) {
      return 1.0;
    } else {
      return 0.9;
    }
  }
}
