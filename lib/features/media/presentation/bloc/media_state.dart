import 'package:equatable/equatable.dart';
import '../../domain/entities/media_item.dart';

abstract class MediaState extends Equatable {
  @override
  List<Object?> get props => [];
}

class MediaInitial extends MediaState {}

class MediaLoading extends MediaState {}

class MediaLoaded extends MediaState {
  final List<MediaItem> mediaItems;
  final String currentCategory;

  MediaLoaded(this.mediaItems, {this.currentCategory = '全部'});

  @override
  List<Object?> get props => [mediaItems, currentCategory];
}

class MediaError extends MediaState {
  final String message;

  MediaError(this.message);

  @override
  List<Object?> get props => [message];
}

class MediaAdding extends MediaState {}

class MediaAdded extends MediaState {}

class MediaUpdating extends MediaState {}

class MediaUpdated extends MediaState {}

class MediaDeleting extends MediaState {}

class MediaDeleted extends MediaState {}

class FavoriteToggling extends MediaState {}

class FavoriteToggled extends MediaState {
  final String mediaId;
  final bool isFavorite;

  FavoriteToggled(this.mediaId, this.isFavorite);

  @override
  List<Object?> get props => [mediaId, isFavorite];
}
