import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../learning/data/models/learning_models.dart';
import '../../../learning/data/quiz_progress_store.dart';
import '../../data/models/exam_plan.dart';

/// One topic's progress facts, derived from real answer data, not estimated.
class _TopicStats {
  final String topic;
  final int totalQuestions; // all quiz items tagged with this topic
  final int answered; // how many of those we've answered (correct or not)
  final int correct; // how many we got right
  const _TopicStats({
    required this.topic,
    required this.totalQuestions,
    required this.answered,
    required this.correct,
  });

  double get accuracy => answered == 0 ? 0 : correct / answered;
  double get coverage =>
      totalQuestions == 0 ? 0 : answered / totalQuestions;

  /// 4-band mastery used for the stepped chart and "needs work" list.
  /// Untouched topics are forced to needsWork so they surface in the list.
  _MasteryLevel get level {
    if (answered == 0) return _MasteryLevel.untouched;
    if (accuracy < 0.50) return _MasteryLevel.needsWork;
    if (accuracy < 0.75) return _MasteryLevel.practicing;
    if (accuracy < 0.90) return _MasteryLevel.comfortable;
    return _MasteryLevel.mastered;
  }
}

enum _MasteryLevel { untouched, needsWork, practicing, comfortable, mastered }

extension _MasteryColors on _MasteryLevel {
  /// 0 = bottom of chart (worst), 4 = top (best). Untouched plots at 0.5.
  double get y {
    switch (this) {
      case _MasteryLevel.untouched:
        return 0.5;
      case _MasteryLevel.needsWork:
        return 1;
      case _MasteryLevel.practicing:
        return 2;
      case _MasteryLevel.comfortable:
        return 3;
      case _MasteryLevel.mastered:
        return 4;
    }
  }

  Color get color {
    switch (this) {
      case _MasteryLevel.untouched:
        return const Color(0xFF94A3B8);
      case _MasteryLevel.needsWork:
        return const Color(0xFFEF4444);
      case _MasteryLevel.practicing:
        return const Color(0xFFF59E0B);
      case _MasteryLevel.comfortable:
        return const Color(0xFF3B82F6);
      case _MasteryLevel.mastered:
        return const Color(0xFF22C55E);
    }
  }

  String get label {
    switch (this) {
      case _MasteryLevel.untouched:
        return 'Not started';
      case _MasteryLevel.needsWork:
        return 'Needs work';
      case _MasteryLevel.practicing:
        return 'Practicing';
      case _MasteryLevel.comfortable:
        return 'Comfortable';
      case _MasteryLevel.mastered:
        return 'Mastered';
    }
  }
}

/// Apple-style stepped stages chart + actionable topic lists.
/// All numbers are computed from real answered/correct sets in
/// [QuizProgressStore] — no estimates.
class TopicMasteryView extends StatefulWidget {
  final ExamPlan plan;
  final LearningMaterial material;
  const TopicMasteryView({
    super.key,
    required this.plan,
    required this.material,
  });

  @override
  State<TopicMasteryView> createState() => _TopicMasteryViewState();
}

class _TopicMasteryViewState extends State<TopicMasteryView> {
  late Future<QuizProgressSnapshot> _snap;

  @override
  void initState() {
    super.initState();
    _snap = QuizProgressSnapshot.load(widget.material.id);
  }

  @override
  void didUpdateWidget(covariant TopicMasteryView old) {
    super.didUpdateWidget(old);
    if (old.material.id != widget.material.id) {
      _snap = QuizProgressSnapshot.load(widget.material.id);
    }
  }

  List<_TopicStats> _compute(QuizProgressSnapshot snap) {
    // Filter the material's quiz to the topics this plan covers (so the
    // chart shows only what the plan asked for, not the full material).
    final scope = widget.plan.topics.isEmpty
        ? widget.material.topics.toSet()
        : widget.plan.topics.toSet();

    // Group quiz questions by topic.
    final byTopic = <String, List<QuizQuestion>>{};
    for (final q in widget.material.quiz) {
      final t = q.topic.trim().isEmpty ? 'General' : q.topic.trim();
      if (!scope.contains(t)) continue;
      byTopic.putIfAbsent(t, () => []).add(q);
    }
    // Include in-plan topics that have no questions yet (edge case).
    for (final t in scope) {
      byTopic.putIfAbsent(t, () => []);
    }

    final stats = <_TopicStats>[];
    for (final entry in byTopic.entries) {
      var answered = 0;
      var correct = 0;
      for (final q in entry.value) {
        if (snap.answered.contains(q.id)) answered++;
        if (snap.correct.contains(q.id)) correct++;
      }
      stats.add(_TopicStats(
        topic: entry.key,
        totalQuestions: entry.value.length,
        answered: answered,
        correct: correct,
      ));
    }
    // Keep order stable — sort by name so the chart doesn't shuffle.
    stats.sort((a, b) => a.topic.toLowerCase().compareTo(b.topic.toLowerCase()));
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<QuizProgressSnapshot>(
      future: _snap,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 220,
            child: Center(
              child: SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final stats = _compute(snap.data ?? QuizProgressSnapshot(
          answered: const {}, correct: const {}, done: false,
          lastIndex: 0, score: 0,
        ));
        if (stats.isEmpty) {
          return const SizedBox.shrink();
        }

        // Aggregate numbers for the header.
        final totalQ = stats.fold<int>(0, (a, b) => a + b.totalQuestions);
        final totalAnswered = stats.fold<int>(0, (a, b) => a + b.answered);
        final totalCorrect = stats.fold<int>(0, (a, b) => a + b.correct);
        final overallAcc = totalAnswered == 0 ? 0.0 : totalCorrect / totalAnswered;
        final coveragePct = totalQ == 0 ? 0 : (totalAnswered / totalQ * 100).round();

        final needsWork = stats
            .where((s) => s.level == _MasteryLevel.needsWork ||
                s.level == _MasteryLevel.untouched)
            .toList()
          ..sort((a, b) {
            // Surface "actually attempted but low accuracy" before untouched,
            // since those are the most actionable.
            if (a.answered > 0 && b.answered == 0) return -1;
            if (a.answered == 0 && b.answered > 0) return 1;
            return a.accuracy.compareTo(b.accuracy);
          });
        final mastered =
            stats.where((s) => s.level == _MasteryLevel.mastered).toList()
              ..sort((a, b) => b.accuracy.compareTo(a.accuracy));

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Text('Topic mastery',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2)),
                const Spacer(),
                Text('${(overallAcc * 100).round()}% · $coveragePct% covered',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ]),
              const SizedBox(height: 4),
              Text(
                'Across ${stats.length} topic${stats.length == 1 ? '' : 's'} · $totalAnswered of $totalQ questions attempted',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              // Chart
              SizedBox(
                height: 200,
                child: _MasteryStepChart(stats: stats),
              ),
              const SizedBox(height: 6),
              _LegendRow(),
              if (needsWork.isNotEmpty) ...[
                const SizedBox(height: 18),
                _ListHeader(
                  icon: Icons.flag_rounded,
                  label: 'Needs more work',
                  color: const Color(0xFFEF4444),
                  count: needsWork.length,
                ),
                for (final s in needsWork) _TopicListRow(stat: s),
              ],
              if (mastered.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ListHeader(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Mastered',
                  color: const Color(0xFF22C55E),
                  count: mastered.length,
                ),
                for (final s in mastered) _TopicListRow(stat: s),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MasteryStepChart extends StatelessWidget {
  final List<_TopicStats> stats;
  const _MasteryStepChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    // Y-axis labels on the left, chart on the right.
    return LayoutBuilder(builder: (context, c) {
      const yWidth = 86.0;
      final chartW = c.maxWidth - yWidth;
      // Scroll horizontally if there are many topics so labels stay readable.
      final colW = math.max(46.0, chartW / stats.length);
      final fits = colW * stats.length <= chartW;

      Widget chart = SizedBox(
        width: fits ? chartW : colW * stats.length,
        height: c.maxHeight - 28, // room for x labels
        child: CustomPaint(
          painter: _StepPainter(stats: stats),
        ),
      );

      Widget xLabels = SizedBox(
        width: fits ? chartW : colW * stats.length,
        height: 28,
        child: Row(
          children: [
            for (final s in stats)
              SizedBox(
                width: colW,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    s.topic,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      height: 1.05,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

      final chartBlock = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: chart),
          xLabels,
        ],
      );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Y-axis: 4 named bands + Mastered label at top
          SizedBox(
            width: yWidth,
            height: c.maxHeight,
            child: const _YAxisLabels(),
          ),
          Expanded(
            child: fits
                ? chartBlock
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: colW * stats.length,
                      height: c.maxHeight,
                      child: chartBlock,
                    ),
                  ),
          ),
        ],
      );
    });
  }
}

class _YAxisLabels extends StatelessWidget {
  const _YAxisLabels();

  static const _labels = [
    (1, 'Needs work', Color(0xFFEF4444)),
    (2, 'Practicing', Color(0xFFF59E0B)),
    (3, 'Comfortable', Color(0xFF3B82F6)),
    (4, 'Mastered', Color(0xFF22C55E)),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Reserve same 28px for x-axis labels at bottom so y aligns with chart.
      final h = c.maxHeight - 28;
      return SizedBox(
        height: c.maxHeight,
        child: Stack(children: [
          for (final entry in _labels)
            Positioned(
              left: 0,
              right: 6,
              top: h - (entry.$1 / 4) * h - 8,
              child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: entry.$3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.$2,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
        ]),
      );
    });
  }
}

class _StepPainter extends CustomPainter {
  final List<_TopicStats> stats;
  _StepPainter({required this.stats});

  static const _maxLevel = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = stats.length;
    if (n == 0) return;
    final colW = size.width / n;
    final rect = Offset.zero & size;

    // Grid lines (horizontal) at each level.
    final grid = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (var i = 1; i <= _maxLevel.toInt(); i++) {
      final y = size.height - (i / _maxLevel) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Vertical guide lines between columns.
    final colGuide = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;
    for (var i = 1; i < n; i++) {
      final x = i * colW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), colGuide);
    }

    // Build the stepped polygon under the line.
    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i < n; i++) {
      final lvl = stats[i].level.y;
      final h = size.height - (lvl / _maxLevel) * size.height;
      final x1 = i * colW;
      final x2 = (i + 1) * colW;
      path.lineTo(x1, h);
      path.lineTo(x2, h);
    }
    path.lineTo(size.width, size.height);
    path.close();

    // Vertical gradient: red at bottom -> green at top (mastery rises = greener)
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF22C55E), // top  (mastered)
          Color(0xFF3B82F6), // mid-high (comfortable)
          Color(0xFFF59E0B), // mid-low (practicing)
          Color(0xFFEF4444), // bottom (needs work)
        ],
        stops: [0.0, 0.40, 0.70, 1.0],
      ).createShader(rect)
      ..color = Colors.black.withOpacity(0.30);
    // Translucent gradient fill so grid stays readable.
    canvas.saveLayer(rect, Paint());
    canvas.drawPath(path, fillPaint);
    canvas.drawRect(rect, Paint()..color = Colors.white.withOpacity(0.65)
      ..blendMode = BlendMode.dstIn);
    canvas.restore();
    canvas.drawPath(path, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x4022C55E),
          Color(0x403B82F6),
          Color(0x40F59E0B),
          Color(0x40EF4444),
        ],
        stops: [0.0, 0.40, 0.70, 1.0],
      ).createShader(rect));

    // Top stroke that traces the step edges only (not the closing baseline).
    final stroke = Paint()
      ..color = const Color(0xFF1A0E12)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final top = Path();
    for (var i = 0; i < n; i++) {
      final lvl = stats[i].level.y;
      final h = size.height - (lvl / _maxLevel) * size.height;
      final x1 = i * colW;
      final x2 = (i + 1) * colW;
      if (i == 0) top.moveTo(x1, h);
      top.lineTo(x1, h);
      top.lineTo(x2, h);
    }
    canvas.drawPath(top, stroke);

    // Small filled dot at the midpoint of each step, colored by level.
    for (var i = 0; i < n; i++) {
      final lvl = stats[i].level.y;
      final h = size.height - (lvl / _maxLevel) * size.height;
      final cx = (i + 0.5) * colW;
      canvas.drawCircle(
        Offset(cx, h),
        4,
        Paint()..color = stats[i].level.color,
      );
      canvas.drawCircle(
        Offset(cx, h),
        4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StepPainter old) =>
      old.stats.length != stats.length ||
      [for (var i = 0; i < stats.length; i++) stats[i].level] !=
          [for (var i = 0; i < old.stats.length; i++) old.stats[i].level];
}

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                )),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        dot(const Color(0xFFEF4444), 'Needs work'),
        dot(const Color(0xFFF59E0B), 'Practicing'),
        dot(const Color(0xFF3B82F6), 'Comfortable'),
        dot(const Color(0xFF22C55E), 'Mastered'),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int count;
  const _ListHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            )),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              )),
        ),
      ]),
    );
  }
}

class _TopicListRow extends StatelessWidget {
  final _TopicStats stat;
  const _TopicListRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final color = stat.level.color;
    final pct = (stat.accuracy * 100).round();
    final subtitle = stat.answered == 0
        ? 'Not attempted yet · ${stat.totalQuestions} Q available'
        : '$pct% · ${stat.correct} / ${stat.answered} correct '
            '(${stat.answered} of ${stat.totalQuestions} attempted)';
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(children: [
        Container(
          width: 6, height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stat.topic,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A0E12),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            stat.level.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ]),
    );
  }
}
