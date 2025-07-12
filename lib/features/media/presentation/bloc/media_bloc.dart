import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/usecases/media_usecases.dart';
import '../../data/datasources/media_local_datasource.dart';
import 'media_event.dart';
import 'media_state.dart';

class MediaBloc extends Bloc<MediaEvent, MediaState> {
  final AddMediaUseCase _addMediaUseCase;
  final GetMediaItemsUseCase _getMediaItemsUseCase;
  final GetMediaItemsByCategoryUseCase _getMediaItemsByCategoryUseCase;
  final GetFavoriteMediaItemsUseCase _getFavoriteMediaItemsUseCase;
  final UpdateMediaItemUseCase _updateMediaItemUseCase;
  final ToggleFavoriteUseCase _toggleFavoriteUseCase;
  final DeleteMediaItemUseCase _deleteMediaItemUseCase;

  final _uuid = const Uuid();

  MediaBloc({
    required AddMediaUseCase addMediaUseCase,
    required GetMediaItemsUseCase getMediaItemsUseCase,
    required GetMediaItemsByCategoryUseCase getMediaItemsByCategoryUseCase,
    required GetFavoriteMediaItemsUseCase getFavoriteMediaItemsUseCase,
    required UpdateMediaItemUseCase updateMediaItemUseCase,
    required ToggleFavoriteUseCase toggleFavoriteUseCase,
    required DeleteMediaItemUseCase deleteMediaItemUseCase,
  }) : _addMediaUseCase = addMediaUseCase,
       _getMediaItemsUseCase = getMediaItemsUseCase,
       _getMediaItemsByCategoryUseCase = getMediaItemsByCategoryUseCase,
       _getFavoriteMediaItemsUseCase = getFavoriteMediaItemsUseCase,
       _updateMediaItemUseCase = updateMediaItemUseCase,
       _toggleFavoriteUseCase = toggleFavoriteUseCase,
       _deleteMediaItemUseCase = deleteMediaItemUseCase,
       super(MediaInitial()) {
    on<LoadMediaItems>(_onLoadMediaItems);
    on<LoadMediaItemsByCategory>(_onLoadMediaItemsByCategory);
    on<LoadFavoriteMediaItems>(_onLoadFavoriteMediaItems);
    on<AddMediaItem>(_onAddMediaItem);
    on<UpdateMediaItem>(_onUpdateMediaItem);
    on<ToggleFavorite>(_onToggleFavorite);
    on<DeleteMediaItem>(_onDeleteMediaItem);
    on<SearchMediaItems>(_onSearchMediaItems);
  }

  Future<void> _onLoadMediaItems(
    LoadMediaItems event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaLoading());
      final mediaItems = await _getMediaItemsUseCase();
      emit(MediaLoaded(mediaItems));
    } catch (e) {
      final errorMessage = _getErrorMessage(e, '加载媒体项目');
      emit(MediaError(errorMessage));
      if (kDebugMode) {
        print('Error loading media items: $e');
      }
    }
  }

  Future<void> _onLoadMediaItemsByCategory(
    LoadMediaItemsByCategory event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaLoading());

      // 验证分类参数
      if (event.category.isEmpty) {
        throw ArgumentError('Category cannot be empty');
      }

      final mediaItems = await _getMediaItemsByCategoryUseCase(event.category);
      emit(MediaLoaded(mediaItems, currentCategory: event.category));
    } catch (e) {
      final errorMessage = _getErrorMessage(e, '加载分类媒体项目');
      emit(MediaError(errorMessage));
      if (kDebugMode) {
        print('Error loading media items by category ${event.category}: $e');
      }
    }
  }

  Future<void> _onLoadFavoriteMediaItems(
    LoadFavoriteMediaItems event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaLoading());
      final mediaItems = await _getFavoriteMediaItemsUseCase();
      emit(MediaLoaded(mediaItems, currentCategory: '收藏'));
    } catch (e) {
      final errorMessage = _getErrorMessage(e, '加载收藏媒体项目');
      emit(MediaError(errorMessage));
      if (kDebugMode) {
        print('Error loading favorite media items: $e');
      }
    }
  }

  Future<void> _onAddMediaItem(
    AddMediaItem event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaAdding());

      // 验证输入参数
      if (event.title.trim().isEmpty) {
        throw ArgumentError('Media title cannot be empty');
      }

      if (event.filePath.trim().isEmpty) {
        throw ArgumentError('Media file path cannot be empty');
      }

      if (event.duration < 0) {
        throw ArgumentError('Media duration cannot be negative');
      }

      final mediaId = _uuid.v4();
      debugPrint('Generated media ID: $mediaId');

      // Store file bytes for web platform BEFORE creating media item
      if (kIsWeb && event.fileBytes != null) {
        try {
          debugPrint(
            'Storing media bytes for web platform, mediaId: $mediaId, bytes length: ${event.fileBytes!.length}',
          );
          // Use the MediaLocalDataSource to store bytes
          final dataSource = MediaLocalDataSource();
          await dataSource.storeMediaBytes(mediaId, event.fileBytes!);
          debugPrint('Successfully stored media bytes for mediaId: $mediaId');
        } catch (e) {
          debugPrint('Failed to store media bytes: $e');
          emit(MediaError('存储媒体文件失败：${e.toString()}'));
          return;
        }
      }

      final mediaItem = MediaItem(
        id: mediaId,
        title: event.title.trim(),
        description: event.description?.trim(),
        filePath: event.filePath.trim(),
        type: event.type,
        category: event.category,
        duration: event.duration,
        createdAt: DateTime.now(),
        sourceUrl: event.sourceUrl?.trim(),
      );

      await _addMediaUseCase(mediaItem);
      emit(MediaAdded());

      // Reload media items
      add(LoadMediaItems());
    } catch (e) {
      final errorMessage = _getErrorMessage(e, '添加媒体项目');
      emit(MediaError(errorMessage));
      if (kDebugMode) {
        print('Error adding media item: $e');
      }
    }
  }

  Future<void> _onUpdateMediaItem(
    UpdateMediaItem event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaUpdating());

      // 验证媒体项目
      if (event.mediaItem.id.isEmpty) {
        throw ArgumentError('Media item ID cannot be empty');
      }

      if (event.mediaItem.title.trim().isEmpty) {
        throw ArgumentError('Media item title cannot be empty');
      }

      await _updateMediaItemUseCase(event.mediaItem);
      emit(MediaUpdated());

      // Reload current media items
      if (state is MediaLoaded) {
        final currentState = state as MediaLoaded;
        if (currentState.currentCategory == '收藏') {
          add(LoadFavoriteMediaItems());
        } else {
          add(LoadMediaItemsByCategory(currentState.currentCategory));
        }
      } else {
        add(LoadMediaItems());
      }
    } catch (e) {
      final errorMessage = _getErrorMessage(e, '更新媒体项目');
      emit(MediaError(errorMessage));
      if (kDebugMode) {
        print('Error updating media item: $e');
      }
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(FavoriteToggling());

      // 验证ID
      if (event.id.isEmpty) {
        throw ArgumentError('Media item ID cannot be empty');
      }

      await _toggleFavoriteUseCase(event.id, event.isFavorite);
      emit(FavoriteToggled(event.id, event.isFavorite));

      // Reload current media items
      if (state is MediaLoaded) {
        final currentState = state as MediaLoaded;
        if (currentState.currentCategory == '收藏') {
          add(LoadFavoriteMediaItems());
        } else {
          add(LoadMediaItemsByCategory(currentState.currentCategory));
        }
      }
    } catch (e) {
      final errorMessage = _getErrorMessage(e, '切换收藏状态');
      emit(MediaError(errorMessage));
      if (kDebugMode) {
        print('Error toggling favorite for ${event.id}: $e');
      }
    }
  }

  Future<void> _onDeleteMediaItem(
    DeleteMediaItem event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaDeleting());

      // 验证ID
      if (event.id.isEmpty) {
        throw ArgumentError('Media item ID cannot be empty');
      }

      await _deleteMediaItemUseCase(event.id);
      emit(MediaDeleted());

      // Reload media items
      if (state is MediaLoaded) {
        final currentState = state as MediaLoaded;
        add(LoadMediaItemsByCategory(currentState.currentCategory));
      } else {
        add(LoadMediaItems());
      }
    } catch (e) {
      final errorMessage = _getErrorMessage(e, '删除媒体项目');
      emit(MediaError(errorMessage));
      if (kDebugMode) {
        print('Error deleting media item ${event.id}: $e');
      }
    }
  }

  Future<void> _onSearchMediaItems(
    SearchMediaItems event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaLoading());

      // 验证搜索查询
      if (event.query.trim().isEmpty) {
        // 如果查询为空，返回所有项目
        final allItems = await _getMediaItemsUseCase();
        emit(MediaLoaded(allItems, currentCategory: '全部'));
        return;
      }

      final allItems = await _getMediaItemsUseCase();
      final query = event.query.trim().toLowerCase();

      final filteredItems = allItems.where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.category.name.toLowerCase().contains(query) ||
            (item.description?.toLowerCase().contains(query) ?? false) ||
            item.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();

      emit(MediaLoaded(filteredItems, currentCategory: '搜索结果'));
    } catch (e) {
      final errorMessage = _getErrorMessage(e, '搜索媒体项目');
      emit(MediaError(errorMessage));
      if (kDebugMode) {
        print('Error searching media items with query "${event.query}": $e');
      }
    }
  }

  /// 获取用户友好的错误信息
  String _getErrorMessage(dynamic error, String operation) {
    if (error is ArgumentError) {
      return '输入参数错误：${error.message}';
    } else if (error is FormatException) {
      return '数据格式错误：${error.message}';
    } else if (error is Exception) {
      final message = error.toString();
      if (message.contains('database')) {
        return '数据库操作失败，请稍后重试';
      } else if (message.contains('network') ||
          message.contains('connection')) {
        return '网络连接失败，请检查网络设置';
      } else if (message.contains('permission')) {
        return '权限不足，请检查应用权限设置';
      } else if (message.contains('storage') || message.contains('file')) {
        return '存储空间不足或文件访问失败';
      }
    }

    return '$operation失败：${error.toString()}';
  }
}
