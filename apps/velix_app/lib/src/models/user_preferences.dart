class UserPreferences {
  final bool darkMode;
  final bool notifications;
  final bool soundEnabled;
  final String language;
  final double fontSize;
  const UserPreferences({this.darkMode = true, this.notifications = true, this.soundEnabled = true, this.language = 'en', this.fontSize = 1.0});
  UserPreferences copyWith({bool? darkMode, bool? notifications, bool? soundEnabled, String? language, double? fontSize}) => UserPreferences(darkMode: darkMode ?? this.darkMode, notifications: notifications ?? this.notifications, soundEnabled: soundEnabled ?? this.soundEnabled, language: language ?? this.language, fontSize: fontSize ?? this.fontSize);
}
