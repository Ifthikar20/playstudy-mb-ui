import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../learning/data/models/learning_models.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';
import '../bloc/exam_prep_bloc.dart';

/// Multi-section, Airbnb-style plan creation:
///   1. Pick a study material — a simple scrollable list of sets
///   2. Name + date — light inputs, no heavy boxes
///   3. Questions per day — one scrollable number picker (1–30)
///   4. Topics to cover (plain chips, all selected by default)
///
/// Submits via [ExamPrepBloc.CreatePlan].
class CreatePlanPage extends StatefulWidget {
  const CreatePlanPage({super.key});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  LearningMaterial? _material;
  final _titleCtrl = TextEditingController();
  DateTime _examDate = DateTime.now().add(const Duration(days: 14));
  int _questionsPerDay = 10;
  // Default: every topic selected. Switches to a fixed set only when the user
  // unchecks at least one chip.
  Set<String>? _selectedTopics;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  void _selectMaterial(LearningMaterial m) {
    setState(() {
      _material = m;
      _selectedTopics = null; // reset to "all" on material change
      if (_titleCtrl.text.trim().isEmpty) {
        // Helpful default — user can edit.
        _titleCtrl.text = m.title;
      }
    });
  }

  Set<String> get _topicsResolved {
    if (_material == null) return const {};
    return _selectedTopics ?? _material!.topics.toSet();
  }

  /// The section's topics, de-duplicated and with blanks dropped — shown as
  /// simple selectable chips (no confusing per-topic numbers).
  List<String> _displayTopics(LearningMaterial m) {
    final seen = <String>{};
    final out = <String>[];
    for (final t in m.topics) {
      final v = t.trim();
      if (v.isEmpty || !seen.add(v)) continue;
      out.add(v);
    }
    return out;
  }

  bool get _canSubmit =>
      _material != null && _titleCtrl.text.trim().isNotEmpty;

  void _save() {
    if (_material == null) {
      _toast('Pick a study set first');
      return;
    }
    final name = _titleCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Give your exam a name');
      return;
    }
    final topics = _topicsResolved.toList();
    context.read<ExamPrepBloc>().add(CreatePlan(
          materialId: _material!.id,
          materialTitle: _material!.title,
          examTitle: name,
          examDate: _examDate,
          questionsPerDay: _questionsPerDay,
          topics: topics,
        ));
    context.go('/exam');
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LearningBloc>().state.library;
    final daysUntil = DateTime(_examDate.year, _examDate.month, _examDate.day)
        .difference(DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day))
        .inDays;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('New exam plan'),
        backgroundColor: theme.colorScheme.surface,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                // ── Section 1: Study material ─────────────────────────────
                _SectionHeader(
                  step: 1,
                  title: 'Choose your study material',
                  subtitle:
                      '${library.length} set${library.length == 1 ? '' : 's'} in your library',
                  icon: Icons.auto_stories_rounded,
                ),
                const SizedBox(height: 12),
                if (library.isEmpty)
                  _EmptyLibraryPrompt(onCreate: () => context.go('/new'))
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < library.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _MaterialRow(
                          material: library[i],
                          selected: _material?.id == library[i].id,
                          onTap: () => _selectMaterial(library[i]),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 28),

                // ── Section 2: Exam name + date ──────────────────────────
                _SectionHeader(
                  step: 2,
                  title: 'Name it & set a date',
                  subtitle: daysUntil > 0
                      ? '$daysUntil day${daysUntil == 1 ? '' : 's'} to prepare'
                      : 'Exam date is today',
                  icon: Icons.event_rounded,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Biology Midterm',
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(DateFormat.yMMMEd().format(_examDate),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      Text('Change',
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant)),
                    ]),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Section 3: Daily practice cadence ────────────────────
                _SectionHeader(
                  step: 3,
                  title: 'How often do you want to practice?',
                  subtitle:
                      '$_questionsPerDay question${_questionsPerDay == 1 ? '' : 's'} every day',
                  icon: Icons.bolt_rounded,
                ),
                const SizedBox(height: 12),
                _QuestionsSelector(
                  value: _questionsPerDay,
                  onChange: (v) => setState(() => _questionsPerDay = v),
                ),
                const SizedBox(height: 28),

                // ── Section 4: Topics ────────────────────────────────────
                _SectionHeader(
                  step: 4,
                  title: 'Topics you want to cover',
                  subtitle: _material == null
                      ? 'Pick a study set first'
                      : '${_topicsResolved.length} of ${_material!.topics.length} selected',
                  icon: Icons.checklist_rounded,
                  trailing: _material == null
                      ? null
                      : Row(children: [
                          TextButton(
                            onPressed: () => setState(() => _selectedTopics =
                                _material!.topics.toSet()),
                            child: const Text('All'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedTopics = <String>{}),
                            child: const Text('Clear'),
                          ),
                        ]),
                ),
                const SizedBox(height: 8),
                if (_material == null)
                  _HintLine(
                      text: 'Topic chips appear here once you pick material.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _displayTopics(_material!).map((label) {
                      final selected = _topicsResolved.contains(label);
                      return _TopicChip(
                        label: label,
                        selected: selected,
                        onTap: () => setState(() {
                          final current =
                              _selectedTopics ?? _material!.topics.toSet();
                          if (current.contains(label)) {
                            current.remove(label);
                          } else {
                            current.add(label);
                          }
                          _selectedTopics = current;
                        }),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          // ── Sticky bottom CTA ───────────────────────────────────────────
          _SubmitBar(
            enabled: _canSubmit,
            summary: _summary(),
            onSubmit: _save,
          ),
        ]),
      ),
    );
  }

  String _summary() {
    if (_material == null) return 'Pick a study set to continue';
    final topics = _topicsResolved.length;
    return '$_questionsPerDay Q/day · $topics topic${topics == 1 ? '' : 's'} · '
        '${DateFormat.MMMd().format(_examDate)}';
  }
}

// ───────────────────────────────────────────────────────────────────────
// Helpers below — all private to this page.
// ───────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  const _SectionHeader({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 19, color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$step.  $title',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

class _MaterialRow extends StatelessWidget {
  final LearningMaterial material;
  final bool selected;
  final VoidCallback onTap;
  const _MaterialRow({
    required this.material,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon {
    switch (material.sourceKind) {
      case SourceKind.link:
        return Icons.link_rounded;
      case SourceKind.file:
        return Icons.description_rounded;
      case SourceKind.text:
        return Icons.text_snippet_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final topics = material.topics.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? primary : Colors.black.withOpacity(0.08),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(_icon,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${material.quiz.length} questions · $topics topic${topics == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 22,
              color: selected ? primary : Colors.black.withOpacity(0.25),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Horizontal, scrollable number picker for "questions per day" (1–30). One
/// dark pill marks the choice — no preset tiers, no slider, and no purple.
class _QuestionsSelector extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChange;
  const _QuestionsSelector({required this.value, required this.onChange});

  @override
  State<_QuestionsSelector> createState() => _QuestionsSelectorState();
}

class _QuestionsSelectorState extends State<_QuestionsSelector> {
  static const int _min = 1;
  static const int _max = 30;
  static const double _extent = 56.0; // pill width (48) + gap (8)

  late final ScrollController _ctrl = ScrollController(
    initialScrollOffset: (((widget.value - _min) * _extent) - 90)
        .clamp(0.0, (_max - _min) * _extent),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const ink = Color(0xFF1A1A2E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            controller: _ctrl,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: _max - _min + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final n = _min + i;
              final sel = n == widget.value;
              return GestureDetector(
                onTap: () => widget.onChange(n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? ink : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel ? ink : Colors.black.withOpacity(0.10),
                    ),
                  ),
                  child: Text(
                    '$n',
                    style: TextStyle(
                      color:
                          sel ? Colors.white : theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scroll to choose · about ${widget.value} min a day',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const ink = Color(0xFF1A1A2E);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? ink.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? ink.withOpacity(0.45)
                  : Colors.black.withOpacity(0.10),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 16,
              color: selected ? ink : Colors.black.withOpacity(0.35),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? ink : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  final String text;
  const _HintLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
    );
  }
}

class _EmptyLibraryPrompt extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyLibraryPrompt({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(children: [
        Icon(Icons.auto_stories_rounded,
            size: 38, color: theme.colorScheme.primary),
        const SizedBox(height: 10),
        Text('No study sets yet',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text("Create one to start preparing for your exam.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Create your first study set'),
        ),
      ]),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final bool enabled;
  final String summary;
  final VoidCallback onSubmit;
  const _SubmitBar({
    required this.enabled,
    required this.summary,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(summary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: enabled ? onSubmit : null,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    theme.colorScheme.primary.withOpacity(0.32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
                elevation: 0,
              ),
              child: const Text('Create exam plan'),
            ),
          ),
        ],
      ),
    );
  }
}
