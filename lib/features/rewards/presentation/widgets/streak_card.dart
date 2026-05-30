import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/rewards/rewards_bloc.dart';

/// Home dashboard card: streak flame + points + rank progress. Taps into
/// the adventure path.
class StreakCard extends StatelessWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<RewardsBloc, RewardsState>(
      builder: (context, state) {
        if (!state.loaded) return const SizedBox.shrink();
        final activeToday = state.streakActiveToday;
        return Material(
          borderRadius: BorderRadius.circular(20),
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.surface
              : Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/adventure'),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                        theme.brightness == Brightness.dark ? 0.4 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    _Flame(active: activeToday, streak: state.streak),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.streak == 0
                                ? 'Start your streak'
                                : '${state.streak}-day streak',
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            activeToday
                                ? 'Active today — nice! 🔥'
                                : 'Study today to keep it active',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${state.points}',
                            style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800)),
                        Text('points', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Icon(state.currentRank.icon,
                        size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: state.rankProgress,
                          minHeight: 8,
                          backgroundColor: theme.dividerColor,
                          valueColor: AlwaysStoppedAnimation(
                              theme.colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      state.nextRank == null
                          ? 'Max'
                          : '${state.pointsToNextRank} to ${state.nextRank!.name}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Flame extends StatelessWidget {
  final bool active;
  final int streak;
  const _Flame({required this.active, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFFF6B00).withOpacity(0.15)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          active ? '🔥' : '🕯️',
          style: const TextStyle(fontSize: 26),
        ),
      ),
    );
  }
}
