import 'package:flutter/material.dart';

import '../../../../core/games/game_registry.dart';
import '../../../../core/theme/app_theme.dart';

/// Horizontal strip of small "stamp" tiles showcasing the games available in
/// the app. Tapping any stamp routes the user to the New study set screen so
/// they can create material that the games will run on.
class GamesStrip extends StatelessWidget {
  final VoidCallback onTapAny;
  const GamesStrip({super.key, required this.onTapAny});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final games = GameRegistry.instance.all;
    if (games.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(children: [
            Text('Games included',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Text('· tap to create a set',
                style: theme.textTheme.bodySmall),
          ]),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final g = games[i];
              final accent = ThemeColors.accentPalette[
                  i % ThemeColors.accentPalette.length];
              return _GameStamp(
                name: g.name,
                emoji: g.icon == null ? g.emoji : null,
                icon: g.icon,
                accent: accent,
                onTap: onTapAny,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GameStamp extends StatelessWidget {
  final String name;
  final String? emoji;
  final IconData? icon;
  final Color accent;
  final VoidCallback onTap;
  const _GameStamp({
    required this.name,
    required this.emoji,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 84,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent, width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 36,
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: 26, color: theme.colorScheme.onSurface)
                      : Text(emoji ?? '🎮',
                          style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
