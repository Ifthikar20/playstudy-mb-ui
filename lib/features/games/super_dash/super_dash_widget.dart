import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/games/game_stage.dart';
import '../../../core/rewards/rewards_bloc.dart';
import '../../learning/data/models/learning_models.dart';
import '../data/game_score_scope.dart';
import 'super_dash_engine.dart';

/// Super Dash: Pip the pup runs across rolling hills through changing biomes.
/// Tap to jump (double-jump supported). Every so often — paced by *distance*,
/// not a timer — Pip reaches a quiz checkpoint and the run pauses for a
/// question. Answer right to keep all your lives; wrong costs a life.
class SuperDashWidget extends StatefulWidget {
  final List<QuizQuestion> questions;
  const SuperDashWidget({super.key, required this.questions});

  @override
  State<SuperDashWidget> createState() => _SuperDashWidgetState();
}

class _SuperDashWidgetState extends State<SuperDashWidget>
    with SingleTickerProviderStateMixin {
  late final SuperDashWorld _world;
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  bool _started = false;

  bool _showingQuiz = false;
  bool _showingGameOver = false;
  QuizQuestion? _activeQuestion;
  int _correct = 0;

  @override
  void initState() {
    super.initState();
    _world = SuperDashWorld(
      onCheckpoint: _handleCheckpoint,
      onGameOver: _handleGameOver,
      onMeters: (_) {},
    );
    // createTicker honours TickerMode, so the run freezes when the full-screen
    // game is closed (paused) and resumes when reopened.
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!_started) {
      _started = true;
      _last = elapsed;
      return;
    }
    final double dt =
        ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble();
    _last = elapsed;
    _world.update(dt);
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _handleCheckpoint() {
    if (widget.questions.isEmpty) {
      _world.resume();
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
      _correct++;
      GameScoreScope.report(context, _correct);
      context.read<RewardsBloc>().add(
          const RecordActivity(points: 5, reason: 'Super Dash checkpoint'));
    } else {
      _world.loseLife();
    }
    setState(() {
      _showingQuiz = false;
      _activeQuestion = null;
    });
    if (!_world.over) _world.resume();
  }

  void _handleGameOver() {
    setState(() => _showingGameOver = true);
    // Lives ran out — reopening starts a fresh game.
    GameStageScope.maybeOf(context)?.markFinished();
  }

  void _restart() {
    setState(() {
      _showingGameOver = false;
      _correct = 0;
    });
    _world.restart();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _world.size = Size(constraints.maxWidth, constraints.maxHeight);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _world.jump,
              child: CustomPaint(
                painter: SuperDashPainter(_world, repaint: _frame),
                size: Size.infinite,
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: AnimatedBuilder(
              animation: _frame,
              builder: (_, __) => _Hud(
                meters: _world.metersInt,
                lives: _world.lives,
                biome: _world.biomeName,
                checkpoints: _world.checkpointsReached,
              ),
            ),
          ),
          if (_showingQuiz && _activeQuestion != null)
            _CheckpointQuizOverlay(
              question: _activeQuestion!,
              onAnswered: _answerCheckpoint,
            ),
          if (_showingGameOver)
            _GameOverOverlay(
              meters: _world.metersInt,
              correct: _correct,
              biome: _world.biomeName,
              onRestart: _restart,
            ),
        ],
      );
    });
  }
}

class _Hud extends StatelessWidget {
  final int meters;
  final int lives;
  final String biome;
  final int checkpoints;
  const _Hud({
    required this.meters,
    required this.lives,
    required this.biome,
    required this.checkpoints,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Pill(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.directions_run_rounded,
                size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text('${meters}m',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
        ),
        _Pill(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.terrain_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(biome,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
        ),
        _Pill(
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    i < lives ? Icons.favorite_rounded : Icons.favorite_border,
                    size: 16,
                    color: i < lives
                        ? const Color(0xFFEF4444)
                        : Colors.white54,
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
        color: Colors.black.withOpacity(0.42),
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
    // Absorb stray taps so they don't reach the jump handler behind us.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2BB673),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(question.topic,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.flag_rounded,
                      color: Color(0xFF2BB673), size: 18),
                  const SizedBox(width: 4),
                  const Text('Checkpoint',
                      style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 16),
                Text(question.prompt,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 16),
                ...List.generate(question.choices.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => onAnswered(i),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1A1A1A),
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
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final int meters;
  final int correct;
  final String biome;
  final VoidCallback onRestart;
  const _GameOverOverlay({
    required this.meters,
    required this.correct,
    required this.biome,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
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
                const Icon(Icons.directions_run_rounded,
                    size: 44, color: Color(0xFF1A1A1A)),
                const SizedBox(height: 12),
                const Text('Run over',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 8),
                Text('${meters}m  •  reached $biome',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text('$correct checkpoint${correct == 1 ? '' : 's'} cleared',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRestart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Play again'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
