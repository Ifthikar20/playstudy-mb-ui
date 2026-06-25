import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/learning_models.dart';

/// Full-screen friendly waiting screen shown while a study set is being
/// generated. Until the instant preview arrives it cycles reassuring status
/// messages and pulses a hero icon; once [preview] lands it shows the real
/// outline / summary / key terms with a live progress bar, so the user has
/// genuine content to read within seconds.
class GeneratingOverlay extends StatefulWidget {
  /// Optional title hint shown in the subtitle ("Working on: ...").
  final String? subject;

  /// Instant, no-AI preview of the source. Null until the backend has
  /// extracted the text (the first couple of seconds).
  final StudyPreview? preview;

  /// Fraction of AI batches complete, 0..1 (0 shows an indeterminate bar).
  final double progress;

  /// Titles of the real AI sections written so far — checked off live.
  final List<String> sectionTitles;

  const GeneratingOverlay({
    super.key,
    this.subject,
    this.preview,
    this.progress = 0,
    this.sectionTitles = const [],
  });

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
    final preview = widget.preview;
    if (preview != null && !preview.isEmpty) {
      return _buildPreview(context, preview);
    }
    return _buildWaiting(context);
  }

  /// Rich state: real content (outline / summary / key terms) plus a live
  /// progress bar while the AI study set finishes in the background.
  Widget _buildPreview(BuildContext context, StudyPreview preview) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final pct = (widget.progress.clamp(0.0, 1.0) * 100).round();
    return Container(
      color: theme.colorScheme.surface.withOpacity(0.99),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.auto_awesome_rounded, color: primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Building your study set…',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (widget.progress > 0)
                      Text('$pct%',
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: primary, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: widget.progress > 0 ? widget.progress : null,
                      minHeight: 8,
                      backgroundColor: primary.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quizzes and games are being written. Here\'s a head start:',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                children: [
                  if (widget.sectionTitles.isNotEmpty) ...[
                    _SectionLabel(
                        'Sections ready', Icons.check_circle_rounded, primary),
                    const SizedBox(height: 8),
                    ...widget.sectionTitles.map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2, right: 8),
                                child: Icon(Icons.check_circle_rounded,
                                    size: 18, color: primary),
                              ),
                              Expanded(
                                  child: Text(t,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600))),
                            ],
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],
                  if (preview.summary.isNotEmpty) ...[
                    _SectionLabel('Quick summary', Icons.notes_rounded, primary),
                    const SizedBox(height: 8),
                    ...preview.summary.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(s, style: theme.textTheme.bodyMedium),
                        )),
                    const SizedBox(height: 20),
                  ],
                  if (preview.keyTerms.isNotEmpty) ...[
                    _SectionLabel('Key terms', Icons.sell_rounded, primary),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: preview.keyTerms
                          .map((t) => Chip(
                                label: Text(t),
                                backgroundColor: primary.withOpacity(0.10),
                                side: BorderSide(
                                    color: primary.withOpacity(0.25)),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (preview.outline.isNotEmpty) ...[
                    _SectionLabel('Outline', Icons.list_alt_rounded, primary),
                    const SizedBox(height: 8),
                    ...preview.outline.map((o) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6, right: 8),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: primary, shape: BoxShape.circle),
                                ),
                              ),
                              Expanded(
                                  child: Text(o,
                                      style: theme.textTheme.bodyMedium)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 12),
                  ],
                  if (preview.wordCount > 0)
                    Text(
                      '${preview.wordCount} words · ~${preview.readingMinutes} min read',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaiting(BuildContext context) {
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

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionLabel(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Text(label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
    ]);
  }
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
