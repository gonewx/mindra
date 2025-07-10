import 'package:flutter/material.dart';

class AppTheme {
  // Mindra App Colors - matching HTML prototype exactly
  // Light Theme Colors (--app-primary: #2E3B82)
  static const Color primaryColor = Color(0xFF2E3B82); // Deep blue
  static const Color secondaryColor = Color(0xFF00B894); // Mint green
  static const Color accentColor = Color(0xFFFFA94D); // Orange accent

  // Dark Theme Colors (--app-primary: #4C63D2)
  static const Color darkPrimaryColor = Color(
    0xFF4C63D2,
  ); // Lighter blue for dark mode
  static const Color darkSecondaryColor = Color(
    0xFF00D2A3,
  ); // Lighter mint for dark mode
  static const Color darkAccentColor = Color(
    0xFFFFB366,
  ); // Lighter orange for dark mode

  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF2D3748);
  static const Color lightTextSecondary = Color(0xFF626871);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Hover Colors for Light Theme
  static const Color primaryHover = Color(0xFF1D7480); // --color-primary-hover
  static const Color primaryActive = Color(
    0xFF1A6873,
  ); // --color-primary-active
  static const Color secondaryHover = Color(
    0x335E5240,
  ); // --color-secondary-hover (opacity: 0.2)
  static const Color secondaryActive = Color(
    0x405E5240,
  ); // --color-secondary-active (opacity: 0.25)

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF1A202C);
  static const Color darkSurface = Color(0xFF2D3748);
  static const Color darkOnSurface = Color(0xFFF7FAFC);
  static const Color darkTextSecondary = Color(0xFFA7A9A9);
  static const Color darkBorder = Color(0xFF4A5568);

  // Hover Colors for Dark Theme
  static const Color darkPrimaryHover = Color(
    0xFF2DA6B2,
  ); // Dark mode primary hover
  static const Color darkPrimaryActive = Color(
    0xFF2996A1,
  ); // Dark mode primary active
  static const Color darkSecondaryHover = Color(
    0x40777C7C,
  ); // Dark mode secondary hover
  static const Color darkSecondaryActive = Color(
    0x4D777C7C,
  ); // Dark mode secondary active

  // Nature Theme Colors
  static const Color natureBackground = Color(0xFFF1F8E9);
  static const Color natureSurface = Color(0xFFFFFFFF);
  static const Color natureOnSurface = Color(0xFF2E7D32);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
      surface: lightSurface,
      onSurface: lightOnSurface,
      outline: lightBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightSurface,
      foregroundColor: lightOnSurface,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightSurface,
      selectedItemColor: primaryColor,
      unselectedItemColor: lightTextSecondary,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30, // --font-size-4xl: 30px
        fontWeight: FontWeight.w600, // --font-weight-bold: 600
        color: lightOnSurface,
        height: 1.2, // --line-height-tight: 1.2
      ),
      headlineMedium: TextStyle(
        fontSize: 24, // --font-size-3xl: 24px
        fontWeight:
            FontWeight.w500, // --font-weight-medium: 500 (closest to 550)
        color: lightOnSurface,
        height: 1.2, // --line-height-tight: 1.2
      ),
      titleLarge: TextStyle(
        fontSize: 18, // --font-size-xl: 18px
        fontWeight:
            FontWeight.w500, // --font-weight-medium: 500 (closest to 550)
        color: lightOnSurface,
        height: 1.2, // --line-height-tight: 1.2
      ),
      bodyLarge: TextStyle(
        fontSize: 16, // --font-size-lg: 16px
        fontWeight: FontWeight.normal, // --font-weight-normal: 400
        color: lightOnSurface,
        height: 1.5, // --line-height-normal: 1.5
      ),
      bodyMedium: TextStyle(
        fontSize: 14, // --font-size-base: 14px
        fontWeight: FontWeight.normal, // --font-weight-normal: 400
        color: lightOnSurface,
        height: 1.5, // --line-height-normal: 1.5
      ),
      bodySmall: TextStyle(
        fontSize: 12, // --font-size-sm: 12px
        fontWeight: FontWeight.normal, // --font-weight-normal: 400
        color: lightTextSecondary,
        height: 1.5, // --line-height-normal: 1.5
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: darkPrimaryColor, // Use dark theme primary color
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimaryColor, // Use dark theme primary color
      secondary: darkSecondaryColor, // Use dark theme secondary color
      tertiary: darkAccentColor, // Use dark theme accent color
      surface: darkSurface,
      onSurface: darkOnSurface,
      outline: darkBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkOnSurface,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimaryColor, // Use dark theme primary color
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: primaryColor,
      unselectedItemColor: darkTextSecondary,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30, // --font-size-4xl: 30px
        fontWeight: FontWeight.w600, // --font-weight-bold: 600
        color: darkOnSurface,
        height: 1.2, // --line-height-tight: 1.2
      ),
      headlineMedium: TextStyle(
        fontSize: 24, // --font-size-3xl: 24px
        fontWeight:
            FontWeight.w500, // --font-weight-medium: 500 (closest to 550)
        color: darkOnSurface,
        height: 1.2, // --line-height-tight: 1.2
      ),
      titleLarge: TextStyle(
        fontSize: 18, // --font-size-xl: 18px
        fontWeight:
            FontWeight.w500, // --font-weight-medium: 500 (closest to 550)
        color: darkOnSurface,
        height: 1.2, // --line-height-tight: 1.2
      ),
      bodyLarge: TextStyle(
        fontSize: 16, // --font-size-lg: 16px
        fontWeight: FontWeight.normal, // --font-weight-normal: 400
        color: darkOnSurface,
        height: 1.5, // --line-height-normal: 1.5
      ),
      bodyMedium: TextStyle(
        fontSize: 14, // --font-size-base: 14px
        fontWeight: FontWeight.normal, // --font-weight-normal: 400
        color: darkOnSurface,
        height: 1.5, // --line-height-normal: 1.5
      ),
      bodySmall: TextStyle(
        fontSize: 12, // --font-size-sm: 12px
        fontWeight: FontWeight.normal, // --font-weight-normal: 400
        color: darkTextSecondary,
        height: 1.5, // --line-height-normal: 1.5
      ),
    ),
  );

  static ThemeData natureTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: Colors.green,
    scaffoldBackgroundColor: natureBackground,
    colorScheme: const ColorScheme.light(
      primary: Colors.green,
      secondary: Colors.lightGreen,
      surface: natureSurface,
      onSurface: natureOnSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: natureSurface,
      foregroundColor: natureOnSurface,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: natureSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: natureOnSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: natureOnSurface,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: natureOnSurface),
      bodyMedium: TextStyle(fontSize: 14, color: natureOnSurface),
    ),
  );
}

enum AppThemeMode { light, dark, nature }

extension AppThemeModeExtension on AppThemeMode {
  ThemeData get themeData {
    switch (this) {
      case AppThemeMode.light:
        return AppTheme.lightTheme;
      case AppThemeMode.dark:
        return AppTheme.darkTheme;
      case AppThemeMode.nature:
        return AppTheme.natureTheme;
    }
  }

  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return '浅色';
      case AppThemeMode.dark:
        return '深色';
      case AppThemeMode.nature:
        return '自然';
    }
  }

  String displayNameLocalized(BuildContext context) {
    final localizations = context.findAncestorWidgetOfExactType<Localizations>()?.locale.languageCode ?? 'zh';
    
    switch (this) {
      case AppThemeMode.light:
        return localizations == 'zh' ? '浅色主题' : 'Light Theme';
      case AppThemeMode.dark:
        return localizations == 'zh' ? '深色主题' : 'Dark Theme';
      case AppThemeMode.nature:
        return localizations == 'zh' ? '自然主题' : 'Nature Theme';
    }
  }
}
