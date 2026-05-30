import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/learning_models.dart';
import '../../data/repositories/learning_repository.dart';

abstract class LearningEvent extends Equatable {
  const LearningEvent();
  @override
  List<Object?> get props => [];
}

class LoadLibrary extends LearningEvent {}

class GenerateMaterial extends LearningEvent {
  final SourceKind sourceKind;
  final String sourceRef;
  final String? titleHint;
  const GenerateMaterial({
    required this.sourceKind,
    required this.sourceRef,
    this.titleHint,
  });

  @override
  List<Object?> get props => [sourceKind, sourceRef, titleHint];
}

class DeleteMaterial extends LearningEvent {
  final String id;
  const DeleteMaterial(this.id);
  @override
  List<Object?> get props => [id];
}

abstract class LearningState extends Equatable {
  final List<LearningMaterial> library;
  const LearningState(this.library);
  @override
  List<Object?> get props => [library];
}

class LearningInitial extends LearningState {
  const LearningInitial() : super(const []);
}

class LibraryReady extends LearningState {
  const LibraryReady(super.library);
}

class Generating extends LearningState {
  const Generating(super.library);
}

class GenerateSuccess extends LearningState {
  final LearningMaterial material;
  const GenerateSuccess({required this.material, required List<LearningMaterial> library})
      : super(library);
  @override
  List<Object?> get props => [material, library];
}

class LearningError extends LearningState {
  final String message;
  const LearningError(this.message, List<LearningMaterial> library) : super(library);
  @override
  List<Object?> get props => [message, library];
}

class LearningBloc extends Bloc<LearningEvent, LearningState> {
  final LearningRepository repository;

  LearningBloc({required this.repository}) : super(const LearningInitial()) {
    on<LoadLibrary>((event, emit) async {
      try {
        await repository.loadLibrary();
        emit(LibraryReady(repository.library));
      } catch (e) {
        emit(LearningError(apiErrorMessage(e), repository.library));
      }
    });

    on<GenerateMaterial>((event, emit) async {
      debugPrint('[learning] Generate kind=${event.sourceKind.name} ref=${event.sourceRef}');
      emit(Generating(repository.library));
      try {
        final m = await repository.generate(
          sourceKind: event.sourceKind,
          sourceRef: event.sourceRef,
          titleHint: event.titleHint,
        );
        debugPrint('[learning] Generate SUCCESS id=${m.id} title="${m.title}"');
        emit(GenerateSuccess(material: m, library: repository.library));
      } catch (e) {
        debugPrint('[learning] Generate FAILED: $e');
        emit(LearningError(apiErrorMessage(e), repository.library));
      }
    });

    on<DeleteMaterial>((event, emit) async {
      try {
        await repository.delete(event.id);
      } catch (_) {
        // best-effort; fall through to re-emit current library
      }
      emit(LibraryReady(repository.library));
    });
  }
}
