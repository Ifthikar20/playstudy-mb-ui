import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/rewards/badges.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../../../core/widgets/airbnb_card.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';

/// Compact horizontal preview of recently-unlocked badges. Renders nothing
/// until the user has at least one badge.
class BadgesStrip extends StatelessWidget {
  const BadgesStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<RewardsBloc, RewardsState>(
      builder: (context, rewards) {
        return BlocBuilder<LearningBloc, LearningState>(
          builder: (context, learning) {
            final ctx = buildBadgeContext(
              rewards: rewards,
              librarySize: learning.library.length,
            );
            final unlocked =
                kAchievements.where((a) => a.isUnlocked(ctx)).toList();
            if (unlocked.isEmpty) return const SizedBox.shrink();
            final preview = unlocked.length > 4
                ? unlocked.sublist(unlocked.length - 4)
                : unlocked;
            return AirbnbCard(
              onTap: () => context.go('/profile'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Badges', style: theme.textTheme.titleLarge),
                      Text(
                        '${unlocked.length} of ${kAchievements.length} unlocked',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        for (var i = 0; i < preview.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          _Chip(achievement: preview[i]),
                        ],
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ]),
            );
          },
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final Achievement achievement;
  const _Chip({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: achievement.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: achievement.colors.last.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(achievement.emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
