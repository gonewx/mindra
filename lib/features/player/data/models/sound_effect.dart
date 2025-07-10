class SoundEffect {
  final String id;
  final String name;
  final String iconName;
  final String? assetPath;
  final String? url;
  final bool isBuiltIn;
  final double defaultVolume;

  const SoundEffect({
    required this.id,
    required this.name,
    required this.iconName,
    this.assetPath,
    this.url,
    this.isBuiltIn = true,
    this.defaultVolume = 0.5,
  });

  factory SoundEffect.fromJson(Map<String, dynamic> json) {
    return SoundEffect(
      id: json['id'],
      name: json['name'],
      iconName: json['iconName'],
      assetPath: json['assetPath'],
      url: json['url'],
      isBuiltIn: json['isBuiltIn'] ?? true,
      defaultVolume: json['defaultVolume']?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'assetPath': assetPath,
      'url': url,
      'isBuiltIn': isBuiltIn,
      'defaultVolume': defaultVolume,
    };
  }
}

// 预置音效配置
class BuiltInSoundEffects {
  static const List<SoundEffect> effects = [
    SoundEffect(
      id: 'rain',
      name: '雨声',
      iconName: 'grain',
      assetPath: 'audio/effects/rain.mp3',
    ),
    SoundEffect(
      id: 'ocean',
      name: '海浪',
      iconName: 'waves',
      assetPath: 'audio/effects/ocean.mp3',
    ),
    SoundEffect(
      id: 'wind_chimes',
      name: '风铃',
      iconName: 'air',
      assetPath: 'audio/effects/wind_chimes.mp3',
    ),
    SoundEffect(
      id: 'birds',
      name: '鸟鸣',
      iconName: 'flutter_dash',
      assetPath: 'audio/effects/birds.mp3',
    ),
  ];
}
