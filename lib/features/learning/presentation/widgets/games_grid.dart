import 'package:flutter/material.dart';

import '../../../../core/games/game_registry.dart';
import '../../../../core/games/game_stage.dart';
import '../../../library/presentation/pages/library_page.dart'
    show GameTileCard;
import '../../data/models/learning_models.dart';

/// Renders one card per registered game that can be played for this material.
/// Tapping a card opens the game full-screen — pausable and resumable via the
/// shared [GameStage].
class GamesGrid extends StatelessWidget {
  final LearningMaterial material;
  const GamesGrid({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    // While the set is still generating (opened early), games can have a
    // sparse word/quiz list — hold them until everything has landed so a game
    // never launches with half its content.
    if (material.isGenerating) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text('Games are getting ready',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                  'They unlock as soon as your study set finishes generating. '
                  'You can keep reading and quizzing in the meantime.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    final games = GameRegistry.instance.availableFor(material);
    if (games.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videogame_asset_rounded,
                  size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('No games available',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('This study set doesn\'t have content for any game yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: games.length,
      itemBuilder: (context, i) => GameTileCard(
        game: games[i],
        questionCount: games[i].questionCount(material),
        theme: Theme.of(context),
        onTap: () => launchGameFullscreen(
          context,
          game: games[i],
          material: material,
        ),
      ),
    );
  }
}
