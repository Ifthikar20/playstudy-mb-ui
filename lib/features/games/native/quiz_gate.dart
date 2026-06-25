import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/rewards/rewards_bloc.dart';
import '../../learning/data/models/learning_models.dart';

/// Result of a gated quiz question shown mid-game.
typedef QuizResult = void Function(bool correct);

/// A reusable, native (no WebView) quiz overlay. Games call [ask] to pause and
/// pose a question from the study set; advancement is gated on a correct
/// answer. A correct answer fires a rewards event automatically.
class QuizGate {
  final BuildContext context;
  final List<QuizQuestion> quiz;
  int _cursor = 0;

  QuizGate(this.context, this.quiz);

  bool get hasQuestions => quiz.isNotEmpty;

  /// How many distinct questions exist.
  int get total => quiz.length;

  QuizQuestion _nextQuestion() {
    // Round-robin so the player sees variety instead of the same item.
    final q = quiz[_cursor % quiz.length];
    _cursor++;
    return q;
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
