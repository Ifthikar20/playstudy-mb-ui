import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/api_client.dart';
import '../network/token_store.dart';
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
  final String? idToken; // signed token from the native SDK
  const AuthSignInWithProvider(this.provider, {this.idToken});
  @override
  List<Object?> get props => [provider, idToken];
}

class AuthSignOut extends AuthEvent {}

class UpdateProfile extends AuthEvent {
  final String? name;
  final String? avatarUrl;
  final String? timezone;
  const UpdateProfile({this.name, this.avatarUrl, this.timezone});
  @override
  List<Object?> get props => [name, avatarUrl, timezone];
}

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
  final ApiClient api;
  final TokenStore tokens;

  AuthBloc({required this.api, required this.tokens}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_check);
    on<AuthSignInWithEmail>(_signInEmail);
    on<AuthSignInWithProvider>(_signInProvider);
    on<AuthSignOut>(_signOut);
    on<UpdateProfile>(_updateProfile);
  }

  User _userFrom(Map<String, dynamic> j) => User(
        id: (j['id'] ?? '').toString(),
        email: j['email'] as String? ?? '',
        name: j['name'] as String? ?? 'Student',
        avatarUrl: j['avatarUrl'] as String?,
      );

  Future<void> _check(AuthCheckRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    if (!await tokens.hasTokens()) {
      emit(const Unauthenticated());
      return;
    }
    try {
      final response = await api.dio.get('me/');
      emit(Authenticated(_userFrom(response.data['user'] as Map<String, dynamic>)));
    } catch (_) {
      await tokens.clear();
      emit(const Unauthenticated());
    }
  }

  Future<void> _signInEmail(
      AuthSignInWithEmail e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await api.dio.post(
        'auth/email/',
        data: {'email': e.email, 'password': e.password},
        options: Options(extra: {'noAuth': true}),
      );
      await tokens.setTokens(
        response.data['accessToken'] as String,
        response.data['refreshToken'] as String,
      );
      emit(Authenticated(_userFrom(response.data['user'] as Map<String, dynamic>)));
    } catch (err) {
      emit(Unauthenticated(message: apiErrorMessage(err)));
    }
  }

  Future<void> _signInProvider(
      AuthSignInWithProvider e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    if (e.idToken == null) {
      // The native Apple/Google SDK isn't wired yet, so there's no ID token to
      // verify server-side. Use email sign-in for now.
      emit(const Unauthenticated(
          message: 'Social sign-in is coming soon — use email for now.'));
      return;
    }
    try {
      final response = await api.dio.post(
        'auth/provider/',
        data: {'provider': e.provider, 'idToken': e.idToken},
        options: Options(extra: {'noAuth': true}),
      );
      await tokens.setTokens(
        response.data['accessToken'] as String,
        response.data['refreshToken'] as String,
      );
      emit(Authenticated(_userFrom(response.data['user'] as Map<String, dynamic>)));
    } catch (err) {
      emit(Unauthenticated(message: apiErrorMessage(err)));
    }
  }

  Future<void> _updateProfile(
      UpdateProfile e, Emitter<AuthState> emit) async {
    if (state is! Authenticated) return;
    final body = <String, dynamic>{};
    if (e.name != null) body['name'] = e.name;
    if (e.avatarUrl != null) body['avatarUrl'] = e.avatarUrl;
    if (e.timezone != null) body['timezone'] = e.timezone;
    if (body.isEmpty) return;
    try {
      final response = await api.dio.patch('me/', data: body);
      emit(Authenticated(_userFrom(response.data['user'] as Map<String, dynamic>)));
    } catch (_) {
      // keep the current user on failure
    }
  }

  Future<void> _signOut(AuthSignOut e, Emitter<AuthState> emit) async {
    final refresh = await tokens.refreshToken();
    try {
      if (refresh != null) {
        await api.dio.post('auth/signout/', data: {'refreshToken': refresh});
      }
    } catch (_) {
      // Signing out is best-effort + idempotent.
    }
    await tokens.clear();
    emit(const Unauthenticated());
  }
}
