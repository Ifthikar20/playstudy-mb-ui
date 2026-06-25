import 'package:flutter/widgets.dart';

/// Lets a game report its current score up to whatever is hosting it (the
/// play-tracking launch page) without the game knowing anything about
/// networking. A game calls, from anywhere in its subtree:
///
///     GameScoreScope.report(context, currentScore);
///
/// The host keeps the latest value and records it with the play session, so a
/// score earned on one platform is saved server-side and reflects on the other.
/// If no scope is present (tests / standalone), the call is a safe no-op.
class GameScoreScope extends InheritedWidget {
  final ValueChanged<int> onScore;

  const GameScoreScope({
    super.key,
    required this.onScore,
    required super.child,
  });

  /// Report the latest score. Safe to call from event/tick callbacks (it does
  /// not register an inherited-widget dependency).
  static void report(BuildContext context, int score) {
    final element =
        context.getElementForInheritedWidgetOfExactType<GameScoreScope>();
    final scope = element?.widget as GameScoreScope?;
    scope?.onScore(score);
  }

  @override
  bool updateShouldNotify(GameScoreScope oldWidget) => false;
}
