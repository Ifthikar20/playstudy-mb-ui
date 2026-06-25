import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../learning/data/models/learning_models.dart';
import '../data/game_score_scope.dart';
import 'quiz_gate.dart';

/// Native (no WebView) space shooter. Drag to move, auto-fire. Clear a wave of
/// invaders, then answer a study-set question to advance to the next wave.
class ShooterNativeWidget extends StatefulWidget {
  final List<QuizQuestion> quiz;
  const ShooterNativeWidget({super.key, required this.quiz});

  @override
  State<ShooterNativeWidget> createState() => _ShooterNativeWidgetState();
}

class _ShooterNativeWidgetState extends State<ShooterNativeWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late QuizGate _gate;
  final _rng = math.Random();

  Size _size = Size.zero;
  Duration _last = Duration.zero;

  String _state = 'play'; // play | over
  bool _busy = false;

  late _Ship _ship;
  final List<_Bullet> _bullets = [];
  final List<_Enemy> _enemies = [];
  final List<_EBullet> _eBullets = [];
  final List<_Particle> _particles = [];
  final List<_Star> _stars = [];

  int _wave = 1;
  int _score = 0;
  int _lives = 3;
  double _fireT = 0;
  double _enemyFireT = 0;

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

  void _start() {
    final s = _size;
    _ship = _Ship(x: s.width / 2, y: s.height - 90);
    _bullets.clear();
    _enemies.clear();
    _eBullets.clear();
    _particles.clear();
    _stars
      ..clear()
      ..addAll(List.generate(
          60,
          (_) => _Star(
                x: _rng.nextDouble() * s.width,
                y: _rng.nextDouble() * s.height,
                z: 0.3 + _rng.nextDouble(),
              )));
    _wave = 1;
    _score = 0;
    _lives = 3;
    _state = 'play';
    _spawnWave();
  }

  void _spawnWave() {
    final s = _size;
    final cols = math.min(3 + _wave, 7);
    const rows = 3;
    final spacing = s.width / (cols + 1);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        _enemies.add(_Enemy(
          x: spacing * (c + 1),
          y: 90 + r * 56.0,
          hp: 1 + (_wave ~/ 3),
        ));
      }
    }
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

  void _update(double dt) {
    // Stars drift.
    for (final st in _stars) {
      st.y += (30 * st.z) * dt;
      if (st.y > _size.height) {
        st.y = 0;
        st.x = _rng.nextDouble() * _size.width;
      }
    }
    // Particles.
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) _particles.removeAt(i);
    }
    if (_state != 'play' || _busy) return;

    // Auto-fire.
    _fireT += dt;
    if (_fireT >= 0.22) {
      _fireT = 0;
      _bullets.add(_Bullet(x: _ship.x, y: _ship.y - 22));
    }

    // Player bullets.
    for (var i = _bullets.length - 1; i >= 0; i--) {
      final b = _bullets[i];
      b.y -= 560 * dt;
      if (b.y < -10) {
        _bullets.removeAt(i);
        continue;
      }
      for (var j = _enemies.length - 1; j >= 0; j--) {
        final e = _enemies[j];
        if ((b.x - e.x).abs() < 20 && (b.y - e.y).abs() < 18) {
          _bullets.removeAt(i);
          e.hp--;
          if (e.hp <= 0) {
            _score += 10;
            GameScoreScope.report(context, _score);
            _boom(e.x, e.y, const Color(0xFF8FE3B6));
            _enemies.removeAt(j);
          }
          break;
        }
      }
    }

    // Enemy movement (drift sideways + descend slowly).
    var hitEdge = false;
    for (final e in _enemies) {
      e.x += e.dir * 36 * dt;
      if (e.x < 24 || e.x > _size.width - 24) hitEdge = true;
    }
    if (hitEdge) {
      for (final e in _enemies) {
        e.dir *= -1;
        e.y += 16;
      }
    }

    // Enemy fire.
    _enemyFireT += dt;
    if (_enemyFireT >= 0.9 && _enemies.isNotEmpty) {
      _enemyFireT = 0;
      final shooter = _enemies[_rng.nextInt(_enemies.length)];
      _eBullets.add(_EBullet(x: shooter.x, y: shooter.y + 18));
    }
    for (var i = _eBullets.length - 1; i >= 0; i--) {
      final b = _eBullets[i];
      b.y += 300 * dt;
      if (b.y > _size.height + 10) {
        _eBullets.removeAt(i);
        continue;
      }
      if ((b.x - _ship.x).abs() < 18 && (b.y - _ship.y).abs() < 18) {
        _eBullets.removeAt(i);
        _hitShip();
      }
    }

    // Enemy reaches the ship line.
    for (final e in _enemies) {
      if (e.y > _ship.y - 30) {
        _hitShip();
        e.y = 90;
        break;
      }
    }

    // Wave cleared -> quiz gate.
    if (_enemies.isEmpty) {
      _advanceWave();
    }
  }

  void _hitShip() {
    _lives--;
    _boom(_ship.x, _ship.y, const Color(0xFFFF5A6E));
    if (_lives <= 0) {
      _state = 'over';
    }
  }

  void _boom(double x, double y, Color c) {
    for (var i = 0; i < 14; i++) {
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: (_rng.nextDouble() - 0.5) * 260,
        vy: (_rng.nextDouble() - 0.5) * 260,
        life: 0.5,
        color: c,
      ));
    }
  }

  Future<void> _advanceWave() async {
    if (_busy) return;
    _busy = true;
    final ok = await _gate.ask(
      title: 'Wave ${_wave} cleared!',
      subtitle: 'Answer correctly to launch the next wave',
    );
    if (!mounted) return;
    if (ok) {
      _wave++;
      _eBullets.clear();
      _spawnWave();
    } else {
      // Wrong answer: lose a life; if still alive, replay same wave.
      _lives--;
      if (_lives <= 0) {
        _state = 'over';
      } else {
        _spawnWave();
      }
    }
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final newSize = Size(constraints.maxWidth, constraints.maxHeight);
      if (_size == Size.zero && newSize != Size.zero) {
        _size = newSize;
        _start();
      } else {
        _size = newSize;
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          if (_state != 'play' || _busy) return;
          _ship.x = (_ship.x + d.delta.dx).clamp(24.0, _size.width - 24);
          _ship.y =
              (_ship.y + d.delta.dy).clamp(_size.height * 0.5, _size.height - 40);
        },
        onTapDown: (d) {
          if (_state == 'over') {
            _start();
          } else if (_state == 'play' && !_busy) {
            _ship.x = d.localPosition.dx.clamp(24.0, _size.width - 24);
          }
        },
        child: Stack(children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ShooterPainter(
                ship: _ship,
                bullets: _bullets,
                enemies: _enemies,
                eBullets: _eBullets,
                particles: _particles,
                stars: _stars,
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(children: [
              GameHudChip(
                  icon: Icons.layers_rounded,
                  label: 'Wave $_wave',
                  color: const Color(0xFFC4C0F5)),
              const SizedBox(width: 8),
              GameHudChip(
                  icon: Icons.star_rounded,
                  label: '$_score',
                  color: const Color(0xFFFFD23F)),
              const Spacer(),
              GameHudChip(
                  icon: Icons.favorite_rounded,
                  label: '$_lives',
                  color: const Color(0xFFFF5A6E)),
            ]),
          ),
          if (_state == 'over')
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
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
                    Text('Reached wave $_wave  ·  Score $_score',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Play again'),
                    ),
                  ],
                ),
              ),
            ),
          if (_state == 'play')
            const Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Text('Drag to move · auto-fire',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
        ]),
      );
    });
  }
}

class _Ship {
  double x, y;
  _Ship({required this.x, required this.y});
}

class _Bullet {
  double x, y;
  _Bullet({required this.x, required this.y});
}

class _EBullet {
  double x, y;
  _EBullet({required this.x, required this.y});
}

class _Enemy {
  double x, y;
  int hp;
  double dir = 1;
  _Enemy({required this.x, required this.y, required this.hp});
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

class _Star {
  double x, y, z;
  _Star({required this.x, required this.y, required this.z});
}

class _ShooterPainter extends CustomPainter {
  final _Ship ship;
  final List<_Bullet> bullets;
  final List<_Enemy> enemies;
  final List<_EBullet> eBullets;
  final List<_Particle> particles;
  final List<_Star> stars;

  _ShooterPainter({
    required this.ship,
    required this.bullets,
    required this.enemies,
    required this.eBullets,
    required this.particles,
    required this.stars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    // Space background.
    canvas.drawRect(
        Rect.fromLTWH(0, 0, W, H),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F1B2E), Color(0xFF0E0E14)],
          ).createShader(Rect.fromLTWH(0, 0, W, H)));
    // Stars.
    for (final st in stars) {
      canvas.drawCircle(Offset(st.x, st.y), st.z * 1.4,
          Paint()..color = Colors.white.withOpacity(0.25 + 0.5 * st.z / 1.3));
    }
    // Enemy bullets.
    for (final b in eBullets) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(b.x, b.y), width: 4, height: 12),
              const Radius.circular(2)),
          Paint()..color = const Color(0xFFFF6B6E));
    }
    // Player bullets.
    for (final b in bullets) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(b.x, b.y), width: 4, height: 14),
              const Radius.circular(2)),
          Paint()..color = const Color(0xFFD6F26C));
    }
    // Enemies.
    for (final e in enemies) {
      _enemy(canvas, e.x, e.y);
    }
    // Particles.
    for (final p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), 3,
          Paint()..color = p.color.withOpacity((p.life * 2).clamp(0, 1)));
    }
    // Ship.
    _ship(canvas, ship.x, ship.y);
  }

  void _enemy(Canvas c, double x, double y) {
    final body = Paint()..color = const Color(0xFF8FE3B6);
    final path = Path()
      ..moveTo(x, y - 14)
      ..lineTo(x + 16, y + 10)
      ..lineTo(x, y + 4)
      ..lineTo(x - 16, y + 10)
      ..close();
    c.drawPath(path, body);
    c.drawCircle(Offset(x, y), 4, Paint()..color = const Color(0xFF1F1B2E));
  }

  void _ship(Canvas c, double x, double y) {
    final p = Paint()..color = const Color(0xFF9D8DFA);
    final path = Path()
      ..moveTo(x, y - 22)
      ..lineTo(x + 16, y + 16)
      ..lineTo(x, y + 8)
      ..lineTo(x - 16, y + 16)
      ..close();
    c.drawPath(path, p);
    // Engine glow.
    c.drawCircle(Offset(x, y + 14), 5,
        Paint()..color = const Color(0xFFFBC78A).withOpacity(0.9));
  }

  @override
  bool shouldRepaint(covariant _ShooterPainter old) => true;
}
