import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../../../core/widgets/airbnb_card.dart';
import '../../../rewards/presentation/widgets/learning_insights.dart'
    show DayActivity;

/// Compact 14-day study activity bar chart shown on the dashboard, replacing
/// the separate level + streak cards. Self-fetches /rewards/history.
class StudyActivityChart extends StatefulWidget {
  const StudyActivityChart({super.key});

  @override
  State<StudyActivityChart> createState() => _StudyActivityChartState();
}

class _StudyActivityChartState extends State<StudyActivityChart> {
  late Future<_ChartData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ChartData> _load() async {
    // Run BOTH calls in parallel — they're independent endpoints, so doing
    // them serially (the old code) doubled the perceived load time.
    final api = context.read<ApiClient>();
    final historyFuture = api.dio
        .get('rewards/history/', queryParameters: {'days': 14})
        .then((r) => (r.data['results'] as List)
            .cast<Map<String, dynamic>>()
            .map(DayActivity.fromJson)
            .toList())
        .catchError((Object e) {
      debugPrint('[home] rewards/history load failed: $e');
      return <DayActivity>[];
    });
    final progressFuture = api.dio.get('progress/me/').then((r) {
      final totals = r.data['totals'] as Map<String, dynamic>? ?? const {};
      return (
        totalSeconds: (totals['secondsSpent'] as int?) ?? 0,
        sectionsDone: (totals['sectionsCompleted'] as int?) ?? 0,
        sectionsTotal: (totals['sectionsTotal'] as int?) ?? 0,
      );
    }).catchError((Object e) {
      debugPrint('[home] progress/me load failed: $e');
      return (totalSeconds: 0, sectionsDone: 0, sectionsTotal: 0);
    });
    final results = await Future.wait<dynamic>([historyFuture, progressFuture]);
    final days = results[0] as List<DayActivity>;
    final p = results[1] as ({int totalSeconds, int sectionsDone, int sectionsTotal});
    return _ChartData(
      days: days,
      totalSeconds: p.totalSeconds,
      sectionsDone: p.sectionsDone,
      sectionsTotal: p.sectionsTotal,
    );
  }

  String _fmtDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final mm = m % 60;
    return mm == 0 ? '${h}h' : '${h}h ${mm}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<RewardsBloc, RewardsState>(
      builder: (context, rewards) {
        return FutureBuilder<_ChartData>(
          future: _future,
          builder: (context, snap) {
            final data = snap.data ?? const _ChartData.empty();
            final days = data.days;
            return AirbnbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('Study activity',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('Last 14 days', style: theme.textTheme.bodySmall),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    _Metric(
                        label: 'Time studied',
                        value: _fmtDuration(data.totalSeconds),
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 18),
                    _Metric(
                        label: 'Streak',
                        value: '${rewards.streak} d',
                        color: theme.colorScheme.secondary),
                    const SizedBox(width: 18),
                    _Metric(
                        label: 'Sections done',
                        value: data.sectionsTotal == 0
                            ? '${data.sectionsDone}'
                            : '${data.sectionsDone}/${data.sectionsTotal}',
                        color: theme.colorScheme.tertiary),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: snap.connectionState == ConnectionState.waiting
                        ? _ChartSkeleton(color: theme.colorScheme.primary)
                        : _BarChart(data: days, color: theme.colorScheme.primary),
                  ),
                  // Mastery progress: a second view of the same data so the
                  // user sees both *what they did* (bars) and *how far they
                  // are* through the material (this strip).
                  if (data.sectionsTotal > 0) ...[
                    const SizedBox(height: 18),
                    _MasteryStrip(
                      done: data.sectionsDone,
                      total: data.sectionsTotal,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChartData {
  final List<DayActivity> days;
  final int totalSeconds;
  final int sectionsDone;
  final int sectionsTotal;
  const _ChartData({
    required this.days,
    required this.totalSeconds,
    required this.sectionsDone,
    required this.sectionsTotal,
  });
  const _ChartData.empty()
      : days = const [],
        totalSeconds = 0,
        sectionsDone = 0,
        sectionsTotal = 0;
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w800)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Lightweight placeholder shown while the first chart load is in flight.
/// Renders the same shape as the real chart so layout doesn't jump.
class _ChartSkeleton extends StatefulWidget {
  final Color color;
  const _ChartSkeleton({required this.color});

  @override
  State<_ChartSkeleton> createState() => _ChartSkeletonState();
}

class _ChartSkeletonState extends State<_ChartSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final tint = widget.color
            .withOpacity(0.08 + (_ctrl.value * 0.10));
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(14, (i) {
            // pseudo-random heights so it looks like bars, not all identical
            final h = 24.0 + ((i * 13) % 80);
            return Container(
              width: 10,
              height: h,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Compact "X / Y sections — Z%" mastery bar shown under the bar chart.
class _MasteryStrip extends StatelessWidget {
  final int done;
  final int total;
  final Color color;
  const _MasteryStrip({
    required this.done,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final pctLabel = (pct * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.task_alt_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text('Mastery',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3,
              )),
          const Spacer(),
          Text(
            '$done / $total  ·  $pctLabel%',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            tween: Tween(begin: 0, end: pct),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<DayActivity> data;
  final Color color;
  const _BarChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text('No activity yet — start a study set to see your trend.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
      );
    }
    final maxY = data
            .map((d) => d.points)
            .fold<int>(0, (a, b) => b > a ? b : a)
            .clamp(10, 1 << 30)
            .toDouble() *
        1.15;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                // Only label every other day to avoid clutter on 14 bars.
                if (i % 2 != 0) return const SizedBox.shrink();
                final d = data[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${d.day}/${d.month}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].points.toDouble(),
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                  color: data[i].points > 0 ? color : color.withOpacity(0.18),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
