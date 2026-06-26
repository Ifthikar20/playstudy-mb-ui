import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../data/models/learning_models.dart';
import '../../data/quiz_progress_store.dart';
import '../../data/repositories/learning_repository.dart';

class QuizView extends StatefulWidget {
  final List<QuizQuestion> questions;
  /// Optional id used to persist progress so reopening the tab resumes
  /// where the user left off instead of starting over.
  final String? resumeKey;
  const QuizView({super.key, required this.questions, this.resumeKey});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _revealed = false;
  bool _done = false;
  bool _started = false;
  bool _fetchingMore = false;
  late List<QuizQuestion> _questions = List<QuizQuestion>.from(widget.questions);

  @override
  void initState() {
    super.initState();
    _restoreProgress();
  }

  Future<void> _generateFreshPack() async {
    if (widget.resumeKey == null) return;
    setState(() => _fetchingMore = true);
    try {
      final repo = context.read<LearningRepository>();
      final fresh = await repo.generateQuizPack(widget.resumeKey!, count: 10);
      if (!mounted) return;
      if (fresh.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No fresh questions came back.')),
        );
        return;
      }
      setState(() {
        _questions = [..._questions, ...fresh];
        _index = _questions.length - fresh.length;
        _score = 0;
        _selected = null;
        _revealed = false;
        _done = false;
        _fetchingMore = false;
      });
      _saveProgress();
    } catch (e) {
      if (!mounted) return;
      setState(() => _fetchingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t fetch more questions: $e')),
      );
    }
  }

  Future<void> _restoreProgress() async {
    final mid = widget.resumeKey;
    if (mid == null) {
      // No resume key -> no persistence; still show overview first.
      return;
    }
    final snap = await QuizProgressSnapshot.load(mid);
    if (!mounted) return;
    if (snap.done) {
      // User already finished this quiz — show the done screen on re-open so
      // they don't end up dropped mid-replay. They can tap "Retry these" to
      // start over.
      setState(() {
        _index = _questions.length - 1;
        _score = snap.score;
        _done = true;
        _started = true;
      });
      return;
    }
    // Resume at the first unanswered question (synced with the Study tab,
    // which also writes into the shared answered-set on every reveal).
    int resumeIdx = _questions.indexWhere((q) => !snap.answered.contains(q.id));
    if (resumeIdx < 0) resumeIdx = snap.lastIndex.clamp(0, _questions.length - 1);
    final hasProgress = snap.answered.isNotEmpty || snap.lastIndex > 0;
    setState(() {
      _index = resumeIdx;
      _score = snap.correct.length;
      // Jump straight into the question if they've already started; otherwise
      // show the overview / table-of-contents first.
      _started = hasProgress;
    });
  }

  Future<void> _saveProgress() async {
    final mid = widget.resumeKey;
    if (mid == null) return;
    await QuizProgressStore.saveCursor(mid, lastIndex: _index, score: _score);
  }

  Future<void> _clearProgress() async {
    final mid = widget.resumeKey;
    if (mid == null) return;
    await QuizProgressStore.resetAll(mid);
  }

  QuizQuestion get _q => _questions[_index];

  void _choose(int i) {
    if (_revealed) return;
    final correct = i == _q.correctIndex;
    setState(() {
      _selected = i;
      _revealed = true;
      if (correct) _score++;
    });
    final mid = widget.resumeKey;
    if (mid != null) {
      // Share this answer with StudyFlowView via the unified store so the
      // two views stay in sync on what's been answered.
      QuizProgressStore.markAnswered(mid, _q.id, correct: correct);
    }
  }

  void _next() {
    if (_index + 1 < _questions.length) {
      setState(() {
        _index++;
        _selected = null;
        _revealed = false;
      });
      _saveProgress();
    } else {
      setState(() => _done = true);
      final mid = widget.resumeKey;
      if (mid != null) {
        // Persist DONE so a back-then-return lands on the score screen
        // (and a fresh tap of "Retry these" is needed to start over).
        QuizProgressStore.markDone(mid, score: _score);
      }
      context.read<RewardsBloc>().add(RecordActivity(
            points: 5 + _score * 5,
            reason: 'Finished a quiz',
            context: {'score': _score, 'total': _questions.length},
          ));
    }
  }

  void _restart() {
    setState(() {
      _index = 0;
      _score = 0;
      _selected = null;
      _revealed = false;
      _done = false;
      _started = false; // back to the overview screen
    });
    _clearProgress();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return const Center(child: Text('No quiz questions yet.'));
    }
    if (!_started && !_done) {
      return _QuizOverview(
        questions: _questions,
        onStart: () => setState(() => _started = true),
      );
    }
    if (_done) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.workspace_premium_rounded,
                    size: 38, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text('Quiz complete',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text('You scored $_score / ${_questions.length}',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                tween: Tween(begin: 0, end: 1),
                builder: (context, t, child) =>
                    Transform.scale(scale: t, child: child),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF2A2A2E), Color(0xFF1A1A1A)]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text('+${5 + _score * 5} points',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed: _fetchingMore || widget.resumeKey == null
                      ? null
                      : _generateFreshPack,
                  icon: _fetchingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_fetchingMore
                      ? 'Generating…'
                      : 'Get fresh questions'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 240,
                child: OutlinedButton(
                  onPressed: _restart,
                  child: const Text('Retry these'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = _questions.length;
    final answered = _revealed ? _index + 1 : _index;
    final pct = total == 0 ? 0 : ((answered / total) * 100).round();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact progress strip: thin bar + tiny "X / Y" caption.
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  tween:
                      Tween(begin: 0, end: total == 0 ? 0 : answered / total),
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 3,
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.10),
                    valueColor:
                        AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$answered/$total',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          // Per-question header row: position + difficulty.
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Q${_index + 1}/$total',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            _DifficultyBadge(difficulty: _q.difficulty),
          ]),
          const SizedBox(height: 10),
          // Question — clamped to 4 lines so really long prompts don't push
          // the answers off-screen.
          Text(
            _q.prompt,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          // Compact answer tiles — natural height (~46px each). Wrapped in
          // a SingleChildScrollView so an unusually long set still scrolls
          // instead of overflowing, but in the common 4-option case it
          // sits comfortably without ever scrolling.
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < _q.choices.length; i++) ...[
                    _AnswerTile(
                      letter: String.fromCharCode(65 + i),
                      text: _q.choices[i],
                      isCorrect: i == _q.correctIndex,
                      isPicked: i == _selected,
                      revealed: _revealed,
                      onTap: () => _choose(i),
                    ),
                    if (i != _q.choices.length - 1)
                      const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
          if (_revealed && _q.explanation != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_q.explanation!,
                  style: theme.textTheme.bodySmall),
            ),
          ],
          const SizedBox(height: 8),
          _PrimaryQuizButton(
            label: _index + 1 == total ? 'Finish' : 'Next',
            enabled: _revealed,
            onPressed: _next,
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(text,
                      style: theme.textTheme.bodyMedium, maxLines: 3),
                ),
              ),
            ),
            if (revealed && isCorrect)
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
            if (revealed && isPicked && !isCorrect)
              const Icon(Icons.cancel_rounded, color: Colors.red, size: 18),
          ]),
        ),
      ),
    );
  }
}


/// "What you're about to cover" screen shown before the quiz starts.
/// Gives the learner context: how many questions, the difficulty mix, and
/// the topics drawn from the source material. Tapping "Start quiz" enters
/// the question UI.
class _QuizOverview extends StatelessWidget {
  final List<QuizQuestion> questions;
  final VoidCallback onStart;
  const _QuizOverview({required this.questions, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = questions.length;
    final easy = questions.where((q) => q.difficulty == QuizDifficulty.easy).length;
    final med = questions.where((q) => q.difficulty == QuizDifficulty.medium).length;
    final hard = questions.where((q) => q.difficulty == QuizDifficulty.hard).length;

    // Group by topic, preserving the order they appear in the question list.
    final topicCounts = <String, int>{};
    for (final q in questions) {
      final t = q.topic.trim().isEmpty ? 'General' : q.topic.trim();
      topicCounts.update(t, (v) => v + 1, ifAbsent: () => 1);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_rounded,
                    color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("What you're about to cover",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      '$total question${total == 1 ? '' : 's'} drawn from your study material',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 18),
            // Difficulty breakdown
            Row(children: [
              Expanded(
                child: _DifficultyStat(
                  label: 'Easy',
                  count: easy,
                  color: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DifficultyStat(
                  label: 'Medium',
                  count: med,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DifficultyStat(
                  label: 'Hard',
                  count: hard,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ]),
            const SizedBox(height: 22),
            // Topics
            Text('Topics in this quiz',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  for (final entry in topicCounts.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Icon(Icons.bolt_rounded,
                            size: 16,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${entry.value} Q',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _PrimaryQuizButton(
              label: 'Start quiz',
              enabled: true,
              onPressed: onStart,
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _DifficultyStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }
}

/// Clean, generously-sized primary CTA used at the bottom of each quiz
/// question. The previous 40px `ElevatedButton` rendered with crushed text
/// and a washed-out disabled state that the user called "smudged".
class _PrimaryQuizButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  const _PrimaryQuizButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: scheme.primary.withOpacity(0.32),
          disabledForegroundColor: Colors.white.withOpacity(0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
        child: Text(label),
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
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
