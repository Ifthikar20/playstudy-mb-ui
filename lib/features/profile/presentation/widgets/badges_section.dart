import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/rewards/badges.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../../../core/widgets/airbnb_card.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';

/// Airbnb-style badge wall: header with progress + 3-column grid of badges.
/// Unlocked badges show their gradient + emoji; locked are dimmed with a
/// lock overlay.
class BadgesSection extends StatelessWidget {
  const BadgesSection({super.key});

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
            final unlocked = countUnlocked(ctx);
            return AirbnbCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Badges', style: theme.textTheme.titleLarge),
                          Text(
                            '$unlocked of ${kAchievements.length} unlocked',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$unlocked / ${kAchievements.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: kAchievements.isEmpty
                          ? 0
                          : unlocked / kAchievements.length,
                      minHeight: 6,
                      backgroundColor: theme.dividerColor,
                      valueColor:
                          AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                    children: [
                      for (final a in kAchievements)
                        _BadgeTile(
                          achievement: a,
                          unlocked: a.isUnlocked(ctx),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  const _BadgeTile({required this.achievement, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showDetail(context),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: unlocked
                    ? LinearGradient(
                        colors: achievement.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: unlocked ? null : theme.dividerColor.withOpacity(0.35),
                boxShadow: unlocked
                    ? [
                        BoxShadow(
                          color: achievement.colors.last.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: unlocked
                    ? Text(achievement.emoji,
                        style: const TextStyle(fontSize: 32))
                    : Icon(Icons.lock_outline,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        size: 24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: unlocked
                  ? null
                  : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: unlocked
                    ? LinearGradient(colors: achievement.colors)
                    : null,
                color: unlocked ? null : theme.dividerColor.withOpacity(0.35),
              ),
              child: Center(
                child: unlocked
                    ? Text(achievement.emoji,
                        style: const TextStyle(fontSize: 44))
                    : Icon(Icons.lock_outline,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        size: 36),
              ),
            ),
            const SizedBox(height: 16),
            Text(achievement.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: unlocked
                    ? theme.colorScheme.primary.withOpacity(0.12)
                    : theme.dividerColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                unlocked ? 'Unlocked' : 'Locked',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: unlocked ? theme.colorScheme.primary : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
