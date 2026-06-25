import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/learning_models.dart';

/// Top-to-bottom learning tree for a study set:
///
///        ┌────── Study set ──────┐
///        │                        │
///        ▼          ▼          ▼
///     ┌──────┐   ┌──────┐   ┌──────┐
///     │Topic │   │Topic │   │Topic │
///     └──┬───┘   └──┬───┘   └──┬───┘
///        │          │          │
///       leaf       leaf       leaf
///       leaf       leaf       leaf
///
/// Pannable + pinch-zoomable for large sets. Tap a topic node to jump back
/// to it in the study flow.
class LearningTreeView extends StatelessWidget {
  final LearningMaterial material;
  final Set<int> completed;
  final int? currentSection;
  final ValueChanged<int>? onJumpToSection;
  const LearningTreeView({
    super.key,
    required this.material,
    this.completed = const {},
    this.currentSection,
    this.onJumpToSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = material.sections;
    if (sections.isEmpty) {
      return Center(
        child: Text('No topics to map yet', style: theme.textTheme.bodyMedium),
      );
    }

    // Layout constants tuned to feel compact on phones.
    const rootW = 220.0;
    const rootH = 56.0;
    const topicW = 138.0;
    const topicH = 68.0;
    const leafW = 132.0;
    const leafH = 26.0;
    const colGap = 18.0;
    const rowGap = 56.0;
    const leafGap = 6.0;
    const padX = 24.0;
    const padTop = 20.0;
    const maxLeaves = 4;

    // Per-topic leaves: key word-game terms that appear in the section's
    // content. Fallback to a few words from the section if no terms hit.
    final terms = material.wordGame
        .map((w) => w.word.toUpperCase())
        .where((w) => w.length >= 3)
        .toList();
    final perTopic = <List<String>>[];
    for (final sec in sections) {
      final upper = sec.content.toUpperCase();
      final hits = terms.where(upper.contains).take(maxLeaves).toList();
      if (hits.isEmpty && sec.content.trim().isNotEmpty) {
        final parts = sec.content
            .split(RegExp(r'\s+'))
            .where((p) => p.isNotEmpty)
            .toList();
        perTopic.add([parts.take(4).join(' ')]);
      } else {
        perTopic.add(hits);
      }
    }
    final maxLeafCount =
        perTopic.fold<int>(0, (a, b) => b.length > a ? b.length : a);

    final cols = sections.length;
    final canvasW =
        math.max(padX * 2 + cols * topicW + (cols - 1) * colGap, 320.0);
    final canvasH = padTop +
        rootH +
        rowGap +
        topicH +
        rowGap +
        (maxLeafCount * leafH +
            (maxLeafCount > 0 ? (maxLeafCount - 1) * leafGap : 0)) +
        24;

    final rootCx = canvasW / 2;
    final rootBottomY = padTop + rootH;
    final topicTopY = padTop + rootH + rowGap;
    final leafTopY = topicTopY + topicH + rowGap;

    return InteractiveViewer(
      constrained: false,
      minScale: 0.55,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(80),
      child: SizedBox(
        width: canvasW,
        height: canvasH,
        child: Stack(children: [
          // Edges painted under the nodes.
          Positioned.fill(
            child: CustomPaint(
              painter: _EdgePainter(
                sections: sections,
                completed: completed,
                perTopic: perTopic,
                rootBottomCenter: Offset(rootCx, rootBottomY),
                topicTopY: topicTopY,
                topicH: topicH,
                topicW: topicW,
                colGap: colGap,
                padX: padX,
                leafTopY: leafTopY,
                primary: theme.colorScheme.primary,
                divider: theme.dividerColor,
              ),
            ),
          ),
          // Root.
          Positioned(
            left: rootCx - rootW / 2,
            top: padTop,
            child: _RootNode(
              width: rootW,
              height: rootH,
              title:
                  material.title.isEmpty ? 'Study set' : material.title,
              primary: theme.colorScheme.primary,
            ),
          ),
          // Topics.
          for (var i = 0; i < cols; i++)
            Positioned(
              left: padX + i * (topicW + colGap),
              top: topicTopY,
              child: _TopicNode(
                width: topicW,
                height: topicH,
                section: sections[i],
                index: i,
                done: completed.contains(i),
                current: currentSection == i,
                primary: theme.colorScheme.primary,
                onTap: onJumpToSection == null
                    ? null
                    : () => onJumpToSection!(i),
              ),
            ),
          // Leaves.
          for (var i = 0; i < cols; i++)
            for (var j = 0; j < perTopic[i].length; j++)
              Positioned(
                left: padX + i * (topicW + colGap) + (topicW - leafW) / 2,
                top: leafTopY + j * (leafH + leafGap),
                child: _LeafChip(
                  width: leafW,
                  height: leafH,
                  label: perTopic[i][j],
                  accent: theme.colorScheme.tertiary,
                ),
              ),
        ]),
      ),
    );
  }
}

// ─── Nodes ──────────────────────────────────────────────────────────────

class _RootNode extends StatelessWidget {
  final double width;
  final double height;
  final String title;
  final Color primary;
  const _RootNode({
    required this.width,
    required this.height,
    required this.title,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, Color.lerp(primary, Colors.black, 0.20)!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.30),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        title,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _TopicNode extends StatelessWidget {
  final double width;
  final double height;
  final StudySection section;
  final int index;
  final bool done;
  final bool current;
  final Color primary;
  final VoidCallback? onTap;
  const _TopicNode({
    required this.width,
    required this.height,
    required this.section,
    required this.index,
    required this.done,
    required this.current,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color border = current
        ? primary
        : done
            ? const Color(0xFF15803D)
            : Colors.black.withOpacity(0.10);
    final Color fill = current
        ? primary.withOpacity(0.10)
        : done
            ? const Color(0xFF22C55E).withOpacity(0.10)
            : Colors.white;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: current ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFF22C55E)
                          : primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            size: 12, color: Colors.white)
                        : Text('${index + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: primary,
                            )),
                  ),
                  if (current) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('NOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          )),
                    ),
                  ],
                ]),
                Text(
                  section.title.isEmpty
                      ? 'Topic ${index + 1}'
                      : section.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1A0E12),
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    height: 1.15,
                    letterSpacing: -0.1,
                  ),
                ),
                Text(
                  '${section.quiz.length} Q',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeafChip extends StatelessWidget {
  final double width;
  final double height;
  final String label;
  final Color accent;
  const _LeafChip({
    required this.width,
    required this.height,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.30)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color.lerp(accent, Colors.black, 0.45),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// ─── Edges ──────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  final List<StudySection> sections;
  final Set<int> completed;
  final List<List<String>> perTopic;
  final Offset rootBottomCenter;
  final double topicTopY;
  final double topicH;
  final double topicW;
  final double colGap;
  final double padX;
  final double leafTopY;
  final Color primary;
  final Color divider;
  _EdgePainter({
    required this.sections,
    required this.completed,
    required this.perTopic,
    required this.rootBottomCenter,
    required this.topicTopY,
    required this.topicH,
    required this.topicW,
    required this.colGap,
    required this.padX,
    required this.leafTopY,
    required this.primary,
    required this.divider,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final brandPaint = Paint()
      ..color = primary.withOpacity(0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final donePaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final softPaint = Paint()
      ..color = divider
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Root → each topic: smooth S-curve (root.bottom → topic.top).
    for (var i = 0; i < sections.length; i++) {
      final tx = padX + i * (topicW + colGap) + topicW / 2;
      final ty = topicTopY;
      final p = Path()
        ..moveTo(rootBottomCenter.dx, rootBottomCenter.dy)
        ..cubicTo(
          rootBottomCenter.dx,
          (rootBottomCenter.dy + ty) / 2,
          tx,
          (rootBottomCenter.dy + ty) / 2,
          tx,
          ty,
        );
      canvas.drawPath(p, completed.contains(i) ? donePaint : brandPaint);
    }

    // Topic → leaves: straight drop from topic.bottom to first leaf.
    for (var i = 0; i < sections.length; i++) {
      if (perTopic[i].isEmpty) continue;
      final tx = padX + i * (topicW + colGap) + topicW / 2;
      final topicBottom = topicTopY + topicH;
      final p = Path()
        ..moveTo(tx, topicBottom)
        ..lineTo(tx, leafTopY);
      canvas.drawPath(p, softPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.sections.length != sections.length ||
      old.completed != completed ||
      old.perTopic.length != perTopic.length;
}
