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
                        colors: [Color(0xFFF59E0B), Color(0xFFFF6B35)]),
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: (_index + 1) / total),
          const SizedBox(height: 20),
          Text('Question ${_index + 1} of $total',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(_q.prompt, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          ...List.generate(_q.choices.length, (i) {
            final isCorrect = i == _q.correctIndex;
            final isPicked = i == _selected;
            Color? bg;
            if (_revealed) {
              if (isCorrect) bg = Colors.green.withOpacity(0.12);
              else if (isPicked) bg = Colors.red.withOpacity(0.12);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: bg ?? Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _choose(i),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                          child: Text(_q.choices[i],
                              style: Theme.of(context).textTheme.bodyLarge)),
                      if (_revealed && isCorrect)
                        const Icon(Icons.check_circle, color: Colors.green),
                      if (_revealed && isPicked && !isCorrect)
                        const Icon(Icons.cancel, color: Colors.red),
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
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ElevatedButton(
            onPressed: _revealed ? _next : null,
            child: Text(_index + 1 == total ? 'Finish' : 'Next'),
          ),
        ],
      ),
    );
  }
}
