import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../../family/data/family_repository.dart';
import '../../data/models/learning_models.dart';
import 'learning_tree_view.dart';

/// Guided, section-by-section study loop:
///   read the section's notes  ->  quiz just that section  ->  back to the
///   notes (now marked done)  ->  next section.
///
/// Sections are derived from the quiz `topic` tags (app-only, no backend
/// change). The flow leans on three encoding principles:
///   • pictorial   — each section has a visual anchor (emoji + colour);
///   • motoric     — tap to reveal, tap choices, tap to advance;
///   • elaborative — an "explain it back" prompt before the quiz, and the
///                   answer explanation after each question.
class StudyFlowView extends StatefulWidget {
  final LearningMaterial material;
  const StudyFlowView({super.key, required this.material});

  @override
  State<StudyFlowView> createState() => _StudyFlowViewState();
}

const _emojis = ['📘', '🧠', '💡', '🔬', '🧩', '📐', '🌍', '⚗️', '📊', '🎯'];

class _Section {
  final String title;
  final String emoji;
  final List<String> notes; // fallback bullets (old study sets)
  final String content; // readable chunk (new sectioned content)
  final String example; // real-world example ("Explain further")
  final List<QuizQuestion> questions;
  const _Section({
    required this.title,
    required this.emoji,
    required this.notes,
    this.content = '',
    this.example = '',
    required this.questions,
  });
}

class _StudyFlowViewState extends State<StudyFlowView> {
  late final List<_Section> _sections = _build();
  final Set<int> _completed = {};

  // Time tracking: a heartbeat every 15s credits the current section so the
  // parent analytics board can show how long was spent on each section.
  static const _hbSeconds = 15;
  Timer? _heartbeat;

  int _section = 0;
  bool _inQuiz = false;

  @override
  void initState() {
    super.initState();
    _heartbeat = Timer.periodic(const Duration(seconds: _hbSeconds), _tick);
    _restore();
  }

  String get _progressKey => 'study_progress_${widget.material.id}';

  Future<void> _restore() async {
    if (widget.material.id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null || !mounted) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedSection =
          (data['section'] as int?)?.clamp(0, _sections.length - 1) ?? 0;
      final savedCompleted = (data['completed'] as List?)
              ?.cast<int>()
              .where((i) => i >= 0 && i < _sections.length) ??
          const <int>[];
      setState(() {
        _section = savedSection;
        _completed
          ..clear()
          ..addAll(savedCompleted);
      });
    } catch (_) {
      // Stored shape changed — ignore and start fresh.
    }
  }

  Future<void> _save() async {
    if (widget.material.id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _progressKey,
      jsonEncode({
        'section': _section,
        'completed': _completed.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }),
    );
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    super.dispose();
  }

  void _tick(Timer _) {
    final m = widget.material;
    if (!mounted || m.sections.isEmpty || m.id.isEmpty) return;
    context
        .read<FamilyRepository>()
        .heartbeat(
          studySetId: m.id,
          sectionIndex: _section,
          sectionTitle: _cur.title,
          seconds: _hbSeconds,
        )
        .catchError((_) {}); // progress logging must never disrupt studying
  }

  // Per-section quiz state.
  int _qIndex = 0;
  int _qScore = 0;
  int? _selected;
  bool _revealed = false;
  bool _quizDone = false;

  List<_Section> _build() {
    final m = widget.material;

    // Preferred: server-provided sections (fuller content + example + quiz).
    if (m.sections.isNotEmpty) {
      return [
        for (var i = 0; i < m.sections.length; i++)
          _Section(
            title: m.sections[i].title,
            emoji: _emojis[i % _emojis.length],
            notes: const [],
            content: m.sections[i].content,
            example: m.sections[i].example,
            questions: m.sections[i].quiz,
          ),
      ];
    }

    // Fallback (older study sets without sections): group by quiz topic.
    final order = <String>[];
    final byTopic = <String, List<QuizQuestion>>{};
    for (final q in m.quiz) {
      byTopic.putIfAbsent(q.topic, () {
        order.add(q.topic);
        return [];
      }).add(q);
    }

    if (order.isEmpty) {
      // No quiz — still let the learner read the material as one section.
      final notes = m.keyPoints.isNotEmpty
          ? m.keyPoints
          : (m.summary.trim().isNotEmpty ? [m.summary.trim()] : <String>[]);
      return [
        _Section(title: 'Summary', emoji: _emojis[0], notes: notes, questions: const []),
      ];
    }

    return [
      for (var i = 0; i < order.length; i++)
        _Section(
          title: order[i],
          emoji: _emojis[i % _emojis.length],
          notes: _notesFor(order[i]),
          questions: byTopic[order[i]]!,
        ),
    ];
  }

  // Best-effort notes for a topic from the untagged key points; fall back to
  // the overview so a section is never empty.
  List<String> _notesFor(String topic) {
    final m = widget.material;
    final t = topic.toLowerCase();
    final tokens =
        t.split(RegExp(r'\s+')).where((w) => w.length >= 4).toList();
    final matched = m.keyPoints.where((k) {
      final kl = k.toLowerCase();
      return kl.contains(t) || tokens.any((w) => kl.contains(w));
    }).toList();
    if (matched.isNotEmpty) return matched;
    if (m.summary.trim().isNotEmpty) return [m.summary.trim()];
    return m.keyPoints;
  }

  _Section get _cur => _sections[_section];

  void _startQuiz() {
    if (_cur.questions.isEmpty) return;
    setState(() {
      _inQuiz = true;
      _qIndex = 0;
      _qScore = 0;
      _selected = null;
      _revealed = false;
      _quizDone = false;
    });
  }

  void _choose(int i) {
    if (_revealed) return;
    setState(() {
      _selected = i;
      _revealed = true;
      if (i == _cur.questions[_qIndex].correctIndex) _qScore++;
    });
  }

  void _nextQuestion() {
    if (_qIndex + 1 < _cur.questions.length) {
      setState(() {
        _qIndex++;
        _selected = null;
        _revealed = false;
      });
    } else {
      setState(() {
        _quizDone = true;
        _completed.add(_section);
      });
      _save();
      context.read<RewardsBloc>().add(RecordActivity(
            points: 5 + _qScore * 5,
            reason: 'Finished a quiz',
            context: {
              'score': _qScore,
              'total': _cur.questions.length,
              'section': _cur.title,
            },
          ));
      // Record section completion + score for the parent analytics board.
      final m = widget.material;
      if (m.sections.isNotEmpty && m.id.isNotEmpty) {
        context
            .read<FamilyRepository>()
            .completeSection(
              studySetId: m.id,
              sectionIndex: _section,
              sectionTitle: _cur.title,
              correct: _qScore,
              total: _cur.questions.length,
            )
            .catchError((_) {});
      }
    }
  }

  void _backToNotes() => setState(() => _inQuiz = false);

  void _nextSection() {
    if (_section + 1 < _sections.length) {
      setState(() {
        _section++;
        _inQuiz = false;
      });
      _save();
    }
  }

  void _showTree() {
    // Use the full graphical tree when the set has server sections; otherwise
    // fall back to the simple list (older sets derived from quiz topics).
    if (widget.material.sections.isNotEmpty) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (treeCtx) => Scaffold(
          appBar: AppBar(title: const Text('Learning tree')),
          body: LearningTreeView(
            material: widget.material,
            completed: _completed,
            currentSection: _section,
            onJumpToSection: (i) {
              Navigator.of(treeCtx).pop();
              if (mounted) {
                setState(() {
                  _section = i;
                  _inQuiz = false;
                });
                _save();
              }
            },
          ),
        ),
      ));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _LearningTree(
        titles: _sections.map((s) => s.title).toList(),
        emojis: _sections.map((s) => s.emoji).toList(),
        completed: _completed,
        current: _section,
        onJump: (i) {
          Navigator.of(sheetCtx).pop();
          if (mounted) {
            setState(() {
              _section = i;
              _inQuiz = false;
            });
            _save();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_sections.isEmpty) {
      return Center(child: Text('No material yet', style: theme.textTheme.bodyMedium));
    }
    return Column(
      children: [
        _Header(
          section: _section,
          total: _sections.length,
          title: _cur.title,
          done: _completed.contains(_section),
          completedCount: _completed.length,
        ),
        Expanded(
          child: _inQuiz
              ? _QuizPane(
                  section: _cur,
                  qIndex: _qIndex,
                  selected: _selected,
                  revealed: _revealed,
                  score: _qScore,
                  done: _quizDone,
                  isLastSection: _section + 1 >= _sections.length,
                  onChoose: _choose,
                  onNext: _nextQuestion,
                  onBackToNotes: _backToNotes,
                  onNextSection: _nextSection,
                )
              : _NotesPane(
                  section: _cur,
                  completed: _completed.contains(_section),
                  keyTerms: widget.material.wordGame.map((w) => w.word).toList(),
                  onStartQuiz: _cur.questions.isEmpty ? null : _startQuiz,
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int section;
  final int total;
  final String title;
  final bool done;
  final int completedCount;
  const _Header({
    required this.section,
    required this.total,
    required this.title,
    required this.done,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${section + 1}/$total',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (done)
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : completedCount / total,
              minHeight: 3,
              backgroundColor: theme.dividerColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Graphical progress map: a vertical tree of section nodes showing what's done,
/// where you are, and how much is left.
class _LearningTree extends StatelessWidget {
  final List<String> titles;
  final List<String> emojis;
  final Set<int> completed;
  final int current;
  final ValueChanged<int> onJump;
  const _LearningTree({
    required this.titles,
    required this.emojis,
    required this.completed,
    required this.current,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = titles.length;
    final doneCount = completed.length;
    final left = total - doneCount;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.account_tree, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Learning tree', style: theme.textTheme.titleLarge),
              const Spacer(),
              Text('$doneCount done • $left left', style: theme.textTheme.bodySmall),
            ]),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < total; i++)
                      _TreeNode(
                        index: i,
                        title: titles[i],
                        emoji: emojis[i],
                        isDone: completed.contains(i),
                        isCurrent: i == current,
                        isLast: i == total - 1,
                        onTap: () => onJump(i),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeNode extends StatelessWidget {
  final int index;
  final String title;
  final String emoji;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;
  final VoidCallback onTap;
  const _TreeNode({
    required this.index,
    required this.title,
    required this.emoji,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodeColor = isDone
        ? Colors.green
        : isCurrent
            ? theme.colorScheme.primary
            : theme.dividerColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDone || isCurrent ? nodeColor : theme.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: nodeColor, width: 2),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text('${index + 1}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isCurrent ? Colors.white : null)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: theme.dividerColor),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 14),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isCurrent ? FontWeight.w700 : null,
                            color: isCurrent ? theme.colorScheme.primary : null,
                          )),
                    ),
                    if (isCurrent)
                      Text('you are here', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesPane extends StatelessWidget {
  final _Section section;
  final bool completed;
  final List<String> keyTerms;
  final VoidCallback? onStartQuiz;
  const _NotesPane({
    required this.section,
    required this.completed,
    required this.keyTerms,
    required this.onStartQuiz,
  });

  /// Build a TextSpan where any key term is bolded/coloured (case-insensitive).
  TextSpan _highlight(String text, ThemeData theme) {
    final terms = keyTerms
        .map((t) => t.trim())
        .where((t) => t.length >= 3)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final base = theme.textTheme.bodyLarge?.copyWith(height: 1.55);
    if (terms.isEmpty) return TextSpan(text: text, style: base);
    final pattern = RegExp(
        r'\b(' + terms.map(RegExp.escape).join('|') + r')\b',
        caseSensitive: false);
    final spans = <TextSpan>[];
    var i = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > i) spans.add(TextSpan(text: text.substring(i, m.start)));
      spans.add(TextSpan(
        text: text.substring(m.start, m.end),
        style: TextStyle(
            fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
      ));
      i = m.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return TextSpan(style: base, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Split the content into paragraph "sub-sections".
    final paras = section.content
        .split(RegExp(r'\n\s*\n|\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return Column(
      children: [
        Expanded(
          // The slim _Header above already shows the section title — no need
          // to repeat it here. Use a plain ListView with tight paddings so
          // the body is mostly content.
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            children: [
              // Plain text body — paragraphs only, no card chrome.
              for (final para in paras)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(height: 1.5, fontSize: 15),
                    child: RichText(text: _highlight(para, theme)),
                  ),
                ),
              // Fallback bullets for older sets without section content.
              for (final note in section.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: theme.colorScheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(note,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(height: 1.45)),
                        ),
                      ],
                    ),
                  ),
                ),
              // "Further understanding" — a real-world example or a key
              // term explained, so the reader has something concrete to
               // anchor the section's ideas to.
              if (section.example.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.lightbulb_outline,
                            size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Further understanding',
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.2),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        section.example,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(height: 1.45, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStartQuiz,
              icon: const Icon(Icons.quiz_outlined),
              label: Text(onStartQuiz == null
                  ? 'No quiz for this section'
                  : (completed ? 'Retake section quiz' : 'Quiz this section')),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizPane extends StatelessWidget {
  final _Section section;
  final int qIndex;
  final int? selected;
  final bool revealed;
  final int score;
  final bool done;
  final bool isLastSection;
  final ValueChanged<int> onChoose;
  final VoidCallback onNext;
  final VoidCallback onBackToNotes;
  final VoidCallback onNextSection;

  const _QuizPane({
    required this.section,
    required this.qIndex,
    required this.selected,
    required this.revealed,
    required this.score,
    required this.done,
    required this.isLastSection,
    required this.onChoose,
    required this.onNext,
    required this.onBackToNotes,
    required this.onNextSection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (done) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('✅', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text('Section complete', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('You scored $score / ${section.questions.length}',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              _PointsBurst(points: 5 + score * 5),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onBackToNotes,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Back to notes'),
                ),
              ),
              const SizedBox(height: 10),
              if (!isLastSection)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onNextSection,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next section'),
                  ),
                )
              else
                Text('That was the last section. Great work! 🎉',
                    style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    final q = section.questions[qIndex];
    final total = section.questions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${qIndex + 1}/$total',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            _DifficultyBadge(difficulty: q.difficulty),
            const Spacer(),
            TextButton.icon(
              onPressed: onBackToNotes,
              icon: const Icon(Icons.menu_book_outlined, size: 16),
              label: const Text('Notes'),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            q.prompt,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Compact answer tiles — natural height (~46px each). Scrolls only
          // if the choice list is unusually long.
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < q.choices.length; i++) ...[
                    _AnswerTile(
                      letter: String.fromCharCode(65 + i),
                      text: q.choices[i],
                      isCorrect: i == q.correctIndex,
                      isPicked: i == selected,
                      revealed: revealed,
                      onTap: () => onChoose(i),
                    ),
                    if (i != q.choices.length - 1)
                      const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
          if (revealed && q.explanation != null && q.explanation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Why: ${q.explanation!}',
                  style: theme.textTheme.bodySmall),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: revealed ? onNext : null,
              child: Text(qIndex + 1 == total ? 'Finish section' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool isCorrect;
  final bool isPicked;
  final bool revealed;
  final VoidCallback onTap;
  const _AnswerTile({
    required this.letter,
    required this.text,
    required this.isCorrect,
    required this.isPicked,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? bg;
    Color border = theme.dividerColor;
    if (revealed) {
      if (isCorrect) {
        bg = Colors.green.withOpacity(0.12);
        border = Colors.green;
      } else if (isPicked) {
        bg = Colors.red.withOpacity(0.10);
        border = Colors.red;
      }
    }
    return Material(
      color: bg ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(letter,
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              // FittedBox auto-shrinks long answers so they always fit on
              // one line at the tile's fixed height.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 3,
                  ),
                ),
              ),
            ),
            if (revealed && isCorrect)
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
            if (revealed && isPicked && !isCorrect)
              const Icon(Icons.cancel, color: Colors.red, size: 18),
          ]),
        ),
      ),
    );
  }
}

/// Celebratory "+N points" pill that pops in when a milestone is reached.
class _PointsBurst extends StatelessWidget {
  final int points;
  const _PointsBurst({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      tween: Tween(begin: 0, end: 1),
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6B5CE7), Color(0xFF9D8DFA)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B5CE7).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bolt, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          Text('+$points points',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final QuizDifficulty difficulty;
  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (difficulty) {
      QuizDifficulty.easy => (const Color(0xFF22C55E), 'Easy'),
      QuizDifficulty.medium => (const Color(0xFFF59E0B), 'Medium'),
      QuizDifficulty.hard => (const Color(0xFFEF4444), 'Challenge'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.45), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3),
      ),
    );
  }
}
