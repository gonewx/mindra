import 'package:shared_preferences/shared_preferences.dart';

class MediaLibrarySettingsService {
  static const String _viewModeKey = 'media_library_view_mode';
  static const String _sortOrderKey = 'media_library_sort_order';

  // 获取视图模式
  static Future<bool> getViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_viewModeKey) ?? true; // 默认为网格视图
  }

  // 设置视图模式
  static Future<void> setViewMode(bool isGridView) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_viewModeKey, isGridView);
  }

  // 获取排序顺序
  static Future<List<String>> getSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_sortOrderKey) ?? [];
  }

  // 设置排序顺序
  static Future<void> setSortOrder(List<String> mediaIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sortOrderKey, mediaIds);
  }

  // 清除设置
  static Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_viewModeKey);
    await prefs.remove(_sortOrderKey);
  }
}
