import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/rewards/rewards_bloc.dart';
import '../../learning/data/models/learning_models.dart';

/// Guess the Word — a flame-powered minigame.
/// Flame renders an animated stage with the revealed letters; Flutter renders
/// the keyboard / controls on top.
class GuessWordWidget extends StatefulWidget {
  final List<WordChallenge> challenges;
  const GuessWordWidget({super.key, required this.challenges});

  @override
  State<GuessWordWidget> createState() => _GuessWordWidgetState();
}

class _GuessWordWidgetState extends State<GuessWordWidget> {
  late _GuessWordEngine _engine;
  int _round = 0;
  int _score = 0;
  int _mistakes = 0;
  Set<String> _guessed = {};
  bool _won = false;
  bool _lost = false;
  static const _maxMistakes = 6;

  @override
  void initState() {
    super.initState();
    _engine = _GuessWordEngine(word: _current.word);
  }

  WordChallenge get _current => widget.challenges[_round];

  bool get _solved => _current.word
      .split('')
      .where((c) => c != ' ')
      .every((c) => _guessed.contains(c));

  void _guessLetter(String letter) {
    if (_won || _lost) return;
    if (_guessed.contains(letter)) return;
    setState(() {
      _guessed = {..._guessed, letter};
      if (!_current.word.contains(letter)) {
        _mistakes++;
      }
      _engine.updateReveal(_current.word, _guessed);
      if (_solved) {
        _won = true;
        _score++;
        _engine.celebrate();
        context.read<RewardsBloc>().add(RecordActivity(
              points: 15 - _mistakes * 2,
              reason: 'Guessed a word',
              context: {'mistakes': _mistakes},
            ));
      } else if (_mistakes >= _maxMistakes) {
        _lost = true;
        _engine.revealAll(_current.word);
      }
    });
  }

  void _nextRound() {
    if (_round + 1 >= widget.challenges.length) {
      _showFinal();
      return;
    }
    setState(() {
      _round++;
      _guessed = {};
      _mistakes = 0;
      _won = false;
      _lost = false;
      _engine.reset(_current.word);
    });
  }

  void _restart() {
    setState(() {
      _round = 0;
      _score = 0;
      _guessed = {};
      _mistakes = 0;
      _won = false;
      _lost = false;
      _engine.reset(_current.word);
    });
  }

  void _showFinal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('All done! 🎉'),
        content: Text('You guessed $_score / ${widget.challenges.length} words.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restart();
            },
            child: const Text('Play again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.challenges.isEmpty) {
      return const Center(child: Text('No words to guess yet.'));
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Round ${_round + 1} of ${widget.challenges.length}',
                  style: theme.textTheme.bodySmall),
              Text('Score: $_score',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.lightbulb_outline,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_current.clue,
                      style: theme.textTheme.bodyLarge),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: GameWidget(game: _engine),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MistakeMeter(mistakes: _mistakes, max: _maxMistakes),
          const SizedBox(height: 12),
          if (_won)
            _RoundBanner(
              color: Colors.green,
              icon: Icons.check_circle,
              text: 'Correct! The word is "${_current.word}".',
              onContinue: _nextRound,
              continueLabel: _round + 1 < widget.challenges.length
                  ? 'Next word'
                  : 'See results',
            )
          else if (_lost)
            _RoundBanner(
              color: Colors.red,
              icon: Icons.sentiment_dissatisfied,
              text: 'Out of guesses. The word was "${_current.word}".',
              onContinue: _nextRound,
              continueLabel: _round + 1 < widget.challenges.length
                  ? 'Next word'
                  : 'See results',
            )
          else
            _Keyboard(guessed: _guessed, word: _current.word, onTap: _guessLetter),
        ],
      ),
    );
  }
}

class _MistakeMeter extends StatelessWidget {
  final int mistakes;
  final int max;
  const _MistakeMeter({required this.mistakes, required this.max});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(max, (i) {
        final used = i < mistakes;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(
            used ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: used ? Colors.red : Theme.of(context).colorScheme.outline,
          ),
        );
      }),
    );
  }
}

class _RoundBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final VoidCallback onContinue;
  final String continueLabel;
  const _RoundBanner({
    required this.color,
    required this.icon,
    required this.text,
    required this.onContinue,
    required this.continueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onContinue, child: Text(continueLabel)),
        ),
      ],
    );
  }
}

class _Keyboard extends StatelessWidget {
  final Set<String> guessed;
  final String word;
  final ValueChanged<String> onTap;
  const _Keyboard({required this.guessed, required this.word, required this.onTap});

  static const _rows = [
    'QWERTYUIOP',
    'ASDFGHJKL',
    'ZXCVBNM',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.split('').map((c) {
              final used = guessed.contains(c);
              final hit = used && word.contains(c);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(
                  width: 30,
                  height: 38,
                  child: Material(
                    color: hit
                        ? theme.colorScheme.primary
                        : used
                            ? theme.colorScheme.surface
                            : theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: used && !hit
                            ? theme.colorScheme.error
                            : theme.dividerColor,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: used ? null : () => onTap(c),
                      child: Center(
                        child: Text(
                          c,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: hit
                                ? Colors.white
                                : used
                                    ? theme.colorScheme.onSurface.withOpacity(0.4)
                                    : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

/// Flame engine that renders the revealed-letters strip.
class _GuessWordEngine extends FlameGame {
  String _word;
  final List<_LetterTile> _tiles = [];
  late _ConfettiBurst _confetti;

  _GuessWordEngine({required String word}) : _word = word;

  @override
  Color backgroundColor() => const Color(0xFFF5F5F5);

  @override
  Future<void> onLoad() async {
    _confetti = _ConfettiBurst();
    add(_confetti);
    _buildTiles();
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    _layoutTiles();
  }

  void reset(String word) {
    _word = word;
    for (final t in _tiles) {
      t.removeFromParent();
    }
    _tiles.clear();
    _buildTiles();
  }

  void updateReveal(String word, Set<String> guessed) {
    for (var i = 0; i < _tiles.length; i++) {
      final ch = word[i];
      final reveal = ch == ' ' || guessed.contains(ch);
      _tiles[i].setRevealed(reveal ? ch : null);
    }
  }

  void revealAll(String word) {
    for (var i = 0; i < _tiles.length; i++) {
      _tiles[i].setRevealed(word[i]);
    }
  }

  void celebrate() => _confetti.burst();

  void _buildTiles() {
    for (var i = 0; i < _word.length; i++) {
      final ch = _word[i];
      final tile = _LetterTile(letter: ch, revealed: ch == ' ' ? ch : null);
      _tiles.add(tile);
      add(tile);
    }
    if (size.x > 0) _layoutTiles();
  }

  void _layoutTiles() {
    if (_tiles.isEmpty || size.x == 0) return;
    final n = _tiles.length;
    final maxTile = 44.0;
    final gap = 6.0;
    final available = size.x - 32;
    final tileSize = ((available - gap * (n - 1)) / n).clamp(20.0, maxTile);
    final totalWidth = tileSize * n + gap * (n - 1);
    final startX = (size.x - totalWidth) / 2;
    final y = size.y / 2 - tileSize / 2;
    for (var i = 0; i < n; i++) {
      _tiles[i].size = Vector2.all(tileSize);
      _tiles[i].position = Vector2(startX + i * (tileSize + gap), y);
    }
  }
}

class _LetterTile extends PositionComponent {
  String letter;
  String? revealed;
  late TextComponent _text;

  _LetterTile({required this.letter, this.revealed});

  @override
  Future<void> onLoad() async {
    _text = TextComponent(
      text: revealed ?? '',
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF000000),
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    add(_text);
  }

  void setRevealed(String? ch) {
    revealed = ch;
    _text.text = ch ?? '';
  }

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final isSpace = letter == ' ';
    final isShown = revealed != null;
    final bg = Paint()
      ..color = isShown
          ? const Color(0xFFE7F0FF)
          : isSpace
              ? Colors.transparent
              : const Color(0xFFFFFFFF);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = isShown ? const Color(0xFF007AFF) : const Color(0xFFE5E7EB);
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    if (!isSpace) {
      canvas.drawRRect(r, bg);
      canvas.drawRRect(r, border);
    }
    // Underline for unrevealed letters
    if (!isSpace && !isShown) {
      final underline = Paint()
        ..color = const Color(0xFF6B7280)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(8, size.y - 6),
        Offset(size.x - 8, size.y - 6),
        underline,
      );
    }
    _text.position = Vector2(size.x / 2, size.y / 2);
  }
}

/// Tiny celebration burst — dots floating up briefly when the word is guessed.
class _ConfettiBurst extends Component {
  final List<_Particle> _particles = [];

  void burst() {
    final game = findGame();
    if (game == null) return;
    final cx = game.size.x / 2;
    final cy = game.size.y / 2;
    for (var i = 0; i < 24; i++) {
      _particles.add(_Particle(
        position: Vector2(cx, cy),
        velocity: Vector2(
          (i.isEven ? 1 : -1) * (40 + (i * 7) % 80).toDouble(),
          -120 - (i * 5 % 60).toDouble(),
        ),
      ));
    }
  }

  @override
  void update(double dt) {
    for (final p in _particles) {
      p.update(dt);
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  @override
  void render(Canvas canvas) {
    for (final p in _particles) {
      final paint = Paint()..color = p.color.withOpacity(p.life.clamp(0, 1));
      canvas.drawCircle(p.position.toOffset(), 4, paint);
    }
  }
}

class _Particle {
  Vector2 position;
  Vector2 velocity;
  double life = 1.0;
  final Color color;

  _Particle({required this.position, required this.velocity})
      : color = [
          const Color(0xFF007AFF),
          const Color(0xFF5856D6),
          const Color(0xFF22C55E),
          const Color(0xFFEF4444),
        ][(position.x.toInt() + velocity.y.toInt()) % 4];

  void update(double dt) {
    position += velocity * dt;
    velocity.y += 220 * dt; // gravity
    life -= dt * 0.9;
  }
}
