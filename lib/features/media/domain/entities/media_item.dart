import 'package:equatable/equatable.dart';

class MediaItem extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String filePath;
  final String? thumbnailPath;
  final MediaType type;
  final String category;
  final int duration; // seconds
  final DateTime createdAt;
  final DateTime? lastPlayedAt;
  final int playCount;
  final List<String> tags;
  final bool isFavorite;
  final String? sourceUrl; // for network resources

  const MediaItem({
    required this.id,
    required this.title,
    this.description,
    required this.filePath,
    this.thumbnailPath,
    required this.type,
    required this.category,
    required this.duration,
    required this.createdAt,
    this.lastPlayedAt,
    this.playCount = 0,
    this.tags = const [],
    this.isFavorite = false,
    this.sourceUrl,
  });

  MediaItem copyWith({
    String? id,
    String? title,
    String? description,
    String? filePath,
    String? thumbnailPath,
    MediaType? type,
    String? category,
    int? duration,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    int? playCount,
    List<String>? tags,
    bool? isFavorite,
    String? sourceUrl,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      type: type ?? this.type,
      category: category ?? this.category,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playCount: playCount ?? this.playCount,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      sourceUrl: sourceUrl ?? this.sourceUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'file_path': filePath,
      'thumbnail_path': thumbnailPath,
      'type': type.name,
      'category': category,
      'duration': duration,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_played_at': lastPlayedAt?.millisecondsSinceEpoch,
      'play_count': playCount,
      'tags': tags.join(','),
      'is_favorite': isFavorite ? 1 : 0,
      'source_url': sourceUrl,
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      filePath: map['file_path'],
      thumbnailPath: map['thumbnail_path'],
      type: MediaType.values.firstWhere((e) => e.name == map['type']),
      category: map['category'],
      duration: map['duration'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      lastPlayedAt: map['last_played_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_played_at'])
          : null,
      playCount: map['play_count'] ?? 0,
      tags: map['tags'] != null && map['tags'].isNotEmpty
          ? map['tags'].split(',')
          : [],
      isFavorite: map['is_favorite'] == 1,
      sourceUrl: map['source_url'],
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    filePath,
    thumbnailPath,
    type,
    category,
    duration,
    createdAt,
    lastPlayedAt,
    playCount,
    tags,
    isFavorite,
    sourceUrl,
  ];
}

enum MediaType { audio, video }

extension MediaTypeExtension on MediaType {
  String get displayName {
    switch (this) {
      case MediaType.audio:
        return '音频';
      case MediaType.video:
        return '视频';
    }
  }
}
