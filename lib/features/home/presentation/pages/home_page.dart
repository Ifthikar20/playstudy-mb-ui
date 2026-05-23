import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../learning/data/models/learning_models.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';

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
            Text('What do you want to learn today?',
                style: theme.textTheme.displaySmall),
            const SizedBox(height: 24),
            _PrimaryCta(
              icon: Icons.add_link,
              title: 'New study set',
              subtitle: 'Paste a link, upload a file, or paste text',
              onTap: () => context.go('/new'),
            ),
            const SizedBox(height: 24),
            Text('Recent', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            BlocBuilder<LearningBloc, LearningState>(
              builder: (context, state) {
                final library = state.library;
                if (library.isEmpty) {
                  return _EmptyState(onTap: () => context.go('/new'));
                }
                return Column(
                  children: library
                      .take(5)
                      .map((m) => _MaterialTile(
                            material: m,
                            onTap: () =>
                                context.go('/material/${m.id}', extra: m),
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

class _PrimaryCta extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _PrimaryCta({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: scheme.primary,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Text('📚', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('No study sets yet',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Add a link or upload to get started.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onTap, child: const Text('Get started')),
        ]),
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  final LearningMaterial material;
  final VoidCallback onTap;
  const _MaterialTile({required this.material, required this.onTap});

  IconData get _icon {
    switch (material.sourceKind) {
      case SourceKind.link:
        return Icons.link;
      case SourceKind.file:
        return Icons.description_outlined;
      case SourceKind.text:
        return Icons.text_snippet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withOpacity(0.12),
            child: Icon(_icon, color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(material.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            'Summary • Quiz • Guess the Word',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}
