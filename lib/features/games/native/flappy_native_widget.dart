import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../learning/data/models/learning_models.dart';
import '../data/game_score_scope.dart';
import 'mascot.dart';
import 'quiz_gate.dart';

/// Native (no WebView) Flappy-style game starring **Pip**, the PlayStudy
/// mascot, who rides on the back of a flappy bird. Tap to flap through the
/// gaps, snag bones for bonus points, and survive moving pipes and buzzing
/// bees. On a crash you answer a study-set question to revive; advancement
/// past checkpoints is gated on a correct answer.
///
/// The world cycles through day → sunset → night → dawn biomes the further you
/// fly, and the route gets meaner: gaps narrow, pipes start swaying, doubles
/// appear and everything speeds up.
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
  final _rng = math.Random();

  // World units are pixels; tuned for portrait phones.
  static const double gravity = 1500;
  static const double flap = -460;
  static const double baseSpeed = 165;
  static const double baseGap = 205;
  static const double pipeW = 70;
  static const double basePipeEvery = 1.6;
  static const double groundH = 90;
  static const double margin = 56;
  static const double biomeLen = 2200; // px of travel per biome.

  Size _size = Size.zero;
  Duration _last = Duration.zero;
  double _t = 0; // accumulating seconds, drives all animation.
  double _dist = 0; // total px travelled, drives biome changes.

  // State machine: ready | play | over (quiz handled by dialog).
  String _state = 'ready';
  late _Bird _bird;
  final List<_Pipe> _pipes = [];
  final List<_Bone> _bones = [];
  final List<_Bee> _bees = [];
  final List<_Particle> _particles = [];
  final List<_Cloud> _clouds = [];
  final List<_BgBird> _bgBirds = [];
  double _spawnT = 0;
  double _beeT = 0;
  double _bgBirdT = 0;
  double _invuln = 0;
  int _score = 0;
  int _bonesEaten = 0;
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

  // ---- Difficulty curves: the route gets harder as the score climbs. -------
  double get _speed => (baseSpeed + _score * 3.0).clamp(baseSpeed, 330.0);
  double get _gap => (baseGap - _score * 2.4).clamp(150.0, baseGap);
  double get _pipeEvery => (basePipeEvery - _score * 0.02).clamp(1.12, basePipeEvery);

  void _reset() {
    final s = _size;
    _bird = _Bird(x: s.width * 0.30, y: s.height * 0.42);
    _pipes.clear();
    _bones.clear();
    _bees.clear();
    _particles.clear();
    _spawnT = 0;
    _beeT = 0;
    _invuln = 0;
    _score = 0;
    _bonesEaten = 0;
    _revives = 0;
    _nextQuizAt = 3;
    _dist = 0;
    _seedDecor();
    _state = 'ready';
  }

  void _seedDecor() {
    final s = _size;
    _clouds
      ..clear()
      ..addAll(List.generate(7, (i) {
        final layer = i % 3; // 0 = far, 2 = near
        return _Cloud(
          x: _rng.nextDouble() * s.width,
          y: 40 + _rng.nextDouble() * (s.height * 0.55),
          scale: 0.6 + layer * 0.35 + _rng.nextDouble() * 0.2,
          layer: layer,
        );
      }));
    _bgBirds.clear();
  }

  void _onTick(Duration now) {
    if (_size == Size.zero) return;
    final dt = _last == Duration.zero
        ? 0.0
        : math.min(0.033, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _t += dt;
    _update(dt);
    if (mounted) setState(() {});
  }

  void _flap() {
    if (_busy) return;
    if (_state == 'ready') _state = 'play';
    if (_state == 'play') {
      _bird.vy = flap;
      _bird.flapKick = 1; // makes the wings beat harder briefly.
      for (var i = 0; i < 4; i++) {
        _particles.add(_Particle(
          x: _bird.x - 14,
          y: _bird.y + 10,
          vx: -60 - _rng.nextDouble() * 60,
          vy: 20 - _rng.nextDouble() * 40,
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
    final gap = _gap;
    final span = s.height - groundH - gap - margin * 2;
    final baseTop = margin + _rng.nextDouble() * math.max(40.0, span);

    // Pipes start swaying once you're warmed up; amplitude grows with score.
    double amp = 0;
    if (_score >= 6) {
      final maxAmp = (12 + _score * 1.6).clamp(0, 70).toDouble();
      // Keep the swaying pipe fully on-screen.
      final headroom = math.min(baseTop - margin, span - (baseTop - margin));
      amp = math.min(maxAmp, math.max(0.0, headroom));
      if (_rng.nextDouble() < 0.45) amp = 0; // not every pipe moves.
    }

    final p = _Pipe(
      x: s.width + pipeW,
      baseTop: baseTop,
      gap: gap,
      moveAmp: amp,
      moveSpeed: 1.4 + _rng.nextDouble() * 1.2,
      phase: _rng.nextDouble() * math.pi * 2,
    );
    _pipes.add(p);

    // A bone sometimes floats in the gap as a tasty bonus.
    if (_rng.nextDouble() < 0.6) {
      _bones.add(_Bone(x: p.x + pipeW * 0.5, y: baseTop + gap * 0.5));
    }

    // Tough clusters: a second staggered pipe close behind at higher scores.
    if (_score >= 10 && _rng.nextDouble() < 0.3) {
      final t2 = (margin + _rng.nextDouble() * math.max(40.0, span));
      _pipes.add(_Pipe(
        x: s.width + pipeW + gap + 90,
        baseTop: t2,
        gap: gap + 6,
        moveAmp: 0,
        moveSpeed: 1,
        phase: 0,
      ));
    }
  }

  double _pipeTop(_Pipe p) {
    if (p.moveAmp == 0) return p.baseTop;
    return p.baseTop + math.sin(_t * p.moveSpeed + p.phase) * p.moveAmp;
  }

  void _update(double dt) {
    // Decor + particles drift even on the menu so the scene feels alive.
    final driftScale = _state == 'play' ? 1.0 : 0.35;
    for (final c in _clouds) {
      c.x -= (8 + c.layer * 12) * driftScale * dt + _speed * 0.04 * c.layer * dt * driftScale;
      if (c.x < -90) {
        c.x = _size.width + 80;
        c.y = 40 + _rng.nextDouble() * (_size.height * 0.55);
      }
    }
    for (var i = _bgBirds.length - 1; i >= 0; i--) {
      final b = _bgBirds[i];
      b.x -= b.speed * dt;
      b.phase += dt * 8;
      if (b.x < -40) _bgBirds.removeAt(i);
    }
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) _particles.removeAt(i);
    }
    _bird.flapKick = math.max(0.0, _bird.flapKick - dt * 2.2);

    // Occasionally send a little V of distant birds across the sky.
    _bgBirdT += dt;
    if (_bgBirdT > 4 + _rng.nextDouble() * 4) {
      _bgBirdT = 0;
      final y = 60 + _rng.nextDouble() * (_size.height * 0.35);
      _bgBirds.add(_BgBird(x: _size.width + 30, y: y, speed: 40 + _rng.nextDouble() * 30));
    }

    if (_state != 'play' || _busy) {
      // Gentle idle bob on the menu.
      if (_state == 'ready') {
        _bird.y = _size.height * 0.42 + math.sin(_t * 2) * 10;
        _bird.rot = math.sin(_t * 2) * 0.06;
      }
      return;
    }
    if (_invuln > 0) _invuln -= dt;
    _dist += _speed * dt;

    _bird.vy += gravity * dt;
    _bird.y += _bird.vy * dt;
    _bird.rot = (_bird.vy / 620).clamp(-0.5, 1.2);

    _spawnT += dt;
    if (_spawnT >= _pipeEvery) {
      _spawnT = 0;
      _spawnPipe();
    }

    final s = _size;
    final horizon = s.height - groundH;

    // Bones: drift with the world, collect on overlap.
    for (var i = _bones.length - 1; i >= 0; i--) {
      final b = _bones[i];
      b.x -= _speed * dt;
      b.phase += dt * 4;
      if (b.x < -30) {
        _bones.removeAt(i);
        continue;
      }
      if (!b.taken &&
          (b.x - _bird.x).abs() < 30 &&
          (b.y + math.sin(b.phase) * 6 - _bird.y).abs() < 30) {
        b.taken = true;
        _bones.removeAt(i);
        _bonesEaten++;
        _score += 2;
        GameScoreScope.report(context, _score);
        for (var k = 0; k < 8; k++) {
          _particles.add(_Particle(
            x: b.x,
            y: b.y,
            vx: (_rng.nextDouble() - 0.5) * 220,
            vy: (_rng.nextDouble() - 0.5) * 220,
            life: 0.5,
            color: const Color(0xFFFFE08A),
          ));
        }
      }
    }

    // Pipes.
    for (var i = _pipes.length - 1; i >= 0; i--) {
      final p = _pipes[i];
      p.x -= _speed * dt;
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

    // Bees: a buzzing hazard that weaves in once things heat up.
    _beeT += dt;
    if (_score >= 12 && _beeT > 3.2 && _bees.length < 2) {
      _beeT = 0;
      _bees.add(_Bee(
        x: s.width + 30,
        y: margin + _rng.nextDouble() * (horizon - margin * 2),
        phase: _rng.nextDouble() * math.pi,
      ));
    }
    for (var i = _bees.length - 1; i >= 0; i--) {
      final b = _bees[i];
      b.x -= (_speed * 0.7 + 40) * dt;
      b.phase += dt * 6;
      b.y += math.sin(b.phase) * 50 * dt;
      if (b.x < -30) {
        _bees.removeAt(i);
        continue;
      }
      if (_invuln <= 0 &&
          (b.x - _bird.x).abs() < 24 &&
          (b.y - _bird.y).abs() < 22) {
        _onCrash();
        return;
      }
    }

    if (_bird.y + _bird.r > horizon) {
      _bird.y = horizon - _bird.r;
      _onCrash();
      return;
    }
    if (_bird.y - _bird.r < 0) {
      _bird.y = _bird.r;
      _bird.vy = 0;
    }
  }

  bool _hits(_Pipe p) {
    final r = _bird.r * 0.82;
    final top = _pipeTop(p);
    if (_bird.x + r < p.x || _bird.x - r > p.x + pipeW) return false;
    return (_bird.y - r < top) || (_bird.y + r > top + p.gap);
  }

  Future<void> _askPlayQuestion() async {
    _busy = true;
    final ok = await _gate.ask(
      title: 'Quick question',
      subtitle: 'Correct = bonus points + a shield for Pip',
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
        vx: (_rng.nextDouble() - 0.5) * 320,
        vy: (_rng.nextDouble() - 0.5) * 320,
        life: 0.6,
        color: const Color(0xFFFFCF33),
      ));
    }
    if (_gate.hasQuestions && _revives < 3) {
      _revives++;
      _busy = true;
      final ok = await _gate.ask(
        title: 'Answer to revive Pip',
        subtitle: 'Get it right to keep flying',
      );
      if (!mounted) return;
      if (ok) {
        _pipes.removeWhere((p) => p.x > _bird.x - 120 && p.x < _bird.x + 160);
        _bees.clear();
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

  // Biome blended from travel distance for smooth day↔night transitions.
  _Biome get _biome {
    final f = _dist / biomeLen;
    final i = f.floor();
    final frac = Curves.easeInOut.transform((f - i).clamp(0.0, 1.0));
    final a = _kBiomes[i % _kBiomes.length];
    final b = _kBiomes[(i + 1) % _kBiomes.length];
    return _Biome.lerp(a, b, frac);
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
                bones: _bones,
                bees: _bees,
                particles: _particles,
                clouds: _clouds,
                bgBirds: _bgBirds,
                biome: _biome,
                score: _score,
                state: _state,
                invuln: _invuln,
                t: _t,
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
              const SizedBox(width: 8),
              GameHudChip(
                  icon: Icons.pets_rounded,
                  label: '$_bonesEaten',
                  color: const Color(0xFFFFB24D)),
              const Spacer(),
              GameHudChip(
                  icon: Icons.favorite_rounded,
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
                    Text('Score $_score  ·  Best $_best  ·  🦴 $_bonesEaten',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _flap,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Fly again'),
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
  double x, y, vy = 0, rot = 0, flapKick = 0;
  final double r = 19;
  _Bird({required this.x, required this.y});
}

class _Pipe {
  double x;
  final double baseTop;
  final double gap;
  final double moveAmp;
  final double moveSpeed;
  final double phase;
  bool passed = false;
  _Pipe({
    required this.x,
    required this.baseTop,
    required this.gap,
    required this.moveAmp,
    required this.moveSpeed,
    required this.phase,
  });
}

class _Bone {
  double x, y, phase = 0;
  bool taken = false;
  _Bone({required this.x, required this.y});
}

class _Bee {
  double x, y, phase;
  _Bee({required this.x, required this.y, required this.phase});
}

class _Cloud {
  double x, y, scale;
  final int layer;
  _Cloud({required this.x, required this.y, required this.scale, required this.layer});
}

class _BgBird {
  double x, y, speed, phase = 0;
  _BgBird({required this.x, required this.y, required this.speed});
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

/// A blendable sky/ground theme. `night` is a 0..1 amount so we can cross-fade
/// stars, the sun and the moon smoothly between biomes.
class _Biome {
  final Color skyTop, skyMid, skyLow;
  final Color ground, groundTop, city;
  final Color pipe, pipeDark;
  final double night;
  const _Biome({
    required this.skyTop,
    required this.skyMid,
    required this.skyLow,
    required this.ground,
    required this.groundTop,
    required this.city,
    required this.pipe,
    required this.pipeDark,
    required this.night,
  });

  static Color _l(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  static _Biome lerp(_Biome a, _Biome b, double t) => _Biome(
        skyTop: _l(a.skyTop, b.skyTop, t),
        skyMid: _l(a.skyMid, b.skyMid, t),
        skyLow: _l(a.skyLow, b.skyLow, t),
        ground: _l(a.ground, b.ground, t),
        groundTop: _l(a.groundTop, b.groundTop, t),
        city: _l(a.city, b.city, t),
        pipe: _l(a.pipe, b.pipe, t),
        pipeDark: _l(a.pipeDark, b.pipeDark, t),
        night: a.night + (b.night - a.night) * t,
      );
}

const List<_Biome> _kBiomes = [
  // Day
  _Biome(
    skyTop: Color(0xFF4EC0F7),
    skyMid: Color(0xFF9BD9FB),
    skyLow: Color(0xFFBFE9FF),
    ground: Color(0xFF8FCB6B),
    groundTop: Color(0xFF6FB24E),
    city: Color(0x73789CC8),
    pipe: Color(0xFF52D784),
    pipeDark: Color(0xFF2FAE5E),
    night: 0,
  ),
  // Sunset
  _Biome(
    skyTop: Color(0xFFFF8E6E),
    skyMid: Color(0xFFFFC28A),
    skyLow: Color(0xFFFFE3B0),
    ground: Color(0xFFB98A5E),
    groundTop: Color(0xFF9C6E45),
    city: Color(0x73583B6E),
    pipe: Color(0xFFE39B5A),
    pipeDark: Color(0xFFB9743A),
    night: 0.15,
  ),
  // Night
  _Biome(
    skyTop: Color(0xFF161A36),
    skyMid: Color(0xFF273063),
    skyLow: Color(0xFF3A3F77),
    ground: Color(0xFF2C2F4A),
    groundTop: Color(0xFF3D4166),
    city: Color(0x661A2150),
    pipe: Color(0xFF5C6BC0),
    pipeDark: Color(0xFF3949AB),
    night: 1,
  ),
  // Dawn
  _Biome(
    skyTop: Color(0xFF7B6CCB),
    skyMid: Color(0xFFC9A2D8),
    skyLow: Color(0xFFFFD2C2),
    ground: Color(0xFF8E9B6B),
    groundTop: Color(0xFF73824E),
    city: Color(0x73544A8C),
    pipe: Color(0xFF8FC77E),
    pipeDark: Color(0xFF5FA055),
    night: 0.25,
  ),
];

class _FlappyPainter extends CustomPainter {
  final _Bird bird;
  final List<_Pipe> pipes;
  final List<_Bone> bones;
  final List<_Bee> bees;
  final List<_Particle> particles;
  final List<_Cloud> clouds;
  final List<_BgBird> bgBirds;
  final _Biome biome;
  final int score;
  final String state;
  final double invuln;
  final double t;

  _FlappyPainter({
    required this.bird,
    required this.pipes,
    required this.bones,
    required this.bees,
    required this.particles,
    required this.clouds,
    required this.bgBirds,
    required this.biome,
    required this.score,
    required this.state,
    required this.invuln,
    required this.t,
  });

  static const double groundH = 90;
  static const double pipeW = 70;

  double _pipeTop(_Pipe p) => p.moveAmp == 0
      ? p.baseTop
      : p.baseTop + math.sin(t * p.moveSpeed + p.phase) * p.moveAmp;

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    final horizon = H - groundH;

    // Sky.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, W, H),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [biome.skyTop, biome.skyMid, biome.skyLow],
          stops: const [0, 0.6, 1],
        ).createShader(Rect.fromLTWH(0, 0, W, H)),
    );

    // Sun / moon cross-fade.
    final celestial = Offset(W * 0.78, H * 0.20);
    if (biome.night < 0.85) {
      canvas.drawCircle(celestial, 34,
          Paint()..color = const Color(0xFFFFF1B0).withOpacity((1 - biome.night).clamp(0.0, 1.0) * 0.95));
      canvas.drawCircle(celestial, 50,
          Paint()..color = const Color(0xFFFFF1B0).withOpacity((1 - biome.night).clamp(0.0, 1.0) * 0.20));
    }
    if (biome.night > 0.15) {
      final moonO = biome.night.clamp(0.0, 1.0) * 0.95;
      canvas.drawCircle(celestial, 28, Paint()..color = const Color(0xFFEFF3FF).withOpacity(moonO));
      canvas.drawCircle(Offset(celestial.dx + 10, celestial.dy - 8), 24,
          Paint()..color = biome.skyTop.withOpacity(moonO));
    }

    // Stars at night.
    if (biome.night > 0.25) {
      final sp = Paint()..color = Colors.white.withOpacity((biome.night - 0.25) * 1.1);
      for (var i = 0; i < 36; i++) {
        final sx = (i * 53.0 + (i * i) % 37) % W;
        final sy = ((i * 71.0) % (horizon - 40));
        final tw = 0.5 + 0.5 * math.sin(t * 2 + i);
        canvas.drawCircle(Offset(sx, sy), 1.0 + tw, sp);
      }
    }

    // Parallax clouds.
    for (final c in clouds) {
      _cloud(canvas, c, biome.night);
    }

    // Distant skyline.
    final city = Paint()..color = biome.city;
    for (var bx = 0.0; bx < W + 60; bx += 60) {
      final bh = 60 + (math.sin(bx * 0.7).abs()) * 90;
      canvas.drawRect(Rect.fromLTWH(bx - 30, horizon - bh, 46, bh), city);
    }

    // Distant decorative birds.
    for (final b in bgBirds) {
      final wing = math.sin(b.phase) * 5;
      final p = Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(b.x - 8, b.y)
          ..lineTo(b.x, b.y - wing)
          ..lineTo(b.x + 8, b.y),
        p,
      );
    }

    // Pipes.
    for (final p in pipes) {
      final top = _pipeTop(p);
      final pg = Paint()
        ..shader = LinearGradient(colors: [biome.pipeDark, biome.pipe])
            .createShader(Rect.fromLTWH(p.x, 0, pipeW, H));
      _rr(canvas, Rect.fromLTWH(p.x, 0, pipeW, top), 8, pg);
      // lip
      _rr(canvas, Rect.fromLTWH(p.x - 5, top - 18, pipeW + 10, 18), 6, pg);
      _rr(canvas, Rect.fromLTWH(p.x, top + p.gap, pipeW, horizon - (top + p.gap)),
          8, pg);
      _rr(canvas, Rect.fromLTWH(p.x - 5, top + p.gap, pipeW + 10, 18), 6, pg);
    }

    // Bones.
    for (final b in bones) {
      if (b.taken) continue;
      _bone(canvas, b.x, b.y + math.sin(b.phase) * 6);
    }

    // Bees.
    for (final b in bees) {
      _bee(canvas, b.x, b.y, t);
    }

    // Ground.
    canvas.drawRect(Rect.fromLTWH(0, horizon, W, groundH), Paint()..color = biome.ground);
    canvas.drawRect(Rect.fromLTWH(0, horizon, W, 10), Paint()..color = biome.groundTop);
    // little grass tufts that scroll with distance.
    final tuft = Paint()..color = biome.groundTop;
    final off = (t * 60) % 28;
    for (var gx = -off; gx < W; gx += 28) {
      canvas.drawCircle(Offset(gx, horizon + 4), 4, tuft);
    }

    // Particles.
    for (final pt in particles) {
      final paint = Paint()..color = pt.color.withOpacity((pt.life * 1.6).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(pt.x, pt.y, 4, 4), paint);
    }

    // Pip riding the bird.
    _drawSteed(canvas);

    // Score (big).
    _text(canvas, '$score', Offset(W / 2, 54), 44, FontWeight.w800, Colors.white,
        center: true, shadow: true);

    if (state == 'ready') {
      _text(canvas, 'Tap to help ${Mascot.name} fly', Offset(W / 2, H * 0.62),
          20, FontWeight.w700, Colors.white,
          center: true, shadow: true);
      _text(canvas, 'grab 🦴 bones · dodge pipes & bees', Offset(W / 2, H * 0.62 + 28),
          13, FontWeight.w600, Colors.white70,
          center: true, shadow: true);
    }
  }

  void _drawSteed(Canvas canvas) {
    final r = bird.r;
    final rising = bird.vy < 0;
    final flapFreq = rising ? 22.0 : 11.0;
    final wing = math.sin(t * flapFreq) * (0.5 + bird.flapKick * 0.5);
    final ear = math.sin(t * (rising ? 16 : 8)) * (rising ? 1.0 : 0.4);
    final blink = (math.sin(t * 0.8) > 0.97) ? 1.0 : 0.0;

    canvas.save();
    canvas.translate(bird.x, bird.y);
    canvas.rotate(bird.rot * 0.55);

    final sw = r * 0.12;
    Paint ink() => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..color = const Color(0xFF1A1A1A)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Tail.
    final tail = Path()
      ..moveTo(-r * 1.0, r * 0.1)
      ..lineTo(-r * 1.9, -r * 0.3 + wing * 6)
      ..lineTo(-r * 1.85, r * 0.5 + wing * 6)
      ..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xFF2BB3AE));
    canvas.drawPath(tail, ink());

    // Body.
    final body = Rect.fromCenter(
        center: Offset(0, r * 0.35), width: r * 2.7, height: r * 1.95);
    canvas.drawOval(body, Paint()..color = const Color(0xFF36C5C0));
    canvas.drawOval(
        Rect.fromCenter(center: Offset(r * 0.1, r * 0.6), width: r * 2.0, height: r * 1.2),
        Paint()..color = const Color(0xFFBFF3F0));
    canvas.drawOval(body, ink());

    // Far wing (behind body) + near wing (in front) flapping.
    for (final front in [false, true]) {
      canvas.save();
      canvas.translate(-r * 0.1, r * 0.2);
      canvas.rotate(wing * 0.5 - 0.2 + (front ? 0.0 : 0.15));
      final wingPath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-r * 0.4, r * 1.1, r * 0.6, r * 1.25)
        ..quadraticBezierTo(r * 0.5, r * 0.3, 0, 0)
        ..close();
      canvas.drawPath(wingPath,
          Paint()..color = front ? const Color(0xFF2BB3AE) : const Color(0xFF1E928E));
      canvas.drawPath(wingPath, ink());
      canvas.restore();
      if (!front) {
        // draw body again over the far wing so it sits behind.
        canvas.drawOval(body, Paint()..color = const Color(0xFF36C5C0));
        canvas.drawOval(
            Rect.fromCenter(center: Offset(r * 0.1, r * 0.6), width: r * 2.0, height: r * 1.2),
            Paint()..color = const Color(0xFFBFF3F0));
        canvas.drawOval(body, ink());
      }
    }

    // Bird head + beak at the front (kept small — Pip is the star).
    canvas.drawCircle(Offset(r * 1.15, r * 0.0), r * 0.55, Paint()..color = const Color(0xFF36C5C0));
    canvas.drawCircle(Offset(r * 1.15, r * 0.0), r * 0.55, ink());
    final beak = Path()
      ..moveTo(r * 1.6, -r * 0.1)
      ..lineTo(r * 2.05, r * 0.08)
      ..lineTo(r * 1.6, r * 0.28)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFFF9E2C));
    canvas.drawPath(beak, ink());
    canvas.drawCircle(Offset(r * 1.25, -r * 0.12), r * 0.12, Paint()..color = const Color(0xFF1A1A1A));

    // Pip rides on the back, leaning with the dive.
    final shield = invuln > 0;
    Mascot.rider(
      canvas,
      Offset(-r * 0.05, -r * 1.15),
      r * 0.92,
      earFlap: ear,
      blink: blink,
      tilt: bird.rot * 0.25 + math.sin(t * 2) * 0.03,
      look: 0.3,
    );

    // Shield bubble when invulnerable.
    if (shield) {
      final o = 0.35 + 0.25 * math.sin(t * 8);
      canvas.drawCircle(Offset(-r * 0.05, -r * 0.2), r * 2.4,
          Paint()..color = const Color(0xFF8FE3FF).withOpacity(o * 0.4));
      canvas.drawCircle(
          Offset(-r * 0.05, -r * 0.2),
          r * 2.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFFBFefff).withOpacity(o + 0.3));
    }

    canvas.restore();
  }

  void _cloud(Canvas canvas, _Cloud c, double night) {
    final base = Color.lerp(Colors.white, const Color(0xFFB9C2E8), night)!;
    final p = Paint()..color = base.withOpacity(0.85 - c.layer * 0.12);
    final s = c.scale;
    canvas.drawCircle(Offset(c.x, c.y), 18 * s, p);
    canvas.drawCircle(Offset(c.x + 20 * s, c.y + 4 * s), 22 * s, p);
    canvas.drawCircle(Offset(c.x + 44 * s, c.y), 16 * s, p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(c.x - 2, c.y + 2 * s, 50 * s, 16 * s),
            Radius.circular(10 * s)),
        p);
  }

  void _bone(Canvas canvas, double x, double y) {
    final p = Paint()..color = const Color(0xFFFFF3D6);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF6B5B3A);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-0.5);
    final shaft = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 6),
        const Radius.circular(3));
    canvas.drawRRect(shaft, p);
    for (final sx in [-10.0, 10.0]) {
      canvas.drawCircle(Offset(sx, -4), 4.5, p);
      canvas.drawCircle(Offset(sx, 4), 4.5, p);
    }
    canvas.drawRRect(shaft, ink);
    canvas.restore();
    // sparkle
    canvas.drawCircle(Offset(x + 10, y - 10), 1.6, Paint()..color = Colors.white);
  }

  void _bee(Canvas canvas, double x, double y, double t) {
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF2A2A2A);
    // wings
    final wo = 0.5 + 0.5 * math.sin(t * 30);
    canvas.drawOval(Rect.fromCenter(center: Offset(x - 2, y - 9), width: 10, height: 6),
        Paint()..color = Colors.white.withOpacity(0.6 * wo + 0.3));
    canvas.drawOval(Rect.fromCenter(center: Offset(x + 6, y - 9), width: 10, height: 6),
        Paint()..color = Colors.white.withOpacity(0.6 * wo + 0.3));
    // body
    final body = Rect.fromCenter(center: Offset(x, y), width: 22, height: 16);
    canvas.drawOval(body, Paint()..color = const Color(0xFFFFC83D));
    for (final sx in [-4.0, 2.0]) {
      canvas.drawRect(Rect.fromCenter(center: Offset(x + sx, y), width: 3, height: 14),
          Paint()..color = const Color(0xFF2A2A2A));
    }
    canvas.drawOval(body, ink);
    canvas.drawCircle(Offset(x + 9, y - 1), 2, Paint()..color = const Color(0xFF2A2A2A));
  }

  void _rr(Canvas c, Rect r, double radius, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p);
  }

  void _text(Canvas c, String s, Offset at, double size, FontWeight w, Color color,
      {bool center = false, bool shadow = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: size,
            fontWeight: w,
            color: color,
            shadows: shadow
                ? const [Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))]
                : null,
          )),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center ? at.dx - tp.width / 2 : at.dx;
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _FlappyPainter old) => true;
}
