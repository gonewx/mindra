import 'package:flutter/foundation.dart';
import '../../domain/entities/media_item.dart';
import '../../../../core/database/database_helper.dart';

// Conditional import for web storage
import '../../../../core/database/web_storage_helper.dart'
    if (dart.library.io) '../../../../core/database/stub_web_storage_helper.dart';

class MediaLocalDataSource {
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  Future<void> insertMediaItem(MediaItem mediaItem) async {
    await _executeWithRetry(() async {
      if (kIsWeb) {
        await WebStorageHelper.insertMediaItem(mediaItem);
      } else {
        await DatabaseHelper.insertMediaItem(mediaItem.toMap());
      }
    }, 'insertMediaItem');
  }

  Future<List<MediaItem>> getMediaItems() async {
    return await _executeWithRetry(() async {
      if (kIsWeb) {
        return await WebStorageHelper.getMediaItems();
      } else {
        final maps = await DatabaseHelper.getMediaItems();
        return _parseMediaItems(maps);
      }
    }, 'getMediaItems');
  }

  Future<MediaItem?> getMediaItemById(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('Media item ID cannot be empty');
    }

    return await _executeWithRetry(() async {
      if (kIsWeb) {
        return await WebStorageHelper.getMediaItemById(id);
      } else {
        final map = await DatabaseHelper.getMediaItemById(id);
        if (map == null) return null;
        return MediaItem.fromMap(map);
      }
    }, 'getMediaItemById');
  }

  Future<List<MediaItem>> getMediaItemsByCategory(String category) async {
    return await _executeWithRetry(() async {
      if (kIsWeb) {
        return await WebStorageHelper.getMediaItemsByCategory(category);
      } else {
        if (category == '全部') {
          return await getMediaItems();
        }
        final maps = await DatabaseHelper.getMediaItemsByCategory(category);
        return _parseMediaItems(maps);
      }
    }, 'getMediaItemsByCategory');
  }

  Future<List<MediaItem>> getFavoriteMediaItems() async {
    return await _executeWithRetry(() async {
      if (kIsWeb) {
        return await WebStorageHelper.getFavoriteMediaItems();
      } else {
        final maps = await DatabaseHelper.getFavoriteMediaItems();
        return _parseMediaItems(maps);
      }
    }, 'getFavoriteMediaItems');
  }

  Future<List<MediaItem>> getRecentMediaItems(int limit) async {
    return await _executeWithRetry(() async {
      if (kIsWeb) {
        final items = await WebStorageHelper.getMediaItems();
        final recentItems = items
            .where((item) => item.lastPlayedAt != null)
            .toList();
        recentItems.sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
        return recentItems.take(limit).toList();
      } else {
        final maps = await DatabaseHelper.getRecentMediaItems(limit);
        return _parseMediaItems(maps);
      }
    }, 'getRecentMediaItems');
  }

  Future<void> updateMediaItem(MediaItem mediaItem) async {
    await _executeWithRetry(() async {
      if (kIsWeb) {
        await WebStorageHelper.updateMediaItem(mediaItem.id, mediaItem.toMap());
      } else {
        await DatabaseHelper.updateMediaItem(mediaItem.id, mediaItem.toMap());
      }
    }, 'updateMediaItem');
  }

  Future<void> deleteMediaItem(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('Media item ID cannot be empty');
    }

    await _executeWithRetry(() async {
      if (kIsWeb) {
        await WebStorageHelper.deleteMediaItem(id);
      } else {
        await DatabaseHelper.deleteMediaItem(id);
      }
    }, 'deleteMediaItem');
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    if (id.isEmpty) {
      throw ArgumentError('Media item ID cannot be empty');
    }

    await _executeWithRetry(() async {
      final updates = {'is_favorite': isFavorite ? 1 : 0};
      if (kIsWeb) {
        await WebStorageHelper.updateMediaItem(id, updates);
      } else {
        await DatabaseHelper.updateMediaItem(id, updates);
      }
    }, 'toggleFavorite');
  }

  Future<void> updatePlayCount(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('Media item ID cannot be empty');
    }

    await _executeWithRetry(() async {
      if (kIsWeb) {
        final items = await WebStorageHelper.getMediaItems();
        final item = items.firstWhere((item) => item.id == id);
        final updates = {
          'play_count': item.playCount + 1,
          'last_played_at': DateTime.now().millisecondsSinceEpoch,
        };
        await WebStorageHelper.updateMediaItem(id, updates);
      } else {
        // 获取当前播放次数
        final maps = await DatabaseHelper.getMediaItems();
        final currentItem = maps.firstWhere((map) => map['id'] == id);
        final currentPlayCount = currentItem['play_count'] ?? 0;

        final updates = {
          'play_count': currentPlayCount + 1,
          'last_played_at': DateTime.now().millisecondsSinceEpoch,
        };
        await DatabaseHelper.updateMediaItem(id, updates);
      }
    }, 'updatePlayCount');
  }

  // Web平台特有的方法
  Future<void> storeMediaBytes(String mediaId, Uint8List bytes) async {
    if (!kIsWeb) {
      return; // 非Web平台不需要存储字节
    }

    if (mediaId.isEmpty) {
      throw ArgumentError('Media ID cannot be empty');
    }

    if (bytes.isEmpty) {
      throw ArgumentError('Media bytes cannot be empty');
    }

    await _executeWithRetry(() async {
      await WebStorageHelper.storeMediaBytes(mediaId, bytes);
    }, 'storeMediaBytes');
  }

  // 获取Web平台的音频Blob URL
  String? createAudioBlobUrl(String mediaId, String mimeType) {
    if (!kIsWeb) {
      return null; // 非Web平台不需要Blob URL
    }

    if (mediaId.isEmpty) {
      throw ArgumentError('Media ID cannot be empty');
    }

    if (mimeType.isEmpty) {
      throw ArgumentError('MIME type cannot be empty');
    }

    try {
      return WebStorageHelper.createBlobUrl(mediaId, mimeType);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to create blob URL for $mediaId: $e');
      }
      return null;
    }
  }

  // 清理Web平台的Blob URL
  void revokeBlobUrl(String url) {
    if (!kIsWeb) {
      return; // 非Web平台不需要清理Blob URL
    }

    if (url.isEmpty) {
      if (kDebugMode) {
        debugPrint('Cannot revoke empty blob URL');
      }
      return;
    }

    try {
      WebStorageHelper.revokeBlobUrl(url);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to revoke blob URL $url: $e');
      }
    }
  }

  /// 解析媒体项目列表，处理解析错误
  List<MediaItem> _parseMediaItems(List<Map<String, dynamic>> maps) {
    final items = <MediaItem>[];
    final errors = <String>[];

    for (final map in maps) {
      try {
        final item = MediaItem.fromMap(map);
        items.add(item);
      } catch (e) {
        errors.add('Failed to parse media item: $e');
        if (kDebugMode) {
          debugPrint('Error parsing media item from map: $map, error: $e');
        }
      }
    }

    if (errors.isNotEmpty && kDebugMode) {
      debugPrint(
        'Encountered ${errors.length} parsing errors: ${errors.join(', ')}',
      );
    }

    return items;
  }

  /// 执行操作并在失败时重试
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    Exception? lastException;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());

        if (kDebugMode) {
          debugPrint('$operationName attempt $attempt failed: $e');
        }

        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
        }
      }
    }

    throw Exception(
      'Failed to execute $operationName after $_maxRetries attempts. Last error: $lastException',
    );
  }
}
