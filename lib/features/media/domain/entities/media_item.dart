import 'package:equatable/equatable.dart';
import '../../../../core/constants/media_category.dart';

class MediaItem extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String filePath;
  final String? thumbnailPath;
  final MediaType type;
  final MediaCategory category;
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
    MediaCategory? category,
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
      'category': category.name,
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
    try {
      // 验证必需字段
      if (map['id'] == null || map['id'].toString().isEmpty) {
        throw ArgumentError('MediaItem ID cannot be null or empty');
      }

      if (map['title'] == null || map['title'].toString().isEmpty) {
        throw ArgumentError('MediaItem title cannot be null or empty');
      }

      if (map['file_path'] == null || map['file_path'].toString().isEmpty) {
        throw ArgumentError('MediaItem file_path cannot be null or empty');
      }

      // 安全地解析媒体类型
      MediaType type = MediaType.audio; // 默认值
      if (map['type'] != null) {
        try {
          type = MediaType.values.firstWhere(
            (e) => e.name == map['type'].toString(),
            orElse: () => MediaType.audio,
          );
        } catch (e) {
          // 如果解析失败，使用默认值
          type = MediaType.audio;
        }
      }

      // 安全地解析分类
      MediaCategory category = _parseCategoryFromMap(map['category']);

      // 安全地解析时间戳
      DateTime createdAt = DateTime.now(); // 默认值
      if (map['created_at'] != null) {
        try {
          final timestamp = map['created_at'];
          if (timestamp is int) {
            createdAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else if (timestamp is String) {
            createdAt = DateTime.parse(timestamp);
          }
        } catch (e) {
          // 如果解析失败，使用当前时间
          createdAt = DateTime.now();
        }
      }

      // 安全地解析最后播放时间
      DateTime? lastPlayedAt;
      if (map['last_played_at'] != null) {
        try {
          final timestamp = map['last_played_at'];
          if (timestamp is int) {
            lastPlayedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else if (timestamp is String) {
            lastPlayedAt = DateTime.parse(timestamp);
          }
        } catch (e) {
          // 如果解析失败，设为null
          lastPlayedAt = null;
        }
      }

      // 安全地解析标签
      List<String> tags = [];
      if (map['tags'] != null) {
        try {
          final tagsValue = map['tags'];
          if (tagsValue is String && tagsValue.isNotEmpty) {
            tags = tagsValue
                .split(',')
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList();
          } else if (tagsValue is List) {
            tags = tagsValue
                .map((tag) => tag.toString().trim())
                .where((tag) => tag.isNotEmpty)
                .toList();
          }
        } catch (e) {
          // 如果解析失败，使用空列表
          tags = [];
        }
      }

      // 安全地解析数值字段
      int duration = 0;
      if (map['duration'] != null) {
        try {
          duration = int.parse(map['duration'].toString());
          if (duration < 0) duration = 0; // 确保非负
        } catch (e) {
          duration = 0;
        }
      }

      int playCount = 0;
      if (map['play_count'] != null) {
        try {
          playCount = int.parse(map['play_count'].toString());
          if (playCount < 0) playCount = 0; // 确保非负
        } catch (e) {
          playCount = 0;
        }
      }

      // 安全地解析布尔值
      bool isFavorite = false;
      if (map['is_favorite'] != null) {
        try {
          final favoriteValue = map['is_favorite'];
          if (favoriteValue is bool) {
            isFavorite = favoriteValue;
          } else if (favoriteValue is int) {
            isFavorite = favoriteValue == 1;
          } else if (favoriteValue is String) {
            isFavorite =
                favoriteValue.toLowerCase() == 'true' || favoriteValue == '1';
          }
        } catch (e) {
          isFavorite = false;
        }
      }

      return MediaItem(
        id: map['id'].toString(),
        title: map['title'].toString(),
        description: map['description']?.toString(),
        filePath: map['file_path'].toString(),
        thumbnailPath: map['thumbnail_path']?.toString(),
        type: type,
        category: category,
        duration: duration,
        createdAt: createdAt,
        lastPlayedAt: lastPlayedAt,
        playCount: playCount,
        tags: tags,
        isFavorite: isFavorite,
        sourceUrl: map['source_url']?.toString(),
      );
    } catch (e) {
      // 如果完全解析失败，抛出更详细的异常
      throw FormatException(
        'Failed to parse MediaItem from map: $e. Map data: $map',
      );
    }
  }

  /// 从Map中解析分类，兼容旧数据
  static MediaCategory _parseCategoryFromMap(dynamic categoryValue) {
    if (categoryValue == null) return MediaCategory.meditation;

    try {
      final categoryString = categoryValue.toString().trim();

      // 首先尝试从枚举名称解析
      final enumCategory = MediaCategoryExtension.fromEnumName(categoryString);
      if (enumCategory != null) {
        return enumCategory;
      }

      // 然后尝试从本地化字符串解析
      return MediaCategoryExtension.fromLocalizedString(categoryString);
    } catch (e) {
      // 如果所有解析都失败，返回默认分类
      return MediaCategory.meditation;
    }
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
