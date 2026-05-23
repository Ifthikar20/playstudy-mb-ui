import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../games/data/models/game_models.dart';
import '../../../games/presentation/bloc/games_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Hi there 👋', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Ready to turn your notes into games?',
                style: theme.textTheme.displaySmall),
            const SizedBox(height: 24),
            _ScanCta(onTap: () => context.go('/scan')),
            const SizedBox(height: 24),
            Text('Recent games', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            BlocBuilder<GamesBloc, GamesState>(
              builder: (context, state) {
                final library = state is GamesLoaded
                    ? state.library
                    : state is GameGenerated
                        ? state.library
                        : <Game>[];
                if (library.isEmpty) {
                  return _EmptyRecent(onTap: () => context.go('/scan'));
                }
                return Column(
                  children: library
                      .take(5)
                      .map((g) => _GameTile(
                            game: g,
                            onTap: () => context.go('/game/${g.id}', extra: g),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanCta extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      borderRadius: BorderRadius.circular(24),
      color: scheme.primary,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.camera_alt_outlined,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan a note',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Snap a photo — get a game in seconds',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ]),
        ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyRecent({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Text('📚', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('No games yet',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Scan your first study note to begin.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onTap, child: const Text('Scan now')),
        ]),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  const _GameTile({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Text(game.type.emoji,
              style: const TextStyle(fontSize: 28)),
          title: Text(game.title),
          subtitle: Text('${game.subject} • ${game.type.label}'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
