import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/rewards/rewards_bloc.dart';
import '../../../../core/widgets/airbnb_card.dart';

/// Dashboard card: current rank (level), points, and progress to the next level.
class LevelCard extends StatelessWidget {
  const LevelCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<RewardsBloc, RewardsState>(
      builder: (context, st) {
        final next = st.nextRank;
        return AirbnbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(st.currentRank.icon,
                      size: 22, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(st.currentRank.name,
                          style: theme.textTheme.titleLarge),
                      Text('${st.points} points',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bolt, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 2),
                    Text('Lv ${st.currentRankIndex + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: st.rankProgress,
                  minHeight: 8,
                  backgroundColor: theme.dividerColor,
                ),
              ),
              const SizedBox(height: 6),
              next == null
                  ? Text('Max level reached', style: theme.textTheme.bodySmall)
                  : Row(children: [
                      Text('${st.pointsToNextRank} pts to ${next.name}',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(width: 6),
                      Icon(next.icon,
                          size: 14, color: theme.textTheme.bodySmall?.color),
                    ]),
            ],
          ),
        );
      },
    );
  }
}
