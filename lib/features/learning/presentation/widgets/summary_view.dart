import 'package:flutter/material.dart';
import '../../data/models/learning_models.dart';

/// Paginated summary: swipe (or use Back/Next) to move section by section —
/// the overview first (split into pages when long), then each key point.
class SummaryView extends StatefulWidget {
  final LearningMaterial material;
  const SummaryView({super.key, required this.material});

  @override
  State<SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends State<SummaryView> {
  final _controller = PageController();
  int _index = 0;
  late final List<_SummaryPage> _pages = _build();

  List<_SummaryPage> _build() {
    final m = widget.material;
    final pages = <_SummaryPage>[];

    // Overview: break a long summary into paragraph-sized pages.
    final paras = m.summary
        .split(RegExp(r'\n\s*\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (paras.isEmpty && m.summary.trim().isNotEmpty) {
      paras.add(m.summary.trim());
    }
    for (var i = 0; i < paras.length; i++) {
      pages.add(_SummaryPage(
        icon: Icons.auto_awesome_rounded,
        title: paras.length > 1 ? 'Overview (${i + 1}/${paras.length})' : 'Overview',
        body: paras[i],
      ));
    }

    // One page per key point.
    for (var i = 0; i < m.keyPoints.length; i++) {
      pages.add(_SummaryPage(
        icon: Icons.lightbulb_outline_rounded,
        title: 'Key point ${i + 1}',
        body: m.keyPoints[i],
      ));
    }
    return pages;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int i) => _controller.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_pages.isEmpty) {
      return Center(
        child: Text('No summary available', style: theme.textTheme.bodyMedium),
      );
    }
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _PageCard(
              page: _pages[i],
              index: i,
              total: _pages.length,
            ),
          ),
        ),
        _Footer(
          index: _index,
          total: _pages.length,
          sourceRef: widget.material.sourceRef,
          onPrev: _index > 0 ? () => _go(_index - 1) : null,
          onNext: _index < _pages.length - 1 ? () => _go(_index + 1) : null,
        ),
      ],
    );
  }
}

class _SummaryPage {
  final IconData icon;
  final String title;
  final String body;
  const _SummaryPage({required this.icon, required this.title, required this.body});
}

class _PageCard extends StatelessWidget {
  final _SummaryPage page;
  final int index;
  final int total;
  const _PageCard({required this.page, required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: SizedBox.expand(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(page.icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(page.title, style: theme.textTheme.titleLarge),
                  ),
                  Text('${index + 1} / $total', style: theme.textTheme.bodySmall),
                ]),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      page.body,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                    ),
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

class _Footer extends StatelessWidget {
  final int index;
  final int total;
  final String sourceRef;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Footer({
    required this.index,
    required this.total,
    required this.sourceRef,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : (index + 1) / total,
              minHeight: 4,
              backgroundColor: theme.dividerColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onPrev,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                label: const Text('Back'),
              ),
              const Spacer(),
              Text('Page ${index + 1} of $total', style: theme.textTheme.bodySmall),
              const Spacer(),
              TextButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                label: const Text('Next'),
              ),
            ],
          ),
          if (sourceRef.isNotEmpty)
            Text(
              'Source: $sourceRef',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
