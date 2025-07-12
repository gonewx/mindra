import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

/// 素材分类枚举
enum MediaCategory {
  meditation, // 冥想
  sleep, // 睡前/睡眠
  focus, // 专注
  relaxation, // 放松
  nature, // 自然音效
  breathing, // 呼吸
  mindfulness, // 正念
  study, // 学习
  soothing, // 舒缓
  environment, // 环境
}

/// 素材分类扩展方法
extension MediaCategoryExtension on MediaCategory {
  /// 获取本地化显示名称
  String getDisplayName(BuildContext context) {
    try {
      final localizations = AppLocalizations.of(context);
      if (localizations == null) {
        // 如果本地化为null，返回默认英文名称
        return _getDefaultDisplayName();
      }

      switch (this) {
        case MediaCategory.meditation:
          return localizations.categoryMeditation;
        case MediaCategory.sleep:
          return localizations.categorySleep;
        case MediaCategory.focus:
          return localizations.categoryFocus;
        case MediaCategory.relaxation:
          return localizations.categoryRelax;
        case MediaCategory.nature:
          return localizations.categoryNature;
        case MediaCategory.breathing:
          return localizations.categoryBreathing;
        case MediaCategory.mindfulness:
          return localizations.categoryMindfulness;
        case MediaCategory.study:
          return localizations.categoryStudy;
        case MediaCategory.soothing:
          return localizations.categorySoothing;
        case MediaCategory.environment:
          return localizations.categoryEnvironment;
      }
    } catch (e) {
      // 如果发生任何异常，返回默认名称
      return _getDefaultDisplayName();
    }
  }

  /// 获取本地化显示名称（无需Context，使用默认语言）
  String getDisplayNameWithLocale(AppLocalizations? localizations) {
    try {
      if (localizations == null) {
        return _getDefaultDisplayName();
      }

      switch (this) {
        case MediaCategory.meditation:
          return localizations.categoryMeditation;
        case MediaCategory.sleep:
          return localizations.categorySleep;
        case MediaCategory.focus:
          return localizations.categoryFocus;
        case MediaCategory.relaxation:
          return localizations.categoryRelax;
        case MediaCategory.nature:
          return localizations.categoryNature;
        case MediaCategory.breathing:
          return localizations.categoryBreathing;
        case MediaCategory.mindfulness:
          return localizations.categoryMindfulness;
        case MediaCategory.study:
          return localizations.categoryStudy;
        case MediaCategory.soothing:
          return localizations.categorySoothing;
        case MediaCategory.environment:
          return localizations.categoryEnvironment;
      }
    } catch (e) {
      return _getDefaultDisplayName();
    }
  }

  /// 获取默认显示名称（英文）
  String _getDefaultDisplayName() {
    switch (this) {
      case MediaCategory.meditation:
        return 'Meditation';
      case MediaCategory.sleep:
        return 'Sleep';
      case MediaCategory.focus:
        return 'Focus';
      case MediaCategory.relaxation:
        return 'Relaxation';
      case MediaCategory.nature:
        return 'Nature';
      case MediaCategory.breathing:
        return 'Breathing';
      case MediaCategory.mindfulness:
        return 'Mindfulness';
      case MediaCategory.study:
        return 'Study';
      case MediaCategory.soothing:
        return 'Soothing';
      case MediaCategory.environment:
        return 'Environment';
    }
  }

  /// 从字符串创建枚举（用于数据库读取）
  static MediaCategory fromString(String? value) {
    if (value == null || value.isEmpty) {
      return MediaCategory.meditation; // 默认分类
    }

    try {
      switch (value.toLowerCase().trim()) {
        case 'meditation':
          return MediaCategory.meditation;
        case 'sleep':
        case 'bedtime':
          return MediaCategory.sleep;
        case 'focus':
          return MediaCategory.focus;
        case 'relaxation':
        case 'relax':
          return MediaCategory.relaxation;
        case 'nature':
          return MediaCategory.nature;
        case 'breathing':
          return MediaCategory.breathing;
        case 'mindfulness':
          return MediaCategory.mindfulness;
        case 'study':
          return MediaCategory.study;
        case 'soothing':
          return MediaCategory.soothing;
        case 'environment':
          return MediaCategory.environment;
        default:
          return MediaCategory.meditation; // 默认分类
      }
    } catch (e) {
      return MediaCategory.meditation; // 异常时返回默认分类
    }
  }

  /// 从本地化字符串创建枚举（用于兼容旧数据）
  static MediaCategory fromLocalizedString(String? value) {
    if (value == null || value.isEmpty) {
      return MediaCategory.meditation; // 默认分类
    }

    try {
      // 中文映射
      switch (value.trim()) {
        case '冥想':
          return MediaCategory.meditation;
        case '睡前':
        case '睡眠':
          return MediaCategory.sleep;
        case '专注':
          return MediaCategory.focus;
        case '放松':
          return MediaCategory.relaxation;
        case '自然音效':
        case '自然':
          return MediaCategory.nature;
        case '呼吸':
          return MediaCategory.breathing;
        case '正念':
          return MediaCategory.mindfulness;
        case '学习':
          return MediaCategory.study;
        case '舒缓':
          return MediaCategory.soothing;
        case '环境':
          return MediaCategory.environment;
        default:
          // 尝试英文映射
          return fromString(value);
      }
    } catch (e) {
      return MediaCategory.meditation; // 异常时返回默认分类
    }
  }

  /// 安全地从枚举名称创建枚举
  static MediaCategory? fromEnumName(String? enumName) {
    if (enumName == null || enumName.isEmpty) {
      return null;
    }

    try {
      return MediaCategory.values.firstWhere(
        (category) => category.name == enumName,
      );
    } catch (e) {
      return null;
    }
  }

  /// 获取所有分类列表
  static List<MediaCategory> get allCategories => MediaCategory.values;

  /// 获取默认分类列表
  static List<MediaCategory> get defaultCategories => [
    MediaCategory.meditation,
    MediaCategory.sleep,
    MediaCategory.focus,
    MediaCategory.relaxation,
    MediaCategory.nature,
  ];
}
