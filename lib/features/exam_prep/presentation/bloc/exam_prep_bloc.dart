import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/exam_plan.dart';
import '../../data/repositories/exam_prep_repository.dart';

abstract class ExamPrepEvent extends Equatable {
  const ExamPrepEvent();
  @override
  List<Object?> get props => [];
}

class LoadPlans extends ExamPrepEvent {}

class CreatePlan extends ExamPrepEvent {
  final String materialId;
  final String materialTitle;
  final String examTitle;
  final DateTime examDate;
  final int questionsPerDay;
  final List<String> topics;
  const CreatePlan({
    required this.materialId,
    required this.materialTitle,
    required this.examTitle,
    required this.examDate,
    required this.questionsPerDay,
    required this.topics,
  });
  @override
  List<Object?> get props =>
      [materialId, examTitle, examDate, questionsPerDay, topics];
}

class CompleteSession extends ExamPrepEvent {
  final String planId;
  final DateTime day;
  final int correct;
  final int total;
  const CompleteSession({
    required this.planId,
    required this.day,
    required this.correct,
    required this.total,
  });
  @override
  List<Object?> get props => [planId, day, correct, total];
}

class DeletePlan extends ExamPrepEvent {
  final String id;
  const DeletePlan(this.id);
  @override
  List<Object?> get props => [id];
}

class ExamPrepState extends Equatable {
  final List<ExamPlan> plans;
  final bool loading;
  const ExamPrepState({this.plans = const [], this.loading = false});

  /// Plan whose schedule covers today (any active plan).
  List<ExamPlan> get activeToday {
    final today = DateTime.now();
    return plans
        .where((p) => !today.isBefore(p.createdAt) && !today.isAfter(p.examDate.add(const Duration(days: 1))))
        .toList();
  }

  @override
  List<Object?> get props => [plans, loading];
}

class ExamPrepBloc extends Bloc<ExamPrepEvent, ExamPrepState> {
  final ExamPrepRepository repository;

  ExamPrepBloc({required this.repository}) : super(const ExamPrepState()) {
    on<LoadPlans>((e, emit) async {
      emit(const ExamPrepState(loading: true));
      final plans = await repository.all();
      emit(ExamPrepState(plans: plans));
    });

    on<CreatePlan>((e, emit) async {
      await repository.create(
        materialId: e.materialId,
        materialTitle: e.materialTitle,
        examTitle: e.examTitle,
        examDate: e.examDate,
        questionsPerDay: e.questionsPerDay,
        topics: e.topics,
      );
      final plans = await repository.all();
      emit(ExamPrepState(plans: plans));
    });

    on<CompleteSession>((e, emit) async {
      final plan = state.plans.firstWhere((p) => p.id == e.planId);
      final updated = plan.markCompleted(
        day: e.day,
        correct: e.correct,
        total: e.total,
      );
      await repository.update(updated);
      final plans = await repository.all();
      emit(ExamPrepState(plans: plans));
    });

    on<DeletePlan>((e, emit) async {
      await repository.delete(e.id);
      final plans = await repository.all();
      emit(ExamPrepState(plans: plans));
    });
  }
}
