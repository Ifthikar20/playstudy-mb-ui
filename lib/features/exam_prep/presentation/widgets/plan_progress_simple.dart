import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../learning/data/models/learning_models.dart';
import '../../../learning/data/quiz_progress_store.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';
import '../../data/models/exam_plan.dart';

/// Simple per-plan progress block:
///   - one overall coverage bar
///   - a topic list where each topic shows its status and is tappable
///     to re-read the section content (and jump back into the study flow).
///
/// All numbers come from the shared [QuizProgressStore] so the same answers
/// drive the Quiz tab, the Study tab, and this view.
class PlanProgressSimple extends StatelessWidget {
  final ExamPlan plan;
  const PlanProgressSimple({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LearningBloc, LearningState>(
      buildWhen: (a, b) => a.library != b.library,
      builder: (context, ls) {
        final i = ls.library.indexWhere((m) => m.id == plan.materialId);
        if (i < 0) {
          return _NotInLibrary();
        }
        return _PlanProgressBody(plan: plan, material: ls.library[i]);
      },
    );
  }
}

class _NotInLibrary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Text(
        'Study material not in your library yet.',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _PlanProgressBody extends StatefulWidget {
  final ExamPlan plan;
  final LearningMaterial material;
  const _PlanProgressBody({required this.plan, required this.material});

  @override
  State<_PlanProgressBody> createState() => _PlanProgressBodyState();
}

class _PlanProgressBodyState extends State<_PlanProgressBody> {
  late Future<QuizProgressSnapshot> _snap;

  @override
  void initState() {
    super.initState();
    _snap = QuizProgressSnapshot.load(widget.material.id);
  }

  @override
  void didUpdateWidget(covariant _PlanProgressBody old) {
    super.didUpdateWidget(old);
    if (old.material.id != widget.material.id) {
      _snap = QuizProgressSnapshot.load(widget.material.id);
    }
  }

  /// In-plan topics only — respect the plan's topic filter, else the full set.
  List<String> get _scopedTopics =>
      widget.plan.topics.isEmpty ? widget.material.topics : widget.plan.topics;

  /// Map topic name -> matching StudySection (if the material has one).
  StudySection? _sectionFor(String topic) {
    final t = topic.trim().toLowerCase();
    for (final s in widget.material.sections) {
      if (s.title.trim().toLowerCase() == t) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<QuizProgressSnapshot>(
      future: _snap,
      builder: (context, snap) {
        final s = snap.data ??
            QuizProgressSnapshot(
              answered: const {},
              correct: const {},
              done: false,
              lastIndex: 0,
              score: 0,
            );
        // Bucket questions by topic, then compute per-topic answered count.
        final byTopic = <String, List<QuizQuestion>>{};
        for (final q in widget.material.quiz) {
          final t = q.topic.trim().isEmpty ? 'General' : q.topic.trim();
          byTopic.putIfAbsent(t, () => []).add(q);
        }
        // Build the row data, ordered by the plan's topic list.
        final rows = <_TopicRow>[];
        var totalQ = 0;
        var totalAnswered = 0;
        for (final topic in _scopedTopics) {
          final qs = byTopic[topic] ?? const <QuizQuestion>[];
          var answered = 0;
          for (final q in qs) {
            if (s.answered.contains(q.id)) answered++;
          }
          totalQ += qs.length;
          totalAnswered += answered;
          rows.add(_TopicRow(
            topic: topic,
            total: qs.length,
            answered: answered,
            section: _sectionFor(topic),
          ));
        }
        final overall = totalQ == 0 ? 0.0 : totalAnswered / totalQ;
        final overallPct = (overall * 100).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Overall progress strip.
            Row(children: [
              Text('Coverage',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const Spacer(),
              Text('$overallPct%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  )),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                tween: Tween(begin: 0, end: overall),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor:
                      theme.colorScheme.primary.withOpacity(0.10),
                  valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Topic list — tappable to re-read each section.
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: Colors.black.withOpacity(0.06),
                        indent: 14,
                        endIndent: 14,
                      ),
                    _TopicRowTile(
                      row: rows[i],
                      onTap: () => _openTopic(rows[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _openTopic(_TopicRow row) {
    if (row.section == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No reading content saved for this topic.")),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _TopicReader(
        topic: row.topic,
        section: row.section!,
        answered: row.answered,
        total: row.total,
      ),
    );
  }
}

class _TopicRow {
  final String topic;
  final int total;
  final int answered;
  final StudySection? section;
  const _TopicRow({
    required this.topic,
    required this.total,
    required this.answered,
    required this.section,
  });

  _TopicStatus get status {
    if (total == 0) return _TopicStatus.notStarted;
    if (answered == 0) return _TopicStatus.notStarted;
    if (answered >= total) return _TopicStatus.covered;
    return _TopicStatus.inProgress;
  }
}

enum _TopicStatus { notStarted, inProgress, covered }

class _TopicRowTile extends StatelessWidget {
  final _TopicRow row;
  final VoidCallback onTap;
  const _TopicRowTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, icon) = switch (row.status) {
      _TopicStatus.covered => (
          'Covered',
          const Color(0xFF22C55E),
          Icons.check_circle_rounded,
        ),
      _TopicStatus.inProgress => (
          '${row.answered}/${row.total}',
          const Color(0xFFF59E0B),
          Icons.timelapse_rounded,
        ),
      _TopicStatus.notStarted => (
          'Not started',
          const Color(0xFF94A3B8),
          Icons.radio_button_unchecked,
        ),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                row.topic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

/// Bottom sheet for re-reading a covered (or in-progress) section.
class _TopicReader extends StatelessWidget {
  final String topic;
  final StudySection section;
  final int answered;
  final int total;
  const _TopicReader({
    required this.topic,
    required this.section,
    required this.answered,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: EdgeInsets.only(bottom: mq.padding.bottom),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(topic,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          '$answered of $total questions attempted',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.55,
                          fontSize: 14.5,
                        ),
                      ),
                      if (section.example.trim().isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.lightbulb_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Text('FURTHER UNDERSTANDING',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 0.4,
                                    )),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                section.example,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
