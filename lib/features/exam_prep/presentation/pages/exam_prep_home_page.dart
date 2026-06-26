import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/airbnb_card.dart';
import '../../data/models/exam_plan.dart';
import '../bloc/exam_prep_bloc.dart';
import '../widgets/exam_progress_summary.dart';
import '../widgets/plan_progress_simple.dart';

/// Exam tab: lists all exam plans + a calendar view per plan.
class ExamPrepHomePage extends StatelessWidget {
  const ExamPrepHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam prep'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/exam/new'),
          ),
        ],
      ),
      body: BlocBuilder<ExamPrepBloc, ExamPrepState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.plans.isEmpty) {
            return _Empty(onTap: () => context.push('/exam/new'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              ExamProgressSummary(plans: state.plans),
              const SizedBox(height: 22),
              Text("Today's plan",
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              ...state.plans
                  .where((p) => p.isToday)
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TodayCard(plan: p),
                      )),
              const SizedBox(height: 8),
              Text('All plans', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              ...state.plans.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PlanCard(plan: p),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onTap;
  const _Empty({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_rounded,
                size: 56,
                color: ThemeColors.brandIndigo),
            const SizedBox(height: 12),
            Text('No exam plans yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Set an exam date, choose topics, and we\'ll build your daily schedule.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onTap, child: const Text('Create a plan')),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final ExamPlan plan;
  const _TodayCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = plan.resultFor(DateTime.now())?.completed ?? false;
    return Material(
      borderRadius: BorderRadius.circular(20),
      color: ThemeColors.brandIndigo,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/exam/${plan.id}/today'),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: ThemeColors.brandIndigo.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    done ? 'COMPLETED' : 'TODAY',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(),
                Text('${plan.daysUntilExam}d to exam',
                    style: const TextStyle(color: Colors.white70)),
              ]),
              const SizedBox(height: 12),
              Text(plan.examTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(plan.materialTitle,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.assignment_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text('${plan.questionsPerDay} questions today',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(done ? 'Tap to review' : 'Tap to start',
                    style: const TextStyle(color: Colors.white)),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ExamPlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat.yMMMd();
    return AirbnbCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.examTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text('${plan.materialTitle} • ${df.format(plan.examDate)}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => context
                  .read<ExamPrepBloc>()
                  .add(DeletePlan(plan.id)),
            ),
          ]),
          const SizedBox(height: 14),
          // Simple coverage bar + per-topic list. Tap a topic to re-read
          // its section content in a bottom sheet.
          PlanProgressSimple(plan: plan),
        ],
      ),
    );
  }
}
