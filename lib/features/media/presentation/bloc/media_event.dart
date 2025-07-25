import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/media_item.dart';
import '../../../../core/constants/media_category.dart';

abstract class MediaEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadMediaItems extends MediaEvent {}

class LoadMediaItemsByCategory extends MediaEvent {
  final String category; // 保持String类型以支持"全部"等特殊分类

  LoadMediaItemsByCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class LoadFavoriteMediaItems extends MediaEvent {}

class AddMediaItem extends MediaEvent {
  final String title;
  final String? description;
  final String filePath;
  final MediaCategory category;
  final String? sourceUrl;
  final MediaType type;
  final int duration;
  final Uint8List? fileBytes; // For web platform file bytes

  AddMediaItem({
    required this.title,
    this.description,
    required this.filePath,
    required this.category,
    this.sourceUrl,
    required this.type,
    required this.duration,
    this.fileBytes,
  });

  @override
  List<Object?> get props => [
    title,
    description,
    filePath,
    category,
    sourceUrl,
    type,
    duration,
    fileBytes,
  ];
}

class UpdateMediaItem extends MediaEvent {
  final MediaItem mediaItem;

  UpdateMediaItem(this.mediaItem);

  @override
  List<Object?> get props => [mediaItem];
}

class ToggleFavorite extends MediaEvent {
  final String id;
  final bool isFavorite;

  ToggleFavorite(this.id, this.isFavorite);

  @override
  List<Object?> get props => [id, isFavorite];
}

class DeleteMediaItem extends MediaEvent {
  final String id;

  DeleteMediaItem(this.id);

  @override
  List<Object?> get props => [id];
}

class SearchMediaItems extends MediaEvent {
  final String query;

  SearchMediaItems(this.query);

  @override
  List<Object?> get props => [query];
}
