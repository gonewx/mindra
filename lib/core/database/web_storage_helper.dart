import 'dart:html' as html show window, Storage, Blob, Url;
import 'dart:convert';
import 'dart:typed_data';
import '../../features/media/domain/entities/media_item.dart';

class WebStorageHelper {
  static const String _mediaItemsKey = 'mindra_media_items';
  static const String _sessionsKey = 'mindra_sessions';
  static const String _preferencesKey = 'mindra_preferences';
  
  // Store blob URLs temporarily (not persisted)
  static final Map<String, String> _blobUrls = {};
  static final Map<String, Uint8List> _mediaBytes = {};

  static html.Storage get _localStorage => html.window.localStorage;

  // Store file bytes in memory for current session
  static Future<void> storeMediaBytes(String mediaId, Uint8List bytes) async {
    try {
      print('Storing media bytes for ID: $mediaId, size: ${bytes.length} bytes');
      _mediaBytes[mediaId] = bytes;
      print('Successfully stored media bytes in memory for ID: $mediaId');
    } catch (e) {
      print('Failed to store media bytes: $e');
      throw Exception('Failed to store media bytes: $e');
    }
  }

  // Retrieve file bytes and create blob URL
  static String? createBlobUrl(String mediaId, String mimeType) {
    try {
      // Get bytes from memory storage
      final bytes = _mediaBytes[mediaId];
      if (bytes == null) {
        print('No stored bytes found for media ID: $mediaId');
        return null;
      }

      print('Found stored bytes for media ID: $mediaId, length: ${bytes.length}');
      
      // Create blob and return object URL
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrl(blob);
      print('Created blob URL: $url');
      return url;
    } catch (e) {
      print('Error creating blob URL: $e');
      return null;
    }
  }

  // Clean up blob URL
  static void revokeBlobUrl(String url) {
    try {
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print('Error revoking blob URL: $e');
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

  static Future<List<MediaItem>> getMediaItemsByCategory(String category) async {
    final items = await getMediaItems();
    if (category == '全部') return items;
    return items.where((item) => item.category == category).toList();
  }

  static Future<List<MediaItem>> getFavoriteMediaItems() async {
    final items = await getMediaItems();
    return items.where((item) => item.isFavorite).toList();
  }

  static Future<void> updateMediaItem(String id, Map<String, dynamic> updates) async {
    final items = await getMediaItems();
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      final currentItem = items[index];
      final updatedItem = MediaItem(
        id: currentItem.id,
        title: updates['title'] ?? currentItem.title,
        description: updates['description'] ?? currentItem.description,
        filePath: updates['file_path'] ?? currentItem.filePath,
        thumbnailPath: updates['thumbnail_path'] ?? currentItem.thumbnailPath,
        type: MediaType.values.firstWhere(
          (type) => type.name == (updates['type'] ?? currentItem.type.name),
        ),
        category: updates['category'] ?? currentItem.category,
        duration: updates['duration'] ?? currentItem.duration,
        createdAt: currentItem.createdAt,
        lastPlayedAt: updates['last_played_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(updates['last_played_at'])
          : currentItem.lastPlayedAt,
        playCount: updates['play_count'] ?? currentItem.playCount,
        tags: updates['tags']?.split(',') ?? currentItem.tags,
        isFavorite: updates['is_favorite'] == 1 ? true : (updates['is_favorite'] == 0 ? false : currentItem.isFavorite),
        sourceUrl: updates['source_url'] ?? currentItem.sourceUrl,
      );
      items[index] = updatedItem;
      await _saveMediaItems(items);
    }
  }

  static Future<void> deleteMediaItem(String id) async {
    final items = await getMediaItems();
    items.removeWhere((item) => item.id == id);
    await _saveMediaItems(items);
  }

  static Future<void> _saveMediaItems(List<MediaItem> items) async {
    final jsonList = items.map((item) => item.toMap()).toList();
    _localStorage[_mediaItemsKey] = json.encode(jsonList);
  }

  // Preferences operations
  static Future<void> setPreference(String key, String value) async {
    final prefsJson = _localStorage[_preferencesKey];
    final prefs = prefsJson != null ? json.decode(prefsJson) as Map<String, dynamic> : <String, dynamic>{};
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
}