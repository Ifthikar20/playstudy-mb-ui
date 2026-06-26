import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../learning/data/models/learning_models.dart';
import '../../../learning/data/quiz_progress_store.dart';
import '../../../learning/data/repositories/learning_repository.dart';
import '../../data/models/exam_plan.dart';
import '../bloc/exam_prep_bloc.dart';

/// Today's session: shows N questions for the plan, scoped to the plan's
/// topics. Records the result back into the plan when finished.
class DailySessionPage extends StatefulWidget {
  final String planId;
  const DailySessionPage({super.key, required this.planId});

  @override
  State<DailySessionPage> createState() => _DailySessionPageState();
}

class _DailySessionPageState extends State<DailySessionPage> {
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool _revealed = false;
  bool _done = false;
  bool _loading = true;
  bool _started = false; // false -> show the overview before Q1 lands
  LearningMaterial? _material;

  @override
  void initState() {
    super.initState();
    _loadMaterial();
  }

  Future<void> _loadMaterial() async {
    try {
      final m = await context.read<LearningRepository>().fetch(_plan.materialId);
      if (mounted) setState(() => _material = m);
    } catch (_) {
      // leave _material null -> "No questions" state
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ExamPlan get _plan => context
      .read<ExamPrepBloc>()
      .state
      .plans
      .firstWhere((p) => p.id == widget.planId);

  /// Deterministic per-day question selection: take the plan's topic-filtered
  /// quiz, shuffle with a seed derived from today's date so the same set
  /// shows up if the user reopens, but a fresh set tomorrow.
  List<QuizQuestion> get _questions {
    final m = _material;
    if (m == null) return const [];
    final pool = m.quizForTopics(_plan.topics);
    if (pool.isEmpty) return const [];
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final shuffled = [...pool]..sort((a, b) =>
        ((a.id.hashCode ^ seed) - (b.id.hashCode ^ seed)).compareTo(0));
    return shuffled.take(_plan.questionsPerDay).toList();
  }

  QuizQuestion get _q => _questions[_index];

  void _choose(int i) {
    if (_revealed) return;
    setState(() {
      _selected = i;
      _revealed = true;
      if (i == _q.correctIndex) _correct++;
    });
  }

  void _next() {
    if (_index + 1 < _questions.length) {
      setState(() {
        _index++;
        _selected = null;
        _revealed = false;
      });
    } else {
      setState(() => _done = true);
      context.read<ExamPrepBloc>().add(CompleteSession(
            planId: widget.planId,
            day: DateTime.now(),
            correct: _correct,
            total: _questions.length,
          ));
      // The daily-session reward is granted server-side by the sessions
      // endpoint (idempotent per day); just refresh the local rewards state.
      context.read<RewardsBloc>().add(LoadRewards());
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's session"),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/exam'),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : questions.isEmpty
            ? const Center(child: Text('No questions for today.'))
            : !_started && !_done
                ? _SessionOverview(
                    plan: _plan,
                    questions: questions,
                    onStart: () => setState(() => _started = true),
                  )
                : _done
                ? _Done(
                    correct: _correct,
                    total: questions.length,
                    onClose: () => context.go('/exam'),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(
                            value: (_index + 1) / questions.length),
                        const SizedBox(height: 20),
                        Row(children: [
                          Text(
                              'Question ${_index + 1} of ${questions.length}',
                              style: theme.textTheme.bodySmall),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  ThemeColors.brandIndigo.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_q.topic,
                                style: TextStyle(
                                    color: ThemeColors.brandIndigo,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Text(_q.prompt,
                            style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 20),
                        ...List.generate(_q.choices.length, (i) {
                          final isCorrect = i == _q.correctIndex;
                          final isPicked = i == _selected;
                          Color? bg;
                          if (_revealed) {
                            if (isCorrect) {
                              bg = Colors.green.withOpacity(0.12);
                            } else if (isPicked) {
                              bg = Colors.red.withOpacity(0.12);
                            }
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: bg ?? theme.colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: theme.dividerColor),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _choose(i),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(_q.choices[i],
                                            style: theme
                                                .textTheme.bodyLarge)),
                                    if (_revealed && isCorrect)
                                      const Icon(Icons.check_circle_rounded,
                                          color: Colors.green),
                                    if (_revealed && isPicked && !isCorrect)
                                      const Icon(Icons.cancel_rounded,
                                          color: Colors.red),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        }),
                        const Spacer(),
                        if (_revealed && _q.explanation != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(_q.explanation!,
                                style: theme.textTheme.bodySmall),
                          ),
                        ElevatedButton(
                          onPressed: _revealed ? _next : null,
                          child: Text(_index + 1 == questions.length
                              ? 'Finish'
                              : 'Next'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// "What's coming up" screen shown before today's first question lands.
/// Computed entirely from the actual question set the user is about to see —
/// counts, topics and difficulty mix all match the real session, not estimates.
class _SessionOverview extends StatefulWidget {
  final ExamPlan plan;
  final List<QuizQuestion> questions;
  final VoidCallback onStart;
  const _SessionOverview({
    required this.plan,
    required this.questions,
    required this.onStart,
  });

  @override
  State<_SessionOverview> createState() => _SessionOverviewState();
}

class _SessionOverviewState extends State<_SessionOverview> {
  late Future<QuizProgressSnapshot> _snap;

  @override
  void initState() {
    super.initState();
    _snap = QuizProgressSnapshot.load(widget.plan.materialId);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final questions = widget.questions;
    final theme = Theme.of(context);
    final primary = ThemeColors.brandIndigo;
    final total = questions.length;
    final easy = questions.where((q) => q.difficulty == QuizDifficulty.easy).length;
    final med = questions.where((q) => q.difficulty == QuizDifficulty.medium).length;
    final hard = questions.where((q) => q.difficulty == QuizDifficulty.hard).length;

    // Group by topic preserving the first-seen order, and count per topic.
    final topicCounts = <String, int>{};
    for (final q in questions) {
      final t = q.topic.trim().isEmpty ? 'General' : q.topic.trim();
      topicCounts.update(t, (v) => v + 1, ifAbsent: () => 1);
    }

    final estMinutes = (total * 0.5).ceil(); // rough — 30s per question

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header card with exam context ─────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, const Color(0xFF9D8DFA)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "TODAY'S SESSION",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${plan.daysUntilExam}d to exam',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(
                  plan.examTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.materialTitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  _BigStat(value: '$total', label: 'questions'),
                  const SizedBox(width: 24),
                  _BigStat(
                      value: '~$estMinutes',
                      label: estMinutes == 1 ? 'minute' : 'minutes'),
                  const SizedBox(width: 24),
                  _BigStat(
                      value: '${topicCounts.length}',
                      label: topicCounts.length == 1 ? 'topic' : 'topics'),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Done / Pending strip (cross-referenced with shared store) ─
          FutureBuilder<QuizProgressSnapshot>(
            future: _snap,
            builder: (context, asnap) {
              final answered = asnap.data?.answered ?? const <String>{};
              final doneSet =
                  questions.where((q) => answered.contains(q.id)).toList();
              final done = doneSet.length;
              final pending = total - done;
              return _DonePendingStrip(
                done: done,
                pending: pending,
                total: total,
                primary: primary,
              );
            },
          ),
          const SizedBox(height: 22),

          // ── Difficulty breakdown ──────────────────────────────────────
          Text("How it's split",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800,
                              letterSpacing: -0.2)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _DifficultyTile(
                count: easy,
                label: 'Easy',
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DifficultyTile(
                count: med,
                label: 'Medium',
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DifficultyTile(
                count: hard,
                label: 'Hard',
                color: const Color(0xFFEF4444),
              ),
            ),
          ]),
          const SizedBox(height: 22),

          // ── Topics covered ────────────────────────────────────────────
          Text("Topics in today's session",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800,
                              letterSpacing: -0.2)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                for (final entry in topicCounts.entries) ...[
                  if (entry.key != topicCounts.keys.first)
                    Divider(
                      height: 1,
                      color: Colors.black.withOpacity(0.05),
                      indent: 14,
                      endIndent: 14,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    child: Row(children: [
                      Icon(Icons.bolt_rounded, size: 16, color: primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.value} Q',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── What you'll know ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withOpacity(0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: primary),
                  const SizedBox(width: 6),
                  Text("By the end you'll be sharper on",
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      )),
                ]),
                const SizedBox(height: 8),
                for (final t in topicCounts.keys)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('•  ',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          )),
                      Expanded(
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Quick facts row ──────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _FactPill(
                icon: Icons.event_rounded,
                label: 'Exam',
                value: '${plan.daysUntilExam}d away',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FactPill(
                icon: Icons.check_circle_rounded,
                label: 'Plan progress',
                value: '${plan.completedDays}/${plan.totalDays}',
              ),
            ),
          ]),
          const SizedBox(height: 22),

          // ── Start CTA ────────────────────────────────────────────────
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: widget.onStart,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
                elevation: 0,
              ),
              child: const Text('Start session'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline summary of how many of today's questions you've already answered
/// (across any session) vs how many are still pending. Sits at the top of
/// the session overview so the user immediately sees what's left.
class _DonePendingStrip extends StatelessWidget {
  final int done;
  final int pending;
  final int total;
  final Color primary;
  const _DonePendingStrip({
    required this.done,
    required this.pending,
    required this.total,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: Color(0xFF22C55E)),
                const SizedBox(width: 6),
                Text('Done',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    )),
                const SizedBox(width: 4),
                Text('$done',
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    )),
              ]),
            ),
            Expanded(
              child: Row(children: [
                const Icon(Icons.radio_button_unchecked,
                    size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text('Pending',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    )),
                const SizedBox(width: 4),
                Text('$pending',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    )),
              ]),
            ),
            Text('$done / $total',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: primary,
                )),
          ]),
          const SizedBox(height: 8),
          // Per-question dot row — quick visual scan of what's done.
          LayoutBuilder(builder: (ctx, c) {
            final maxW = c.maxWidth;
            const minDot = 8.0;
            const gap = 4.0;
            final dotW = total == 0
                ? minDot
                : math.max(minDot,
                    math.min(14.0, (maxW - gap * (total - 1)) / total));
            return Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Container(
                    width: dotW,
                    height: dotW,
                    decoration: BoxDecoration(
                      color: i < done
                          ? const Color(0xFF22C55E)
                          : Colors.black.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(dotW / 2),
                    ),
                  ),
                ],
              ],
            );
          }),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 3,
              backgroundColor: primary.withOpacity(0.10),
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  const _BigStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            )),
        Text(label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            )),
      ],
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _DifficultyTile({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(children: [
        Text('$count',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            )),
      ]),
    );
  }
}

class _FactPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _FactPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: ThemeColors.brandIndigo),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5)),
              Text(value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Session result with a real score ring, performance-tier message, and
/// the headline stats. Replaces the generic green-check screen — the ring
/// color + headline change based on actual accuracy, so the user gets a
/// different feel for "nailed it" vs "needs work".
class _Done extends StatefulWidget {
  final int correct;
  final int total;
  final VoidCallback onClose;
  const _Done({
    required this.correct,
    required this.total,
    required this.onClose,
  });

  @override
  State<_Done> createState() => _DoneState();
}

class _DoneState extends State<_Done> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ({Color color, String headline, IconData icon, String sub}) _tier() {
    final pct = widget.total == 0
        ? 0.0
        : widget.correct / widget.total;
    if (pct >= 0.90) {
      return (
        color: const Color(0xFF22C55E),
        icon: Icons.workspace_premium_rounded,
        headline: 'Outstanding',
        sub: "You crushed it. Keep this rhythm going.",
      );
    }
    if (pct >= 0.75) {
      return (
        color: const Color(0xFF3B82F6),
        icon: Icons.auto_awesome_rounded,
        headline: 'Strong session',
        sub: "Solid run — you're getting comfortable here.",
      );
    }
    if (pct >= 0.55) {
      return (
        color: const Color(0xFFF59E0B),
        icon: Icons.trending_up_rounded,
        headline: 'On your way',
        sub: "Coming together — a couple more passes and it sticks.",
      );
    }
    return (
      color: const Color(0xFFEF4444),
      icon: Icons.restart_alt_rounded,
      headline: "Keep at it",
      sub: "Tomorrow's a fresh shot — review the misses first.",
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tier = _tier();
    final pct = widget.total == 0 ? 0.0 : widget.correct / widget.total;
    final wrong = widget.total - widget.correct;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            const Spacer(),
            // Animated score ring.
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                return SizedBox(
                  width: 200,
                  height: 200,
                  child: CustomPaint(
                    painter: _ScoreRingPainter(
                      progress: pct * _anim.value,
                      color: tier.color,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tier.icon, size: 30, color: tier.color),
                          const SizedBox(height: 4),
                          Text(
                            '${(pct * 100 * _anim.value).round()}%',
                            style: TextStyle(
                              color: tier.color,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            '${widget.correct} of ${widget.total}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            Text(tier.headline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(tier.sub,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  )),
            ),
            const SizedBox(height: 24),
            // 3 stat tiles.
            Row(children: [
              Expanded(
                child: _DoneStat(
                  label: 'Correct',
                  value: '${widget.correct}',
                  color: const Color(0xFF22C55E),
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DoneStat(
                  label: 'Missed',
                  value: '$wrong',
                  color: const Color(0xFFEF4444),
                  icon: Icons.cancel_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DoneStat(
                  label: 'Points',
                  value: '+${5 + widget.correct * 5}',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.bolt_rounded,
                ),
              ),
            ]),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: widget.onClose,
                style: FilledButton.styleFrom(
                  backgroundColor: tier.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                  elevation: 0,
                ),
                child: const Text('Back to plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  _ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 10;
    final track = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, track);
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withOpacity(0.55), color],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}

class _DoneStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _DoneStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            )),
      ]),
    );
  }
}
