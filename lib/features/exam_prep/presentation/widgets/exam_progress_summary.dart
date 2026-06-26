import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/exam_plan.dart';

/// Top-of-tab summary: how the user is doing across ALL exam plans they've
/// created. Numbers are derived from each plan's recorded daily results —
/// no estimates.
class ExamProgressSummary extends StatelessWidget {
  final List<ExamPlan> plans;
  const ExamProgressSummary({super.key, required this.plans});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (plans.isEmpty) return const SizedBox.shrink();

    var totalDays = 0;
    var doneDays = 0;
    var totalCorrect = 0;
    var totalAttempted = 0;
    var onTrack = 0;
    var behind = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final p in plans) {
      totalDays += p.totalDays;
      doneDays += p.completedDays;
      for (final r in p.results.values) {
        if (!r.completed) continue;
        totalCorrect += r.correct;
        totalAttempted += r.total;
      }
      final start = DateTime(p.createdAt.year, p.createdAt.month, p.createdAt.day);
      final expected = today
          .difference(start)
          .inDays
          .clamp(0, p.totalDays)
          .toInt() +
          1;
      if (p.completedDays + 1 >= expected) {
        onTrack++;
      } else {
        behind++;
      }
    }
    final overallProgress = totalDays == 0 ? 0.0 : doneDays / totalDays;
    final overallAccuracy =
        totalAttempted == 0 ? 0.0 : totalCorrect / totalAttempted;
    final primary = ThemeColors.brandIndigo;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('Your exam progress',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                )),
            const Spacer(),
            Text(
              '${plans.length} plan${plans.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Overall progress bar
          Row(children: [
            Text('Days done',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                )),
            const Spacer(),
            Text('$doneDays / $totalDays',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: primary,
                )),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: overallProgress),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: primary.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation(primary),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 3 stat tiles
          Row(children: [
            Expanded(
              child: _Stat(
                label: 'On track',
                value: '$onTrack',
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: 'Behind',
                value: '$behind',
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: 'Accuracy',
                value: '${(overallAccuracy * 100).round()}%',
                color: const Color(0xFF3B82F6),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            )),
      ]),
    );
  }
}
