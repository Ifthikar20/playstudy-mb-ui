import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../../../core/widgets/airbnb_card.dart';

/// One day's learning activity (points earned + number of actions).
class DayActivity {
  final String ymd;
  final int points;
  final int count;
  const DayActivity({required this.ymd, required this.points, required this.count});

  static DayActivity fromJson(Map<String, dynamic> j) => DayActivity(
        ymd: j['ymd'] as String? ?? '',
        points: j['points'] as int? ?? 0,
        count: j['count'] as int? ?? 0,
      );

  DateTime get date => DateTime.tryParse(ymd) ?? DateTime.now();
}

/// Interactive learning dashboard: rank progress ring, a weekly points bar
/// chart, and a 14-day activity strip. Self-fetches /rewards/history.
class LearningInsights extends StatefulWidget {
  final RewardsState state;
  const LearningInsights({super.key, required this.state});

  @override
  State<LearningInsights> createState() => _LearningInsightsState();
}

class _LearningInsightsState extends State<LearningInsights> {
  late Future<List<DayActivity>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DayActivity>> _load() async {
    final api = context.read<ApiClient>();
    final response =
        await api.dio.get('rewards/history/', queryParameters: {'days': 14});
    final results = (response.data['results'] as List).cast<Map<String, dynamic>>();
    return results.map(DayActivity.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<DayActivity>>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <DayActivity>[];
        final weekPoints =
            data.length >= 7 ? data.sublist(data.length - 7) : data;
        final earnedThisWeek =
            weekPoints.fold<int>(0, (a, d) => a + d.points);
        final activeDays = data.where((d) => d.count > 0).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your progress', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            AirbnbCard(
              child: Row(
                children: [
                  _RankRing(state: widget.state),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Metric(
                          label: 'Points this week',
                          value: '$earnedThisWeek',
                          icon: Icons.bolt,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 10),
                        _Metric(
                          label: 'Current streak',
                          value: '${widget.state.streak} days',
                          icon: Icons.local_fire_department,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(height: 10),
                        _Metric(
                          label: 'Active days (14d)',
                          value: '$activeDays',
                          icon: Icons.calendar_today,
                          color: theme.colorScheme.secondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AirbnbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last 7 days', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : weekPoints.isEmpty
                            ? Center(
                                child: Text('No activity yet',
                                    style: theme.textTheme.bodySmall))
                            : _WeeklyBars(days: weekPoints),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AirbnbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Activity (14 days)', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _ActivityStrip(days: data),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RankRing extends StatelessWidget {
  final RewardsState state;
  const _RankRing({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = state.rankProgress.clamp(0.0, 1.0);
    return SizedBox(
      height: 110,
      width: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 0,
              centerSpaceRadius: 42,
              sections: [
                PieChartSectionData(
                  value: progress * 100,
                  color: theme.colorScheme.primary,
                  radius: 10,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: (1 - progress) * 100,
                  color: theme.dividerColor,
                  radius: 10,
                  showTitle: false,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.currentRank.emoji,
                  style: const TextStyle(fontSize: 26)),
              Text('${(progress * 100).round()}%',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  final List<DayActivity> days;
  const _WeeklyBars({required this.days});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxPoints = days.fold<int>(0, (m, d) => d.points > m ? d.points : m);
    final maxY = (maxPoints < 10 ? 10 : maxPoints) * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                final d = (i >= 0 && i < days.length) ? days[i].date : null;
                final label = d == null ? '' : _labels[(d.weekday - 1) % 7];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(label, style: theme.textTheme.bodySmall),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].points.toDouble(),
                  width: 18,
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A GitHub-style strip: one cell per day, shaded by activity intensity.
class _ActivityStrip extends StatelessWidget {
  final List<DayActivity> days;
  const _ActivityStrip({required this.days});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxPoints = days.fold<int>(1, (m, d) => d.points > m ? d.points : m);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in days)
          Tooltip(
            message: '${d.ymd}: ${d.points} pts',
            child: Container(
              height: 22,
              width: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: d.points == 0
                    ? theme.dividerColor.withOpacity(0.4)
                    : theme.colorScheme.primary
                        .withOpacity(0.25 + 0.75 * (d.points / maxPoints)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(value,
            style: theme.textTheme.titleLarge?.copyWith(color: color)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
