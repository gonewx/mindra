import 'package:flutter/foundation.dart';
import '../../domain/entities/media_item.dart';
import '../../../../core/database/database_helper.dart';

// Conditional import for web storage
import '../../../../core/database/web_storage_helper.dart'
    if (dart.library.io) '../../../../core/database/stub_web_storage_helper.dart';

class MediaLocalDataSource {
  Future<void> insertMediaItem(MediaItem mediaItem) async {
    if (kIsWeb) {
      await WebStorageHelper.insertMediaItem(mediaItem);
    } else {
      await DatabaseHelper.insertMediaItem(mediaItem.toMap());
    }
  }

  Future<List<MediaItem>> getMediaItems() async {
    if (kIsWeb) {
      return await WebStorageHelper.getMediaItems();
    } else {
      final maps = await DatabaseHelper.getMediaItems();
      return maps.map((map) => MediaItem.fromMap(map)).toList();
    }
  }

  Future<List<MediaItem>> getMediaItemsByCategory(String category) async {
    if (kIsWeb) {
      return await WebStorageHelper.getMediaItemsByCategory(category);
    } else {
      if (category == '全部') {
        return await getMediaItems();
      }
      final maps = await DatabaseHelper.getMediaItemsByCategory(category);
      return maps.map((map) => MediaItem.fromMap(map)).toList();
    }
  }

  Future<List<MediaItem>> getFavoriteMediaItems() async {
    if (kIsWeb) {
      return await WebStorageHelper.getFavoriteMediaItems();
    } else {
      final maps = await DatabaseHelper.getFavoriteMediaItems();
      return maps.map((map) => MediaItem.fromMap(map)).toList();
    }
  }

  Future<List<MediaItem>> getRecentMediaItems(int limit) async {
    if (kIsWeb) {
      final items = await WebStorageHelper.getMediaItems();
      return items.where((item) => item.lastPlayedAt != null).toList()
        ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    } else {
      final maps = await DatabaseHelper.getRecentMediaItems(limit);
      return maps.map((map) => MediaItem.fromMap(map)).toList();
    }
  }

  Future<void> updateMediaItem(MediaItem mediaItem) async {
    if (kIsWeb) {
      await WebStorageHelper.updateMediaItem(mediaItem.id, mediaItem.toMap());
    } else {
      await DatabaseHelper.updateMediaItem(mediaItem.id, mediaItem.toMap());
    }
  }

  Future<void> deleteMediaItem(String id) async {
    if (kIsWeb) {
      await WebStorageHelper.deleteMediaItem(id);
    } else {
      await DatabaseHelper.deleteMediaItem(id);
    }
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    if (kIsWeb) {
      await WebStorageHelper.updateMediaItem(id, {'is_favorite': isFavorite ? 1 : 0});
    } else {
      await DatabaseHelper.updateMediaItem(id, {'is_favorite': isFavorite ? 1 : 0});
    }
  }

  Future<void> updatePlayCount(String id) async {
    if (kIsWeb) {
      final items = await WebStorageHelper.getMediaItems();
      final item = items.firstWhere((item) => item.id == id);
      final updatedItem = item.copyWith(
        playCount: item.playCount + 1,
        lastPlayedAt: DateTime.now(),
      );
      await WebStorageHelper.updateMediaItem(id, updatedItem.toMap());
    } else {
      // Get current item to increment play count
      final items = await DatabaseHelper.getMediaItems();
      final item = items.firstWhere((item) => item['id'] == id);
      final currentCount = item['play_count'] ?? 0;
      
      await DatabaseHelper.updateMediaItem(id, {
        'play_count': currentCount + 1,
        'last_played_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  // Store media bytes for web platform
  Future<void> storeMediaBytes(String mediaId, Uint8List bytes) async {
    if (kIsWeb) {
      await WebStorageHelper.storeMediaBytes(mediaId, bytes);
    }
    // For non-web platforms, bytes are not needed since we use file paths
  }

  // Get blob URL for web platform audio playback
  String? createAudioBlobUrl(String mediaId, String mimeType) {
    if (kIsWeb) {
      return WebStorageHelper.createBlobUrl(mediaId, mimeType);
    }
    return null;
  }

  // Clean up blob URL
  void revokeBlobUrl(String url) {
    if (kIsWeb) {
      WebStorageHelper.revokeBlobUrl(url);
    }
  }
}