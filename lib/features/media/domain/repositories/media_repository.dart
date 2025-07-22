import '../entities/media_item.dart';

abstract class MediaRepository {
  Future<void> addMediaItem(MediaItem mediaItem);
  Future<List<MediaItem>> getMediaItems();
  Future<MediaItem?> getMediaItemById(String id);
  Future<List<MediaItem>> getMediaItemsByCategory(String category);
  Future<List<MediaItem>> getFavoriteMediaItems();
  Future<List<MediaItem>> getRecentMediaItems(int limit);
  Future<void> updateMediaItem(MediaItem mediaItem);
  Future<void> deleteMediaItem(String id);
  Future<void> toggleFavorite(String id, bool isFavorite);
  Future<void> updatePlayCount(String id);
  Future<void> updateMediaDuration(String id, int durationSeconds);
}
