import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  static const String _localeKey = 'app_locale';
  
  AppThemeMode _themeMode = AppThemeMode.light;
  Locale _locale = const Locale('zh', 'CN');
  
  AppThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  ThemeData get themeData => _themeMode.themeData;
  
  /// Initialize theme provider and load saved preferences
  Future<void> initialize() async {
    await _loadThemeMode();
    await _loadLocale();
  }
  
  /// Load theme mode from SharedPreferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt(_themeKey) ?? 0;
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
      await prefs.setString(_localeKey, '${locale.languageCode}_${locale.countryCode ?? ''}');
    } catch (e) {
      debugPrint('Error saving locale: $e');
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