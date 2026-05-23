import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../learning/data/models/learning_models.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: BlocBuilder<LearningBloc, LearningState>(
        builder: (context, state) {
          final library = state.library;
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
                    Text('Study sets you create will appear here.',
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
              final m = library[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    onTap: () => context.go('/material/${m.id}', extra: m),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.12),
                      child: Icon(
                        _iconFor(m.sourceKind),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(m.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(m.sourceRef,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          context.read<LearningBloc>().add(DeleteMaterial(m.id)),
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

  IconData _iconFor(SourceKind k) {
    switch (k) {
      case SourceKind.link:
        return Icons.link;
      case SourceKind.file:
        return Icons.description_outlined;
      case SourceKind.text:
        return Icons.text_snippet_outlined;
    }
  }
}
