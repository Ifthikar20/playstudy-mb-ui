import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/airbnb_card.dart';
import '../../data/family_repository.dart';

/// Parent analytics board for one linked student: time spent, completion, and
/// per-section breakdown across their study sets.
class ChildDashboardPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  const ChildDashboardPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ChildDashboardPage> createState() => _ChildDashboardPageState();
}

class _ChildDashboardPageState extends State<ChildDashboardPage> {
  Future<Analytics>? _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<FamilyRepository>().childAnalytics(widget.studentId);
  }

  static String _dur(int secs) {
    if (secs < 60) return '${secs}s';
    final m = secs ~/ 60;
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(widget.studentName),
      ),
      body: FutureBuilder<Analytics>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return Center(
                child: Text('Could not load analytics',
                    style: theme.textTheme.bodyMedium));
          }
          final a = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Headline stats
              Row(children: [
                Expanded(
                    child: _Stat(
                        label: 'Time studying',
                        value: _dur(a.secondsSpent),
                        icon: Icons.timer_outlined)),
                const SizedBox(width: 12),
                Expanded(
                    child: _Stat(
                        label: 'Completed',
                        value:
                            '${a.completionPct}%',
                        icon: Icons.task_alt)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _Stat(
                        label: 'Points',
                        value: '${a.points}',
                        icon: Icons.bolt)),
                const SizedBox(width: 12),
                Expanded(
                    child: _Stat(
                        label: 'Streak',
                        value: '${a.streak}d',
                        icon: Icons.local_fire_department)),
              ]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${a.sectionsCompleted} of ${a.sectionsTotal} sections done '
                  'across ${a.studySetCount} study set'
                  '${a.studySetCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),

              if (a.studySets.isEmpty)
                AirbnbCard(
                  child: Text("No activity yet — once ${a.studentName} starts "
                      "studying, it'll show here."),
                ),
              for (final s in a.studySets) _SetCard(set: s, durFn: _dur),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AirbnbCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(height: 8),
        Text(value, style: theme.textTheme.headlineMedium),
        Text(label, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

class _SetCard extends StatefulWidget {
  final SetProgress set;
  final String Function(int) durFn;
  const _SetCard({required this.set, required this.durFn});

  @override
  State<_SetCard> createState() => _SetCardState();
}

class _SetCardState extends State<_SetCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final set = widget.set;
    final durFn = widget.durFn;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AirbnbCard(
        onTap: set.sections.isEmpty
            ? null
            : () => setState(() => _expanded = !_expanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(set.title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (set.avgScorePct != null)
                Text('avg ${set.avgScorePct}%',
                    style: theme.textTheme.bodySmall),
              if (set.sections.isNotEmpty)
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20, color: theme.colorScheme.onSurface.withOpacity(0.5)),
            ]),
            const SizedBox(height: 6),
            Text(
              '${set.sectionsCompleted}/${set.sectionsTotal} sections · '
              '${durFn(set.secondsSpent)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: set.sectionsTotal == 0
                    ? 0
                    : set.sectionsCompleted / set.sectionsTotal,
                minHeight: 6,
                backgroundColor: theme.dividerColor,
              ),
            ),
            if (_expanded && set.sections.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(height: 130, child: _SectionBars(sections: set.sections)),
              const SizedBox(height: 8),
              for (final sec in set.sections)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon(
                      sec.completed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: sec.completed ? Colors.green : theme.dividerColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sec.title.isEmpty ? 'Section ${sec.index + 1}' : sec.title,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(durFn(sec.secondsSpent),
                        style: theme.textTheme.bodySmall),
                    if (sec.scorePct != null) ...[
                      const SizedBox(width: 8),
                      Text('${sec.scorePct}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary)),
                    ],
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionBars extends StatelessWidget {
  final List<SectionProgress> sections;
  const _SectionBars({required this.sections});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSecs = sections.fold<int>(
        1, (m, s) => s.secondsSpent > m ? s.secondsSpent : m);
    final maxY = (maxSecs < 60 ? 60 : maxSecs).toDouble() * 1.2;
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
              reservedSize: 18,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${value.toInt() + 1}',
                    style: theme.textTheme.bodySmall),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < sections.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: sections[i].secondsSpent.toDouble(),
                width: 16,
                color: sections[i].completed
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withOpacity(0.4),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ]),
        ],
      ),
    );
  }
}
