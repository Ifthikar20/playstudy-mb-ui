import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../learning/data/models/learning_models.dart';
import '../data/game_score_scope.dart';
import 'quiz_gate.dart';

/// Native (no WebView) Flappy-style game. Tap to flap through the gaps; on a
/// crash you answer a study-set question to revive. Advancement past
/// checkpoints is gated on a correct answer.
class FlappyNativeWidget extends StatefulWidget {
  final List<QuizQuestion> quiz;
  const FlappyNativeWidget({super.key, required this.quiz});

  @override
  State<FlappyNativeWidget> createState() => _FlappyNativeWidgetState();
}

class _FlappyNativeWidgetState extends State<FlappyNativeWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late QuizGate _gate;

  // World units are pixels; tuned for portrait phones.
  static const double gravity = 1500;
  static const double flap = -460;
  static const double speed = 165;
  static const double gap = 200;
  static const double pipeW = 70;
  static const double pipeEvery = 1.6;
  static const double groundH = 90;

  Size _size = Size.zero;
  Duration _last = Duration.zero;

  // State machine: ready | play | over (quiz handled by dialog).
  String _state = 'ready';
  late _Bird _bird;
  final List<_Pipe> _pipes = [];
  final List<_Particle> _particles = [];
  double _spawnT = 0;
  double _invuln = 0;
  int _score = 0;
  int _best = 0;
  int _revives = 0;
  int _nextQuizAt = 3;
  bool _busy = false; // a quiz dialog is open

  @override
  void initState() {
    super.initState();
    _gate = QuizGate(context, widget.quiz);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _reset() {
    final s = _size;
    _bird = _Bird(x: s.width * 0.28, y: s.height * 0.4);
    _pipes.clear();
    _particles.clear();
    _spawnT = 0;
    _invuln = 0;
    _score = 0;
    _revives = 0;
    _nextQuizAt = 3;
    _state = 'ready';
  }

  void _onTick(Duration now) {
    if (_size == Size.zero) return;
    final dt = _last == Duration.zero
        ? 0.0
        : math.min(0.033, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _update(dt);
    if (mounted) setState(() {});
  }

  void _flap() {
    if (_busy) return;
    if (_state == 'ready') _state = 'play';
    if (_state == 'play') {
      _bird.vy = flap;
      for (var i = 0; i < 4; i++) {
        _particles.add(_Particle(
          x: _bird.x - 8,
          y: _bird.y + 6,
          vx: -60 - math.Random().nextDouble() * 60,
          vy: 20 - math.Random().nextDouble() * 40,
          life: 0.4,
          color: Colors.white,
        ));
      }
    } else if (_state == 'over') {
      _reset();
    }
  }

  void _spawnPipe() {
    final s = _size;
    const margin = 60.0;
    final top = margin +
        math.Random().nextDouble() *
            (s.height - groundH - gap - margin * 2);
    _pipes.add(_Pipe(x: s.width + pipeW, top: top));
  }

  void _update(double dt) {
    // Particles + invuln always tick.
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) _particles.removeAt(i);
    }
    if (_state != 'play' || _busy) return;
    if (_invuln > 0) _invuln -= dt;

    _bird.vy += gravity * dt;
    _bird.y += _bird.vy * dt;
    _bird.rot = (_bird.vy / 600).clamp(-0.5, 1.2);

    _spawnT += dt;
    if (_spawnT >= pipeEvery) {
      _spawnT = 0;
      _spawnPipe();
    }

    final s = _size;
    for (var i = _pipes.length - 1; i >= 0; i--) {
      final p = _pipes[i];
      p.x -= speed * dt;
      if (!p.passed && p.x + pipeW < _bird.x) {
        p.passed = true;
        _score++;
        GameScoreScope.report(context, _score);
        if (_gate.hasQuestions && _score >= _nextQuizAt) {
          _nextQuizAt = _score + 3;
          _askPlayQuestion();
          return;
        }
      }
      if (p.x + pipeW < -10) _pipes.removeAt(i);
      if (_invuln <= 0 && _hits(p)) {
        _onCrash();
        return;
      }
    }

    if (_bird.y + _bird.r > s.height - groundH) {
      _bird.y = s.height - groundH - _bird.r;
      _onCrash();
      return;
    }
    if (_bird.y - _bird.r < 0) {
      _bird.y = _bird.r;
      _bird.vy = 0;
    }
  }

  bool _hits(_Pipe p) {
    final r = _bird.r * 0.85;
    if (_bird.x + r < p.x || _bird.x - r > p.x + pipeW) return false;
    return (_bird.y - r < p.top) || (_bird.y + r > p.top + gap);
  }

  Future<void> _askPlayQuestion() async {
    _busy = true;
    final ok = await _gate.ask(
      title: 'Quick question',
      subtitle: 'Correct = bonus points + a shield',
    );
    if (!mounted) return;
    if (ok) {
      _score += 2;
      GameScoreScope.report(context, _score);
      _invuln = 1.6;
    }
    _bird.y = _size.height * 0.4;
    _bird.vy = 0;
    _busy = false;
  }

  Future<void> _onCrash() async {
    for (var i = 0; i < 16; i++) {
      _particles.add(_Particle(
        x: _bird.x,
        y: _bird.y,
        vx: (math.Random().nextDouble() - 0.5) * 320,
        vy: (math.Random().nextDouble() - 0.5) * 320,
        life: 0.6,
        color: const Color(0xFFFFCF33),
      ));
    }
    if (_gate.hasQuestions && _revives < 3) {
      _revives++;
      _busy = true;
      final ok = await _gate.ask(
        title: 'Answer to revive',
        subtitle: 'Get it right to keep flying',
      );
      if (!mounted) return;
      if (ok) {
        _pipes.removeWhere(
            (p) => p.x > _bird.x - 120 && p.x < _bird.x + 160);
        _bird.y = _size.height * 0.4;
        _bird.vy = 0;
        _invuln = 1.8;
        _state = 'play';
      } else {
        _gameOver();
      }
      _busy = false;
    } else {
      _gameOver();
    }
  }

  void _gameOver() {
    _state = 'over';
    _best = math.max(_best, _score);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final newSize = Size(constraints.maxWidth, constraints.maxHeight);
      if (_size == Size.zero && newSize != Size.zero) {
        _size = newSize;
        _reset();
      } else {
        _size = newSize;
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _flap(),
        child: Stack(children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _FlappyPainter(
                bird: _bird,
                pipes: _pipes,
                particles: _particles,
                score: _score,
                state: _state,
                best: _best,
                invuln: _invuln,
              ),
            ),
          ),
          // HUD
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(children: [
              GameHudChip(
                  icon: Icons.star_rounded,
                  label: '$_score',
                  color: const Color(0xFFFFD23F)),
              const Spacer(),
              GameHudChip(
                  icon: Icons.favorite,
                  label: '${3 - _revives}',
                  color: const Color(0xFFFF5A6E)),
            ]),
          ),
          if (_state == 'over')
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Game over',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Score $_score  ·  Best $_best',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _flap,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Play again'),
                    ),
                  ],
                ),
              ),
            ),
        ]),
      );
    });
  }
}

class _Bird {
  double x, y, vy = 0, rot = 0;
  final double r = 16;
  _Bird({required this.x, required this.y});
}

class _Pipe {
  double x;
  final double top;
  bool passed = false;
  _Pipe({required this.x, required this.top});
}

class _Particle {
  double x, y, vx, vy, life;
  final Color color;
  _Particle(
      {required this.x,
      required this.y,
      required this.vx,
      required this.vy,
      required this.life,
      required this.color});
}

class _FlappyPainter extends CustomPainter {
  final _Bird bird;
  final List<_Pipe> pipes;
  final List<_Particle> particles;
  final int score;
  final int best;
  final String state;
  final double invuln;

  _FlappyPainter({
    required this.bird,
    required this.pipes,
    required this.particles,
    required this.score,
    required this.best,
    required this.state,
    required this.invuln,
  });

  static const double groundH = 90;
  static const double pipeW = 70;
  static const double gap = 200;

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    // Sky.
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4EC0F7), Color(0xFF9BD9FB), Color(0xFFBFE9FF)],
        stops: [0, 0.7, 1],
      ).createShader(Rect.fromLTWH(0, 0, W, H));
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), sky);

    final horizon = H - groundH;
    // Distant skyline.
    final city = Paint()..color = const Color(0x73789CC8);
    for (var bx = 0.0; bx < W + 60; bx += 60) {
      final bh = 60 + (math.sin(bx * 0.7).abs()) * 90;
      canvas.drawRect(Rect.fromLTWH(bx - 30, horizon - bh, 46, bh), city);
    }

    // Pipes.
    for (final p in pipes) {
      final pg = Paint()
        ..shader = const LinearGradient(
                colors: [Color(0xFF2FAE5E), Color(0xFF52D784)])
            .createShader(Rect.fromLTWH(p.x, 0, pipeW, H));
      _rr(canvas, Rect.fromLTWH(p.x, 0, pipeW, p.top), 8, pg);
      _rr(
          canvas,
          Rect.fromLTWH(
              p.x, p.top + gap, pipeW, horizon - (p.top + gap)),
          8,
          pg);
    }

    // Ground.
    canvas.drawRect(
        Rect.fromLTWH(0, horizon, W, groundH), Paint()..color = const Color(0xFFDED39A));
    canvas.drawRect(Rect.fromLTWH(0, horizon, W, 10),
        Paint()..color = const Color(0xFFC9BD80));

    // Particles.
    for (final pt in particles) {
      final paint = Paint()
        ..color = pt.color.withOpacity((pt.life * 1.6).clamp(0, 1));
      canvas.drawRect(Rect.fromLTWH(pt.x, pt.y, 4, 4), paint);
    }

    // Bird.
    canvas.save();
    canvas.translate(bird.x, bird.y);
    canvas.rotate(bird.rot);
    final birdPaint = Paint()
      ..color = const Color(0xFFFFCE3A)
          .withOpacity(invuln > 0 ? (0.55 + 0.45 * math.sin(score * 1.0)) : 1);
    canvas.drawCircle(Offset.zero, bird.r, birdPaint);
    // Eye.
    canvas.drawCircle(const Offset(7, -5), 5, Paint()..color = Colors.white);
    canvas.drawCircle(
        const Offset(9, -5), 2.2, Paint()..color = const Color(0xFF222222));
    // Beak.
    final beak = Path()
      ..moveTo(14, 0)
      ..lineTo(24, 3)
      ..lineTo(14, 6)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFFF7B00));
    canvas.restore();

    // Score (big).
    _text(canvas, '$score', Offset(W / 2, 54), 44, FontWeight.w800,
        Colors.white, center: true);

    if (state == 'ready') {
      _text(canvas, 'Tap to flap', Offset(W / 2, H * 0.6), 20,
          FontWeight.w600, Colors.black54,
          center: true);
    }
  }

  void _rr(Canvas c, Rect r, double radius, Paint p) {
    c.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius)), p);
  }

  void _text(Canvas c, String s, Offset at, double size, FontWeight w,
      Color color,
      {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontSize: size, fontWeight: w, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? at.dx - tp.width / 2 : at.dx;
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _FlappyPainter old) => true;
}
