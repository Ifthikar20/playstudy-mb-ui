import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';

/// Airbnb-style 2x2 stats grid: streak, points, study sets, rank.
class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RewardsBloc, RewardsState>(
      builder: (context, rewards) {
        return BlocBuilder<LearningBloc, LearningState>(
          builder: (context, learning) {
            final tiles = [
              _StatTile(
                emoji: '🔥',
                value: '${rewards.streak}',
                label: rewards.streak == 1 ? 'day streak' : 'day streak',
                accent: const Color(0xFFFF6B00),
              ),
              _StatTile(
                emoji: '⭐',
                value: '${rewards.points}',
                label: 'points',
                accent: const Color(0xFF007AFF),
              ),
              _StatTile(
                emoji: '📚',
                value: '${learning.library.length}',
                label: 'study sets',
                accent: const Color(0xFF22C55E),
              ),
              _StatTile(
                emoji: rewards.currentRank.emoji,
                value: rewards.currentRank.name,
                label: 'rank',
                accent: const Color(0xFFA855F7),
              ),
            ];
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: tiles,
            );
          },
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color accent;
  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 32,
            width: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
