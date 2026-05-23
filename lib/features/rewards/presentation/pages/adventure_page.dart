import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/rewards/rewards_bloc.dart';

/// The "adventure" — a vertical path of ranks. The player climbs it by
/// earning points from studying. The current rank glows; future ranks are
/// locked until their point threshold is reached.
class AdventurePage extends StatelessWidget {
  const AdventurePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Adventure')),
      body: BlocBuilder<RewardsBloc, RewardsState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _Header(state: state),
              const SizedBox(height: 24),
              // Render the path top-down: highest rank first.
              for (var i = kRanks.length - 1; i >= 0; i--)
                _RankStep(
                  rank: kRanks[i],
                  index: i,
                  state: state,
                  alignRight: i.isOdd,
                  isLast: i == 0,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final RewardsState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        Text(state.currentRank.emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.currentRank.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              Text('${state.points} points',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: state.rankProgress,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.nextRank == null
                    ? 'Max rank reached 🏆'
                    : '${state.pointsToNextRank} pts to ${state.nextRank!.name}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _RankStep extends StatelessWidget {
  final Rank rank;
  final int index;
  final RewardsState state;
  final bool alignRight;
  final bool isLast;
  const _RankStep({
    required this.rank,
    required this.index,
    required this.state,
    required this.alignRight,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = index == state.currentRankIndex;
    final unlocked = state.points >= rank.threshold;

    final node = Container(
      height: 72,
      width: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current
            ? theme.colorScheme.primary
            : unlocked
                ? theme.colorScheme.tertiary
                : theme.colorScheme.surface,
        border: Border.all(
          color: current ? theme.colorScheme.primary : theme.dividerColor,
          width: current ? 3 : 1,
        ),
        boxShadow: current
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.4),
                  blurRadius: 18,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Center(
        child: unlocked
            ? Text(rank.emoji, style: const TextStyle(fontSize: 32))
            : Icon(Icons.lock_outline,
                color: theme.colorScheme.onSurface.withOpacity(0.4)),
      ),
    );

    final label = Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(rank.name, style: theme.textTheme.titleLarge),
        Text(
          unlocked
              ? (current ? 'You are here' : 'Unlocked')
              : '${rank.threshold} pts',
          style: theme.textTheme.bodySmall?.copyWith(
            color: current ? theme.colorScheme.primary : null,
            fontWeight: current ? FontWeight.w700 : null,
          ),
        ),
      ],
    );

    final row = Row(
      children: alignRight
          ? [Expanded(child: label), const SizedBox(width: 16), node]
          : [node, const SizedBox(width: 16), Expanded(child: label)],
    );

    return Column(
      children: [
        row,
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Align(
              alignment: alignRight
                  ? const Alignment(0.72, 0)
                  : const Alignment(-0.72, 0),
              child: Column(
                children: List.generate(
                  3,
                  (_) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    height: 5,
                    width: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: unlocked
                          ? theme.colorScheme.tertiary
                          : theme.dividerColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
