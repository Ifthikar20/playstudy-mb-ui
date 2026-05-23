import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../games/data/models/game_models.dart';
import '../../../games/presentation/bloc/games_bloc.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: BlocBuilder<GamesBloc, GamesState>(
        builder: (context, state) {
          final library = state is GamesLoaded
              ? state.library
              : state is GameGenerated
                  ? state.library
                  : <Game>[];
          if (library.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📭', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text('Your library is empty',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('Generated games will show up here.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: library.length,
            itemBuilder: (context, i) {
              final g = library[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    onTap: () => context.go('/game/${g.id}', extra: g),
                    leading: Text(g.type.emoji,
                        style: const TextStyle(fontSize: 28)),
                    title: Text(g.title),
                    subtitle: Text('${g.subject} • ${g.type.label}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          context.read<GamesBloc>().add(DeleteGame(g.id)),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
