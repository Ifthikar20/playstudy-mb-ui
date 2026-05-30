import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../data/models/learning_models.dart';

class QuizView extends StatefulWidget {
  final List<QuizQuestion> questions;
  const QuizView({super.key, required this.questions});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _revealed = false;
  bool _done = false;

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
    } else {
      setState(() => _done = true);
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact progress strip with a chip pill on the right.
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                    value: (_index + 1) / total, minHeight: 3),
              ),
            ),
            const SizedBox(width: 10),
            Text('${_index + 1}/$total',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
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
          // Answers — Expanded so they always fit, scrollable if a prompt
          // happens to have unusually long choices.
          Expanded(
            child: ListView.separated(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _q.choices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final isCorrect = i == _q.correctIndex;
                final isPicked = i == _selected;
                Color? bg;
                Color border = theme.dividerColor;
                if (_revealed) {
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
                    onTap: () => _choose(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            String.fromCharCode(65 + i),
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _q.choices[i],
                            style: theme.textTheme.bodyMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_revealed && isCorrect)
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                        if (_revealed && isPicked && !isCorrect)
                          const Icon(Icons.cancel,
                              color: Colors.red, size: 18),
                      ]),
                    ),
                  ),
                );
              },
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
