import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/games/game_registry.dart';
import '../../../../core/games/learning_game.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';

/// Library with two tabs: Study (the user's generated study sets) and
/// Games (every game registered with [GameRegistry]).
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/'),
          ),
          title: const Text('Library'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(36),
            child: TabBar(
              isScrollable: false,
              labelPadding: EdgeInsets.symmetric(vertical: 6),
              tabs: [
                Tab(height: 30, text: 'Study'),
                Tab(height: 30, text: 'Games'),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _StudyLibraryTab(),
            _GamesLibraryTab(),
          ],
        ),
      ),
    );
  }
}

class _StudyLibraryTab extends StatelessWidget {
  const _StudyLibraryTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LearningBloc, LearningState>(
      builder: (context, state) {
        final library = state.library;
        if (library.isEmpty) {
          return _EmptyLibrary(
            icon: Icons.menu_book_rounded,
            title: 'Your study library is empty',
            body: 'Study sets you create will appear here.',
            ctaLabel: 'Create a study set',
            onCta: () => context.go('/new'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          itemCount: library.length,
          itemBuilder: (context, i) {
            final m = library[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey(m.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) =>
                    context.read<LearningBloc>().add(DeleteMaterial(m.id)),
                child: StudySetCard(
                  material: m,
                  onTap: () => context.push('/material/${m.id}', extra: m),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GamesLibraryTab extends StatelessWidget {
  const _GamesLibraryTab();

  @override
  Widget build(BuildContext context) {
    final games = GameRegistry.instance.all;
    return BlocBuilder<LearningBloc, LearningState>(
      builder: (context, state) {
        final library = state.library;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: games.length,
          itemBuilder: (context, i) {
            final g = games[i];
            final accent =
                ThemeColors.accentPalette[i % ThemeColors.accentPalette.length];
            return _GameTile(
              game: g,
              accent: accent,
              onTap: () => _openGame(context, g, library),
            );
          },
        );
      },
    );
  }

  void _openGame(BuildContext context, LearningGame game,
      List<dynamic> library) async {
    // If the user has no study sets yet, route to /new so they can create
    // material that the game will run on. Otherwise let them pick which set
    // to play this game with.
    if (library.isEmpty) {
      context.go('/new');
      return;
    }
    final material = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Play ${game.name} with…',
                    style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Pick a study set for this game.',
                    style: Theme.of(sheet).textTheme.bodySmall),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: library.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1, color: Theme.of(sheet).dividerColor),
                    itemBuilder: (_, i) {
                      final m = library[i];
                      final playable = game.canPlay(m);
                      return ListTile(
                        leading: const Icon(Icons.menu_book_rounded),
                        title: Text(m.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          playable
                              ? '${m.quiz.length} quiz · ${m.wordGame.length} words'
                              : 'Not enough content for this game',
                          style: TextStyle(
                              color: playable
                                  ? null
                                  : Theme.of(sheet).hintColor),
                        ),
                        enabled: playable,
                        onTap: playable ? () => Navigator.pop(sheet, m) : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (material == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(game.name)),
          body: game.build(context, material),
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final LearningGame game;
  final Color accent;
  final int? questionCount;
  final VoidCallback onTap;
  const _GameTile(
      {required this.game,
      required this.accent,
      required this.onTap,
      this.questionCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GameTileCard(
      game: game,
      questionCount: questionCount,
      onTap: onTap,
      theme: theme,
    );
  }
}

/// Retro arcade-poster game tile: thick ink frame, sunburst rays radiating
/// from a chunky cream-on-ink icon medallion, a bottom marquee with a Bungee
/// display title + mono tagline, star difficulty + round count badges.
/// Each game's [LearningGame.coverColors] drives the hue, so every tile is
/// distinct without per-game artwork.
class GameTileCard extends StatelessWidget {
  final LearningGame game;
  final int? questionCount;
  final VoidCallback onTap;
  final ThemeData theme;
  const GameTileCard({
    super.key,
    required this.game,
    required this.onTap,
    required this.theme,
    this.questionCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = game.coverColors;
    final bgA = colors.first;
    final bgB = colors.length > 1 ? colors.last : colors.first;
    const ink = Color(0xFF1A0E12);          // poster ink (almost-black plum)
    const cream = Color(0xFFFFF6E1);        // off-white paper stock

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          // Outer thick frame (the poster border).
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: ink.withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(children: [
              // Sunburst-rays background driven by the game's cover colors.
              Positioned.fill(
                child: CustomPaint(
                  painter: _SunburstPainter(
                    base: bgA,
                    accent: bgB,
                    rayColor: cream.withOpacity(0.18),
                    rayCount: 14,
                  ),
                ),
              ),
              // Top-right star difficulty (arcade-style 1–3 stars).
              Positioned(
                top: 8,
                right: 8,
                child:
                    _PosterStarRating(difficulty: game.difficulty, color: cream),
              ),
              // Top-left round-count badge (skipped when unknown).
              if (questionCount != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _PosterRoundBadge(count: questionCount!, color: cream),
                ),
              // Center medallion holding the game's icon/emoji.
              const Positioned(
                left: 0,
                right: 0,
                top: 40,
                child: SizedBox.shrink(),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 38,
                child: Center(
                  child: _PosterMedallion(game: game, cream: cream, ink: ink),
                ),
              ),
              // Bottom marquee strip: chunky display title + mono tagline.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _PosterMarquee(
                  title: game.name,
                  tagline: game.description,
                  ink: ink,
                  cream: cream,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Retro-poster helpers (used by GameTileCard only).
// ─────────────────────────────────────────────────────────────────────────

class _SunburstPainter extends CustomPainter {
  final Color base;
  final Color accent;
  final Color rayColor;
  final int rayCount;
  _SunburstPainter({
    required this.base,
    required this.accent,
    required this.rayColor,
    required this.rayCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 1. Diagonal base — the printed poster paper.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, Color.lerp(accent, Colors.black, 0.18)!],
        ).createShader(rect),
    );

    // 2. Alternating sunburst wedges emanating from the medallion area.
    final origin = Offset(size.width / 2, size.height * 0.36);
    final reach =
        math.sqrt(size.width * size.width + size.height * size.height) * 1.05;
    final ray = Paint()..color = rayColor;
    for (int i = 0; i < rayCount; i++) {
      final wedge = (math.pi * 2) / rayCount;
      final a1 = i * wedge;
      final a2 = a1 + wedge / 2;
      final p = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(origin.dx + reach * math.cos(a1),
            origin.dy + reach * math.sin(a1))
        ..lineTo(origin.dx + reach * math.cos(a2),
            origin.dy + reach * math.sin(a2))
        ..close();
      canvas.drawPath(p, ray);
    }

    // 3. Vignette: darkens edges for a printed-on-paper feel.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter old) =>
      old.base != base ||
      old.accent != accent ||
      old.rayColor != rayColor ||
      old.rayCount != rayCount;
}

class _PosterMedallion extends StatelessWidget {
  final LearningGame game;
  final Color cream;
  final Color ink;
  const _PosterMedallion(
      {required this.game, required this.cream, required this.ink});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: cream,
        shape: BoxShape.circle,
        border: Border.all(color: ink, width: 3),
        boxShadow: [
          BoxShadow(
            color: ink.withOpacity(0.45),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          game.icon ?? Icons.videogame_asset_rounded,
          size: 32,
          color: ink,
        ),
      ),
    );
  }
}

class _PosterMarquee extends StatelessWidget {
  final String title;
  final String tagline;
  final Color ink;
  final Color cream;
  const _PosterMarquee({
    required this.title,
    required this.tagline,
    required this.ink,
    required this.cream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cream,
        border: Border(top: BorderSide(color: ink, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              style: GoogleFonts.bungee(
                color: ink,
                fontSize: 16,
                letterSpacing: 0.4,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tagline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceMono(
              color: ink.withOpacity(0.78),
              fontSize: 10.5,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterStarRating extends StatelessWidget {
  final GameDifficulty difficulty;
  final Color color;
  const _PosterStarRating(
      {required this.difficulty, required this.color});

  @override
  Widget build(BuildContext context) {
    final filled = switch (difficulty) {
      GameDifficulty.easy => 1,
      GameDifficulty.medium => 2,
      GameDifficulty.hard => 3,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.55), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 13,
              color: color,
            ),
          ),
      ]),
    );
  }
}

class _PosterRoundBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _PosterRoundBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.55), width: 1),
      ),
      child: Text(
        '$count ROUND${count == 1 ? '' : 'S'}',
        style: GoogleFonts.bungee(
          color: color,
          fontSize: 9,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;
  const _EmptyLibrary({
    required this.icon,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title,
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCta,
              icon: const Icon(Icons.add_rounded),
              label: Text(ctaLabel),
            ),
          ],
        ),
      ),
    );
  }
}
