import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/api_client.dart';

/// Tracks subscription tier + free-tier usage from the server.
///
/// `usageCount` is owned by the backend (incremented only on a successful
/// generation), so the client reads it rather than counting locally.
/// [freeLimit] mirrors the server's FREE_GENERATION_LIMIT.
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  static const freeLimit = 2;

  final ApiClient api;

  SubscriptionBloc({required this.api})
      : super(const SubscriptionState.unknown()) {
    on<LoadSubscription>(_load);
    on<RecordUsage>(_load); // usage changes live server-side; just re-read
    on<UpgradeToPremium>(_upgrade);
    on<CancelPremium>(_cancel);
  }

  Future<void> _load(
      SubscriptionEvent e, Emitter<SubscriptionState> emit) async {
    try {
      final response = await api.dio.get('subscription/');
      final d = response.data as Map<String, dynamic>;
      emit(SubscriptionState(
        isPremium: d['isPremium'] as bool? ?? false,
        usageCount: d['usageCount'] as int? ?? 0,
      ));
    } catch (_) {
      emit(const SubscriptionState(isPremium: false, usageCount: 0));
    }
  }

  Future<void> _upgrade(
      UpgradeToPremium e, Emitter<SubscriptionState> emit) async {
    // IAP receipt validation (POST /subscription/validate) is wired on the
    // backend but needs the native store receipt. Until the IAP SDK is added,
    // optimistically reflect premium locally so the paywall flow is testable.
    emit(state.copyWith(isPremium: true));
  }

  Future<void> _cancel(
      CancelPremium e, Emitter<SubscriptionState> emit) async {
    try {
      await api.dio.post('subscription/cancel/');
    } catch (_) {
      // dev/testing endpoint; ignore failures (prod uses store webhooks)
    }
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
