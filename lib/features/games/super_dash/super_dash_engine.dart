import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../native/mascot.dart';

/// Super Dash world model + painter.
///
/// Pip the pup auto-runs to the right across rolling hills, jumping (tap, with
/// a double-jump) to clear hazards. The scenery cycles through several biomes
/// so the landscape keeps changing as you go. Every so often — paced by
/// *distance run*, not by the clock — Pip reaches a quiz checkpoint and the
/// host pauses the run to pose a question.
///
/// This is a plain Flutter implementation (a [CustomPainter] driven by a
/// [Ticker] in the widget), so it honours the app's [TickerMode] pause: when
/// the full-screen game is closed, the ticker mutes and the run freezes.

/// One stretch of scenery: sky, hills, ground and the prop that dots it.
class Biome {
  final String name;
  final Color skyTop, skyBottom, sun;
  final Color farHill, midHill;
  final Color groundTop, groundBody;
  final Color prop; // tree / cactus / pine / crystal colour
  final int propKind; // 0 leafy tree, 1 pine, 2 cactus, 3 crystal
  final bool night;
  const Biome({
    required this.name,
    required this.skyTop,
    required this.skyBottom,
    required this.sun,
    required this.farHill,
    required this.midHill,
    required this.groundTop,
    required this.groundBody,
    required this.prop,
    required this.propKind,
    this.night = false,
  });
}

/// The biome rotation. Kept free of brand purple (in-game art palette).
const List<Biome> kBiomes = [
  Biome(
    name: 'Meadow',
    skyTop: Color(0xFF8FD3FF),
    skyBottom: Color(0xFFE9F8FF),
    sun: Color(0xFFFFE08A),
    farHill: Color(0xFF93D2AD),
    midHill: Color(0xFF5FB985),
    groundTop: Color(0xFF57C66A),
    groundBody: Color(0xFF2E9E4F),
    prop: Color(0xFF3E9E57),
    propKind: 0,
  ),
  Biome(
    name: 'Desert',
    skyTop: Color(0xFFFFC98A),
    skyBottom: Color(0xFFFFF2DC),
    sun: Color(0xFFFFF1B8),
    farHill: Color(0xFFE8BC8E),
    midHill: Color(0xFFD79A63),
    groundTop: Color(0xFFE8C083),
    groundBody: Color(0xFFCB9A55),
    prop: Color(0xFF4FA86A),
    propKind: 2,
  ),
  Biome(
    name: 'Pinewood',
    skyTop: Color(0xFF7FC6C0),
    skyBottom: Color(0xFFE7F7F3),
    sun: Color(0xFFFFEEC0),
    farHill: Color(0xFF6FA89A),
    midHill: Color(0xFF4C8C7A),
    groundTop: Color(0xFF49A06B),
    groundBody: Color(0xFF2C7F52),
    prop: Color(0xFF2F6F4A),
    propKind: 1,
  ),
  Biome(
    name: 'Snowcap',
    skyTop: Color(0xFFAFD7F2),
    skyBottom: Color(0xFFF6FCFF),
    sun: Color(0xFFFFFFFF),
    farHill: Color(0xFFD9E8F3),
    midHill: Color(0xFFBFD6E8),
    groundTop: Color(0xFFF3F9FF),
    groundBody: Color(0xFFD3E2EE),
    prop: Color(0xFF2F6F4A),
    propKind: 1,
  ),
  Biome(
    name: 'Dusk',
    skyTop: Color(0xFF24335F),
    skyBottom: Color(0xFFFF9E6D),
    sun: Color(0xFFFFD27D),
    farHill: Color(0xFF38477A),
    midHill: Color(0xFF28355C),
    groundTop: Color(0xFF36487A),
    groundBody: Color(0xFF1F294B),
    prop: Color(0xFF8FE3D6),
    propKind: 3,
    night: true,
  ),
];

/// A hazard sitting on the terrain. [worldX] is its absolute position; the
/// painter maps it to the screen each frame.
class Obstacle {
  final double worldX;
  final double w;
  final double h;
  bool hit = false;
  double screenX = 0;
  double screenY = 0;
  Obstacle({required this.worldX, required this.w, required this.h});
  Rect get rect => Rect.fromLTWH(screenX - w / 2, screenY, w, h);
}

/// A short-lived dust puff kicked up by Pip's paws.
class Dust {
  double x, y, vx, vy, life, r;
  Dust({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.r,
  });
}

/// Holds and advances the whole run. The widget owns one of these, ticks it
/// with a real delta-time, and hands it to [SuperDashPainter].
class SuperDashWorld {
  SuperDashWorld({
    required this.onCheckpoint,
    required this.onGameOver,
    required this.onMeters,
  });

  // ── Tuning ────────────────────────────────────────────────────────────────
  static const double scrollSpeed = 240; // px / second
  static const double pxPerMeter = 24; // → 10 m/s
  static const double gravity = 2600;
  static const double jumpVelocity = 940;
  static const double biomeMeters = 320; // length of each biome
  static const double firstCheckpoint = 150; // metres before the first quiz
  static const double checkpointGap = 200; // metres between quizzes (~20s)

  final VoidCallback onCheckpoint;
  final VoidCallback onGameOver;
  final ValueChanged<int> onMeters;

  Size size = Size.zero;
  double scroll = 0;
  int lives = 3;
  bool paused = false;
  bool over = false;

  // Pip's vertical state (height above the terrain surface).
  double pipJump = 0;
  double _vy = 0;
  int _jumpsUsed = 0;
  bool _grounded = true;
  double runPhase = 0;
  double airborne = 0;
  double _earKick = 0;

  // Hazards + effects.
  final List<Obstacle> obstacles = [];
  final List<Dust> dust = [];
  double _nextObstacleWorldX = 0;
  double _invuln = 0;
  double hitFlash = 0;
  final math.Random _rng = math.Random();

  // Quiz checkpoints, paced by distance.
  double _nextCpMeters = firstCheckpoint;
  int checkpointsReached = 0;

  double get meters => scroll / pxPerMeter;
  int get metersInt => meters.floor();
  double get pipX => size.width * 0.26;
  double get nextCpMeters => _nextCpMeters;
  bool get invulnerable => _invuln > 0;
  double get earFlap =>
      (math.sin(runPhase * 2) * 0.3) + airborne * 0.5 + _earKick;

  /// Screen-x of the approaching checkpoint flag (reaches [pipX] on trigger).
  double get cpFlagScreenX => pipX + (_nextCpMeters - meters) * pxPerMeter;

  String get biomeName =>
      kBiomes[(meters ~/ biomeMeters) % kBiomes.length].name;

  /// Rolling terrain height offset for an absolute world position.
  double terrain(double world) =>
      math.sin(world * 0.0050) * 30 +
      math.sin(world * 0.0123 + 1.7) * 13 +
      math.sin(world * 0.0310 + 0.5) * 5;

  double _baseGroundY() => size.height - 120;

  /// Y of the ground surface at a given screen x.
  double groundYAt(double screenX) =>
      _baseGroundY() + terrain(scroll + screenX);

  void jump() {
    if (paused || over) return;
    if (_grounded || _jumpsUsed < 2) {
      _vy = jumpVelocity;
      _grounded = false;
      _jumpsUsed++;
      _earKick = 0.5;
      _kickDust(6);
    }
  }

  void resume() => paused = false;

  void loseLife() {
    if (_invuln > 0) return;
    lives = math.max(0, lives - 1);
    _invuln = 1.1;
    hitFlash = 0.45;
    if (lives <= 0) {
      over = true;
      onGameOver();
    }
  }

  void restart() {
    scroll = 0;
    lives = 3;
    paused = false;
    over = false;
    pipJump = 0;
    _vy = 0;
    _jumpsUsed = 0;
    _grounded = true;
    runPhase = 0;
    airborne = 0;
    _earKick = 0;
    obstacles.clear();
    dust.clear();
    _nextObstacleWorldX = 0;
    _invuln = 0;
    hitFlash = 0;
    _nextCpMeters = firstCheckpoint;
    checkpointsReached = 0;
    onMeters(0);
  }

  void _kickDust(int n) {
    if (size == Size.zero) return;
    final fx = pipX;
    final fy = groundYAt(pipX) - 2;
    for (var i = 0; i < n; i++) {
      dust.add(Dust(
        x: fx - 6 + _rng.nextDouble() * 12,
        y: fy,
        vx: -50 - _rng.nextDouble() * 90,
        vy: -20 - _rng.nextDouble() * 55,
        life: 0.4 + _rng.nextDouble() * 0.3,
        r: 3 + _rng.nextDouble() * 4,
      ));
    }
  }

  void update(double dt) {
    if (paused || over || size == Size.zero) return;

    final prevMeters = metersInt;
    scroll += scrollSpeed * dt;
    if (metersInt != prevMeters) onMeters(metersInt);

    runPhase += dt * 11;
    if (_earKick > 0) _earKick = math.max(0.0, _earKick - dt * 1.6);

    // Vertical physics over the terrain surface.
    if (!_grounded) {
      _vy -= gravity * dt;
      pipJump += _vy * dt;
      airborne = (airborne + dt * 6).clamp(0.0, 1.0).toDouble();
      if (pipJump <= 0) {
        pipJump = 0;
        _vy = 0;
        _grounded = true;
        _jumpsUsed = 0;
        _kickDust(8);
      }
    } else {
      airborne = (airborne - dt * 8).clamp(0.0, 1.0).toDouble();
      if (_rng.nextDouble() < dt * 9) _kickDust(1);
    }

    if (_invuln > 0) _invuln -= dt;
    if (hitFlash > 0) hitFlash -= dt;

    // Spawn hazards by distance so they stay dodgeable.
    if (_nextObstacleWorldX == 0) {
      _nextObstacleWorldX = scroll + size.width + 90;
    }
    if (scroll + size.width >= _nextObstacleWorldX) {
      obstacles.add(Obstacle(
        worldX: _nextObstacleWorldX,
        w: 26 + _rng.nextDouble() * 12,
        h: 28 + _rng.nextDouble() * 26,
      ));
      _nextObstacleWorldX += 300 + _rng.nextDouble() * 280;
    }

    // Position + collide hazards.
    final pr = pipRect();
    for (final o in obstacles) {
      o.screenX = o.worldX - scroll;
      o.screenY = groundYAt(o.screenX) - o.h;
      if (!o.hit && _invuln <= 0 && pr.overlaps(o.rect)) {
        o.hit = true;
        loseLife();
      }
    }
    obstacles.removeWhere((o) => o.worldX - scroll < -90);

    // Dust.
    for (final d in dust) {
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.vy += 130 * dt;
      d.life -= dt;
    }
    dust.removeWhere((d) => d.life <= 0);

    // Distance-paced quiz checkpoint.
    if (meters >= _nextCpMeters) {
      checkpointsReached++;
      _nextCpMeters += checkpointGap;
      paused = true;
      onCheckpoint();
    }
  }

  /// Pip's collision box.
  Rect pipRect() {
    const r = 22.0;
    final footY = groundYAt(pipX) - pipJump;
    return Rect.fromCenter(
      center: Offset(pipX, footY - r),
      width: r * 1.7,
      height: r * 1.9,
    );
  }
}

/// Renders [SuperDashWorld]: parallax sky, hills, themed props, terrain,
/// hazards, dust and the running Pip.
class SuperDashPainter extends CustomPainter {
  final SuperDashWorld w;
  SuperDashPainter(this.w, {Listenable? repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    w.size = size;
    final s = _sceneAt(w.meters);

    _sky(canvas, size, s);
    _celestial(canvas, size, s);
    _hill(canvas, size,
        parallax: 0.20,
        baseY: size.height * 0.50,
        amp: 26,
        freq: 0.0040,
        phase: 0.0,
        color: s.farHill);
    _hill(canvas, size,
        parallax: 0.42,
        baseY: size.height * 0.60,
        amp: 34,
        freq: 0.0060,
        phase: 1.3,
        color: s.midHill);
    _clouds(canvas, size, s);
    _ground(canvas, size, s);
    _props(canvas, size);
    _checkpointFlag(canvas, size);
    _obstacles(canvas, size);
    _dust(canvas);
    _pip(canvas, size);

    if (w.hitFlash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFFFF4444)
              .withOpacity((w.hitFlash * 0.5).clamp(0.0, 0.4).toDouble()),
      );
    }
  }

  // ── Scene blending ──────────────────────────────────────────────────────
  _Scene _sceneAt(double meters) {
    final seg = meters / SuperDashWorld.biomeMeters;
    final i = seg.floor();
    final f = seg - i;
    final a = kBiomes[(i % kBiomes.length + kBiomes.length) % kBiomes.length];
    final b = kBiomes[
        ((i + 1) % kBiomes.length + kBiomes.length) % kBiomes.length];
    final double t =
        f < 0.82 ? 0.0 : ((f - 0.82) / 0.18).clamp(0.0, 1.0).toDouble();
    Color l(Color x, Color y) => Color.lerp(x, y, t)!;
    final night =
        (a.night ? 1.0 : 0.0) * (1 - t) + (b.night ? 1.0 : 0.0) * t;
    return _Scene(
      skyTop: l(a.skyTop, b.skyTop),
      skyBottom: l(a.skyBottom, b.skyBottom),
      sun: l(a.sun, b.sun),
      farHill: l(a.farHill, b.farHill),
      midHill: l(a.midHill, b.midHill),
      groundTop: l(a.groundTop, b.groundTop),
      groundBody: l(a.groundBody, b.groundBody),
      nightAmt: night,
    );
  }

  // ── Layers ────────────────────────────────────────────────────────────────
  void _sky(Canvas canvas, Size size, _Scene s) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [s.skyTop, s.skyBottom],
        ).createShader(Offset.zero & size),
    );
  }

  void _celestial(Canvas canvas, Size size, _Scene s) {
    final c = Offset(size.width * 0.78, size.height * 0.22);
    final double day = (1 - s.nightAmt).clamp(0.0, 1.0).toDouble();
    final double night = s.nightAmt.clamp(0.0, 1.0).toDouble();

    // Stars (night).
    if (night > 0.02) {
      final star = Paint()..color = Colors.white.withOpacity(0.9 * night);
      for (var i = 0; i < 46; i++) {
        final sx = (i * 73.0) % size.width;
        final sy = (i * 39.0) % (size.height * 0.5);
        final tw = 0.5 + 0.5 * math.sin(i * 12.9 + w.meters * 0.25);
        canvas.drawCircle(Offset(sx, sy), 1.2 * tw, star);
      }
    }
    // Sun glow + disk (day).
    if (day > 0.02) {
      canvas.drawCircle(
          c, 60, Paint()..color = s.sun.withOpacity(0.30 * day));
      canvas.drawCircle(c, 30, Paint()..color = s.sun.withOpacity(day));
    }
    // Moon (night).
    if (night > 0.5) {
      final moon = Paint()..color = const Color(0xFFEFF3FF).withOpacity(night);
      canvas.drawCircle(c, 26, moon);
      canvas.drawCircle(Offset(c.dx + 10, c.dy - 6), 22,
          Paint()..color = s.skyTop.withOpacity(night));
    }
  }

  void _hill(
    Canvas canvas,
    Size size, {
    required double parallax,
    required double baseY,
    required double amp,
    required double freq,
    required double phase,
    required Color color,
  }) {
    final off = w.scroll * parallax;
    final path = Path();
    double yAt(double x) =>
        baseY +
        math.sin((off + x) * freq + phase) * amp +
        math.sin((off + x) * freq * 2.3 + phase) * amp * 0.3;
    path.moveTo(0, yAt(0));
    for (double x = 0; x <= size.width; x += 16) {
      path.lineTo(x, yAt(x));
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _clouds(Canvas canvas, Size size, _Scene s) {
    final double op = (1 - s.nightAmt).clamp(0.0, 1.0).toDouble() * 0.85;
    if (op < 0.03) return;
    final p = Paint()..color = Colors.white.withOpacity(op);
    for (var i = 0; i < 4; i++) {
      final speed = 12.0 + i * 6;
      final cx = (size.width + 120) -
          ((w.scroll * 0.12 + speed * 3 + i * 220) %
              (size.width + 220));
      final cy = 40.0 + i * 34;
      final cw = 70.0 + i * 16;
      _cloud(canvas, Offset(cx, cy), cw, p);
    }
  }

  void _cloud(Canvas canvas, Offset c, double wd, Paint p) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: wd, height: wd * 0.34),
        Radius.circular(wd * 0.2),
      ),
      p,
    );
    canvas.drawCircle(Offset(c.dx - wd * 0.22, c.dy - wd * 0.06), wd * 0.20, p);
    canvas.drawCircle(Offset(c.dx + wd * 0.16, c.dy - wd * 0.10), wd * 0.24, p);
  }

  void _ground(Canvas canvas, Size size, _Scene s) {
    final body = Path();
    body.moveTo(0, w.groundYAt(0));
    for (double x = 0; x <= size.width; x += 14) {
      body.lineTo(x, w.groundYAt(x));
    }
    body.lineTo(size.width, size.height);
    body.lineTo(0, size.height);
    body.close();
    canvas.drawPath(body, Paint()..color = s.groundBody);

    // Grass / surface stripe along the top edge.
    final top = Path();
    top.moveTo(0, w.groundYAt(0));
    for (double x = 0; x <= size.width; x += 14) {
      top.lineTo(x, w.groundYAt(x));
    }
    canvas.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = s.groundTop,
    );
  }

  void _props(Canvas canvas, Size size) {
    const spacing = 200.0;
    final startK = ((w.scroll - 60) / spacing).floor();
    final endK = ((w.scroll + size.width + 60) / spacing).ceil();
    for (var k = startK; k <= endK; k++) {
      if ((k * 13) % 3 == 0) continue; // thin them out
      final jitter = ((k * 37) % 40) - 20.0;
      final worldX = k * spacing + jitter;
      final sx = worldX - w.scroll;
      if (sx < -50 || sx > size.width + 50) continue;
      final m = worldX / SuperDashWorld.pxPerMeter;
      final biome = kBiomes[
          (m ~/ SuperDashWorld.biomeMeters % kBiomes.length + kBiomes.length) %
              kBiomes.length];
      final scale = 0.8 + ((k * 7) % 5) / 6.0;
      _prop(canvas, Offset(sx, w.groundYAt(sx) + 2), biome, scale);
    }
  }

  void _prop(Canvas canvas, Offset base, Biome b, double scale) {
    final h = 46.0 * scale;
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x33000000);
    switch (b.propKind) {
      case 1: // pine
        final trunk = Rect.fromLTWH(base.dx - 3, base.dy - h * 0.3, 6, h * 0.3);
        canvas.drawRect(trunk, Paint()..color = const Color(0xFF7A5230));
        for (var i = 0; i < 3; i++) {
          final ty = base.dy - h * (0.3 + i * 0.22);
          final tw = (h * 0.5) * (1 - i * 0.22);
          final tri = Path()
            ..moveTo(base.dx, ty - h * 0.3)
            ..lineTo(base.dx - tw / 2, ty)
            ..lineTo(base.dx + tw / 2, ty)
            ..close();
          canvas.drawPath(tri, Paint()..color = b.prop);
          if (b.name == 'Snowcap') {
            final cap = Path()
              ..moveTo(base.dx, ty - h * 0.3)
              ..lineTo(base.dx - tw * 0.18, ty - h * 0.16)
              ..lineTo(base.dx + tw * 0.18, ty - h * 0.16)
              ..close();
            canvas.drawPath(cap, Paint()..color = Colors.white);
          }
        }
        break;
      case 2: // cactus
        final col = Paint()..color = b.prop;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(base.dx - 5, base.dy - h, 10, h),
                const Radius.circular(5)),
            col);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(base.dx + 4, base.dy - h * 0.7, 8, 6),
                const Radius.circular(3)),
            col);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(base.dx + 10, base.dy - h * 0.78, 5, h * 0.34),
                const Radius.circular(3)),
            col);
        break;
      case 3: // crystal
        final glow = Paint()..color = b.prop.withOpacity(0.35);
        canvas.drawCircle(Offset(base.dx, base.dy - h * 0.5), h * 0.5, glow);
        final cry = Path()
          ..moveTo(base.dx, base.dy - h)
          ..lineTo(base.dx + h * 0.22, base.dy - h * 0.4)
          ..lineTo(base.dx, base.dy)
          ..lineTo(base.dx - h * 0.22, base.dy - h * 0.4)
          ..close();
        canvas.drawPath(cry, Paint()..color = b.prop);
        canvas.drawPath(cry, ink);
        break;
      default: // leafy tree
        canvas.drawRect(Rect.fromLTWH(base.dx - 3, base.dy - h * 0.42, 6, h * 0.42),
            Paint()..color = const Color(0xFF7A5230));
        final leaf = Paint()..color = b.prop;
        canvas.drawCircle(Offset(base.dx, base.dy - h * 0.62), h * 0.34, leaf);
        canvas.drawCircle(
            Offset(base.dx - h * 0.22, base.dy - h * 0.46), h * 0.24, leaf);
        canvas.drawCircle(
            Offset(base.dx + h * 0.22, base.dy - h * 0.46), h * 0.24, leaf);
    }
  }

  void _checkpointFlag(Canvas canvas, Size size) {
    final fx = w.cpFlagScreenX;
    if (fx < -40 || fx > size.width + 40) return;
    if (w.meters >= w.nextCpMeters) return;
    final gy = w.groundYAt(fx);
    final poleTop = gy - 96;
    canvas.drawRect(
        Rect.fromLTWH(fx - 2, poleTop, 4, gy - poleTop),
        Paint()..color = const Color(0xFF8A8F98));
    final wave = math.sin(w.runPhase * 1.5) * 4;
    final flag = Path()
      ..moveTo(fx + 2, poleTop + 4)
      ..quadraticBezierTo(fx + 24, poleTop + 8 + wave, fx + 44, poleTop + 6)
      ..lineTo(fx + 44, poleTop + 30)
      ..quadraticBezierTo(fx + 24, poleTop + 28 + wave, fx + 2, poleTop + 32)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFF2BB673));
    _text(canvas, 'QUIZ', Offset(fx + 2, poleTop - 20),
        const Color(0xFF1A1A1A), 13, FontWeight.w900);
  }

  void _obstacles(Canvas canvas, Size size) {
    for (final o in w.obstacles) {
      if (o.screenX < -60 || o.screenX > size.width + 60) continue;
      final r = Rect.fromLTWH(o.screenX - o.w / 2, o.screenY, o.w, o.h);
      // shadow
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(o.screenX, o.screenY + o.h), width: o.w * 1.1, height: 8),
          Paint()..color = Colors.black.withOpacity(0.16));
      // boulder body
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(o.w * 0.32)),
          Paint()..color = o.hit ? const Color(0xFF9AA1A8) : const Color(0xFF5C6470));
      // danger spikes on top
      final spike = Paint()..color = const Color(0xFFE5484D);
      final p = Path()
        ..moveTo(r.left + 3, r.top)
        ..lineTo(r.left + o.w * 0.3, r.top - 10)
        ..lineTo(r.left + o.w * 0.5, r.top)
        ..lineTo(r.left + o.w * 0.7, r.top - 10)
        ..lineTo(r.right - 3, r.top)
        ..close();
      canvas.drawPath(p, spike);
    }
  }

  void _dust(Canvas canvas) {
    for (final d in w.dust) {
      final double k = d.life.clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
        Offset(d.x, d.y),
        d.r * (k + 0.3),
        Paint()
          ..color = const Color(0xFFEDE6D6)
              .withOpacity(d.life.clamp(0.0, 0.7).toDouble()),
      );
    }
  }

  void _pip(Canvas canvas, Size size) {
    final footY = w.groundYAt(w.pipX) - w.pipJump;
    // Ground shadow shrinks as Pip rises.
    final double lift = (w.pipJump / 120).clamp(0.0, 1.0).toDouble();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w.pipX, w.groundYAt(w.pipX) + 4),
        width: 46 * (1 - lift * 0.5),
        height: 12 * (1 - lift * 0.4),
      ),
      Paint()..color = Colors.black.withOpacity(0.18 * (1 - lift * 0.5)),
    );
    // Blink Pip while briefly invulnerable after a hit.
    if (w.invulnerable && (w.meters * 12).floor() % 2 == 0) return;
    Mascot.runner(
      canvas,
      Offset(w.pipX, footY - 22),
      22,
      runPhase: w.runPhase,
      airborne: w.airborne,
      earFlap: w.earFlap,
    );
  }

  void _text(Canvas canvas, String str, Offset at, Color color, double size,
      FontWeight weight) {
    final tp = TextPainter(
      text: TextSpan(
        text: str,
        style: TextStyle(
            color: color, fontSize: size, fontWeight: weight, letterSpacing: 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant SuperDashPainter oldDelegate) => true;
}

/// Per-frame blended scene colours.
class _Scene {
  final Color skyTop, skyBottom, sun, farHill, midHill, groundTop, groundBody;
  final double nightAmt;
  const _Scene({
    required this.skyTop,
    required this.skyBottom,
    required this.sun,
    required this.farHill,
    required this.midHill,
    required this.groundTop,
    required this.groundBody,
    required this.nightAmt,
  });
}
