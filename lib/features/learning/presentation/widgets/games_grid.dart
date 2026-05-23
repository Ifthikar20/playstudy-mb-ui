import 'package:flutter/material.dart';
import '../../../../core/games/game_registry.dart';
import '../../../../core/games/learning_game.dart';
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
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: games.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _GameCard(material: material, game: games[i]),
    );
  }
}

class _GameCard extends StatelessWidget {
  final LearningMaterial material;
  final LearningGame game;
  const _GameCard({required this.material, required this.game});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _GamePlayPage(material: material, game: game),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: game.icon != null
                  ? Icon(game.icon, color: scheme.primary, size: 28)
                  : Center(
                      child: Text(game.emoji,
                          style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.name,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(game.description,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ]),
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
