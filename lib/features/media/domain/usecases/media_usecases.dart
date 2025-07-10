import '../entities/media_item.dart';
import '../repositories/media_repository.dart';

class AddMediaUseCase {
  final MediaRepository _repository;

  AddMediaUseCase(this._repository);

  Future<void> call(MediaItem mediaItem) async {
    await _repository.addMediaItem(mediaItem);
  }
}

class GetMediaItemsUseCase {
  final MediaRepository _repository;

  GetMediaItemsUseCase(this._repository);

  Future<List<MediaItem>> call() async {
    return await _repository.getMediaItems();
  }
}

class GetMediaItemsByCategoryUseCase {
  final MediaRepository _repository;

  GetMediaItemsByCategoryUseCase(this._repository);

  Future<List<MediaItem>> call(String category) async {
    return await _repository.getMediaItemsByCategory(category);
  }
}

class GetFavoriteMediaItemsUseCase {
  final MediaRepository _repository;

  GetFavoriteMediaItemsUseCase(this._repository);

  Future<List<MediaItem>> call() async {
    return await _repository.getFavoriteMediaItems();
  }
}

class ToggleFavoriteUseCase {
  final MediaRepository _repository;

  ToggleFavoriteUseCase(this._repository);

  Future<void> call(String id, bool isFavorite) async {
    await _repository.toggleFavorite(id, isFavorite);
  }
}

class UpdateMediaItemUseCase {
  final MediaRepository _repository;

  UpdateMediaItemUseCase(this._repository);

  Future<void> call(MediaItem mediaItem) async {
    await _repository.updateMediaItem(mediaItem);
  }
}

class DeleteMediaItemUseCase {
  final MediaRepository _repository;

  DeleteMediaItemUseCase(this._repository);

  Future<void> call(String id) async {
    await _repository.deleteMediaItem(id);
  }
}
