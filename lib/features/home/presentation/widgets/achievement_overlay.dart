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
    // Material parent so Text widgets don't get the yellow-underline
    // "missing Material ancestor" debug treatment.
    return Material(
      color: Colors.transparent,
      child: Stack(
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
              _PulsingTrophy(rankedUp: rankedUp),
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
                      colors: [Color(0xFF6B5CE7), Color(0xFF9D8DFA)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  // Smooth count-up so the "+N points" feels earned.
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: delta.toDouble()),
                    builder: (_, v, __) => Text('+${v.round()} points',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                  ),
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
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t; // 0..1
  _ConfettiPainter(this.t);
  static const _colors = [
    Color(0xFF6B5CE7), // indigo
    Color(0xFFD6F26C), // lime
    Color(0xFF8FE3B6), // mint
    Color(0xFFA8E6F0), // sky
    Color(0xFFC4C0F5), // lavender
    Color(0xFFFBC78A), // peach
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

/// Trophy / bolt icon with a pulsing halo and a soft rotation — gives the
/// reward card a bit of life when it opens.
class _PulsingTrophy extends StatefulWidget {
  final bool rankedUp;
  const _PulsingTrophy({required this.rankedUp});

  @override
  State<_PulsingTrophy> createState() => _PulsingTrophyState();
}

class _PulsingTrophyState extends State<_PulsingTrophy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 96,
      height: 96,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          return Stack(alignment: Alignment.center, children: [
            // Expanding halo
            Container(
              width: 72 + 20 * t,
              height: 72 + 20 * t,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.18 * (1 - t)),
                shape: BoxShape.circle,
              ),
            ),
            // Solid inner circle pulses subtly
            Transform.scale(
              scale: 0.95 + 0.05 * t,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Icon — tiny wobble so it feels alive
            Transform.rotate(
              angle: (t - 0.5) * 0.12,
              child: Icon(
                widget.rankedUp ? Icons.military_tech_rounded : Icons.bolt_rounded,
                size: 40,
                color: primary,
              ),
            ),
          ]);
        },
      ),
    );
  }
}
