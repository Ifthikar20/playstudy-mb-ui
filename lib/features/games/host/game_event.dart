/// An event emitted by a running game bundle over the PlayStudy SDK bridge.
///
/// This is the platform-agnostic shape both hosts ([GameHostView] on mobile via
/// WebView, on web via an iframe) hand back to the app. Games speak the same
/// contract regardless of the engine they're built with (Phaser, Pixi, plain
/// canvas, Godot/Unity web export, …):
///
///   ready     — game initialized; host should (re)send the init payload.
///   score     — current score update.
///   progress  — opaque save-state for resume (data['state']).
///   reward    — request a gameplay reward (data['reason']).
///   gameover  — run finished (data may carry 'score').
///   error     — game reported a fatal error (data['message']).
class GameEvent {
  final String type;
  final Map<String, dynamic> data;

  const GameEvent(this.type, [this.data = const {}]);

  factory GameEvent.fromJson(Map<String, dynamic> json) =>
      GameEvent((json['type'] ?? '').toString(), json);

  int? get score => data['score'] is num ? (data['score'] as num).toInt() : null;
  String? get reason => data['reason']?.toString();
  String? get message => data['message']?.toString();
  Map<String, dynamic>? get state =>
      data['state'] is Map ? Map<String, dynamic>.from(data['state']) : null;

  @override
  String toString() => 'GameEvent($type, $data)';
}

/// Callback the host invokes for every event a game emits.
typedef GameEventCallback = void Function(GameEvent event);
