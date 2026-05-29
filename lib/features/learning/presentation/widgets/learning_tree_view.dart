import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/learning_models.dart';

/// A graphical, pannable learning tree built from a study set:
///   study set (root) -> topics (sections) -> sub-topics (paragraphs)
///   -> sub-sub-topics (key terms).
/// Topic nodes show how many questions they have + completion; related topics
/// (sharing a key term) are joined with a dashed line. Tap a topic to jump.
class LearningTreeView extends StatelessWidget {
  final LearningMaterial material;
  final Set<int> completed;
  final ValueChanged<int>? onJumpToSection;
  const LearningTreeView({
    super.key,
    required this.material,
    this.completed = const {},
    this.onJumpToSection,
  });

  // ---- Build a flat, ordered node list + parent links + related pairs ----
  _TreeData _build() {
    final nodes = <_Node>[];
    final terms = material.wordGame
        .map((w) => w.word.toUpperCase())
        .where((w) => w.length >= 3)
        .toList();

    nodes.add(_Node(
      depth: 0,
      kind: _Kind.root,
      label: material.title.isEmpty ? 'Study set' : material.title,
      parent: -1,
    ));
    final rootRow = 0;

    final topicRow = <int>[]; // section index -> row
    final topicTerms = <Set<String>>[];

    for (var si = 0; si < material.sections.length; si++) {
      final sec = material.sections[si];
      final done = completed.contains(si);
      final topicIdx = nodes.length;
      topicRow.add(topicIdx);
      nodes.add(_Node(
        depth: 1,
        kind: _Kind.topic,
        label: sec.title.isEmpty ? 'Topic ${si + 1}' : sec.title,
        parent: rootRow,
        sectionIndex: si,
        done: done,
        qTotal: sec.quiz.length,
        qDone: done ? sec.quiz.length : 0,
      ));

      final contentUpper = sec.content.toUpperCase();
      topicTerms.add(terms.where(contentUpper.contains).toSet());

      // Sub-topics = paragraphs of the section content.
      final paras = sec.content
          .split(RegExp(r'\n\s*\n|\n'))
          .map((p) => p.trim())
          .where((p) => p.length > 12)
          .take(4)
          .toList();
      for (final p in paras) {
        final subIdx = nodes.length;
        nodes.add(_Node(
          depth: 2,
          kind: _Kind.sub,
          label: _short(p, 6),
          parent: topicIdx,
        ));
        // Sub-sub-topics = key terms appearing in this paragraph.
        final pu = p.toUpperCase();
        for (final t in terms.where(pu.contains).take(3)) {
          nodes.add(_Node(
            depth: 3,
            kind: _Kind.leaf,
            label: _titleCase(t),
            parent: subIdx,
          ));
        }
      }
    }

    // Related topics: share at least one key term.
    final related = <List<int>>[];
    for (var a = 0; a < topicTerms.length; a++) {
      for (var b = a + 1; b < topicTerms.length; b++) {
        if (topicTerms[a].intersection(topicTerms[b]).isNotEmpty) {
          related.add([topicRow[a], topicRow[b]]);
        }
      }
    }
    return _TreeData(nodes, related);
  }

  static String _short(String s, int words) {
    final parts = s.split(RegExp(r'\s+'));
    final out = parts.take(words).join(' ');
    return parts.length > words ? '$out…' : out;
  }

  static String _titleCase(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _build();
    if (data.nodes.length <= 1) {
      return Center(
        child: Text('No topics to map yet', style: theme.textTheme.bodyMedium),
      );
    }
    const rowH = 60.0;
    final height = data.nodes.length * rowH + 32;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, 320.0);
        return InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          minScale: 0.6,
          maxScale: 2.5,
          boundaryMargin: const EdgeInsets.all(80),
          constrained: false,
          child: GestureDetector(
            onTapUp: (d) {
              final row = (d.localPosition.dy ~/ rowH);
              if (row < 0 || row >= data.nodes.length) return;
              final n = data.nodes[row];
              if (n.kind == _Kind.topic && onJumpToSection != null) {
                onJumpToSection!(n.sectionIndex);
              }
            },
            child: CustomPaint(
              size: Size(width, height),
              painter: _TreePainter(
                data: data,
                rowH: rowH,
                theme: theme,
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _Kind { root, topic, sub, leaf }

class _Node {
  final int depth;
  final _Kind kind;
  final String label;
  final int parent;
  final int sectionIndex;
  final bool done;
  final int qTotal;
  final int qDone;
  const _Node({
    required this.depth,
    required this.kind,
    required this.label,
    required this.parent,
    this.sectionIndex = -1,
    this.done = false,
    this.qTotal = 0,
    this.qDone = 0,
  });
}

class _TreeData {
  final List<_Node> nodes;
  final List<List<int>> related; // pairs of topic row indices
  const _TreeData(this.nodes, this.related);
}

class _TreePainter extends CustomPainter {
  final _TreeData data;
  final double rowH;
  final ThemeData theme;
  _TreePainter({required this.data, required this.rowH, required this.theme});

  static const _leftPad = 16.0;
  static const _indent = 24.0;

  double _nodeX(int depth) => _leftPad + depth * _indent;
  double _rowY(int row) => row * rowH + rowH / 2 + 12;

  @override
  void paint(Canvas canvas, Size size) {
    final divider = theme.dividerColor;
    final primary = theme.colorScheme.primary;
    final accent = theme.colorScheme.tertiary;

    // 1) Solid hierarchy connectors (parent -> child elbow).
    final line = Paint()
      ..color = divider
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < data.nodes.length; i++) {
      final n = data.nodes[i];
      if (n.parent < 0) continue;
      final cx = _nodeX(n.depth);
      final cy = _rowY(i);
      final px = _nodeX(data.nodes[n.parent].depth) + 10;
      final py = _rowY(n.parent);
      final branchX = cx - 11;
      final path = Path()
        ..moveTo(branchX, py)
        ..lineTo(branchX, cy)
        ..lineTo(cx, cy);
      canvas.drawPath(path, line);
    }

    // 2) Dashed "related topics" lines (bowing into the left gutter).
    final dashed = Paint()
      ..color = accent.withOpacity(0.8)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (final pair in data.related) {
      final y1 = _rowY(pair[0]);
      final y2 = _rowY(pair[1]);
      final x = _nodeX(1);
      final mid = (y1 + y2) / 2;
      final path = Path()
        ..moveTo(x - 4, y1)
        ..quadraticBezierTo(2, mid, x - 4, y2);
      _drawDashed(canvas, path, dashed);
    }

    // 3) Nodes.
    for (var i = 0; i < data.nodes.length; i++) {
      _drawNode(canvas, size, i, data.nodes[i], primary, accent, divider);
    }
  }

  void _drawNode(Canvas canvas, Size size, int row, _Node n, Color primary,
      Color accent, Color divider) {
    final x = _nodeX(n.depth);
    final y = _rowY(row);
    final h = rowH - 18;
    final right = size.width - 12;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(x, y - h / 2, right, y + h / 2),
      const Radius.circular(12),
    );

    Color fill;
    switch (n.kind) {
      case _Kind.root:
        fill = primary.withOpacity(0.14);
        break;
      case _Kind.topic:
        fill = n.done ? const Color(0x3322C55E) : primary.withOpacity(0.06);
        break;
      case _Kind.sub:
        fill = theme.cardColor;
        break;
      case _Kind.leaf:
        fill = accent.withOpacity(0.08);
        break;
    }
    canvas.drawRRect(rect, Paint()..color = fill);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = n.done ? const Color(0xFF22C55E) : divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = n.kind == _Kind.topic ? 1.5 : 1,
    );

    // Bullet / status dot.
    final dotC = n.kind == _Kind.root
        ? primary
        : n.kind == _Kind.topic
            ? (n.done ? const Color(0xFF22C55E) : primary)
            : n.kind == _Kind.sub
                ? divider
                : accent;
    canvas.drawCircle(Offset(x + 14, y), 5, Paint()..color = dotC);

    // Right badge for topics: questions + completion check.
    var labelRight = right - 10;
    if (n.kind == _Kind.topic && n.qTotal > 0) {
      final badge = '${n.qDone}/${n.qTotal} Q';
      final tp = _text(badge, 11, FontWeight.w700,
          n.done ? const Color(0xFF16A34A) : primary);
      tp.layout();
      tp.paint(canvas, Offset(right - 12 - tp.width, y - tp.height / 2));
      labelRight = right - 18 - tp.width;
    }

    // Label.
    final style = n.kind == _Kind.root || n.kind == _Kind.topic
        ? FontWeight.w700
        : FontWeight.w500;
    final color = n.kind == _Kind.leaf
        ? accent
        : (theme.textTheme.bodyLarge?.color ?? Colors.black);
    final maxW = (labelRight - (x + 26)).clamp(40.0, size.width);
    final tp = _text(n.label, n.kind == _Kind.root ? 15 : 13.5, style, color,
        maxWidth: maxW);
    tp.layout(maxWidth: maxW);
    tp.paint(canvas, Offset(x + 26, y - tp.height / 2));
  }

  TextPainter _text(String s, double size, FontWeight w, Color c,
      {double? maxWidth}) {
    return TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(fontSize: size, fontWeight: w, color: c)),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    );
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint,
      {double dash = 6, double gap = 4}) {
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = math.min(dist + dash, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) =>
      old.data != data || old.rowH != rowH;
}
