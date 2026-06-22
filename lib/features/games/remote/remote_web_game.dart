import 'package:flutter/material.dart';

import '../../../core/games/learning_game.dart';
import '../../learning/data/models/learning_models.dart';
import '../web/web_game_view.dart';

/// A single entry from the backend games manifest (`GET /api/v1/games`).
///
/// This is the wire shape published from the Django `Game` model. Adding a
/// game on the server (plus uploading its HTML bundle to the games CDN) makes
/// it appear here with no app release — see [RemoteWebGame].
class RemoteGameDef {
  final String key; // stable client id (LearningGame.id)
  final String slug; // {gamesBaseUrl}/games/<slug>/index.html
  final String name;
  final String description;
  final String icon; // Material icon name, may be unknown to this build
  final String emoji;
  final List<Color> coverColors;
  final GameDifficulty difficulty;
  final Map<String, int> requires; // {"quiz": 1} / {"words": 2}
  final String minAppVersion; // semver, '' = no minimum

  const RemoteGameDef({
    required this.key,
    required this.slug,
    required this.name,
    required this.description,
    required this.icon,
    required this.emoji,
    required this.coverColors,
    required this.difficulty,
    required this.requires,
    required this.minAppVersion,
  });

  factory RemoteGameDef.fromJson(Map<String, dynamic> j) {
    final colors = (j['coverColors'] as List? ?? const [])
        .map((c) => _parseColor(c.toString()))
        .whereType<Color>()
        .toList();
    final requires = <String, int>{};
    final rawRequires = j['requires'];
    if (rawRequires is Map) {
      rawRequires.forEach((k, v) {
        final count = v is int ? v : int.tryParse('$v');
        if (count != null) requires[k.toString()] = count;
      });
    }
    return RemoteGameDef(
      key: (j['key'] ?? '').toString(),
      slug: (j['slug'] ?? '').toString(),
      name: (j['name'] ?? 'Game').toString(),
      description: (j['description'] ?? '').toString(),
      icon: (j['icon'] ?? '').toString(),
      emoji: (j['emoji'] ?? '').toString(),
      coverColors: colors.length >= 2
          ? colors
          : const [Color(0xFF9D8DFA), Color(0xFF6B5CE7)],
      difficulty: _parseDifficulty((j['difficulty'] ?? 'medium').toString()),
      requires: requires,
      minAppVersion: (j['minAppVersion'] ?? '').toString(),
    );
  }
}

/// Adapts a server-published [RemoteGameDef] to the [LearningGame] contract so
/// the registry and UI treat it exactly like a built-in game. The playable
/// surface is the existing [WebGameView], which loads the HTML bundle from the
/// games CDN and bridges the study set's quiz/words + reward events.
class RemoteWebGame extends LearningGame {
  final RemoteGameDef def;
  RemoteWebGame(this.def);

  @override
  String get id => def.key;

  @override
  String get name => def.name;

  @override
  String get emoji => def.emoji.isNotEmpty ? def.emoji : '🎮';

  @override
  IconData? get icon => _iconByName(def.icon);

  @override
  String get description => def.description;

  @override
  List<Color> get coverColors => def.coverColors;

  @override
  GameDifficulty get difficulty => def.difficulty;

  @override
  int questionCount(LearningMaterial m) {
    if (def.requires.containsKey('words')) return m.wordGame.length;
    return m.quiz.length;
  }

  /// Data-driven gate: every key in [RemoteGameDef.requires] must be satisfied
  /// by the material. Empty requirements means always playable.
  @override
  bool canPlay(LearningMaterial material) {
    for (final entry in def.requires.entries) {
      final have = switch (entry.key) {
        'quiz' => material.quiz.length,
        'words' => material.wordGame.length,
        _ => 0, // unknown requirement this build can't satisfy → hide
      };
      if (have < entry.value) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context, LearningMaterial material) {
    return WebGameView(
      slug: def.slug,
      title: def.name,
      quiz: material.quiz,
      words: material.wordGame,
    );
  }
}

GameDifficulty _parseDifficulty(String value) => switch (value.toLowerCase()) {
      'easy' => GameDifficulty.easy,
      'hard' => GameDifficulty.hard,
      _ => GameDifficulty.medium,
    };

/// Parses '0xAARRGGBB', '0xRRGGBB', '#RRGGBB', or '#AARRGGBB' into a [Color].
Color? _parseColor(String raw) {
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.toLowerCase().startsWith('0x')) s = s.substring(2);
  if (s.length == 6) s = 'FF$s'; // assume opaque if no alpha
  final value = int.tryParse(s, radix: 16);
  return value == null ? null : Color(value);
}

/// Resolves a Material icon name to its [IconData]. Kept as an explicit map so
/// icon font tree-shaking still works (all entries reference const `Icons.*`).
/// Unknown names fall back to null, and the UI then uses the emoji / a generic
/// game icon — so a server can reference an icon a stale build doesn't know
/// without breaking the tile.
IconData? _iconByName(String name) => _icons[name];

const Map<String, IconData> _icons = {
  'flutter_dash': Icons.flutter_dash,
  'rocket_launch': Icons.rocket_launch,
  'rocket': Icons.rocket,
  'grid_on': Icons.grid_on,
  'spellcheck_outlined': Icons.spellcheck_outlined,
  'casino_outlined': Icons.casino_outlined,
  'sports_esports': Icons.sports_esports,
  'videogame_asset_outlined': Icons.videogame_asset_outlined,
  'extension': Icons.extension,
  'quiz': Icons.quiz,
  'psychology': Icons.psychology,
  'bolt': Icons.bolt,
  'auto_awesome': Icons.auto_awesome,
  'flag': Icons.flag,
  'pets': Icons.pets,
};
