import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the user has seen the first-login onboarding. The flag is
/// persisted so onboarding shows exactly once.
class OnboardingState {
  final bool loaded;
  final bool seen;
  const OnboardingState({this.loaded = false, this.seen = false});
}

abstract class OnboardingEvent {}

class LoadOnboarding extends OnboardingEvent {}

class CompleteOnboarding extends OnboardingEvent {}

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  static const _key = 'onboarding_seen';

  OnboardingBloc() : super(const OnboardingState()) {
    on<LoadOnboarding>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      emit(OnboardingState(loaded: true, seen: prefs.getBool(_key) ?? false));
    });

    on<CompleteOnboarding>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
      emit(const OnboardingState(loaded: true, seen: true));
    });
  }
}
