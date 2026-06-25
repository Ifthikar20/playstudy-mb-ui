import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/games/game_registry.dart';
import '../../../../core/games/learning_game.dart';
import '../../../../core/network/api_client.dart';
import '../../../games/data/game_score_scope.dart';
import '../../../games/data/game_session_repository.dart';
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
              Icon(Icons.videogame_asset_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary),
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

class _GamePlayPage extends StatefulWidget {
  final LearningMaterial material;
  final LearningGame game;
  const _GamePlayPage({required this.material, required this.game});

  @override
  State<_GamePlayPage> createState() => _GamePlayPageState();
}

class _GamePlayPageState extends State<_GamePlayPage> {
  GameSessionRepository? _sessions;
  String? _sessionId;
  int _lastScore = 0;

  @override
  void initState() {
    super.initState();
    // Record the play for every game (Flame or otherwise): start on open,
    // finalize on close with the score the game reported. Engine-agnostic and
    // best-effort — a tracking failure never affects gameplay.
    _sessions = GameSessionRepository(context.read<ApiClient>());
    _sessions!
        .start(gameKey: widget.game.id, studySetId: widget.material.id)
        .then((id) => _sessionId = id);
  }

  @override
  void dispose() {
    final id = _sessionId;
    if (id != null) _sessions?.complete(id, score: _lastScore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.name)),
      // Games report their score through this scope; we keep the latest and
      // save it with the session on close so it syncs across platforms.
      body: GameScoreScope(
        onScore: (score) => _lastScore = score,
        child: widget.game.build(context, widget.material),
      ),
    );
  }
}
