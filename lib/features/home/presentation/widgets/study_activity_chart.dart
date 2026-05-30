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
  late Future<List<DayActivity>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DayActivity>> _load() async {
    try {
      final api = context.read<ApiClient>();
      final response =
          await api.dio.get('rewards/history/', queryParameters: {'days': 14});
      final results =
          (response.data['results'] as List).cast<Map<String, dynamic>>();
      return results.map(DayActivity.fromJson).toList();
    } catch (e) {
      debugPrint('[home] StudyActivityChart load failed: $e');
      return const <DayActivity>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<RewardsBloc, RewardsState>(
      builder: (context, rewards) {
        return FutureBuilder<List<DayActivity>>(
          future: _future,
          builder: (context, snap) {
            final data = snap.data ?? const <DayActivity>[];
            final last7 = data.length >= 7 ? data.sublist(data.length - 7) : data;
            final weekTotal = last7.fold<int>(0, (a, d) => a + d.points);
            final activeDays = data.where((d) => d.count > 0).length;
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
                        label: 'Points this week',
                        value: '$weekTotal',
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 18),
                    _Metric(
                        label: 'Streak',
                        value: '${rewards.streak} d',
                        color: theme.colorScheme.secondary),
                    const SizedBox(width: 18),
                    _Metric(
                        label: 'Active days',
                        value: '$activeDays / 14',
                        color: theme.colorScheme.tertiary),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Center(
                            child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2)))
                        : _BarChart(data: data, color: theme.colorScheme.primary),
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
