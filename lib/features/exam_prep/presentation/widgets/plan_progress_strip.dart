import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/exam_plan.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Analytics derived from `ExamPlan.results` for the progress widgets.
/// Kept as extensions so the data model stays serialization-focused.
extension PlanAnalytics on ExamPlan {
  /// Average % correct across every completed session.
  double get averageAccuracy {
    var c = 0;
    var t = 0;
    for (final r in results.values) {
      if (!r.completed) continue;
      c += r.correct;
      t += r.total;
    }
    return t == 0 ? 0 : c / t;
  }

  /// Longest run of consecutive completed days ending today (or yesterday).
  /// Counts back from today; allows starting at yesterday so finishing today
  /// late doesn't reset the streak.
  int get currentStreak {
    var n = 0;
    final today = _dateOnly(DateTime.now());
    var d = today;
    if (!(results[_ymd(d)]?.completed ?? false)) {
      d = today.subtract(const Duration(days: 1));
      if (!(results[_ymd(d)]?.completed ?? false)) return 0;
    }
    while (true) {
      final hit = results[_ymd(d)]?.completed ?? false;
      if (!hit) break;
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Returns: (completed, expected, label) where `expected` is the number of
  /// scheduled days from createdAt up to *today*. `label` is one of
  /// 'ahead' | 'on track' | 'behind'.
  ({int completed, int expected, String label}) get pace {
    final today = _dateOnly(DateTime.now());
    final start = _dateOnly(createdAt);
    final expected = today.difference(start).inDays + 1;
    final clamped = expected.clamp(0, totalDays);
    final done = completedDays;
    String label;
    if (done > clamped + 1) {
      label = 'ahead';
    } else if (done >= clamped - 1) {
      label = 'on track';
    } else {
      label = 'behind';
    }
    return (completed: done, expected: clamped, label: label);
  }

  /// Per-day accuracy for the trend chart, in chronological order.
  /// Returns one entry per scheduled day from (today - [windowDays] + 1) up
  /// to today. Days without a completed session contribute 0.
  List<({DateTime date, double accuracy, bool done})> recentAccuracySeries(
      {int windowDays = 14}) {
    final today = _dateOnly(DateTime.now());
    final out = <({DateTime date, double accuracy, bool done})>[];
    for (var i = windowDays - 1; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final r = results[_ymd(d)];
      final ok = r?.completed ?? false;
      final acc = (ok && (r!.total > 0)) ? r.correct / r.total : 0.0;
      out.add((date: d, accuracy: acc, done: ok));
    }
    return out;
  }

  /// Most recent N completed sessions, newest first.
  List<({DateTime date, DailyResult result})> recentSessions(int n) {
    final entries = results.entries
        .where((e) => e.value.completed)
        .map((e) {
      final parts = e.key.split('-');
      return (
        date: DateTime(int.parse(parts[0]), int.parse(parts[1]),
            int.parse(parts[2])),
        result: e.value,
      );
    }).toList();
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries.take(n).toList();
  }
}

/// Compact "progress over time" panel attached to a plan card. Shows: 4
/// summary stats, a 14-day accuracy mini-chart, a pace badge, and the most
/// recent few sessions.
class PlanProgressStrip extends StatelessWidget {
  final ExamPlan plan;
  const PlanProgressStrip({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = ThemeColors.brandIndigo;
    final accuracy = plan.averageAccuracy;
    final streak = plan.currentStreak;
    final pace = plan.pace;
    final series = plan.recentAccuracySeries();
    final recent = plan.recentSessions(3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Stat strip: Done / Accuracy / Streak / Days left ──────────────
        Row(children: [
          Expanded(
            child: _StatTile(
              value: '${plan.completedDays}',
              denominator: '/${plan.totalDays}',
              label: 'Days done',
              color: primary,
              icon: Icons.check_circle_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              value: '${(accuracy * 100).round()}%',
              label: 'Accuracy',
              color: const Color(0xFF22C55E),
              icon: Icons.adjust_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              value: '$streak',
              suffix: streak == 1 ? 'day' : 'days',
              label: 'Streak',
              color: const Color(0xFFF59E0B),
              icon: Icons.local_fire_department_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatTile(
              value: '${plan.daysUntilExam}',
              suffix: 'd',
              label: 'To exam',
              color: ThemeColors.brandIndigo,
              icon: Icons.event_rounded,
            ),
          ),
        ]),
        const SizedBox(height: 14),
        // ── Trend mini-chart: accuracy over the last 14 days ──────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withOpacity(0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.show_chart_rounded, size: 16, color: primary),
                const SizedBox(width: 6),
                Text('Accuracy trend',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    )),
                const Spacer(),
                _PaceBadge(label: pace.label),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: _TrendBars(series: series, color: primary),
              ),
              const SizedBox(height: 4),
              Row(children: [
                Text(DateFormat.MMMd().format(series.first.date),
                    style:
                        theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                const Spacer(),
                Text('Today',
                    style:
                        theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
              ]),
            ],
          ),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Recent sessions',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 6),
          for (final r in recent) _RecentRow(date: r.date, result: r.result),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String? denominator;
  final String? suffix;
  final String label;
  final Color color;
  final IconData icon;
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    this.denominator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(children: [
            TextSpan(
              text: value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.2,
              ),
            ),
            if (denominator != null)
              TextSpan(
                text: denominator,
                style: TextStyle(
                  color: color.withOpacity(0.55),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            if (suffix != null)
              TextSpan(
                text: ' $suffix',
                style: TextStyle(
                  color: color.withOpacity(0.55),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
          ]),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }
}

class _PaceBadge extends StatelessWidget {
  final String label;
  const _PaceBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (label) {
      'ahead' => (const Color(0xFF22C55E), Icons.trending_up_rounded),
      'on track' => (const Color(0xFF6B5CE7), Icons.bolt_rounded),
      _ => (const Color(0xFFEF4444), Icons.trending_down_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.40)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            )),
      ]),
    );
  }
}

/// Small bar chart for the accuracy series. Empty days are dim grey ticks
/// so the user sees both the days they showed up AND the days they missed.
class _TrendBars extends StatelessWidget {
  final List<({DateTime date, double accuracy, bool done})> series;
  final Color color;
  const _TrendBars({required this.series, required this.color});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      final n = series.length;
      final gap = 4.0;
      final barW = math.max(4.0, (c.maxWidth - gap * (n - 1)) / n);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Tooltip(
              message: series[i].done
                  ? '${DateFormat.MMMd().format(series[i].date)} · ${(series[i].accuracy * 100).round()}%'
                  : '${DateFormat.MMMd().format(series[i].date)} · skipped',
              child: SizedBox(
                width: barW,
                height: c.maxHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: barW,
                    height: series[i].done
                        ? math.max(4, series[i].accuracy * c.maxHeight)
                        : 4,
                    decoration: BoxDecoration(
                      color: series[i].done
                          ? Color.lerp(
                              const Color(0xFFEF4444),
                              const Color(0xFF22C55E),
                              series[i].accuracy,
                            )
                          : color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _RecentRow extends StatelessWidget {
  final DateTime date;
  final DailyResult result;
  const _RecentRow({required this.date, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = result.total == 0 ? 0 : (result.correct / result.total * 100).round();
    final color = pct >= 80
        ? const Color(0xFF22C55E)
        : pct >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${date.day}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.MMMEd().format(date),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text('${result.correct} / ${result.total} correct',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$pct%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              )),
        ),
      ]),
    );
  }
}
