import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/rewards/rewards_bloc.dart';
import '../../learning/data/models/learning_models.dart';
import 'mascot.dart';

/// Result of a gated quiz question shown mid-game.
typedef QuizResult = void Function(bool correct);

/// A reusable, native (no WebView) quiz overlay. Games call [ask] to pause and
/// pose a question from the study set; advancement is gated on a correct
/// answer. A correct answer fires a rewards event automatically.
class QuizGate {
  final BuildContext context;
  final List<QuizQuestion> quiz;
  int _cursor = 0;
  int _lastIndex = 0;

  // Per-run stats, surfaced on the end-of-run stat screen.
  int asked = 0; // questions posed this run
  int correctCount = 0; // answered correctly this run
  final Set<int> _mastered = {}; // distinct question indices answered right

  QuizGate(this.context, this.quiz);

  bool get hasQuestions => quiz.isNotEmpty;

  /// How many distinct questions exist.
  int get total => quiz.length;

  /// Distinct questions answered correctly this run.
  int get masteredCount => _mastered.length;

  /// 0..1 progress toward "perfection" — mastering every question in the set.
  double get mastery => total == 0 ? 1.0 : masteredCount / total;

  /// Clear per-run stats. Games call this when (re)starting a run.
  void resetStats() {
    asked = 0;
    correctCount = 0;
    _mastered.clear();
    _cursor = 0;
  }

  QuizQuestion _nextQuestion() {
    // Round-robin so the player sees variety instead of the same item.
    _lastIndex = _cursor % quiz.length;
    _cursor++;
    return quiz[_lastIndex];
  }

  /// Show a blocking question dialog. Resolves to true if answered correctly.
  Future<bool> ask({
    String title = 'Answer to continue',
    String subtitle = 'Get it right to keep going',
    bool dismissibleOnWrong = true,
  }) async {
    if (!hasQuestions) return true;
    final q = _nextQuestion();
    final correct = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => _QuizDialog(
            question: q,
            title: title,
            subtitle: subtitle,
          ),
        ) ??
        false;
    asked++;
    if (correct) {
      correctCount++;
      _mastered.add(_lastIndex);
    }
    if (correct && context.mounted) {
      context
          .read<RewardsBloc>()
          .add(const RecordActivity(points: 5, reason: 'Game checkpoint'));
    }
    return correct;
  }
}

class _QuizDialog extends StatefulWidget {
  final QuizQuestion question;
  final String title;
  final String subtitle;
  const _QuizDialog({
    required this.question,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog> {
  int? _picked;
  bool _revealed = false;

  void _choose(int i) {
    if (_revealed) return;
    setState(() {
      _picked = i;
      _revealed = true;
    });
    final correct = i == widget.question.correctIndex;
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) Navigator.of(context).pop(correct);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = widget.question;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.quiz_rounded,
                  size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(widget.subtitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            Text(q.prompt,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 14),
            ...List.generate(q.choices.length, (i) {
              final isCorrect = i == q.correctIndex;
              final isPicked = i == _picked;
              Color border = theme.dividerColor;
              Color? bg;
              if (_revealed) {
                if (isCorrect) {
                  border = Colors.green;
                  bg = Colors.green.withOpacity(0.12);
                } else if (isPicked) {
                  border = Colors.red;
                  bg = Colors.red.withOpacity(0.10);
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: bg ?? theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _choose(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      child: Row(children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                theme.colorScheme.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(String.fromCharCode(65 + i),
                              style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(q.choices[i],
                                style: theme.textTheme.bodyMedium)),
                        if (_revealed && isCorrect)
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.green, size: 18),
                        if (_revealed && isPicked && !isCorrect)
                          const Icon(Icons.cancel_rounded,
                              color: Colors.red, size: 18),
                      ]),
                    ),
                  ),
                ),
              );
            }),
            if (_revealed &&
                _picked != q.correctIndex &&
                (q.explanation ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Why: ${q.explanation}',
                    style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small HUD chip used by the native games (score, lives, etc.).
class GameHudChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const GameHudChip(
      {super.key,
      required this.icon,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      ]),
    );
  }
}

/// Polished, animated end-of-run stat screen shared by the native games. Shows
/// the points earned, how many questions were answered (correct / posed) and a
/// "perfection" ring — how much of the study set you've mastered this run, the
/// distance from completing the quiz. It springs in and counts up for juice.
class GameStatScreen extends StatelessWidget {
  final String title; // e.g. 'Game over'
  final int score;
  final int best;
  final int answered; // questions posed this run
  final int correct; // answered correctly
  final int mastered; // distinct questions mastered
  final int totalQuestions;
  final String? extraLabel; // e.g. 'Reached wave 4' / '🦴 5 bones'
  final VoidCallback onPlayAgain;

  const GameStatScreen({
    super.key,
    required this.title,
    required this.score,
    required this.best,
    required this.answered,
    required this.correct,
    required this.mastered,
    required this.totalQuestions,
    required this.onPlayAgain,
    this.extraLabel,
  });

  @override
  Widget build(BuildContext context) {
    final perfect = totalQuestions > 0 && mastered >= totalQuestions;
    final frac =
        totalQuestions == 0 ? 0.0 : (mastered / totalQuestions).clamp(0.0, 1.0);
    // Absorb taps so a stray tap on the game behind doesn't instantly restart —
    // the run stats stay up until the player hits "Play again".
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: Colors.black.withOpacity(0.62),
        alignment: Alignment.center,
        child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, t, child) => Transform.scale(
          scale: 0.82 + 0.18 * t.clamp(0.0, 1.0),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        ),
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2B2D52), Color(0xFF16172B)],
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 12)),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CustomPaint(painter: _MascotBadgePainter(happy: perfect)),
              ),
              const SizedBox(height: 6),
              Text(perfect ? 'Perfect run!' : title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0.0, end: frac),
                builder: (context, v, _) => SizedBox(
                  width: 128,
                  height: 128,
                  child: Stack(alignment: Alignment.center, children: [
                    CustomPaint(
                        size: const Size(128, 128),
                        painter: _RingPainter(v)),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${(v * 100).round()}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900)),
                      const Text('to perfection',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                  totalQuestions == 0
                      ? 'No quiz on this set'
                      : perfect
                          ? 'You mastered all $totalQuestions questions 🎉'
                          : 'Mastered $mastered / $totalQuestions questions',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _stat('Points', '$score', Icons.star_rounded,
                    const Color(0xFFFFD23F)),
                _stat('Correct', '$correct/$answered',
                    Icons.check_circle_rounded, const Color(0xFF5BD6A6)),
                _stat('Best', '$best', Icons.emoji_events_rounded,
                    const Color(0xFFFFB24D)),
              ]),
              if (extraLabel != null) ...[
                const SizedBox(height: 10),
                Text(extraLabel!,
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPlayAgain,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Play again'),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  _RingPainter(this.frac);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 9;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..color = Colors.white.withOpacity(0.12));
    final sweep = 2 * math.pi * frac.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [Color(0xFF5BD6A6), Color(0xFFFFD23F), Color(0xFF5BD6A6)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), -math.pi / 2, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.frac != frac;
}

class _MascotBadgePainter extends CustomPainter {
  final bool happy;
  _MascotBadgePainter({required this.happy});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
        c, size.width * 0.46, Paint()..color = Mascot.orange.withOpacity(0.16));
    Mascot.head(canvas, c, size.width * 0.30, earFlap: happy ? 0.6 : 0.0);
  }

  @override
  bool shouldRepaint(covariant _MascotBadgePainter old) => old.happy != happy;
}
