import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/rewards/rewards_bloc.dart';
import '../../../learning/data/models/learning_models.dart';
import '../../../learning/data/repositories/learning_repository.dart';
import '../../data/models/exam_plan.dart';
import '../bloc/exam_prep_bloc.dart';

/// Today's session: shows N questions for the plan, scoped to the plan's
/// topics. Records the result back into the plan when finished.
class DailySessionPage extends StatefulWidget {
  final String planId;
  const DailySessionPage({super.key, required this.planId});

  @override
  State<DailySessionPage> createState() => _DailySessionPageState();
}

class _DailySessionPageState extends State<DailySessionPage> {
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool _revealed = false;
  bool _done = false;

  ExamPlan get _plan =>
      context.read<ExamPrepBloc>().state.plans.firstWhere((p) => p.id == widget.planId);

  LearningMaterial? get _material =>
      LearningRepository().byId(_plan.materialId);

  /// Deterministic per-day question selection: take the plan's topic-filtered
  /// quiz, shuffle with a seed derived from today's date so the same set
  /// shows up if the user reopens, but a fresh set tomorrow.
  List<QuizQuestion> get _questions {
    final m = _material;
    if (m == null) return const [];
    final pool = m.quizForTopics(_plan.topics);
    if (pool.isEmpty) return const [];
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    final shuffled = [...pool]..sort((a, b) =>
        ((a.id.hashCode ^ seed) - (b.id.hashCode ^ seed)).compareTo(0));
    return shuffled.take(_plan.questionsPerDay).toList();
  }

  QuizQuestion get _q => _questions[_index];

  void _choose(int i) {
    if (_revealed) return;
    setState(() {
      _selected = i;
      _revealed = true;
      if (i == _q.correctIndex) _correct++;
    });
  }

  void _next() {
    if (_index + 1 < _questions.length) {
      setState(() {
        _index++;
        _selected = null;
        _revealed = false;
      });
    } else {
      setState(() => _done = true);
      context.read<ExamPrepBloc>().add(CompleteSession(
            planId: widget.planId,
            day: DateTime.now(),
            correct: _correct,
            total: _questions.length,
          ));
      context.read<RewardsBloc>().add(RecordActivity(
            points: 10 + _correct * 5,
            reason: 'Daily exam session',
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _questions;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's session"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/exam'),
        ),
      ),
      body: SafeArea(
        child: questions.isEmpty
            ? const Center(child: Text('No questions for today.'))
            : _done
                ? _Done(
                    correct: _correct,
                    total: questions.length,
                    onClose: () => context.go('/exam'),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(
                            value: (_index + 1) / questions.length),
                        const SizedBox(height: 20),
                        Row(children: [
                          Text(
                              'Question ${_index + 1} of ${questions.length}',
                              style: theme.textTheme.bodySmall),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  theme.colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(_q.topic,
                                style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Text(_q.prompt,
                            style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 20),
                        ...List.generate(_q.choices.length, (i) {
                          final isCorrect = i == _q.correctIndex;
                          final isPicked = i == _selected;
                          Color? bg;
                          if (_revealed) {
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
                                onTap: () => _choose(i),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(_q.choices[i],
                                            style: theme
                                                .textTheme.bodyLarge)),
                                    if (_revealed && isCorrect)
                                      const Icon(Icons.check_circle,
                                          color: Colors.green),
                                    if (_revealed && isPicked && !isCorrect)
                                      const Icon(Icons.cancel,
                                          color: Colors.red),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        }),
                        const Spacer(),
                        if (_revealed && _q.explanation != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(_q.explanation!,
                                style: theme.textTheme.bodySmall),
                          ),
                        ElevatedButton(
                          onPressed: _revealed ? _next : null,
                          child: Text(_index + 1 == questions.length
                              ? 'Finish'
                              : 'Next'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  final int correct;
  final int total;
  final VoidCallback onClose;
  const _Done(
      {required this.correct, required this.total, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text("Today's session complete",
                style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 6),
            Text('$correct / $total correct',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onClose, child: const Text('Back to plan')),
          ],
        ),
      ),
    );
  }
}
