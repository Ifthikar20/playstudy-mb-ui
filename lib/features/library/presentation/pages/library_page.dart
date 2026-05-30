import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
            icon: const Icon(Icons.arrow_back),
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
            icon: Icons.menu_book_outlined,
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
                  child: const Icon(Icons.delete_outline, color: Colors.white),
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
                        leading: const Icon(Icons.menu_book_outlined),
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

/// Reusable game card: gradient cover with the icon as a watermark, then a
/// title row plus two chips — question count and difficulty.
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: theme.colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover: gradient with a large watermark icon.
              SizedBox(
                height: 78,
                child: Stack(children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: game.coverColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -8,
                    bottom: -12,
                    child: Icon(
                      game.icon ?? Icons.videogame_asset_outlined,
                      size: 92,
                      color: Colors.white.withOpacity(0.22),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        game.icon ?? Icons.videogame_asset_outlined,
                        color: game.coverColors.last,
                        size: 22,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _GameDifficultyBadge(difficulty: game.difficulty),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      game.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      _Chip(
                        icon: Icons.help_outline,
                        label: questionCount != null
                            ? '$questionCount Q'
                            : 'from your set',
                        color: theme.colorScheme.primary,
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color)),
      ]),
    );
  }
}

class _GameDifficultyBadge extends StatelessWidget {
  final GameDifficulty difficulty;
  const _GameDifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (difficulty) {
      GameDifficulty.easy => (const Color(0xFF22C55E), 'Easy'),
      GameDifficulty.medium => (const Color(0xFFF59E0B), 'Medium'),
      GameDifficulty.hard => (const Color(0xFFEF4444), 'Hard'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3),
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
              icon: const Icon(Icons.add),
              label: Text(ctaLabel),
            ),
          ],
        ),
      ),
    );
  }
}
