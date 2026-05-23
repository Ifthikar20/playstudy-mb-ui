import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'user.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSignInWithEmail extends AuthEvent {
  final String email;
  final String password;
  const AuthSignInWithEmail({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class AuthSignInWithProvider extends AuthEvent {
  final String provider; // 'apple', 'google'
  const AuthSignInWithProvider(this.provider);
  @override
  List<Object?> get props => [provider];
}

class AuthSignOut extends AuthEvent {}

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final User user;
  const Authenticated(this.user);
  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {
  final String? message;
  const Unauthenticated({this.message});
  @override
  List<Object?> get props => [message];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const _idKey = 'auth_user_id';
  static const _emailKey = 'auth_user_email';
  static const _nameKey = 'auth_user_name';

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_check);
    on<AuthSignInWithEmail>(_signInEmail);
    on<AuthSignInWithProvider>(_signInProvider);
    on<AuthSignOut>(_signOut);
  }

  Future<void> _check(AuthCheckRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_idKey);
    if (id == null) {
      emit(const Unauthenticated());
      return;
    }
    emit(Authenticated(User(
      id: id,
      email: prefs.getString(_emailKey) ?? '',
      name: prefs.getString(_nameKey) ?? 'Student',
    )));
  }

  Future<void> _signInEmail(
      AuthSignInWithEmail e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await Future.delayed(const Duration(milliseconds: 600));
    if (!e.email.contains('@') || e.password.length < 4) {
      emit(const Unauthenticated(message: 'Check your email and password.'));
      return;
    }
    final user = User(
      id: const Uuid().v4(),
      email: e.email,
      name: e.email.split('@').first,
    );
    await _persist(user);
    emit(Authenticated(user));
  }

  Future<void> _signInProvider(
      AuthSignInWithProvider e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await Future.delayed(const Duration(milliseconds: 500));
    final user = User(
      id: const Uuid().v4(),
      email: '${e.provider}@playstudy.app',
      name: e.provider == 'apple' ? 'Apple User' : 'Google User',
    );
    await _persist(user);
    emit(Authenticated(user));
  }

  Future<void> _signOut(AuthSignOut e, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_nameKey);
    emit(const Unauthenticated());
  }

  Future<void> _persist(User u) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, u.id);
    await prefs.setString(_emailKey, u.email);
    await prefs.setString(_nameKey, u.name);
  }
}
