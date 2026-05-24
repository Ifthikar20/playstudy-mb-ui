import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/api_client.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A rank on the adventure path. Reaching [threshold] points unlocks it.
class Rank {
  final String name;
  final String emoji;
  final int threshold;
  const Rank(this.name, this.emoji, this.threshold);
}

const kRanks = <Rank>[
  Rank('Novice', '🌱', 0),
  Rank('Explorer', '🧭', 100),
  Rank('Scholar', '📖', 300),
  Rank('Strategist', '♟️', 600),
  Rank('Sage', '🦉', 1000),
  Rank('Master', '🎓', 1500),
  Rank('Legend', '🏆', 2200),
];

/// Tracks daily streak, lifetime points, and adventure rank. Points are
/// awarded for studying activity; the streak increments once per day the
/// user does anything and resets if a day is missed.
/// Server-authoritative rewards. Points + streak are owned by the backend;
/// the client posts an activity *reason* (+ context) and the server decides
/// the points. If the network is unavailable we fall back to an optimistic
/// local update using the reason's known formula so the UI stays responsive.
class RewardsBloc extends Bloc<RewardsEvent, RewardsState> {
  final ApiClient api;

  RewardsBloc({required this.api}) : super(const RewardsState.initial()) {
    on<LoadRewards>(_load);
    on<RecordActivity>(_record);
  }

  Future<void> _load(LoadRewards e, Emitter<RewardsState> emit) async {
    try {
      final response = await api.dio.get('rewards/');
      final d = response.data as Map<String, dynamic>;
      emit(RewardsState(
        points: d['points'] as int? ?? 0,
        streak: d['streak'] as int? ?? 0,
        lastActiveYmd: null,
        loaded: true,
        lastAward: d['lastAward'] as int? ?? 0,
        lastReason: d['lastReason'] as String?,
      ));
    } catch (_) {
      // Unauthenticated or offline — show a clean zero state.
      emit(const RewardsState(
          points: 0, streak: 0, lastActiveYmd: null, loaded: true));
    }
  }

  Future<void> _record(RecordActivity e, Emitter<RewardsState> emit) async {
    try {
      final response = await api.dio.post(
        'rewards/activity/',
        data: {'reason': e.reason, 'context': e.context},
      );
      final d = response.data as Map<String, dynamic>;
      emit(state.copyWith(
        points: d['points'] as int?,
        streak: d['streak'] as int?,
        lastAward: d['lastAward'] as int?,
        lastReason: d['lastReason'] as String?,
      ));
    } catch (_) {
      // Offline fallback: optimistic local update using the provided points.
      emit(state.copyWith(
        points: state.points + e.points,
        lastAward: e.points,
        lastReason: e.reason,
      ));
    }
  }
}

abstract class RewardsEvent extends Equatable {
  const RewardsEvent();
  @override
  List<Object?> get props => [];
}

class LoadRewards extends RewardsEvent {}

class RecordActivity extends RewardsEvent {
  /// Offline fallback amount. The server recomputes points from [reason] +
  /// [context], so this is only used when the request can't reach the backend.
  final int points;
  final String reason;
  final Map<String, dynamic> context;
  const RecordActivity({
    required this.points,
    required this.reason,
    this.context = const {},
  });
  @override
  List<Object?> get props => [points, reason, context];
}

class RewardsState extends Equatable {
  final int points;
  final int streak;
  final String? lastActiveYmd;
  final bool loaded;
  final int lastAward;
  final String? lastReason;

  const RewardsState({
    required this.points,
    required this.streak,
    required this.lastActiveYmd,
    this.loaded = true,
    this.lastAward = 0,
    this.lastReason,
  });

  const RewardsState.initial()
      : points = 0,
        streak = 0,
        lastActiveYmd = null,
        loaded = false,
        lastAward = 0,
        lastReason = null;

  bool get streakActiveToday {
    if (lastActiveYmd == null) return false;
    return lastActiveYmd == _ymd(DateTime.now());
  }

  int get currentRankIndex {
    var idx = 0;
    for (var i = 0; i < kRanks.length; i++) {
      if (points >= kRanks[i].threshold) idx = i;
    }
    return idx;
  }

  Rank get currentRank => kRanks[currentRankIndex];
  Rank? get nextRank =>
      currentRankIndex + 1 < kRanks.length ? kRanks[currentRankIndex + 1] : null;

  /// Progress (0..1) toward the next rank.
  double get rankProgress {
    final next = nextRank;
    if (next == null) return 1;
    final base = currentRank.threshold;
    final span = next.threshold - base;
    if (span <= 0) return 1;
    return ((points - base) / span).clamp(0, 1);
  }

  int get pointsToNextRank =>
      nextRank == null ? 0 : (nextRank!.threshold - points).clamp(0, 99999);

  RewardsState copyWith({
    int? points,
    int? streak,
    String? lastActiveYmd,
    int? lastAward,
    String? lastReason,
  }) {
    return RewardsState(
      points: points ?? this.points,
      streak: streak ?? this.streak,
      lastActiveYmd: lastActiveYmd ?? this.lastActiveYmd,
      loaded: true,
      lastAward: lastAward ?? 0,
      lastReason: lastReason,
    );
  }

  @override
  List<Object?> get props =>
      [points, streak, lastActiveYmd, loaded, lastAward, lastReason];
}
