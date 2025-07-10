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
      emit(MediaError('Failed to load media items: ${e.toString()}'));
    }
  }

  Future<void> _onLoadMediaItemsByCategory(
    LoadMediaItemsByCategory event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaLoading());
      final mediaItems = await _getMediaItemsByCategoryUseCase(event.category);
      emit(MediaLoaded(mediaItems, currentCategory: event.category));
    } catch (e) {
      emit(MediaError('Failed to load media items: ${e.toString()}'));
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
      emit(MediaError('Failed to load favorite media items: ${e.toString()}'));
    }
  }

  Future<void> _onAddMediaItem(
    AddMediaItem event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaAdding());

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
          emit(MediaError('Failed to store media file: ${e.toString()}'));
          return;
        }
      }

      final mediaItem = MediaItem(
        id: mediaId,
        title: event.title,
        description: event.description,
        filePath: event.filePath,
        type: event.type,
        category: event.category,
        duration: event.duration, // Use actual duration from event
        createdAt: DateTime.now(),
        sourceUrl: event.sourceUrl,
      );

      await _addMediaUseCase(mediaItem);
      emit(MediaAdded());

      // Reload media items
      add(LoadMediaItems());
    } catch (e) {
      emit(MediaError('Failed to add media item: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateMediaItem(
    UpdateMediaItem event,
    Emitter<MediaState> emit,
  ) async {
    try {
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
      emit(MediaError('Failed to update media item: ${e.toString()}'));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<MediaState> emit,
  ) async {
    try {
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
      emit(MediaError('Failed to toggle favorite: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteMediaItem(
    DeleteMediaItem event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaDeleting());
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
      emit(MediaError('Failed to delete media item: ${e.toString()}'));
    }
  }

  Future<void> _onSearchMediaItems(
    SearchMediaItems event,
    Emitter<MediaState> emit,
  ) async {
    try {
      emit(MediaLoading());
      final allItems = await _getMediaItemsUseCase();
      final filteredItems = allItems.where((item) {
        return item.title.toLowerCase().contains(event.query.toLowerCase()) ||
            item.category.toLowerCase().contains(event.query.toLowerCase()) ||
            (item.description?.toLowerCase().contains(
                  event.query.toLowerCase(),
                ) ??
                false);
      }).toList();
      emit(MediaLoaded(filteredItems, currentCategory: '搜索结果'));
    } catch (e) {
      emit(MediaError('Failed to search media items: ${e.toString()}'));
    }
  }
}
