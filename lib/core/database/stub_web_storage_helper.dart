import 'dart:typed_data';
import '../../features/media/domain/entities/media_item.dart';

// Stub implementation for non-web platforms
class WebStorageHelper {
  static Future<void> insertMediaItem(MediaItem item) async {
    throw UnsupportedError('WebStorageHelper is only available on web');
  }

  static Future<List<MediaItem>> getMediaItems() async {
    throw UnsupportedError('WebStorageHelper is only available on web');
  }

  static Future<List<MediaItem>> getMediaItemsByCategory(
    String category,
  ) async {
    throw UnsupportedError('WebStorageHelper is only available on web');
  }

  static Future<List<MediaItem>> getFavoriteMediaItems() async {
    throw UnsupportedError('WebStorageHelper is only available on web');
  }

  static Future<void> updateMediaItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    throw UnsupportedError('WebStorageHelper is only available on web');
  }

  static Future<void> deleteMediaItem(String id) async {
    throw UnsupportedError('WebStorageHelper is only available on web');
  }

  static Future<void> setPreference(String key, String value) async {
    throw UnsupportedError('WebStorageHelper is only available on web');
  }

  static Future<String?> getPreference(String key) async {
    throw UnsupportedError('WebStorageHelper is only available on web');
  }

  static Future<void> clearAllData() async {
    throw UnsupportedError('WebStorageHelper is only available on web');
  }

  // Media bytes storage methods (not needed on non-web platforms)
  static Future<void> storeMediaBytes(String mediaId, Uint8List bytes) async {
    // No-op on non-web platforms since we use file paths directly
  }

  static String? createBlobUrl(String mediaId, String mimeType) {
    // Not needed on non-web platforms
    return null;
  }

  static void revokeBlobUrl(String url) {
    // No-op on non-web platforms
  }
}
