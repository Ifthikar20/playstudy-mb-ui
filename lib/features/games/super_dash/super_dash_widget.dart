import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/rewards/rewards_bloc.dart';
import '../../learning/data/models/learning_models.dart';
import 'super_dash_engine.dart';

/// Super Dash with quiz checkpoints. Tap anywhere to jump. Every 30m the
/// player hits a checkpoint flag → the game pauses and a quiz question
/// overlay appears. Answer correctly to continue, wrong = lose a life.
class SuperDashWidget extends StatefulWidget {
  final List<QuizQuestion> questions;
  const SuperDashWidget({super.key, required this.questions});

  @override
  State<SuperDashWidget> createState() => _SuperDashWidgetState();
}

class _SuperDashWidgetState extends State<SuperDashWidget> {
  late SuperDashEngine _engine;
  int _meters = 0;
  bool _showingQuiz = false;
  bool _showingGameOver = false;
  QuizQuestion? _activeQuestion;
  int _correctAtCheckpoint = 0;

  @override
  void initState() {
    super.initState();
    _engine = SuperDashEngine(
      onCheckpoint: _handleCheckpoint,
      onGameOver: _handleGameOver,
      onMetersChanged: (m) => setState(() => _meters = m),
    );
  }

  void _handleCheckpoint() {
    if (widget.questions.isEmpty) {
      _engine.resume();
      return;
    }
    final q = widget.questions[Random().nextInt(widget.questions.length)];
    setState(() {
      _activeQuestion = q;
      _showingQuiz = true;
    });
  }

  void _answerCheckpoint(int index) {
    final q = _activeQuestion!;
    final correct = index == q.correctIndex;
    if (correct) {
      _correctAtCheckpoint++;
      context.read<RewardsBloc>().add(
          const RecordActivity(points: 5, reason: 'Super Dash checkpoint'));
    }
    if (!correct) _engine.loseLife();
    setState(() {
      _showingQuiz = false;
      _activeQuestion = null;
    });
    _engine.resume();
  }

  void _handleGameOver() {
    setState(() => _showingGameOver = true);
  }

  void _restart() {
    setState(() {
      _showingGameOver = false;
      _correctAtCheckpoint = 0;
    });
    _engine.restart();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _engine.jump,
            child: GameWidget(game: _engine),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _HUD(
            meters: _meters,
            lives: _engine.lives,
            checkpoints: _engine.checkpointsReached,
          ),
        ),
        if (_showingQuiz && _activeQuestion != null)
          _CheckpointQuizOverlay(
            question: _activeQuestion!,
            onAnswered: _answerCheckpoint,
          ),
        if (_showingGameOver)
          _GameOverOverlay(
            meters: _meters,
            correct: _correctAtCheckpoint,
            onRestart: _restart,
          ),
      ],
    );
  }
}

class _HUD extends StatelessWidget {
  final int meters;
  final int lives;
  final int checkpoints;
  const _HUD({
    required this.meters,
    required this.lives,
    required this.checkpoints,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Pill(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.directions_run, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text('${meters}m',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
        _Pill(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.flag, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text('$checkpoints',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
        _Pill(
          child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                i < lives ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: i < lives ? const Color(0xFFEF4444) : Colors.white54,
              ),
            );
          })),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _CheckpointQuizOverlay extends StatelessWidget {
  final QuizQuestion question;
  final ValueChanged<int> onAnswered;
  const _CheckpointQuizOverlay({
    required this.question,
    required this.onAnswered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5856D6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(question.topic,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.flag, color: Color(0xFF5856D6), size: 18),
                const SizedBox(width: 4),
                const Text('Checkpoint',
                    style: TextStyle(
                        color: Color(0xFF5856D6),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 16),
              Text(question.prompt,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ...List.generate(question.choices.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => onAnswered(i),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(question.choices[i]),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              const Text('Wrong answer = -1 life',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final int meters;
  final int correct;
  final VoidCallback onRestart;
  const _GameOverOverlay({
    required this.meters,
    required this.correct,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💥', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              const Text('Game over',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${meters}m  •  $correct correct answers',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRestart,
                  child: const Text('Play again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
