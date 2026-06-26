import 'package:flutter/material.dart';

import '../../../../core/games/game_registry.dart';

/// Horizontal strip of clean, Airbnb-style game cards previewing what's
/// included in the app. Tapping any card routes the user to the New study
/// set screen so they can create material that the games will run on.
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
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(children: [
            Text(
              'Newly added games',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
            Text('Tap any to play',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ]),
        ),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final g = games[i];
              return _GameCard(
                name: g.name,
                emoji: g.icon == null ? g.emoji : null,
                icon: g.icon,
                accent: g.coverColors.last,
                onTap: onTapAny,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  final String name;
  final String? emoji;
  final IconData? icon;
  final Color accent;
  final VoidCallback onTap;
  const _GameCard({
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 116,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Soft tinted medallion with the game's icon/emoji.
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon ?? Icons.videogame_asset_rounded,
                  size: 24,
                  color: accent,
                ),
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  fontSize: 13,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Play',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
