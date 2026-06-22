class AppConfig {
  static AppConfig? _instance;
  static AppConfig get instance => _instance ??= AppConfig._();

  AppConfig._();

  static void initialize() {
    _instance = AppConfig._();
  }

  String get appName => 'PlayStudy';
  String get tagline => 'Turn notes into games';
  String get apiBaseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://api.playstudy.app',
      );

  /// Base URL where the embeddable HTML5 games are hosted (the landing site's
  /// static `public/games/` folder). Override per environment with
  /// `--dart-define=GAMES_BASE_URL=...`.
  String get gamesBaseUrl => const String.fromEnvironment(
        'GAMES_BASE_URL',
        defaultValue: 'https://playstudy.app',
      );
}
