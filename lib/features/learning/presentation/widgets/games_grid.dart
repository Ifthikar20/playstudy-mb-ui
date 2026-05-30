import 'package:flutter/material.dart';
import '../../../../core/games/game_registry.dart';
import '../../../../core/games/learning_game.dart';
import '../../../library/presentation/pages/library_page.dart'
    show GameTileCard;
import '../../data/models/learning_models.dart';

/// Renders one card per registered game that can be played for this material.
/// Tapping a card opens the game full-screen.
class GamesGrid extends StatelessWidget {
  final LearningMaterial material;
  const GamesGrid({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    final games = GameRegistry.instance.availableFor(material);
    if (games.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎮', style: TextStyle(fontSize: 56)),
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _GamePlayPage(material: material, game: games[i]),
          ),
        ),
      ),
    );
  }
}

class _GamePlayPage extends StatelessWidget {
  final LearningMaterial material;
  final LearningGame game;
  const _GamePlayPage({required this.material, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(game.name)),
      body: game.build(context, material),
    );
  }
}
