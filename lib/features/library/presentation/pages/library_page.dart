import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/games/game_registry.dart';
import '../../../../core/games/learning_game.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
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

/// Modern, Airbnb-style game tile: a gradient "cover" header with the game's
/// icon medallion and small difficulty / round badges, over a clean white body
/// with the title, description and a Play affordance. Springs on press. Each
/// game's [LearningGame.coverColors] drives the hue, so every tile is distinct
/// without per-game artwork.
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
    final c1 = colors.first;
    final c2 = colors.length > 1 ? colors.last : colors.first;
    final isDark = theme.brightness == Brightness.dark;
    final accent = _readable(c2);
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.07),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover header.
            Stack(children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  height: 94,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [c1, c2],
                    ),
                  ),
                  child: Stack(children: [
                    Positioned(
                      right: -14,
                      bottom: -18,
                      child: Icon(
                        game.icon ?? Icons.videogame_asset_rounded,
                        size: 92,
                        color: Colors.white.withOpacity(0.20),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          game.icon ?? Icons.videogame_asset_rounded,
                          size: 26,
                          color: accent,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _DifficultyPill(difficulty: game.difficulty),
              ),
              if (questionCount != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _CountPill(count: questionCount!),
                ),
            ]),
            // Body.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Expanded(
                      child: Text(
                        game.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.25,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Row(children: [
                      Text(
                        'Play',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 15, color: accent),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Nudge a very light accent darker so "Play" stays legible on white.
  Color _readable(Color c) {
    final l = c.computeLuminance();
    return l > 0.6 ? Color.lerp(c, Colors.black, 0.45)! : c;
  }
}

class _DifficultyPill extends StatelessWidget {
  final GameDifficulty difficulty;
  const _DifficultyPill({required this.difficulty});

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
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 12,
              color: Colors.white,
            ),
          ),
      ]),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count Q',
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
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
