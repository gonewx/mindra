class AppConstants {
  static const String appName = 'Mindra';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'mindra.db';
  static const int databaseVersion = 3;

  // Storage Keys
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language_code';
  static const String onboardingKey = 'onboarding_completed';

  // Media Types
  static const List<String> supportedAudioFormats = [
    'mp3',
    'aac',
    'wav',
    'flac',
    'm4a',
    'ogg',
  ];

  static const List<String> supportedVideoFormats = [
    'mp4',
    'mov',
    'avi',
    'mkv',
    'webm',
  ];

  // Sound Effects
  static const List<String> soundEffects = [
    'rain',
    'ocean',
    'forest',
    'wind_chimes',
    'fire',
    'birds',
    'water',
  ];

  // Meditation Goals
  static const List<int> meditationGoals = [
    5,
    10,
    15,
    20,
    30,
    45,
    60,
  ]; // minutes

  // Reminder Times
  static const List<String> reminderTimes = [
    '06:00',
    '08:00',
    '12:00',
    '18:00',
    '20:00',
    '22:00',
  ];
}
