import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../learning/data/models/learning_models.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';
import '../bloc/exam_prep_bloc.dart';

/// Multi-section, Airbnb-style plan creation:
///   1. Pick a study material — visual cards (not radios)
///   2. Name + date
///   3. Daily practice cadence (preset chips + fine-tune slider)
///   4. Topics to cover (chips with question counts, all selected by default)
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

  Map<String, int> _topicCounts(LearningMaterial m) {
    final counts = <String, int>{};
    for (final q in m.quiz) {
      final t = q.topic.trim().isEmpty ? 'General' : q.topic.trim();
      counts.update(t, (v) => v + 1, ifAbsent: () => 1);
    }
    // Make sure every topic in m.topics appears even with zero count.
    for (final t in m.topics) {
      counts.putIfAbsent(t.trim().isEmpty ? 'General' : t.trim(), () => 0);
    }
    return counts;
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
                  SizedBox(
                    height: 156,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      itemCount: library.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final m = library[i];
                        return _MaterialCard(
                          material: m,
                          selected: _material?.id == m.id,
                          onTap: () => _selectMaterial(m),
                        );
                      },
                    ),
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
                _InputCard(
                  child: TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Biology Midterm',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 10),
                _InputCard(
                  onTap: _pickDate,
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_today_rounded,
                          size: 18, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat.yMMMEd().format(_examDate),
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700)),
                          Text(
                            'Tap to change',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
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
                _CadencePresets(
                  value: _questionsPerDay,
                  onChange: (v) => setState(() => _questionsPerDay = v),
                ),
                const SizedBox(height: 10),
                _InputCard(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Fine-tune', style: theme.textTheme.bodySmall),
                        const Spacer(),
                        Text('$_questionsPerDay / day',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary)),
                      ]),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: theme.colorScheme.primary,
                          thumbColor: theme.colorScheme.primary,
                          overlayColor:
                              theme.colorScheme.primary.withOpacity(0.18),
                        ),
                        child: Slider(
                          value: _questionsPerDay.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          onChanged: (v) => setState(
                              () => _questionsPerDay = v.round()),
                        ),
                      ),
                    ],
                  ),
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
                    children: _topicCounts(_material!).entries.map((e) {
                      final selected = _topicsResolved.contains(e.key);
                      return _TopicChip(
                        label: e.key,
                        count: e.value,
                        selected: selected,
                        onTap: () => setState(() {
                          final current =
                              _selectedTopics ?? _material!.topics.toSet();
                          if (current.contains(e.key)) {
                            current.remove(e.key);
                          } else {
                            current.add(e.key);
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
          color: theme.colorScheme.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 19, color: theme.colorScheme.primary),
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

class _MaterialCard extends StatelessWidget {
  final LearningMaterial material;
  final bool selected;
  final VoidCallback onTap;
  const _MaterialCard({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 200,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: selected ? primary.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? primary : Colors.black.withOpacity(0.08),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withOpacity(0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, size: 17, color: primary),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? Container(
                          key: const ValueKey('on'),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16),
                        )
                      : const SizedBox(
                          key: ValueKey('off'), width: 24, height: 24),
                ),
              ]),
              const Spacer(),
              Text(
                material.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                _Pill(
                  label: '${material.quiz.length} Q',
                  color: primary,
                ),
                const SizedBox(width: 6),
                _Pill(
                  label: '${material.topics.length} topic${material.topics.length == 1 ? '' : 's'}',
                  color: theme.colorScheme.secondary,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _CadencePresets extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChange;
  const _CadencePresets({required this.value, required this.onChange});

  static const _presets = [
    (label: 'Light', count: 5, sub: '~5 min'),
    (label: 'Standard', count: 10, sub: '~10 min'),
    (label: 'Intense', count: 15, sub: '~15 min'),
    (label: 'Marathon', count: 25, sub: '~25 min'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Row(
      children: [
        for (var i = 0; i < _presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => onChange(_presets[i].count),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: value == _presets[i].count
                      ? primary.withOpacity(0.10)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: value == _presets[i].count
                        ? primary
                        : Colors.black.withOpacity(0.08),
                    width: value == _presets[i].count ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_presets[i].count}',
                      style: TextStyle(
                        color: value == _presets[i].count
                            ? primary
                            : theme.colorScheme.onSurface,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _presets[i].label,
                      style: TextStyle(
                        color: value == _presets[i].count
                            ? primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _TopicChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? primary.withOpacity(0.10) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primary : Colors.black.withOpacity(0.10),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 16,
              color: selected ? primary : Colors.black.withOpacity(0.35),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? primary : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (selected ? primary : Colors.black).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? primary : Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  const _InputCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Padding(padding: padding, child: child),
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
