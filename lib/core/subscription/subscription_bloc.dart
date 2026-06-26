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
      final resetsRaw = d['usageResetsAt'] as String?;
      emit(SubscriptionState(
        isPremium: d['isPremium'] as bool? ?? false,
        usageCount: d['usageCount'] as int? ?? 0,
        usageLimit: d['usageLimit'] as int? ?? freeLimit,
        resetsAt: resetsRaw == null ? null : DateTime.tryParse(resetsRaw),
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

  /// Generations used in the CURRENT monthly window (server-owned; resets to 0
  /// each month).
  final int usageCount;

  /// Free generations allowed per month. Mirrors the server's
  /// FREE_GENERATION_LIMIT; falls back to [SubscriptionBloc.freeLimit] offline.
  final int usageLimit;

  /// When [usageCount] rolls back to 0 (first day of next month). Null until
  /// the subscription has been loaded from the server.
  final DateTime? resetsAt;

  final bool loaded;

  const SubscriptionState({
    required this.isPremium,
    required this.usageCount,
    this.usageLimit = SubscriptionBloc.freeLimit,
    this.resetsAt,
    this.loaded = true,
  });

  const SubscriptionState.unknown()
      : isPremium = false,
        usageCount = 0,
        usageLimit = SubscriptionBloc.freeLimit,
        resetsAt = null,
        loaded = false;

  /// Returns true when this user can generate another study set.
  bool get canGenerate => isPremium || usageCount < usageLimit;

  /// How many free generations remain this month.
  int get remainingFree => (usageLimit - usageCount).clamp(0, usageLimit);

  SubscriptionState copyWith({
    bool? isPremium,
    int? usageCount,
    int? usageLimit,
    DateTime? resetsAt,
  }) {
    return SubscriptionState(
      isPremium: isPremium ?? this.isPremium,
      usageCount: usageCount ?? this.usageCount,
      usageLimit: usageLimit ?? this.usageLimit,
      resetsAt: resetsAt ?? this.resetsAt,
      loaded: true,
    );
  }

  @override
  List<Object?> get props => [isPremium, usageCount, usageLimit, resetsAt, loaded];
}
