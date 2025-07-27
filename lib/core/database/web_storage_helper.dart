import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import '../../features/media/domain/entities/media_item.dart';
import '../../features/meditation/domain/entities/meditation_session.dart';
import '../constants/media_category.dart';

// Conditional import for web-only functionality
import 'web_storage_helper_io.dart' as html if (dart.library.html) 'dart:html';

class WebStorageHelper {
  static const String _mediaItemsKey = 'mindra_media_items';
  static const String _sessionsKey = 'mindra_sessions';
  static const String _preferencesKey = 'mindra_preferences';

  // Store media bytes in memory for current session
  static final Map<String, Uint8List> _mediaBytes = {};

  static html.Storage get _localStorage => html.window.localStorage;

  // Store file bytes in memory for current session
  static Future<void> storeMediaBytes(String mediaId, Uint8List bytes) async {
    try {
      developer.log(
        'Storing media bytes for ID: $mediaId, size: ${bytes.length} bytes',
        name: 'WebStorageHelper',
      );
      _mediaBytes[mediaId] = bytes;
      developer.log(
        'Successfully stored media bytes in memory for ID: $mediaId',
        name: 'WebStorageHelper',
      );
    } catch (e) {
      developer.log(
        'Failed to store media bytes: $e',
        name: 'WebStorageHelper',
        error: e,
      );
      throw Exception('Failed to store media bytes: $e');
    }
  }

  // Retrieve file bytes and create blob URL
  static String? createBlobUrl(String mediaId, String mimeType) {
    try {
      // Get bytes from memory storage
      final bytes = _mediaBytes[mediaId];
      if (bytes == null) {
        developer.log(
          'No stored bytes found for media ID: $mediaId',
          name: 'WebStorageHelper',
        );
        return null;
      }

      developer.log(
        'Found stored bytes for media ID: $mediaId, length: ${bytes.length}',
        name: 'WebStorageHelper',
      );

      // Create blob and return object URL
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrl(blob);
      developer.log('Created blob URL: $url', name: 'WebStorageHelper');
      return url;
    } catch (e) {
      developer.log(
        'Error creating blob URL: $e',
        name: 'WebStorageHelper',
        error: e,
      );
      return null;
    }
  }

  // Clean up blob URL
  static void revokeBlobUrl(String url) {
    try {
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      developer.log(
        'Error revoking blob URL: $e',
        name: 'WebStorageHelper',
        error: e,
      );
    }
  }

  static Future<void> insertMediaItem(MediaItem item) async {
    final items = await getMediaItems();
    items.removeWhere((existing) => existing.id == item.id);
    items.add(item);
    await _saveMediaItems(items);
  }

  static Future<List<MediaItem>> getMediaItems() async {
    final jsonString = _localStorage[_mediaItemsKey];
    if (jsonString == null) return [];

    final jsonList = json.decode(jsonString) as List;
    return jsonList.map((json) => MediaItem.fromMap(json)).toList();
  }

  static Future<MediaItem?> getMediaItemById(String id) async {
    final items = await getMediaItems();
    try {
      return items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null; // 如果没找到，返回null
    }
  }

  static Future<List<MediaItem>> getMediaItemsByCategory(
    String category,
  ) async {
    final items = await getMediaItems();
    if (category == '全部') return items;
    return items.where((item) => item.category.name == category).toList();
  }

  static Future<List<MediaItem>> getFavoriteMediaItems() async {
    final items = await getMediaItems();
    return items.where((item) => item.isFavorite).toList();
  }

  static Future<void> updateMediaItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final items = await getMediaItems();
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      final currentItem = items[index];

      // Parse category from updates if provided
      MediaCategory category = currentItem.category;
      if (updates['category'] != null) {
        final categoryValue = updates['category'];
        if (categoryValue is MediaCategory) {
          category = categoryValue;
        } else if (categoryValue is String) {
          // Parse category from string (could be enum name or localized string)
          try {
            category = MediaCategory.values.firstWhere(
              (e) => e.name == categoryValue,
            );
          } catch (_) {
            // If failed, try from localized string (compatible with old data)
            category = MediaCategoryExtension.fromLocalizedString(
              categoryValue,
            );
          }
        }
      }

      final updatedItem = MediaItem(
        id: currentItem.id,
        title: updates['title'] ?? currentItem.title,
        description: updates['description'] ?? currentItem.description,
        filePath: updates['file_path'] ?? currentItem.filePath,
        thumbnailPath: updates['thumbnail_path'] ?? currentItem.thumbnailPath,
        type: MediaType.values.firstWhere(
          (type) => type.name == (updates['type'] ?? currentItem.type.name),
        ),
        category: category,
        duration: updates['duration'] ?? currentItem.duration,
        createdAt: currentItem.createdAt,
        lastPlayedAt: updates['last_played_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(updates['last_played_at'])
            : currentItem.lastPlayedAt,
        playCount: updates['play_count'] ?? currentItem.playCount,
        tags: updates['tags']?.split(',') ?? currentItem.tags,
        isFavorite: updates['is_favorite'] == 1
            ? true
            : (updates['is_favorite'] == 0 ? false : currentItem.isFavorite),
        sourceUrl: updates['source_url'] ?? currentItem.sourceUrl,
      );
      items[index] = updatedItem;
      await _saveMediaItems(items);
    }
  }

  static Future<void> deleteMediaItem(String id) async {
    // 首先删除相关的冥想会话记录
    final sessions = await getAllMeditationSessions();
    final filteredSessions = sessions
        .where((session) => session.mediaItemId != id)
        .toList();
    await _saveMeditationSessions(filteredSessions);

    // 然后删除媒体项
    final items = await getMediaItems();
    items.removeWhere((item) => item.id == id);
    await _saveMediaItems(items);

    // 清理内存中的媒体字节数据
    _mediaBytes.remove(id);
  }

  static Future<void> _saveMediaItems(List<MediaItem> items) async {
    final jsonList = items.map((item) => item.toMap()).toList();
    _localStorage[_mediaItemsKey] = json.encode(jsonList);
  }

  // Preferences operations
  static Future<void> setPreference(String key, String value) async {
    final prefsJson = _localStorage[_preferencesKey];
    final prefs = prefsJson != null
        ? json.decode(prefsJson) as Map<String, dynamic>
        : <String, dynamic>{};
    prefs[key] = value;
    _localStorage[_preferencesKey] = json.encode(prefs);
  }

  static Future<String?> getPreference(String key) async {
    final prefsJson = _localStorage[_preferencesKey];
    if (prefsJson == null) return null;
    final prefs = json.decode(prefsJson) as Map<String, dynamic>;
    return prefs[key];
  }

  static Future<void> clearAllData() async {
    _localStorage.remove(_mediaItemsKey);
    _localStorage.remove(_sessionsKey);
    _localStorage.remove(_preferencesKey);
  }

  // Meditation Sessions operations
  static Future<void> insertMeditationSession(MeditationSession session) async {
    final sessions = await getAllMeditationSessions();
    sessions.removeWhere((existing) => existing.id == session.id);
    sessions.add(session);
    await _saveMeditationSessions(sessions);
  }

  static Future<List<MeditationSession>> getAllMeditationSessions() async {
    final jsonString = _localStorage[_sessionsKey];
    if (jsonString == null) return [];

    final jsonList = json.decode(jsonString) as List;
    final sessions = jsonList
        .map((json) => MeditationSession.fromMap(json))
        .toList();

    // 按开始时间倒序排列（最新的在前面）
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));

    return sessions;
  }

  static Future<List<MeditationSession>> getMeditationSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final sessions = await getAllMeditationSessions();
    return sessions.where((session) {
      return session.startTime.isAfter(startDate) &&
          session.startTime.isBefore(endDate);
    }).toList();
  }

  static Future<List<MeditationSession>> getRecentMeditationSessions({
    int limit = 3,
  }) async {
    final sessions = await getAllMeditationSessions();
    if (sessions.length <= limit) {
      return sessions;
    }
    return sessions.take(limit).toList();
  }

  static Future<void> updateMeditationSession(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final sessions = await getAllMeditationSessions();
    final index = sessions.indexWhere((session) => session.id == id);
    if (index >= 0) {
      final currentSession = sessions[index];
      final updatedSession = currentSession.copyWith(
        title: updates['title'],
        duration: updates['duration'],
        actualDuration: updates['actual_duration'],
        endTime: updates['end_time'] != null
            ? DateTime.fromMillisecondsSinceEpoch(updates['end_time'])
            : null,
        rating: updates['rating']?.toDouble(),
        notes: updates['notes'],
        isCompleted: updates['is_completed'] == 1,
      );
      sessions[index] = updatedSession;
      await _saveMeditationSessions(sessions);
    }
  }

  static Future<void> deleteMeditationSession(String id) async {
    final sessions = await getAllMeditationSessions();
    sessions.removeWhere((session) => session.id == id);
    await _saveMeditationSessions(sessions);
  }

  static Future<void> _saveMeditationSessions(
    List<MeditationSession> sessions,
  ) async {
    final jsonList = sessions.map((session) => session.toMap()).toList();
    _localStorage[_sessionsKey] = json.encode(jsonList);
  }
}
