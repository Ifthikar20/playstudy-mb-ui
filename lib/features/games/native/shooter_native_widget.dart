import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../learning/data/models/learning_models.dart';
import '../data/game_score_scope.dart';
import 'mascot.dart';
import 'quiz_gate.dart';

/// Native (no WebView) space shooter starring **Pip**, the PlayStudy mascot,
/// who pilots the hero ship — not a side-kick, the star. Drag to fly, auto-fire,
/// clear waves of varied invaders (grunts, weavers, tanks, divers and the odd
/// boss), grab 🦴 power-ups, dodge asteroids, then answer a study-set question
/// to launch the next wave.
///
/// [intensity] scales the challenge so the same engine can power a relaxed
/// "Space Shooter" (1.0) and a relentless "Space Hunter" (~1.4).
class ShooterNativeWidget extends StatefulWidget {
  final List<QuizQuestion> quiz;
  final double intensity;
  const ShooterNativeWidget({
    super.key,
    required this.quiz,
    this.intensity = 1.0,
  });

  @override
  State<ShooterNativeWidget> createState() => _ShooterNativeWidgetState();
}

// Enemy kinds.
const int _kGrunt = 0;
const int _kWeaver = 1;
const int _kTank = 2;
const int _kDiver = 3;
const int _kBoss = 4;

class _ShooterNativeWidgetState extends State<ShooterNativeWidget>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late QuizGate _gate;
  final _rng = math.Random();

  Size _size = Size.zero;
  Duration _last = Duration.zero;
  double _t = 0;

  String _state = 'play'; // play | over
  bool _busy = false;

  late _Ship _ship;
  final List<_Bullet> _bullets = [];
  final List<_Enemy> _enemies = [];
  final List<_EBullet> _eBullets = [];
  final List<_Particle> _particles = [];
  final List<_Star> _stars = [];
  final List<_Power> _powers = [];
  final List<_Asteroid> _asteroids = [];
  final List<_Planet> _planets = [];

  int _wave = 1;
  int _score = 0;
  int _lives = 3;
  double _fireT = 0;
  double _enemyFireT = 0;
  double _astT = 0;
  double _rapid = 0; // rapid-fire seconds remaining
  double _shipInvuln = 0; // i-frames after a hit
  int _formDir = 1; // shared formation drift direction
  int _best = 0; // best score across runs this session
  final List<_Pop> _pops = []; // floating "+N" feedback
  double _shake = 0; // screen-shake amount, decays each tick

  double get _intensity => widget.intensity;

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
    _ship = _Ship(x: s.width / 2, y: s.height - 96);
    _bullets.clear();
    _enemies.clear();
    _eBullets.clear();
    _particles.clear();
    _powers.clear();
    _asteroids.clear();
    _stars
      ..clear()
      ..addAll(List.generate(
          70,
          (_) => _Star(
                x: _rng.nextDouble() * s.width,
                y: _rng.nextDouble() * s.height,
                z: 0.3 + _rng.nextDouble(),
              )));
    _planets
      ..clear()
      ..addAll(List.generate(2, (i) => _newPlanet(seedTop: true)));
    _wave = 1;
    _score = 0;
    _lives = 3;
    _rapid = 0;
    _shipInvuln = 0;
    _pops.clear();
    _shake = 0;
    _gate.resetStats();
    _state = 'play';
    _spawnWave();
  }

  void _pop(double x, double y, String text, Color color) {
    _pops.add(_Pop(x: x, y: y, text: text, color: color));
  }

  void _endRun() {
    _best = math.max(_best, _score);
    _state = 'over';
  }

  _Planet _newPlanet({bool seedTop = false}) {
    final s = _size;
    final hue = _rng.nextInt(_kPlanetColors.length);
    return _Planet(
      x: _rng.nextDouble() * s.width,
      y: seedTop ? _rng.nextDouble() * s.height : -80.0,
      r: 26 + _rng.nextDouble() * 46,
      color: _kPlanetColors[hue],
      vy: 8 + _rng.nextDouble() * 10,
    );
  }

  void _spawnWave() {
    final s = _size;
    // Every 5th wave is a boss showdown.
    if (_wave % 5 == 0) {
      final bossHp = ((26 + _wave * 4) * _intensity).round();
      _enemies.add(_Enemy(
        kind: _kBoss,
        x: s.width / 2,
        baseX: s.width / 2,
        y: 110,
        hp: bossHp,
        maxHp: bossHp,
        phase: 0,
      ));
      return;
    }

    final cols = math.min(3 + _wave, 7);
    final rows = math.min(2 + (_wave ~/ 2), 4);
    final spacing = s.width / (cols + 1);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final kind = _pickKind(r, c);
        final baseHp = kind == _kTank ? 4 : 1;
        _enemies.add(_Enemy(
          kind: kind,
          x: spacing * (c + 1),
          baseX: spacing * (c + 1),
          y: 84 + r * 54.0,
          hp: baseHp + (_wave ~/ 3),
          phase: _rng.nextDouble() * math.pi * 2,
        ));
      }
    }
  }

  int _pickKind(int row, int col) {
    final roll = _rng.nextDouble() * (1 + _wave * 0.05 * _intensity);
    if (_wave >= 3 && roll > 1.15 && row == 0) return _kDiver;
    if (_wave >= 2 && roll > 0.9) return _kWeaver;
    if (_wave >= 4 && roll > 1.05) return _kTank;
    return _kGrunt;
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

  void _update(double dt) {
    // Ambient parallax always runs.
    for (final st in _stars) {
      st.y += (30 * st.z) * dt;
      if (st.y > _size.height) {
        st.y = 0;
        st.x = _rng.nextDouble() * _size.width;
      }
    }
    for (var i = _planets.length - 1; i >= 0; i--) {
      final pl = _planets[i];
      pl.y += pl.vy * dt;
      if (pl.y - pl.r > _size.height) _planets[i] = _newPlanet();
    }
    for (var i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) _particles.removeAt(i);
    }
    for (var i = _pops.length - 1; i >= 0; i--) {
      final p = _pops[i];
      p.y -= 40 * dt;
      p.life -= dt;
      if (p.life <= 0) _pops.removeAt(i);
    }
    if (_shake > 0) _shake = math.max(0.0, _shake - dt * 2.6);
    if (_state != 'play' || _busy) return;

    if (_rapid > 0) _rapid -= dt;
    if (_shipInvuln > 0) _shipInvuln -= dt;

    // Engine thruster trail.
    if (_rng.nextDouble() < 0.6) {
      _particles.add(_Particle(
        x: _ship.x + (_rng.nextDouble() - 0.5) * 6,
        y: _ship.y + 18,
        vx: (_rng.nextDouble() - 0.5) * 30,
        vy: 120 + _rng.nextDouble() * 60,
        life: 0.4,
        color: const Color(0xFFFFB04D),
      ));
    }

    // Auto-fire (twin shots when rapid).
    _fireT += dt;
    final interval = _rapid > 0 ? 0.10 : 0.22;
    if (_fireT >= interval) {
      _fireT = 0;
      if (_rapid > 0) {
        _bullets.add(_Bullet(x: _ship.x - 9, y: _ship.y - 20));
        _bullets.add(_Bullet(x: _ship.x + 9, y: _ship.y - 20));
      } else {
        _bullets.add(_Bullet(x: _ship.x, y: _ship.y - 22));
      }
    }

    _updateBullets(dt);
    _updateEnemies(dt);
    _updateEnemyFire(dt);
    _updateAsteroids(dt);
    _updatePowers(dt);

    // Wave cleared -> quiz gate.
    if (_enemies.isEmpty) {
      _advanceWave();
    }
  }

  void _updateBullets(double dt) {
    for (var i = _bullets.length - 1; i >= 0; i--) {
      final b = _bullets[i];
      b.y -= 580 * dt;
      if (b.y < -10) {
        _bullets.removeAt(i);
        continue;
      }
      var hit = false;
      for (var j = _enemies.length - 1; j >= 0; j--) {
        final e = _enemies[j];
        final rx = e.kind == _kBoss ? 60.0 : (e.kind == _kTank ? 24.0 : 20.0);
        final ry = e.kind == _kBoss ? 34.0 : 18.0;
        if ((b.x - e.x).abs() < rx && (b.y - e.y).abs() < ry) {
          hit = true;
          e.hp--;
          e.flash = 0.12;
          if (e.hp <= 0) {
            _onEnemyKilled(e);
            _enemies.removeAt(j);
          }
          break;
        }
      }
      // Bullets also chip asteroids.
      if (!hit) {
        for (var j = _asteroids.length - 1; j >= 0; j--) {
          final a = _asteroids[j];
          if ((b.x - a.x).abs() < a.size && (b.y - a.y).abs() < a.size) {
            hit = true;
            a.hp--;
            if (a.hp <= 0) {
              _score += 5;
              GameScoreScope.report(context, _score);
              _boom(a.x, a.y, const Color(0xFFB9A38C));
              _asteroids.removeAt(j);
            }
            break;
          }
        }
      }
      if (hit) _bullets.removeAt(i);
    }
  }

  void _onEnemyKilled(_Enemy e) {
    final pts = e.kind == _kBoss
        ? 150
        : e.kind == _kTank
            ? 25
            : e.kind == _kDiver
                ? 20
                : 10;
    _score += pts;
    GameScoreScope.report(context, _score);
    _pop(e.x, e.y - 14, '+$pts', _enemyColor(e.kind));
    if (e.kind == _kBoss) _shake = math.max(_shake, 0.9);
    _boom(e.x, e.y, _enemyColor(e.kind));
    // Drops.
    if (e.kind == _kBoss) {
      _powers.add(_Power(x: e.x, y: e.y, kind: _kPowerBone));
    } else if (_rng.nextDouble() < 0.12) {
      _powers.add(_Power(
          x: e.x,
          y: e.y,
          kind: _rng.nextDouble() < 0.25 ? _kPowerHeart : _kPowerBone));
    }
  }

  void _updateEnemies(double dt) {
    var hitEdge = false;
    final formSpeed = (34 + _wave * 2.0) * _intensity;
    for (final e in _enemies) {
      if (e.flash > 0) e.flash -= dt;
      switch (e.kind) {
        case _kGrunt:
        case _kTank:
          e.x += _formDir * formSpeed * (e.kind == _kTank ? 0.6 : 1.0) * dt;
          if (e.x < 24 || e.x > _size.width - 24) hitEdge = true;
          break;
        case _kWeaver:
          e.phase += dt * 2.2;
          e.x = e.baseX + math.sin(e.phase) * 60;
          e.y += 10 * dt;
          break;
        case _kDiver:
          if (e.diving) {
            e.y += 240 * dt;
            e.x += (_ship.x - e.x).clamp(-90.0, 90.0) * dt;
            if (e.y > _size.height + 30) {
              e.y = 70;
              e.diving = false;
              e.x = e.baseX;
            }
          } else {
            e.phase += dt;
            e.x = e.baseX + math.sin(e.phase) * 18;
            if (e.phase > 2 && _rng.nextDouble() < 0.012 * _intensity) {
              e.diving = true;
            }
          }
          break;
        case _kBoss:
          e.phase += dt * 0.7;
          e.x = e.baseX + math.sin(e.phase) * (_size.width * 0.32);
          break;
      }
    }
    if (hitEdge) {
      for (final e in _enemies) {
        if (e.kind == _kGrunt || e.kind == _kTank) {
          e.y += 16;
        }
      }
      _formDir *= -1;
    }

    // Enemy reaches the ship line -> costs a life, push it back up.
    for (final e in _enemies) {
      if (e.kind != _kBoss && e.y > _ship.y - 28) {
        _hitShip();
        e.y = 84;
        e.diving = false;
        break;
      }
    }
  }

  void _updateEnemyFire(double dt) {
    _enemyFireT += dt;
    final cadence = (0.95 - _wave * 0.03) / _intensity;
    final threshold = cadence.clamp(0.32, 0.95);
    if (_enemyFireT >= threshold && _enemies.isNotEmpty) {
      _enemyFireT = 0;
      final shooter = _enemies[_rng.nextInt(_enemies.length)];
      if (shooter.kind == _kBoss) {
        // Boss fires a spread.
        for (final a in [-0.4, -0.15, 0.15, 0.4]) {
          _eBullets.add(_EBullet(
              x: shooter.x, y: shooter.y + 24, vx: math.sin(a) * 220, vy: 260));
        }
      } else {
        // Aim roughly at the ship.
        final dx = (_ship.x - shooter.x);
        final dy = (_ship.y - shooter.y).clamp(1.0, 9999.0);
        final norm = math.sqrt(dx * dx + dy * dy);
        _eBullets.add(_EBullet(
          x: shooter.x,
          y: shooter.y + 18,
          vx: dx / norm * 200,
          vy: dy / norm * 200 + 60,
        ));
      }
    }
    for (var i = _eBullets.length - 1; i >= 0; i--) {
      final b = _eBullets[i];
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      if (b.y > _size.height + 10 || b.x < -10 || b.x > _size.width + 10) {
        _eBullets.removeAt(i);
        continue;
      }
      if (_shipInvuln <= 0 &&
          (b.x - _ship.x).abs() < 16 &&
          (b.y - _ship.y).abs() < 18) {
        _eBullets.removeAt(i);
        _hitShip();
      }
    }
  }

  void _updateAsteroids(double dt) {
    _astT += dt;
    if (_astT > (2.6 / _intensity) && _asteroids.length < 4) {
      _astT = 0;
      final sz = 14.0 + _rng.nextDouble() * 16;
      _asteroids.add(_Asteroid(
        x: 30 + _rng.nextDouble() * (_size.width - 60),
        y: -30,
        vy: 60 + _rng.nextDouble() * 50 * _intensity,
        vx: (_rng.nextDouble() - 0.5) * 40,
        size: sz,
        hp: sz > 24 ? 3 : 2,
        spin: (_rng.nextDouble() - 0.5) * 3,
      ));
    }
    for (var i = _asteroids.length - 1; i >= 0; i--) {
      final a = _asteroids[i];
      a.y += a.vy * dt;
      a.x += a.vx * dt;
      a.rot += a.spin * dt;
      if (a.y - a.size > _size.height) {
        _asteroids.removeAt(i);
        continue;
      }
      if (_shipInvuln <= 0 &&
          (a.x - _ship.x).abs() < a.size + 8 &&
          (a.y - _ship.y).abs() < a.size + 8) {
        _boom(a.x, a.y, const Color(0xFFB9A38C));
        _asteroids.removeAt(i);
        _hitShip();
      }
    }
  }

  void _updatePowers(double dt) {
    for (var i = _powers.length - 1; i >= 0; i--) {
      final p = _powers[i];
      p.y += 70 * dt;
      p.phase += dt * 4;
      if (p.y > _size.height + 20) {
        _powers.removeAt(i);
        continue;
      }
      if ((p.x - _ship.x).abs() < 26 && (p.y - _ship.y).abs() < 26) {
        if (p.kind == _kPowerHeart) {
          _lives = math.min(5, _lives + 1);
        } else {
          _rapid = 6;
        }
        _score += 5;
        GameScoreScope.report(context, _score);
        _pop(
            p.x,
            p.y - 14,
            p.kind == _kPowerHeart ? '+1 ♥' : '⚡ Rapid!',
            p.kind == _kPowerHeart
                ? const Color(0xFFFF5A6E)
                : const Color(0xFFFFC83D));
        for (var k = 0; k < 10; k++) {
          _particles.add(_Particle(
            x: p.x,
            y: p.y,
            vx: (_rng.nextDouble() - 0.5) * 220,
            vy: (_rng.nextDouble() - 0.5) * 220,
            life: 0.5,
            color: p.kind == _kPowerHeart
                ? const Color(0xFFFF5A6E)
                : const Color(0xFFFFC83D),
          ));
        }
        _powers.removeAt(i);
      }
    }
  }

  void _hitShip() {
    if (_shipInvuln > 0) return;
    _lives--;
    _shipInvuln = 1.3;
    _rapid = 0;
    _shake = math.max(_shake, 1.0);
    _boom(_ship.x, _ship.y, const Color(0xFFFF5A6E));
    if (_lives <= 0) {
      _endRun();
    }
  }

  void _boom(double x, double y, Color c) {
    for (var i = 0; i < 16; i++) {
      _particles.add(_Particle(
        x: x,
        y: y,
        vx: (_rng.nextDouble() - 0.5) * 300,
        vy: (_rng.nextDouble() - 0.5) * 300,
        life: 0.55,
        color: c,
      ));
    }
  }

  Color _enemyColor(int kind) {
    switch (kind) {
      case _kWeaver:
        return const Color(0xFFFF8AD8);
      case _kTank:
        return const Color(0xFFB39DFF);
      case _kDiver:
        return const Color(0xFFFF6B6B);
      case _kBoss:
        return const Color(0xFFFFA63D);
      default:
        return const Color(0xFF8FE3B6);
    }
  }

  Future<void> _advanceWave() async {
    if (_busy) return;
    _busy = true;
    final boss = _wave % 5 == 0;
    final ok = await _gate.ask(
      title: boss ? 'Boss down! 🎉' : 'Wave $_wave cleared!',
      subtitle: 'Answer correctly to launch the next wave',
    );
    if (!mounted) return;
    if (ok) {
      _wave++;
      _eBullets.clear();
      _spawnWave();
      _pop(_ship.x, _ship.y - 40, 'Wave $_wave!', const Color(0xFF5BD6A6));
      for (var i = 0; i < 12; i++) {
        _particles.add(_Particle(
          x: _ship.x,
          y: _ship.y,
          vx: (_rng.nextDouble() - 0.5) * 260,
          vy: (_rng.nextDouble() - 0.5) * 260,
          life: 0.6,
          color: const Color(0xFF8FE3FF),
        ));
      }
    } else {
      // Wrong answer: lose a life; if still alive, replay same wave.
      _lives--;
      if (_lives <= 0) {
        _endRun();
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
          _ship.y = (_ship.y + d.delta.dy)
              .clamp(_size.height * 0.5, _size.height - 40);
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
                pops: _pops,
                stars: _stars,
                powers: _powers,
                asteroids: _asteroids,
                planets: _planets,
                wave: _wave,
                rapid: _rapid > 0,
                shipInvuln: _shipInvuln,
                shake: _shake,
                t: _t,
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
              child: GameStatScreen(
                title: 'Game over',
                score: _score,
                best: _best,
                answered: _gate.asked,
                correct: _gate.correctCount,
                mastered: _gate.masteredCount,
                totalQuestions: _gate.total,
                extraLabel: 'Reached wave $_wave',
                onPlayAgain: _start,
              ),
            ),
          if (_state == 'play')
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Text(
                  _rapid > 0
                      ? 'Drag to fly ${Mascot.name} · ⚡ rapid fire!'
                      : 'Drag to fly ${Mascot.name} · auto-fire',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),
        ]),
      );
    });
  }
}

const int _kPowerBone = 0;
const int _kPowerHeart = 1;

const List<Color> _kPlanetColors = [
  Color(0xFF3A4A8C),
  Color(0xFF6B4A8C),
  Color(0xFF2F6E6A),
  Color(0xFF8C5A3A),
];

class _Ship {
  double x, y;
  _Ship({required this.x, required this.y});
}

class _Bullet {
  double x, y;
  _Bullet({required this.x, required this.y});
}

class _EBullet {
  double x, y, vx, vy;
  _EBullet({required this.x, required this.y, this.vx = 0, this.vy = 300});
}

class _Enemy {
  final int kind;
  double x, y, baseX, phase;
  int hp;
  final int maxHp;
  double flash = 0;
  bool diving = false;
  _Enemy({
    required this.kind,
    required this.x,
    required this.y,
    required this.baseX,
    required this.hp,
    required this.phase,
    this.maxHp = 1,
  });
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

class _Pop {
  double x, y, life = 0.9;
  final double maxLife = 0.9;
  final String text;
  final Color color;
  _Pop({required this.x, required this.y, required this.text, required this.color});
}

class _Star {
  double x, y, z;
  _Star({required this.x, required this.y, required this.z});
}

class _Power {
  double x, y, phase = 0;
  final int kind;
  _Power({required this.x, required this.y, required this.kind});
}

class _Asteroid {
  double x, y, vy, vx, size, rot = 0, spin;
  int hp;
  _Asteroid({
    required this.x,
    required this.y,
    required this.vy,
    required this.vx,
    required this.size,
    required this.hp,
    required this.spin,
  });
}

class _Planet {
  double x, y, r, vy;
  final Color color;
  _Planet(
      {required this.x,
      required this.y,
      required this.r,
      required this.vy,
      required this.color});
}

class _ShooterPainter extends CustomPainter {
  final _Ship ship;
  final List<_Bullet> bullets;
  final List<_Enemy> enemies;
  final List<_EBullet> eBullets;
  final List<_Particle> particles;
  final List<_Pop> pops;
  final List<_Star> stars;
  final List<_Power> powers;
  final List<_Asteroid> asteroids;
  final List<_Planet> planets;
  final int wave;
  final bool rapid;
  final double shipInvuln;
  final double shake;
  final double t;

  _ShooterPainter({
    required this.ship,
    required this.bullets,
    required this.enemies,
    required this.eBullets,
    required this.particles,
    required this.pops,
    required this.stars,
    required this.powers,
    required this.asteroids,
    required this.planets,
    required this.wave,
    required this.rapid,
    required this.shipInvuln,
    required this.shake,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height;

    // Screen-shake: nudge the whole world (HUD lives outside the painter).
    canvas.save();
    if (shake > 0.02) {
      canvas.translate(
          math.sin(t * 80) * shake * 7, math.cos(t * 67) * shake * 7);
    }

    // Space background — hue drifts with the wave so the map keeps changing.
    // Oversized so screen-shake never reveals an edge.
    final tint = _kNebula[(wave - 1) % _kNebula.length];
    final bg = Rect.fromLTWH(-16, -16, W + 32, H + 32);
    canvas.drawRect(
        bg,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tint, const Color(0xFF0E0E14)],
          ).createShader(bg));

    // Drifting planets.
    for (final pl in planets) {
      canvas.drawCircle(Offset(pl.x, pl.y), pl.r,
          Paint()..color = pl.color.withOpacity(0.55));
      canvas.drawCircle(Offset(pl.x - pl.r * 0.3, pl.y - pl.r * 0.3),
          pl.r * 0.7, Paint()..color = pl.color.withOpacity(0.25));
    }

    // Stars.
    for (final st in stars) {
      canvas.drawCircle(Offset(st.x, st.y), st.z * 1.4,
          Paint()..color = Colors.white.withOpacity(0.25 + 0.5 * st.z / 1.3));
    }

    // Asteroids.
    for (final a in asteroids) {
      _asteroid(canvas, a);
    }

    // Enemy bullets.
    for (final b in eBullets) {
      canvas.drawCircle(
          Offset(b.x, b.y), 4, Paint()..color = const Color(0xFFFF6B6E));
      canvas.drawCircle(Offset(b.x, b.y), 7,
          Paint()..color = const Color(0xFFFF6B6E).withOpacity(0.3));
    }

    // Player bullets.
    for (final b in bullets) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(b.x, b.y), width: 4, height: 14),
              const Radius.circular(2)),
          Paint()..color = const Color(0xFFD6F26C));
    }

    // Enemies.
    for (final e in enemies) {
      _enemy(canvas, e);
    }

    // Power-ups.
    for (final p in powers) {
      _power(canvas, p);
    }

    // Particles.
    for (final p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), 3,
          Paint()..color = p.color.withOpacity((p.life * 2).clamp(0.0, 1.0)));
    }

    // Pip's ship (the hero).
    _drawHeroShip(canvas);

    // Floating "+N" score pops.
    for (final p in pops) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      _popText(canvas, p.text, Offset(p.x, p.y), p.color.withOpacity(a), a);
    }

    canvas.restore();
  }

  void _popText(Canvas canvas, String s, Offset at, Color color, double a) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 16 + (1 - a) * 5,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  // -- Hero ship: Pip piloting an orange-and-white rocket pod ----------------
  void _drawHeroShip(Canvas canvas) {
    final x = ship.x, y = ship.y;
    // Blink the ship while invulnerable.
    if (shipInvuln > 0 && (t * 14).floor().isEven) {
      // skip drawing for a flicker frame
    } else {
      canvas.save();
      canvas.translate(x, y);
      final bob = math.sin(t * 6) * 1.5;
      canvas.translate(0, bob);

      Paint ink([double w = 2.4]) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = const Color(0xFF1A1A1A)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      // Engine flames.
      final flick = 0.6 + 0.4 * math.sin(t * 30);
      final flame = Path()
        ..moveTo(-8, 18)
        ..quadraticBezierTo(0, 30 + 14 * flick, 8, 18)
        ..close();
      canvas.drawPath(flame, Paint()..color = const Color(0xFFFFD23F));
      final flame2 = Path()
        ..moveTo(-4, 18)
        ..quadraticBezierTo(0, 26 + 9 * flick, 4, 18)
        ..close();
      canvas.drawPath(flame2, Paint()..color = const Color(0xFFFF7B2C));

      // Fins.
      final finL = Path()
        ..moveTo(-12, 6)
        ..lineTo(-24, 20)
        ..lineTo(-12, 18)
        ..close();
      final finR = Path()
        ..moveTo(12, 6)
        ..lineTo(24, 20)
        ..lineTo(12, 18)
        ..close();
      canvas.drawPath(finL, Paint()..color = Mascot.orange);
      canvas.drawPath(finR, Paint()..color = Mascot.orange);
      canvas.drawPath(finL, ink());
      canvas.drawPath(finR, ink());

      // Hull.
      final hull = RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, 6), width: 30, height: 38),
          const Radius.circular(13));
      canvas.drawRRect(hull, Paint()..color = Mascot.cream);
      // orange nose band
      canvas.save();
      canvas.clipRRect(hull);
      canvas.drawRect(const Rect.fromLTWH(-16, -14, 32, 12),
          Paint()..color = Mascot.orange);
      canvas.restore();
      canvas.drawRRect(hull, ink());

      // Cockpit glass.
      canvas.drawCircle(const Offset(0, -2), 12,
          Paint()..color = const Color(0xFFBFEFFF).withOpacity(0.7));
      canvas.drawCircle(const Offset(0, -2), 12, ink(1.8));

      // Pip in the cockpit (the star), ears up, glancing forward.
      Mascot.head(
        canvas,
        const Offset(0, -3),
        9.5,
        earFlap: math.sin(t * 10) * 0.6,
        blink: (math.sin(t * 0.7) > 0.97) ? 1.0 : 0.0,
        tilt: math.sin(t * 2) * 0.05,
      );

      canvas.restore();
    }

    // Shield ring while invulnerable.
    if (shipInvuln > 0) {
      final o = 0.4 + 0.3 * math.sin(t * 10);
      canvas.drawCircle(Offset(x, y + 4), 30,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFFBFEFFF).withOpacity(o));
    }

    // Rapid-fire aura.
    if (rapid) {
      canvas.drawCircle(Offset(x, y + 6), 22,
          Paint()..color = const Color(0xFFFFC83D).withOpacity(0.18));
    }
  }

  void _enemy(Canvas c, _Enemy e) {
    final base = e.flash > 0 ? Colors.white : _colorFor(e.kind);
    switch (e.kind) {
      case _kBoss:
        _boss(c, e, base);
        break;
      case _kWeaver:
        _diamond(c, e.x, e.y, 18, base);
        break;
      case _kTank:
        _tank(c, e.x, e.y, base);
        break;
      case _kDiver:
        _dart(c, e.x, e.y, base);
        break;
      default:
        _saucer(c, e.x, e.y, base);
    }
  }

  Color _colorFor(int kind) {
    switch (kind) {
      case _kWeaver:
        return const Color(0xFFFF8AD8);
      case _kTank:
        return const Color(0xFFB39DFF);
      case _kDiver:
        return const Color(0xFFFF6B6B);
      case _kBoss:
        return const Color(0xFFFFA63D);
      default:
        return const Color(0xFF8FE3B6);
    }
  }

  Paint get _eink => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFF12131A)
    ..strokeJoin = StrokeJoin.round;

  void _saucer(Canvas c, double x, double y, Color col) {
    c.drawOval(Rect.fromCenter(center: Offset(x, y + 3), width: 34, height: 16),
        Paint()..color = col);
    c.drawOval(Rect.fromCenter(center: Offset(x, y + 3), width: 34, height: 16),
        _eink);
    c.drawCircle(Offset(x, y - 4), 8, Paint()..color = col.withOpacity(0.85));
    c.drawCircle(Offset(x, y - 4), 8, _eink);
    c.drawCircle(Offset(x, y - 4), 3, Paint()..color = const Color(0xFF12131A));
  }

  void _diamond(Canvas c, double x, double y, double s, Color col) {
    final p = Path()
      ..moveTo(x, y - s)
      ..lineTo(x + s, y)
      ..lineTo(x, y + s)
      ..lineTo(x - s, y)
      ..close();
    c.drawPath(p, Paint()..color = col);
    c.drawPath(p, _eink);
    // little wings
    c.drawPath(
        Path()
          ..moveTo(x - s, y)
          ..lineTo(x - s - 8, y - 6)
          ..lineTo(x - s, y + 4)
          ..close(),
        Paint()..color = col.withOpacity(0.8));
    c.drawPath(
        Path()
          ..moveTo(x + s, y)
          ..lineTo(x + s + 8, y - 6)
          ..lineTo(x + s, y + 4)
          ..close(),
        Paint()..color = col.withOpacity(0.8));
    c.drawCircle(Offset(x, y), 3, Paint()..color = const Color(0xFF12131A));
  }

  void _tank(Canvas c, double x, double y, Color col) {
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 42, height: 28),
        const Radius.circular(8));
    c.drawRRect(r, Paint()..color = col);
    c.drawRRect(r, _eink);
    // armour plates
    for (final dx in [-12.0, 0.0, 12.0]) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x + dx, y), width: 8, height: 20),
              const Radius.circular(3)),
          Paint()..color = Colors.black.withOpacity(0.12));
    }
    c.drawCircle(Offset(x, y), 4, Paint()..color = const Color(0xFF12131A));
  }

  void _dart(Canvas c, double x, double y, Color col) {
    final p = Path()
      ..moveTo(x, y + 16)
      ..lineTo(x + 12, y - 12)
      ..lineTo(x, y - 6)
      ..lineTo(x - 12, y - 12)
      ..close();
    c.drawPath(p, Paint()..color = col);
    c.drawPath(p, _eink);
    c.drawCircle(Offset(x, y - 2), 3, Paint()..color = const Color(0xFF12131A));
  }

  void _boss(Canvas c, _Enemy e, Color col) {
    final x = e.x, y = e.y;
    // big saucer
    c.drawOval(Rect.fromCenter(center: Offset(x, y + 6), width: 120, height: 44),
        Paint()..color = col);
    c.drawOval(Rect.fromCenter(center: Offset(x, y + 6), width: 120, height: 44),
        _eink);
    c.drawOval(Rect.fromCenter(center: Offset(x, y - 8), width: 60, height: 40),
        Paint()..color = col.withOpacity(0.9));
    c.drawOval(Rect.fromCenter(center: Offset(x, y - 8), width: 60, height: 40),
        _eink);
    // angry eye
    c.drawCircle(Offset(x, y - 6), 12, Paint()..color = Colors.white);
    c.drawCircle(Offset(x, y - 6), 6, Paint()..color = const Color(0xFF12131A));
    // lights
    for (final dx in [-40.0, -20.0, 0.0, 20.0, 40.0]) {
      c.drawCircle(Offset(x + dx, y + 14), 3,
          Paint()..color = const Color(0xFFFFD23F).withOpacity(0.8));
    }
    // hp bar
    final maxHp = e.maxHp > 0 ? e.maxHp.toDouble() : 1.0;
    final frac = (e.hp / maxHp).clamp(0.0, 1.0);
    final bx = x - 50, by = y - 40;
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, 100, 6), const Radius.circular(3)),
        Paint()..color = Colors.white24);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, 100 * frac, 6), const Radius.circular(3)),
        Paint()..color = const Color(0xFFFF5A6E));
  }

  void _asteroid(Canvas c, _Asteroid a) {
    c.save();
    c.translate(a.x, a.y);
    c.rotate(a.rot);
    final p = Path();
    const n = 7;
    for (var i = 0; i < n; i++) {
      final ang = (i / n) * math.pi * 2;
      final rad = a.size * (0.78 + ((i * 13) % 5) / 12.0);
      final px = math.cos(ang) * rad;
      final py = math.sin(ang) * rad;
      if (i == 0) {
        p.moveTo(px, py);
      } else {
        p.lineTo(px, py);
      }
    }
    p.close();
    c.drawPath(p, Paint()..color = const Color(0xFF8B7B6B));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF5C5048));
    c.drawCircle(Offset(-a.size * 0.2, -a.size * 0.1), a.size * 0.18,
        Paint()..color = const Color(0xFF6E6055));
    c.restore();
  }

  void _power(Canvas c, _Power p) {
    final bob = math.sin(p.phase) * 3;
    final at = Offset(p.x, p.y + bob);
    // glow
    c.drawCircle(
        at,
        14,
        Paint()
          ..color = (p.kind == _kPowerHeart
                  ? const Color(0xFFFF5A6E)
                  : const Color(0xFFFFC83D))
              .withOpacity(0.25));
    if (p.kind == _kPowerHeart) {
      final hp = Path()
        ..moveTo(at.dx, at.dy + 6)
        ..cubicTo(at.dx - 12, at.dy - 4, at.dx - 6, at.dy - 12, at.dx,
            at.dy - 5)
        ..cubicTo(at.dx + 6, at.dy - 12, at.dx + 12, at.dy - 4, at.dx,
            at.dy + 6)
        ..close();
      c.drawPath(hp, Paint()..color = const Color(0xFFFF5A6E));
    } else {
      _miniBone(c, at);
    }
  }

  void _miniBone(Canvas c, Offset at) {
    final p = Paint()..color = const Color(0xFFFFF3D6);
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(-0.5);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 16, height: 5),
            const Radius.circular(2.5)),
        p);
    for (final sx in [-9.0, 9.0]) {
      c.drawCircle(Offset(sx, -3.5), 4, p);
      c.drawCircle(Offset(sx, 3.5), 4, p);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _ShooterPainter old) => true;
}

const List<Color> _kNebula = [
  Color(0xFF1F1B2E),
  Color(0xFF231B33),
  Color(0xFF14223A),
  Color(0xFF2A1B2B),
  Color(0xFF1B2A2E),
];
