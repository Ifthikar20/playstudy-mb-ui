import 'package:flutter/material.dart';
import '../../data/models/game_models.dart';

class FlashcardsPlayPage extends StatefulWidget {
  final Game game;
  const FlashcardsPlayPage({super.key, required this.game});

  @override
  State<FlashcardsPlayPage> createState() => _FlashcardsPlayPageState();
}

class _FlashcardsPlayPageState extends State<FlashcardsPlayPage> {
  int _index = 0;
  bool _showBack = false;

  Flashcard get _card => widget.game.flashcards[_index];

  @override
  Widget build(BuildContext context) {
    final total = widget.game.flashcards.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.game.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${_index + 1} / $total',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showBack = !_showBack),
                child: Card(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _showBack ? _card.back : _card.front,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Tap card to flip',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _index > 0
                      ? () => setState(() {
                            _index--;
                            _showBack = false;
                          })
                      : null,
                  child: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _index + 1 < total
                      ? () => setState(() {
                            _index++;
                            _showBack = false;
                          })
                      : () => Navigator.of(context).pop(),
                  child: Text(_index + 1 < total ? 'Next' : 'Done'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
