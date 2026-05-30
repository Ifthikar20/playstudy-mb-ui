import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../data/models/learning_models.dart';

class QuizView extends StatefulWidget {
  final List<QuizQuestion> questions;
  /// Optional id used to persist progress so reopening the tab resumes
  /// where the user left off instead of starting over.
  final String? resumeKey;
  const QuizView({super.key, required this.questions, this.resumeKey});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _revealed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _restoreProgress();
  }

  String? get _prefsKey =>
      widget.resumeKey == null ? null : 'quiz_progress_${widget.resumeKey}';

  Future<void> _restoreProgress() async {
    final key = _prefsKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('${key}_index');
    final savedScore = prefs.getInt('${key}_score') ?? 0;
    if (saved != null && saved < widget.questions.length && mounted) {
      setState(() {
        _index = saved;
        _score = savedScore;
      });
    }
  }

  Future<void> _saveProgress() async {
    final key = _prefsKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${key}_index', _index);
    await prefs.setInt('${key}_score', _score);
  }

  Future<void> _clearProgress() async {
    final key = _prefsKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${key}_index');
    await prefs.remove('${key}_score');
  }

  QuizQuestion get _q => widget.questions[_index];

  void _choose(int i) {
    if (_revealed) return;
    setState(() {
      _selected = i;
      _revealed = true;
      if (i == _q.correctIndex) _score++;
    });
  }

  void _next() {
    if (_index + 1 < widget.questions.length) {
      setState(() {
        _index++;
        _selected = null;
        _revealed = false;
      });
      _saveProgress();
    } else {
      setState(() => _done = true);
      _clearProgress();
      context.read<RewardsBloc>().add(RecordActivity(
            points: 5 + _score * 5,
            reason: 'Finished a quiz',
            context: {'score': _score, 'total': widget.questions.length},
          ));
    }
  }

  void _restart() {
    setState(() {
      _index = 0;
      _score = 0;
      _selected = null;
      _revealed = false;
      _done = false;
    });
    _clearProgress();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Center(child: Text('No quiz questions yet.'));
    }
    if (_done) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text('Quiz complete',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text('You scored $_score / ${widget.questions.length}',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                tween: Tween(begin: 0, end: 1),
                builder: (context, t, child) =>
                    Transform.scale(scale: t, child: child),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF6B5CE7), Color(0xFF9D8DFA)]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.bolt, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text('+${5 + _score * 5} points',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _restart, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    final total = widget.questions.length;
    final answered = _revealed ? _index + 1 : _index;
    final pct = total == 0 ? 0 : ((answered / total) * 100).round();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overall quiz progress card — tells the learner exactly how far
          // through this quiz they are.
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.quiz_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('Quiz progress',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.2)),
                  const Spacer(),
                  Text('$answered / $total  ·  $pct%',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    tween: Tween(
                        begin: 0, end: total == 0 ? 0 : answered / total),
                    builder: (_, v, __) => LinearProgressIndicator(
                        value: v, minHeight: 6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Per-question header row: position + difficulty.
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Q${_index + 1}/$total',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            _DifficultyBadge(difficulty: _q.difficulty),
          ]),
          const SizedBox(height: 10),
          // Question — clamped to 4 lines so really long prompts don't push
          // the answers off-screen.
          Text(
            _q.prompt,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          // Compact answer tiles — natural height (~46px each). Wrapped in
          // a SingleChildScrollView so an unusually long set still scrolls
          // instead of overflowing, but in the common 4-option case it
          // sits comfortably without ever scrolling.
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _q.choices.length; i++) ...[
                    _AnswerTile(
                      letter: String.fromCharCode(65 + i),
                      text: _q.choices[i],
                      isCorrect: i == _q.correctIndex,
                      isPicked: i == _selected,
                      revealed: _revealed,
                      onTap: () => _choose(i),
                    ),
                    if (i != _q.choices.length - 1)
                      const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
          if (_revealed && _q.explanation != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_q.explanation!,
                  style: theme.textTheme.bodySmall),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _revealed ? _next : null,
              child: Text(_index + 1 == total ? 'Finish' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool isCorrect;
  final bool isPicked;
  final bool revealed;
  final VoidCallback onTap;
  const _AnswerTile({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.isPicked,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? bg;
    Color border = theme.dividerColor;
    if (revealed) {
      if (isCorrect) {
        bg = Colors.green.withOpacity(0.12);
        border = Colors.green;
      } else if (isPicked) {
        bg = Colors.red.withOpacity(0.10);
        border = Colors.red;
      }
    }
    return Material(
      color: bg ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(letter,
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(text,
                      style: theme.textTheme.bodyMedium, maxLines: 3),
                ),
              ),
            ),
            if (revealed && isCorrect)
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
            if (revealed && isPicked && !isCorrect)
              const Icon(Icons.cancel, color: Colors.red, size: 18),
          ]),
        ),
      ),
    );
  }
}


class _DifficultyBadge extends StatelessWidget {
  final QuizDifficulty difficulty;
  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (difficulty) {
      QuizDifficulty.easy => (const Color(0xFF22C55E), 'Easy'),
      QuizDifficulty.medium => (const Color(0xFFF59E0B), 'Medium'),
      QuizDifficulty.hard => (const Color(0xFFEF4444), 'Challenge'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.45), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
