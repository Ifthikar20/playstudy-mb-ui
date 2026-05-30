import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/rewards/rewards_bloc.dart';

/// Shows a celebratory achievement animation: a points burst, the current
/// level + progress, and a level-up callout if the rank changed.
Future<void> showAchievement(
  BuildContext context, {
  required int delta,
  required RewardsState state,
  required bool rankedUp,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'achievement',
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, __) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Center(
          child: ScaleTransition(
            scale: curved,
            child: _AchievementCard(
                delta: delta, state: state, rankedUp: rankedUp, anim: anim),
          ),
        ),
      );
    },
  );
}

class _AchievementCard extends StatelessWidget {
  final int delta;
  final RewardsState state;
  final bool rankedUp;
  final Animation<double> anim;
  const _AchievementCard({
    required this.delta,
    required this.state,
    required this.rankedUp,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = state.nextRank;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Confetti behind the card.
        SizedBox(
          width: 320,
          height: 360,
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, __) =>
                CustomPaint(painter: _ConfettiPainter(anim.value)),
          ),
        ),
        Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 30,
                  offset: const Offset(0, 12)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  rankedUp ? Icons.military_tech_outlined : Icons.bolt,
                  size: 40,
                  color: const Color(0xFFFF6B35),
                ),
              ),
              const SizedBox(height: 8),
              Text(rankedUp ? 'Level up!' : 'Nice work!',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              // Points burst pill.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFFF6B35)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bolt, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text('+$delta points',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Icon(state.currentRank.icon,
                    size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rankedUp
                        ? 'You reached ${state.currentRank.name}!'
                        : state.currentRank.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: state.rankProgress,
                  minHeight: 8,
                  backgroundColor: theme.dividerColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                next == null
                    ? 'Max level reached'
                    : '${state.pointsToNextRank} pts to ${next.name}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Keep going'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t; // 0..1
  _ConfettiPainter(this.t);
  static const _colors = [
    Color(0xFFFF385C),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFF007AFF),
    Color(0xFFA855F7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final cx = size.width / 2;
    for (var i = 0; i < 36; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = (40 + rng.nextDouble() * 130) * Curves.easeOut.transform(t);
      final x = cx + math.cos(angle) * dist;
      final y = size.height / 2 + math.sin(angle) * dist - 20;
      final paint = Paint()..color = _colors[i % _colors.length].withOpacity(1 - t * 0.7);
      final s = 4 + rng.nextDouble() * 4;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + t * 6);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s, height: s * 1.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
