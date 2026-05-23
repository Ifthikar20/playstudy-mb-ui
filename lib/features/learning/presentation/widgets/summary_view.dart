import 'package:flutter/material.dart';
import '../../data/models/learning_models.dart';

class SummaryView extends StatelessWidget {
  final LearningMaterial material;
  const SummaryView({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Summary', style: theme.textTheme.titleLarge),
                ]),
                const SizedBox(height: 12),
                Text(material.summary,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.list_alt_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Key points', style: theme.textTheme.titleLarge),
                ]),
                const SizedBox(height: 12),
                ...material.keyPoints.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(p,
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(height: 1.4))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Source: ${material.sourceRef}',
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
