import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  static const String _localeKey = 'app_locale';
  static const String _cardSpacingKey = 'card_spacing';
  static const String _cardPaddingKey = 'card_padding';

  AppThemeMode _themeMode = AppThemeMode.dark; // 默认使用深色主题
  Locale _locale = const Locale('zh', 'CN');
  double _cardSpacing = 8.0; // 默认卡片间距 16px，匹配原型设计
  double _cardPadding = 20.0; // 默认卡片内边距 20px，匹配原型设计

  AppThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
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
      final localeString = prefs.getString(_localeKey) ?? 'zh_CN';
      final parts = localeString.split('_');
      _locale = Locale(parts[0], parts.length > 1 ? parts[1] : '');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading locale: $e');
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
