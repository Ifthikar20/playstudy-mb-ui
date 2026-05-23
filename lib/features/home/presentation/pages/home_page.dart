import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_bloc.dart';
import '../../../../core/subscription/subscription_bloc.dart';
import '../../../../core/widgets/airbnb_card.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _Greeting(),
            const SizedBox(height: 20),
            _HeroCta(onTap: () => context.go('/new')),
            const SizedBox(height: 20),
            BlocBuilder<SubscriptionBloc, SubscriptionState>(
              builder: (context, sub) {
                if (sub.isPremium || !sub.loaded) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _UsageStrip(remaining: sub.remainingFree),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Your study sets', style: theme.textTheme.titleLarge),
                TextButton(
                  onPressed: () => context.go('/library'),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            BlocBuilder<LearningBloc, LearningState>(
              builder: (context, state) {
                final library = state.library;
                if (library.isEmpty) return _EmptyHero(onTap: () => context.go('/new'));
                return Column(
                  children: library
                      .take(5)
                      .map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: StudySetCard(
                              material: m,
                              onTap: () =>
                                  context.go('/material/${m.id}', extra: m),
                            ),
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

class _Greeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is Authenticated ? state.user.name : 'there';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi ${_first(name)} 👋', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('What do you want to learn today?',
                style: theme.textTheme.displaySmall),
          ],
        );
      },
    );
  }

  String _first(String n) {
    final parts = n.split(RegExp(r'[ @]'));
    return parts.first;
  }
}

class _HeroCta extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      borderRadius: BorderRadius.circular(24),
      color: scheme.primary,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_link, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create a study set',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Link, file, or pasted text',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

class _UsageStrip extends StatelessWidget {
  final int remaining;
  const _UsageStrip({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AirbnbCard(
      onTap: () => context.push('/paywall'),
      child: Row(children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.workspace_premium,
              color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                remaining > 0
                    ? '$remaining free study set${remaining == 1 ? '' : 's'} left'
                    : 'Free tier used up',
                style: theme.textTheme.labelLarge,
              ),
              Text('Tap to go unlimited',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const Icon(Icons.chevron_right),
      ]),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AirbnbCard(
      padding: const EdgeInsets.all(28),
      onTap: onTap,
      child: Column(children: [
        const Text('📚', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text('No study sets yet',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Tap to create your first one.',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

/// Airbnb listing-style card for a study set: gradient header on top, body
/// with bold title + meta row, save icon in the corner.
class StudySetCard extends StatelessWidget {
  final LearningMaterial material;
  final VoidCallback onTap;
  const StudySetCard({super.key, required this.material, required this.onTap});

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

  String get _sourceLabel {
    switch (material.sourceKind) {
      case SourceKind.link:
        return 'Web link';
      case SourceKind.file:
        return 'Uploaded file';
      case SourceKind.text:
        return 'Pasted notes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: isDark ? theme.colorScheme.surface : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(children: [
                GradientHeader(seed: material.title, icon: _icon),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.favorite_border,
                        color: Colors.white, size: 20),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_icon, size: 13, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(_sourceLabel,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      material.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      _MetaChip(
                          icon: Icons.menu_book_outlined,
                          label:
                              '${material.keyPoints.length} key points'),
                      const SizedBox(width: 8),
                      _MetaChip(
                          icon: Icons.quiz_outlined,
                          label: '${material.quiz.length} quiz'),
                      const SizedBox(width: 8),
                      _MetaChip(
                          icon: Icons.videogame_asset_outlined,
                          label: '${material.wordGame.length} words'),
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
