import 'package:equatable/equatable.dart';

class MeditationSession extends Equatable {
  final String id;
  final String mediaItemId;
  final String title;
  final int duration; // seconds
  final int actualDuration; // actual time meditated
  final DateTime startTime;
  final DateTime? endTime;
  final SessionType type;
  final List<String> soundEffects;
  final double rating; // 1-5 stars
  final String? notes;
  final bool isCompleted;

  const MeditationSession({
    required this.id,
    required this.mediaItemId,
    required this.title,
    required this.duration,
    required this.actualDuration,
    required this.startTime,
    this.endTime,
    required this.type,
    this.soundEffects = const [],
    this.rating = 0.0,
    this.notes,
    required this.isCompleted,
  });

  MeditationSession copyWith({
    String? id,
    String? mediaItemId,
    String? title,
    int? duration,
    int? actualDuration,
    DateTime? startTime,
    DateTime? endTime,
    SessionType? type,
    List<String>? soundEffects,
    double? rating,
    String? notes,
    bool? isCompleted,
  }) {
    return MeditationSession(
      id: id ?? this.id,
      mediaItemId: mediaItemId ?? this.mediaItemId,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      actualDuration: actualDuration ?? this.actualDuration,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      soundEffects: soundEffects ?? this.soundEffects,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'media_item_id': mediaItemId,
      'title': title,
      'duration': duration,
      'actual_duration': actualDuration,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'type': type.name,
      'sound_effects': soundEffects.join(','),
      'rating': rating,
      'notes': notes,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory MeditationSession.fromMap(Map<String, dynamic> map) {
    return MeditationSession(
      id: map['id'],
      mediaItemId: map['media_item_id'],
      title: map['title'],
      duration: map['duration'],
      actualDuration: map['actual_duration'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time']),
      endTime: map['end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['end_time'])
          : null,
      type: SessionType.values.firstWhere((e) => e.name == map['type']),
      soundEffects:
          map['sound_effects'] != null && map['sound_effects'].isNotEmpty
          ? map['sound_effects'].split(',')
          : [],
      rating: map['rating']?.toDouble() ?? 0.0,
      notes: map['notes'],
      isCompleted: map['is_completed'] == 1,
    );
  }

  @override
  List<Object?> get props => [
    id,
    mediaItemId,
    title,
    duration,
    actualDuration,
    startTime,
    endTime,
    type,
    soundEffects,
    rating,
    notes,
    isCompleted,
  ];
}

enum SessionType { meditation, breathing, sleep, focus, relaxation }

extension SessionTypeExtension on SessionType {
  String get displayName {
    switch (this) {
      case SessionType.meditation:
        return '冥想';
      case SessionType.breathing:
        return '呼吸';
      case SessionType.sleep:
        return '睡眠';
      case SessionType.focus:
        return '专注';
      case SessionType.relaxation:
        return '放松';
    }
  }
}
