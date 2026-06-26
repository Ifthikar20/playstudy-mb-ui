import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/learning_models.dart';
import '../widgets/games_grid.dart';
import '../widgets/learning_tree_view.dart';
import '../widgets/quiz_view.dart';
import '../widgets/study_flow_view.dart';

/// Result page: floating Airbnb-style section selector (Study / Quiz / Games)
/// at the top instead of the standard Material TabBar.
class MaterialPage extends StatelessWidget {
  final LearningMaterial material;
  const MaterialPage({super.key, required this.material});

  void _openTree(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Learning tree')),
        body: _TreeProgressLoader(material: material),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          toolbarHeight: 48,
          titleSpacing: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          scrolledUnderElevation: 0,
          title: Text(
            material.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              tooltip: 'Learning tree',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.account_tree_rounded, size: 20),
              onPressed: () => _openTree(context),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: _FloatingSectionTabs(),
          ),
        ),
        body: TabBarView(
          children: [
            StudyFlowView(material: material),
            QuizView(questions: material.quiz, resumeKey: material.id),
            GamesGrid(material: material),
          ],
        ),
      ),
    );
  }
}

/// Floating pill holding the section tabs — same Airbnb look as the
/// bottom-nav: white background, soft shadow, the active section gets a
/// tinted pill highlight + label color.
class _FloatingSectionTabs extends StatelessWidget {
  const _FloatingSectionTabs();

  static const _tabs = <_SectionTab>[
    _SectionTab(icon: Icons.menu_book_rounded, label: 'Study'),
    _SectionTab(icon: Icons.quiz_rounded, label: 'Quiz'),
    _SectionTab(icon: Icons.videogame_asset_rounded, label: 'Games'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Container(
              height: 38,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    _PillTab(
                      label: _tabs[i].label,
                      active: controller.index == i,
                      activeColor: scheme.primary,
                      onTap: () => controller.animateTo(i),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionTab {
  final IconData icon;
  final String label;
  const _SectionTab({required this.icon, required this.label});
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _PillTab({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF6B6880),
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

/// Loads the saved study progress (the same SharedPreferences blob the study
/// flow writes) so the standalone tree view also shows completed (green) and
/// current (yellow) sections.
class _TreeProgressLoader extends StatefulWidget {
  final LearningMaterial material;
  const _TreeProgressLoader({required this.material});

  @override
  State<_TreeProgressLoader> createState() => _TreeProgressLoaderState();
}

class _TreeProgressLoaderState extends State<_TreeProgressLoader> {
  Set<int> _completed = const {};
  int? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.material.id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('study_progress_${widget.material.id}');
    if (raw == null || !mounted) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final completed =
          (data['completed'] as List?)?.cast<int>().toSet() ?? <int>{};
      final section = data['section'] as int?;
      setState(() {
        _completed = completed;
        _current = section;
      });
    } catch (_) {
      // Stored shape changed — show the tree without progress.
    }
  }

  @override
  Widget build(BuildContext context) {
    return LearningTreeView(
      material: widget.material,
      completed: _completed,
      currentSection: _current,
    );
  }
}
