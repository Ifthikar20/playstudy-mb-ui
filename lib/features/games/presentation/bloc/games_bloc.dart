import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/game_models.dart';
import '../../data/repositories/game_repository.dart';

abstract class GamesEvent extends Equatable {
  const GamesEvent();
  @override
  List<Object?> get props => [];
}

class LoadLibrary extends GamesEvent {}

class GenerateGame extends GamesEvent {
  final String imagePath;
  final GameType type;
  final String? subjectHint;
  const GenerateGame({required this.imagePath, required this.type, this.subjectHint});

  @override
  List<Object?> get props => [imagePath, type, subjectHint];
}

class DeleteGame extends GamesEvent {
  final String id;
  const DeleteGame(this.id);
  @override
  List<Object?> get props => [id];
}

abstract class GamesState extends Equatable {
  const GamesState();
  @override
  List<Object?> get props => [];
}

class GamesInitial extends GamesState {}

class GamesLoaded extends GamesState {
  final List<Game> library;
  const GamesLoaded(this.library);
  @override
  List<Object?> get props => [library];
}

class GameGenerating extends GamesState {}

class GameGenerated extends GamesState {
  final Game game;
  final List<Game> library;
  const GameGenerated({required this.game, required this.library});
  @override
  List<Object?> get props => [game, library];
}

class GamesError extends GamesState {
  final String message;
  const GamesError(this.message);
  @override
  List<Object?> get props => [message];
}

class GamesBloc extends Bloc<GamesEvent, GamesState> {
  final GameRepository repository;

  GamesBloc({required this.repository}) : super(GamesInitial()) {
    on<LoadLibrary>((event, emit) {
      emit(GamesLoaded(repository.library));
    });

    on<GenerateGame>((event, emit) async {
      emit(GameGenerating());
      try {
        final game = await repository.generateFromImage(
          imagePath: event.imagePath,
          type: event.type,
          subjectHint: event.subjectHint,
        );
        emit(GameGenerated(game: game, library: repository.library));
      } catch (e) {
        emit(GamesError('Could not generate game: $e'));
      }
    });

    on<DeleteGame>((event, emit) {
      repository.delete(event.id);
      emit(GamesLoaded(repository.library));
    });
  }
}
