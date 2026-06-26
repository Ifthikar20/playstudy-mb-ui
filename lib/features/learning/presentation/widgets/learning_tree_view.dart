import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/learning_models.dart';

/// Left-to-right (landscape) learning tree for a study set:
///
///                     ┌──────┐    leaf leaf
///        ┌──────────► │Topic │──► leaf
///        │            └──────┘    leaf
///   ┌─────────┐       ┌──────┐
///   │Study set│─────► │Topic │──► leaf leaf
///   └─────────┘       └──────┘
///        │            ┌──────┐    leaf
///        └──────────► │Topic │──► leaf
///                     └──────┘
///
/// Laying the tree on its side makes the trunk → branch → leaf structure (the
/// "roots" and the connecting lines) much easier to read. As you study:
///   • a finished section turns green,
///   • the section you're currently on is light yellow,
/// so progress through the whole set is visible at a glance.
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

  // Section state colours, shared with [_TopicNode] and [_EdgePainter].
  static const Color doneGreen = Color(0xFF22C55E);
  static const Color doneBorder = Color(0xFF15803D);
  static const Color currentAmber = Color(0xFFEAB308);
  static const Color currentFill = Color(0xFFFEF9C3); // light yellow

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = material.sections;
    if (sections.isEmpty) {
      return Center(
        child: Text('No topics to map yet', style: theme.textTheme.bodyMedium),
      );
    }

    // Layout constants — laid out left → right (landscape).
    const rootW = 152.0;
    const rootH = 92.0;
    const topicW = 150.0;
    const topicH = 74.0;
    const leafW = 124.0;
    const leafH = 24.0;
    const leafGap = 6.0;
    const rowGap = 24.0; // vertical gap between topic rows
    const hGap = 46.0; // horizontal gap between root/topic/leaf columns
    const padX = 24.0;
    const padY = 24.0;
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
    final maxLeafBlockH = maxLeafCount > 0
        ? maxLeafCount * leafH + (maxLeafCount - 1) * leafGap
        : 0.0;
    final hasLeaves = maxLeafCount > 0;

    final cols = sections.length;
    final rowH = math.max(topicH, maxLeafBlockH);
    final rowStride = rowH + rowGap;
    final contentH = cols * rowH + (cols - 1) * rowGap;
    final canvasH = math.max(padY * 2 + contentH, padY * 2 + rootH);

    // Column x positions.
    final rootRightX = padX + rootW;
    final topicLeftX = rootRightX + hGap;
    final topicRightX = topicLeftX + topicW;
    final leafLeftX = topicRightX + hGap;
    final canvasW = math.max(
        hasLeaves ? leafLeftX + leafW + padX : topicRightX + padX, 320.0);

    final rootTop = (canvasH - rootH) / 2;
    final rootCenterY = canvasH / 2;

    // Vertical layout for each topic row + its leaf block.
    final topicTopY = <double>[];
    final leafTops = <List<double>>[];
    for (var i = 0; i < cols; i++) {
      final rowTop = padY + i * rowStride;
      topicTopY.add(rowTop + (rowH - topicH) / 2);
      final n = perTopic[i].length;
      final blockH = n > 0 ? n * leafH + (n - 1) * leafGap : 0.0;
      final blockTop = rowTop + (rowH - blockH) / 2;
      leafTops.add(
          [for (var j = 0; j < n; j++) blockTop + j * (leafH + leafGap)]);
    }

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
                completed: completed,
                currentSection: currentSection,
                rootRightCenter: Offset(rootRightX, rootCenterY),
                topicLeftX: topicLeftX,
                topicRightX: topicRightX,
                leafLeftX: leafLeftX,
                topicTopY: topicTopY,
                topicH: topicH,
                leafTops: leafTops,
                leafH: leafH,
                primary: theme.colorScheme.primary,
                divider: theme.dividerColor,
              ),
            ),
          ),
          // Root, centred on the left.
          Positioned(
            left: padX,
            top: rootTop,
            child: _RootNode(
              width: rootW,
              height: rootH,
              title: material.title.isEmpty ? 'Study set' : material.title,
              primary: theme.colorScheme.primary,
            ),
          ),
          // Topics, stacked down the middle column.
          for (var i = 0; i < cols; i++)
            Positioned(
              left: topicLeftX,
              top: topicTopY[i],
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
          // Leaves, to the right of each topic.
          for (var i = 0; i < cols; i++)
            for (var j = 0; j < perTopic[i].length; j++)
              Positioned(
                left: leafLeftX,
                top: leafTops[i][j],
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
        maxLines: 3,
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
        ? LearningTreeView.currentAmber
        : done
            ? LearningTreeView.doneBorder
            : Colors.black.withOpacity(0.10);
    final Color fill = current
        ? LearningTreeView.currentFill
        : done
            ? LearningTreeView.doneGreen.withOpacity(0.12)
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
                          ? LearningTreeView.doneGreen
                          : current
                              ? LearningTreeView.currentAmber
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
                              color: current ? Colors.white : primary,
                            )),
                  ),
                  if (current) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: LearningTreeView.currentAmber,
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
                    color: done
                        ? LearningTreeView.doneBorder
                        : current
                            ? const Color(0xFF92660A)
                            : primary,
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
  final Set<int> completed;
  final int? currentSection;
  final Offset rootRightCenter;
  final double topicLeftX;
  final double topicRightX;
  final double leafLeftX;
  final List<double> topicTopY;
  final double topicH;
  final List<List<double>> leafTops;
  final double leafH;
  final Color primary;
  final Color divider;
  _EdgePainter({
    required this.completed,
    required this.currentSection,
    required this.rootRightCenter,
    required this.topicLeftX,
    required this.topicRightX,
    required this.leafLeftX,
    required this.topicTopY,
    required this.topicH,
    required this.leafTops,
    required this.leafH,
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
      ..color = LearningTreeView.doneGreen
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final currentPaint = Paint()
      ..color = LearningTreeView.currentAmber
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final softPaint = Paint()
      ..color = divider
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Root → each topic: smooth horizontal S-curve (root.right → topic.left).
    final rootMidX = (rootRightCenter.dx + topicLeftX) / 2;
    for (var i = 0; i < topicTopY.length; i++) {
      final ty = topicTopY[i] + topicH / 2;
      final p = Path()
        ..moveTo(rootRightCenter.dx, rootRightCenter.dy)
        ..cubicTo(rootMidX, rootRightCenter.dy, rootMidX, ty, topicLeftX, ty);
      canvas.drawPath(
          p,
          completed.contains(i)
              ? donePaint
              : currentSection == i
                  ? currentPaint
                  : brandPaint);
    }

    // Topic → its leaves: horizontal branch (topic.right → each leaf.left).
    final leafMidX = (topicRightX + leafLeftX) / 2;
    for (var i = 0; i < leafTops.length; i++) {
      if (leafTops[i].isEmpty) continue;
      final ty = topicTopY[i] + topicH / 2;
      final paint = completed.contains(i) ? donePaint : softPaint;
      for (final lt in leafTops[i]) {
        final ly = lt + leafH / 2;
        final p = Path()
          ..moveTo(topicRightX, ty)
          ..cubicTo(leafMidX, ty, leafMidX, ly, leafLeftX, ly);
        canvas.drawPath(p, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.completed != completed ||
      old.currentSection != currentSection ||
      old.topicTopY.length != topicTopY.length ||
      old.leafTops.length != leafTops.length;
}
