import '../../domain/entities/media_item.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/media_local_datasource.dart';

class MediaRepositoryImpl implements MediaRepository {
  final MediaLocalDataSource _localDataSource;

  MediaRepositoryImpl(this._localDataSource);

  @override
  Future<void> addMediaItem(MediaItem mediaItem) async {
    await _localDataSource.insertMediaItem(mediaItem);
  }

  @override
  Future<List<MediaItem>> getMediaItems() async {
    return await _localDataSource.getMediaItems();
  }

  @override
  Future<List<MediaItem>> getMediaItemsByCategory(String category) async {
    if (category == '全部') {
      return await getMediaItems();
    }
    return await _localDataSource.getMediaItemsByCategory(category);
  }

  @override
  Future<List<MediaItem>> getFavoriteMediaItems() async {
    return await _localDataSource.getFavoriteMediaItems();
  }

  @override
  Future<List<MediaItem>> getRecentMediaItems(int limit) async {
    return await _localDataSource.getRecentMediaItems(limit);
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    await _localDataSource.updateMediaItem(mediaItem);
  }

  @override
  Future<void> deleteMediaItem(String id) async {
    await _localDataSource.deleteMediaItem(id);
  }

  @override
  Future<void> toggleFavorite(String id, bool isFavorite) async {
    await _localDataSource.toggleFavorite(id, isFavorite);
  }

  @override
  Future<void> updatePlayCount(String id) async {
    await _localDataSource.updatePlayCount(id);
  }
}
