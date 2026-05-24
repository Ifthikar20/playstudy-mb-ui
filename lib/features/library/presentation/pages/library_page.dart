import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../home/presentation/pages/home_page.dart';
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: library.length,
            itemBuilder: (context, i) {
              final m = library[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
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
                  onDismissed: (_) => context
                      .read<LearningBloc>()
                      .add(DeleteMaterial(m.id)),
                  child: StudySetCard(
                    material: m,
                    onTap: () => context.push('/material/${m.id}', extra: m),
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
