import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/rewards/rewards_bloc.dart';
import '../widgets/learning_insights.dart';

/// The rewards / level-up screen. Shows the user's current rank, exact
/// progress to the next rank, and a clean vertical list of every rank
/// with whether it is locked, unlocked, or current.
class AdventurePage extends StatelessWidget {
  const AdventurePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Rewards'),
      ),
      body: BlocBuilder<RewardsBloc, RewardsState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _LevelHero(state: state),
              const SizedBox(height: 18),
              LearningInsights(state: state),
              const SizedBox(height: 22),
              Text('All levels', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < kRanks.length; i++) ...[
                      _RankRow(
                        rank: kRanks[i],
                        state: state,
                        index: i,
                      ),
                      if (i != kRanks.length - 1)
                        Divider(
                            height: 1,
                            indent: 64,
                            color: theme.dividerColor),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Hero card: current level, total points, progress to next level.
class _LevelHero extends StatelessWidget {
  final RewardsState state;
  const _LevelHero({required this.state});

  @override
  Widget build(BuildContext context) {
    final rank = state.currentRank;
    final next = state.nextRank;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2E), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(rank.icon, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${state.currentRankIndex + 1}  ·  ${rank.name}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text('${state.points} points',
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.rankProgress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Max level reached'
                : '${state.pointsToNextRank} pts to level ${state.currentRankIndex + 2} · ${next.name}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// One row of the all-levels list. Three states: unlocked / current / locked.
class _RankRow extends StatelessWidget {
  final Rank rank;
  final RewardsState state;
  final int index;
  const _RankRow({
    required this.rank,
    required this.state,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = index == state.currentRankIndex;
    final unlocked = state.points >= rank.threshold;
    final ptsToHere = (rank.threshold - state.points).clamp(0, 1 << 30);

    final Color tileColor = current
        ? theme.colorScheme.primary.withOpacity(0.10)
        : Colors.transparent;
    final Color iconBg = current
        ? theme.colorScheme.primary
        : unlocked
            ? theme.colorScheme.primary.withOpacity(0.12)
            : theme.colorScheme.surface;
    final Color iconColor = current
        ? Colors.white
        : unlocked
            ? theme.colorScheme.primary
            : theme.hintColor;

    final String status = current
        ? 'You are here'
        : unlocked
            ? 'Unlocked'
            : '$ptsToHere pts to go';
    final Color statusColor = current
        ? theme.colorScheme.primary
        : unlocked
            ? Colors.green.shade700
            : theme.hintColor;

    return Container(
      color: tileColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
              border: unlocked && !current
                  ? null
                  : Border.all(
                      color: current
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                      width: 1),
            ),
            child: Icon(
              unlocked ? rank.icon : Icons.lock_outline_rounded,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    'Level ${index + 1}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: current ? theme.colorScheme.primary : null),
                  ),
                  const SizedBox(width: 6),
                  Text('·  ${rank.threshold} pts',
                      style: theme.textTheme.bodySmall),
                ]),
                Text(
                  rank.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight:
                        current ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
