import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../learning/data/models/learning_models.dart';
import '../../../learning/presentation/bloc/learning_bloc.dart';
import '../bloc/exam_prep_bloc.dart';

/// Step-by-step plan creation: pick material → set exam title + date →
/// pick topics → set questions per day → save.
class CreatePlanPage extends StatefulWidget {
  const CreatePlanPage({super.key});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  LearningMaterial? _material;
  final _titleCtrl = TextEditingController();
  DateTime _examDate = DateTime.now().add(const Duration(days: 14));
  int _questionsPerDay = 5;
  final Set<String> _selectedTopics = {};

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

  void _save() {
    if (_material == null) {
      _toast('Pick a study set first');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      _toast('Give your exam a name');
      return;
    }
    final topics =
        _selectedTopics.isEmpty ? _material!.topics : _selectedTopics.toList();
    context.read<ExamPrepBloc>().add(CreatePlan(
          materialId: _material!.id,
          materialTitle: _material!.title,
          examTitle: _titleCtrl.text.trim(),
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
    return Scaffold(
      appBar: AppBar(title: const Text('New exam plan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('1. Study material', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (library.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    const Text('You don\'t have any study sets yet.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/new'),
                      child: const Text('Create one first'),
                    ),
                  ]),
                ),
              )
            else
              ...library.map((m) => RadioListTile<String>(
                    value: m.id,
                    groupValue: _material?.id,
                    onChanged: (_) => setState(() => _material = m),
                    title: Text(m.title),
                    subtitle: Text(
                        '${m.quiz.length} questions • ${m.topics.length} topics'),
                  )),
            const Divider(height: 32),
            Text('2. Exam details', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Exam name',
                hintText: 'e.g. Biology Midterm',
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Exam date'),
                subtitle: Text(DateFormat.yMMMEd().format(_examDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Questions per day: $_questionsPerDay',
                        style: theme.textTheme.titleLarge),
                    Slider(
                      value: _questionsPerDay.toDouble(),
                      min: 1,
                      max: 20,
                      divisions: 19,
                      label: '$_questionsPerDay',
                      onChanged: (v) =>
                          setState(() => _questionsPerDay = v.round()),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 32),
            Text('3. Topics to cover', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Leave empty to cover everything in the material.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (_material == null)
              Text('Pick a study set above to see its topics.',
                  style: theme.textTheme.bodySmall)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _material!.topics.map((t) {
                  final selected = _selectedTopics.contains(t);
                  return FilterChip(
                    label: Text(t),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedTopics.add(t);
                      } else {
                        _selectedTopics.remove(t);
                      }
                    }),
                  );
                }).toList(),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              child: const Text('Create plan'),
            ),
          ],
        ),
      ),
    );
  }
}
