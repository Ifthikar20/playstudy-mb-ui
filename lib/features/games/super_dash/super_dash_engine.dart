import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart' hide Image, Gradient;

/// Super Dash-style endless runner. The player auto-runs to the right,
/// jumps on tap, and dodges obstacles. Every [checkpointEveryMeters] the
/// game pauses and fires [onCheckpoint] — the host UI shows a quiz; on
/// success [resume] continues, on failure [loseLife] is called and then
/// [resume] continues.
class SuperDashEngine extends FlameGame {
  static const double gravity = 1800;
  static const double jumpVelocity = -680;
  static const double scrollSpeed = 220;
  static const double groundHeight = 80;
  static const double checkpointEveryMeters = 30;

  final void Function() onCheckpoint;
  final void Function() onGameOver;
  final ValueChanged<int>? onMetersChanged;

  late _Player _player;
  late _Ground _ground;
  double _metersTravelled = 0;
  int _checkpointsReached = 0;
  int lives = 3;
  bool _paused = false;
  bool _gameOver = false;
  double _nextObstacleAt = 4;
  bool _ready = false;
  final _rand = Random();

  SuperDashEngine({
    required this.onCheckpoint,
    required this.onGameOver,
    this.onMetersChanged,
  });

  int get meters => _metersTravelled.floor();
  int get checkpointsReached => _checkpointsReached;
  bool get isPaused => _paused;
  bool get isOver => _gameOver;

  @override
  Color backgroundColor() => const Color(0xFFE0F2FE);

  @override
  Future<void> onLoad() async {
    // `onGameResize` runs before `onLoad` in Flame, so set the initial
    // layout here where `size` is already available and the components exist.
    _ground = _Ground()
      ..size = Vector2(size.x, groundHeight)
      ..position = Vector2(0, size.y - groundHeight);
    add(_ground);
    _player = _Player()
      ..position = Vector2(80, size.y - groundHeight - 30);
    add(_player);
    add(_Cloud(seed: 1));
    add(_Cloud(seed: 2));
    _ready = true;
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    // Skip until onLoad has created the components (avoids LateInitError).
    if (_ready && newSize.x > 0) {
      _player.position = Vector2(80, newSize.y - groundHeight - 30);
      _ground.size = Vector2(newSize.x, groundHeight);
      _ground.position = Vector2(0, newSize.y - groundHeight);
    }
  }

  void jump() {
    if (_paused || _gameOver) return;
    _player.jump();
  }

  void resume() {
    _paused = false;
  }

  void loseLife() {
    lives = (lives - 1).clamp(0, 3);
    if (lives <= 0) {
      _gameOver = true;
      onGameOver();
    }
  }

  void restart() {
    _metersTravelled = 0;
    _checkpointsReached = 0;
    lives = 3;
    _paused = false;
    _gameOver = false;
    _nextObstacleAt = 4;
    children.whereType<_Obstacle>().forEach((o) => o.removeFromParent());
    children.whereType<_Checkpoint>().forEach((c) => c.removeFromParent());
    onMetersChanged?.call(0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_paused || _gameOver) return;
    final prevMeters = _metersTravelled;
    _metersTravelled += scrollSpeed * dt / 30;
    if (prevMeters.floor() != _metersTravelled.floor()) {
      onMetersChanged?.call(meters);
    }

    // Spawn obstacles
    if (_metersTravelled >= _nextObstacleAt) {
      add(_Obstacle());
      _nextObstacleAt += 2.5 + _rand.nextDouble() * 2.5;
    }

    // Spawn checkpoint at every threshold
    final nextCheckpointMeters =
        (_checkpointsReached + 1) * checkpointEveryMeters;
    final spawnAt = nextCheckpointMeters - 4; // slightly before so it slides in
    if (_metersTravelled >= spawnAt &&
        children.whereType<_Checkpoint>().isEmpty &&
        !_paused) {
      add(_Checkpoint());
    }

    // Collisions: very simple AABB
    final playerRect = _player.toRect();
    for (final o in children.whereType<_Obstacle>()) {
      if (o.toRect().overlaps(playerRect) && !o.hit) {
        o.hit = true;
        loseLife();
      }
    }
    for (final cp in children.whereType<_Checkpoint>().toList()) {
      if (cp.toRect().overlaps(playerRect) && !cp.triggered) {
        cp.triggered = true;
        _checkpointsReached++;
        _paused = true;
        onCheckpoint();
      }
    }
  }
}

class _Player extends PositionComponent {
  double _vy = 0;
  bool _onGround = true;

  _Player() {
    size = Vector2(40, 56);
    anchor = Anchor.topLeft;
  }

  void jump() {
    if (!_onGround) return;
    _vy = SuperDashEngine.jumpVelocity;
    _onGround = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _vy += SuperDashEngine.gravity * dt;
    position.y += _vy * dt;
    final game = findGame()!;
    final floorY = game.size.y - SuperDashEngine.groundHeight - size.y;
    if (position.y >= floorY) {
      position.y = floorY;
      _vy = 0;
      _onGround = true;
    }
  }

  Rect toRect() => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void render(Canvas canvas) {
    final body = Paint()..color = const Color(0xFF007AFF);
    final accent = Paint()..color = Colors.white;
    final eye = Paint()..color = Colors.black;
    final r = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), body);
    // visor
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 10, size.x - 16, 14),
        const Radius.circular(4),
      ),
      accent,
    );
    canvas.drawCircle(Offset(size.x - 14, 17), 2.5, eye);
    canvas.drawCircle(Offset(14, 17), 2.5, eye);
  }
}

class _Ground extends PositionComponent {
  @override
  void render(Canvas canvas) {
    final p = Paint()..color = const Color(0xFF22C55E);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), p);
    final dirt = Paint()..color = const Color(0xFF166534);
    canvas.drawRect(Rect.fromLTWH(0, 6, size.x, size.y - 6), dirt);
  }
}

class _Obstacle extends PositionComponent {
  bool hit = false;

  _Obstacle() {
    size = Vector2(28, 44);
  }

  @override
  Future<void> onLoad() async {
    final game = findGame()!;
    position = Vector2(
      game.size.x + 20,
      game.size.y - SuperDashEngine.groundHeight - size.y,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= SuperDashEngine.scrollSpeed * dt;
    if (position.x + size.x < 0) removeFromParent();
  }

  Rect toRect() => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void render(Canvas canvas) {
    final p = Paint()..color = hit ? Colors.grey : const Color(0xFFEF4444);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)), p);
    final spike = Paint()..color = const Color(0xFFFEE2E2);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.x / 2, -10)
      ..lineTo(size.x, 0)
      ..close();
    canvas.drawPath(path, spike);
  }
}

class _Checkpoint extends PositionComponent {
  bool triggered = false;
  late TextComponent _label;

  _Checkpoint() {
    size = Vector2(20, 120);
  }

  @override
  Future<void> onLoad() async {
    final game = findGame()!;
    position = Vector2(
      game.size.x + 20,
      game.size.y - SuperDashEngine.groundHeight - size.y,
    );
    _label = TextComponent(
      text: 'QUIZ',
      anchor: Anchor.bottomCenter,
      position: Vector2(size.x / 2, -6),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF5856D6),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    add(_label);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= SuperDashEngine.scrollSpeed * dt;
  }

  Rect toRect() => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void render(Canvas canvas) {
    final pole = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawRect(Rect.fromLTWH(size.x / 2 - 2, 0, 4, size.y), pole);
    final flag = Paint()..color = const Color(0xFF5856D6);
    final path = Path()
      ..moveTo(size.x / 2, 8)
      ..lineTo(size.x / 2 + 36, 18)
      ..lineTo(size.x / 2, 32)
      ..close();
    canvas.drawPath(path, flag);
  }
}

class _Cloud extends PositionComponent {
  final int seed;
  late double speed;
  _Cloud({required this.seed});

  @override
  Future<void> onLoad() async {
    final game = findGame()!;
    speed = 20.0 + seed * 8;
    size = Vector2(80.0 + seed * 12, 24.0);
    position = Vector2(game.size.x * (seed * 0.4), 40.0 + seed * 30);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x -= speed * dt;
    final game = findGame()!;
    if (position.x + size.x < 0) position.x = game.size.x + 20;
  }

  @override
  void render(Canvas canvas) {
    final p = Paint()..color = Colors.white.withOpacity(0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(12),
      ),
      p,
    );
  }
}
