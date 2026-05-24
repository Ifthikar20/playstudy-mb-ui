import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../data/models/learning_models.dart';

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
  final List<String> notes;
  final List<QuizQuestion> questions;
  const _Section({
    required this.title,
    required this.emoji,
    required this.notes,
    required this.questions,
  });
}

class _StudyFlowViewState extends State<StudyFlowView> {
  late final List<_Section> _sections = _build();
  final Set<int> _completed = {};

  int _section = 0;
  bool _inQuiz = false;

  // Per-section quiz state.
  int _qIndex = 0;
  int _qScore = 0;
  int? _selected;
  bool _revealed = false;
  bool _quizDone = false;

  List<_Section> _build() {
    final m = widget.material;

    // Group questions by their topic tag, preserving first-seen order.
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
      context.read<RewardsBloc>().add(RecordActivity(
            points: 5 + _qScore * 5,
            reason: 'Finished a quiz',
            context: {
              'score': _qScore,
              'total': _cur.questions.length,
              'section': _cur.title,
            },
          ));
    }
  }

  void _backToNotes() => setState(() => _inQuiz = false);

  void _nextSection() {
    if (_section + 1 < _sections.length) {
      setState(() {
        _section++;
        _inQuiz = false;
      });
    }
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
          emoji: _cur.emoji,
          done: _completed.contains(_section),
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
  final String emoji;
  final bool done;
  const _Header({
    required this.section,
    required this.total,
    required this.title,
    required this.emoji,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Section ${section + 1} of $total',
                      style: theme.textTheme.bodySmall),
                  Text(title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (done) const Icon(Icons.check_circle, color: Colors.green),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (section + 1) / total,
              minHeight: 4,
              backgroundColor: theme.dividerColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesPane extends StatelessWidget {
  final _Section section;
  final bool completed;
  final VoidCallback? onStartQuiz;
  const _NotesPane({
    required this.section,
    required this.completed,
    required this.onStartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            children: [
              for (final note in section.notes)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(note,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              // Elaborative prompt (tap to reveal) — encode by self-explaining.
              Card(
                color: theme.colorScheme.primary.withOpacity(0.06),
                child: ExpansionTile(
                  leading: Icon(Icons.psychology_outlined,
                      color: theme.colorScheme.primary),
                  title: const Text('Explain it back'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(
                      'Before the quiz, say each point out loud in your own '
                      'words and connect it to something you already know. '
                      'Elaborating like this makes it stick.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: (qIndex + 1) / total),
          const SizedBox(height: 16),
          Row(children: [
            Text('Question ${qIndex + 1} of $total',
                style: theme.textTheme.bodySmall),
            const Spacer(),
            TextButton(onPressed: onBackToNotes, child: const Text('Notes')),
          ]),
          const SizedBox(height: 8),
          Text(q.prompt, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                ...List.generate(q.choices.length, (i) {
                  final isCorrect = i == q.correctIndex;
                  final isPicked = i == selected;
                  Color? bg;
                  if (revealed) {
                    if (isCorrect) {
                      bg = Colors.green.withOpacity(0.12);
                    } else if (isPicked) {
                      bg = Colors.red.withOpacity(0.12);
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: bg ?? theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.dividerColor),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onChoose(i),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(children: [
                            Expanded(
                                child: Text(q.choices[i],
                                    style: theme.textTheme.bodyLarge)),
                            if (revealed && isCorrect)
                              const Icon(Icons.check_circle, color: Colors.green),
                            if (revealed && isPicked && !isCorrect)
                              const Icon(Icons.cancel, color: Colors.red),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
                if (revealed && q.explanation != null && q.explanation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Why: ${q.explanation!}',
                          style: theme.textTheme.bodyMedium),
                    ),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: revealed ? onNext : null,
            child: Text(qIndex + 1 == total ? 'Finish section' : 'Next'),
          ),
        ],
      ),
    );
  }
}
