import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen friendly waiting screen shown while a study set is being
/// generated. Cycles through reassuring status messages on a timer and
/// pulses a brand-colored hero icon so the wait does not feel frozen.
class GeneratingOverlay extends StatefulWidget {
  /// Optional title hint shown in the subtitle ("Working on: ...").
  final String? subject;
  const GeneratingOverlay({super.key, this.subject});

  @override
  State<GeneratingOverlay> createState() => _GeneratingOverlayState();
}

class _GeneratingOverlayState extends State<GeneratingOverlay>
    with TickerProviderStateMixin {
  static const _steps = <_Step>[
    _Step(Icons.cloud_download_rounded, 'Fetching your material…'),
    _Step(Icons.find_in_page_rounded, 'Reading and extracting key ideas…'),
    _Step(Icons.auto_awesome_rounded, 'Drafting clear, focused sections…'),
    _Step(Icons.quiz_rounded, 'Writing quiz questions to test you…'),
    _Step(Icons.spellcheck_rounded, 'Picking the most useful key words…'),
    _Step(Icons.style_rounded, 'Polishing your study set…'),
  ];

  late final AnimationController _pulse;
  late final AnimationController _ring;
  Timer? _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _ring = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() => _step = (_step + 1) % _steps.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final step = _steps[_step];
    return Container(
      color: theme.colorScheme.surface.withOpacity(0.98),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HeroIcon(pulse: _pulse, ring: _ring, icon: step.icon),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                            begin: const Offset(0, 0.15), end: Offset.zero)
                        .animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  step.label,
                  key: ValueKey(_step),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.subject != null)
                Text(
                  'Working on: ${widget.subject}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 28),
              _ProgressDots(active: _step, total: _steps.length, color: primary),
              const SizedBox(height: 18),
              Text(
                'Usually takes 20–60 seconds. Keep the app open.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String label;
  const _Step(this.icon, this.label);
}

class _HeroIcon extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController ring;
  final IconData icon;
  const _HeroIcon(
      {required this.pulse, required this.ring, required this.icon});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 132,
      height: 132,
      child: AnimatedBuilder(
        animation: Listenable.merge([pulse, ring]),
        builder: (_, __) {
          final t = pulse.value;
          return Stack(alignment: Alignment.center, children: [
            CustomPaint(
              size: const Size(132, 132),
              painter: _RingPainter(progress: ring.value, color: primary),
            ),
            Transform.scale(
              scale: 0.92 + 0.06 * t,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (c, a) =>
                  ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
              child: Icon(icon,
                  key: ValueKey(icon.codePoint),
                  size: 44,
                  color: primary),
            ),
          ]);
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 - 6;
    final c = Offset(size.width / 2, size.height / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withOpacity(0.12);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(c, r, track);
    final start = -math.pi / 2 + progress * math.pi * 2;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r), start, math.pi * 0.9, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _ProgressDots extends StatelessWidget {
  final int active;
  final int total;
  final Color color;
  const _ProgressDots(
      {required this.active, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final on = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: on ? color : color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
