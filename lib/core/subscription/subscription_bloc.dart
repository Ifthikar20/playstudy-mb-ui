import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks subscription tier + free-tier usage.
///
/// Free users get [freeLimit] generations before the paywall blocks more.
/// Premium users are unlimited. Usage count and premium flag are persisted
/// in SharedPreferences. Replace with a real IAP / backend check later.
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  static const freeLimit = 2;
  static const _premiumKey = 'sub_premium';
  static const _usageKey = 'sub_usage_count';

  SubscriptionBloc() : super(const SubscriptionState.unknown()) {
    on<LoadSubscription>(_load);
    on<RecordUsage>(_record);
    on<UpgradeToPremium>(_upgrade);
    on<CancelPremium>(_cancel);
  }

  Future<void> _load(LoadSubscription e, Emitter<SubscriptionState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    emit(SubscriptionState(
      isPremium: prefs.getBool(_premiumKey) ?? false,
      usageCount: prefs.getInt(_usageKey) ?? 0,
    ));
  }

  Future<void> _record(RecordUsage e, Emitter<SubscriptionState> emit) async {
    if (state.isPremium) return;
    final prefs = await SharedPreferences.getInstance();
    final next = state.usageCount + 1;
    await prefs.setInt(_usageKey, next);
    emit(state.copyWith(usageCount: next));
  }

  Future<void> _upgrade(UpgradeToPremium e, Emitter<SubscriptionState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, true);
    emit(state.copyWith(isPremium: true));
  }

  Future<void> _cancel(CancelPremium e, Emitter<SubscriptionState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumKey, false);
    emit(state.copyWith(isPremium: false));
  }
}

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();
  @override
  List<Object?> get props => [];
}

class LoadSubscription extends SubscriptionEvent {}

class RecordUsage extends SubscriptionEvent {}

class UpgradeToPremium extends SubscriptionEvent {}

class CancelPremium extends SubscriptionEvent {}

class SubscriptionState extends Equatable {
  final bool isPremium;
  final int usageCount;
  final bool loaded;

  const SubscriptionState({
    required this.isPremium,
    required this.usageCount,
    this.loaded = true,
  });

  const SubscriptionState.unknown()
      : isPremium = false,
        usageCount = 0,
        loaded = false;

  /// Returns true when this user can generate another study set.
  bool get canGenerate =>
      isPremium || usageCount < SubscriptionBloc.freeLimit;

  /// How many free generations remain.
  int get remainingFree =>
      (SubscriptionBloc.freeLimit - usageCount).clamp(0, SubscriptionBloc.freeLimit);

  SubscriptionState copyWith({bool? isPremium, int? usageCount}) {
    return SubscriptionState(
      isPremium: isPremium ?? this.isPremium,
      usageCount: usageCount ?? this.usageCount,
      loaded: true,
    );
  }

  @override
  List<Object?> get props => [isPremium, usageCount, loaded];
}
