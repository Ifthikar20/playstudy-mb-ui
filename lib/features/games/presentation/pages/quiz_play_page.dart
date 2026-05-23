import 'package:flutter/material.dart';
import '../../data/models/game_models.dart';

/// Plays a multiple-choice quiz built from a study note.
class QuizPlayPage extends StatefulWidget {
  final Game game;
  const QuizPlayPage({super.key, required this.game});

  @override
  State<QuizPlayPage> createState() => _QuizPlayPageState();
}

class _QuizPlayPageState extends State<QuizPlayPage> {
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _revealed = false;

  GameQuestion get _q => widget.game.questions[_index];

  void _choose(int i) {
    if (_revealed) return;
    setState(() {
      _selected = i;
      _revealed = true;
      if (i == _q.correctIndex) _score++;
    });
  }

  void _next() {
    if (_index + 1 < widget.game.questions.length) {
      setState(() {
        _index++;
        _selected = null;
        _revealed = false;
      });
    } else {
      _showResult();
    }
  }

  void _showResult() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nice work! 🎉'),
        content: Text('You scored $_score / ${widget.game.questions.length}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.game.questions.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: (_index + 1) / total),
            const SizedBox(height: 24),
            Text('Question ${_index + 1} of $total',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(_q.prompt, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            ...List.generate(_q.choices.length, (i) {
              final isCorrect = i == _q.correctIndex;
              final isPicked = i == _selected;
              Color? bg;
              if (_revealed) {
                if (isCorrect) bg = Colors.green.withOpacity(0.15);
                else if (isPicked) bg = Colors.red.withOpacity(0.15);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: bg ?? Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _choose(i),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(child: Text(_q.choices[i],
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
      ),
    );
  }
}
