import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
class RewardsBloc extends Bloc<RewardsEvent, RewardsState> {
  static const _pointsKey = 'rewards_points';
  static const _streakKey = 'rewards_streak';
  static const _lastActiveKey = 'rewards_last_active';

  RewardsBloc() : super(const RewardsState.initial()) {
    on<LoadRewards>(_load);
    on<RecordActivity>(_record);
  }

  Future<void> _load(LoadRewards e, Emitter<RewardsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    var streak = prefs.getInt(_streakKey) ?? 0;
    final last = prefs.getString(_lastActiveKey);
    // If the last active day was before yesterday, the streak is broken.
    if (last != null) {
      final today = DateTime.now();
      final yesterday = _ymd(today.subtract(const Duration(days: 1)));
      final todayKey = _ymd(today);
      if (last != todayKey && last != yesterday) {
        streak = 0;
      }
    }
    emit(RewardsState(
      points: prefs.getInt(_pointsKey) ?? 0,
      streak: streak,
      lastActiveYmd: last,
      loaded: true,
    ));
  }

  Future<void> _record(RecordActivity e, Emitter<RewardsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = _ymd(today);
    final yesterday = _ymd(today.subtract(const Duration(days: 1)));

    var streak = state.streak;
    final last = state.lastActiveYmd;
    if (last == todayKey) {
      // already counted today
    } else if (last == yesterday) {
      streak += 1;
    } else {
      streak = 1; // first activity today after a gap (or ever)
    }

    final points = state.points + e.points;

    await prefs.setInt(_pointsKey, points);
    await prefs.setInt(_streakKey, streak);
    await prefs.setString(_lastActiveKey, todayKey);

    emit(state.copyWith(
      points: points,
      streak: streak,
      lastActiveYmd: todayKey,
      lastAward: e.points,
      lastReason: e.reason,
    ));
  }
}

abstract class RewardsEvent extends Equatable {
  const RewardsEvent();
  @override
  List<Object?> get props => [];
}

class LoadRewards extends RewardsEvent {}

class RecordActivity extends RewardsEvent {
  final int points;
  final String reason;
  const RecordActivity({required this.points, required this.reason});
  @override
  List<Object?> get props => [points, reason];
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
