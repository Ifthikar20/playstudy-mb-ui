import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

/// Talks to the backend play-tracking API (`/games/sessions`). Every call is
/// best-effort: a tracking failure must never interrupt gameplay, so errors are
/// swallowed and logged. The server is the source of truth for scores, rewards
/// and resume state — this just reports the host's SDK events to it.
class GameSessionRepository {
  final ApiClient api;
  GameSessionRepository(this.api);

  /// Starts a play and returns the server session id (null on failure).
  Future<String?> start({required String gameKey, String? studySetId}) async {
    try {
      final response = await api.dio.post('games/sessions/', data: {
        'gameKey': gameKey,
        if (studySetId != null) 'studySetId': studySetId,
      });
      return response.data['id'] as String?;
    } catch (e) {
      debugPrint('[games] session start failed: $e');
      return null;
    }
  }

  /// Persists mid-play score / save-state so a play can resume across devices.
  Future<void> heartbeat(
    String sessionId, {
    int? score,
    Map<String, dynamic>? progress,
  }) async {
    try {
      await api.dio.patch('games/sessions/$sessionId/', data: {
        if (score != null) 'score': score,
        if (progress != null) 'progress': progress,
      });
    } catch (e) {
      debugPrint('[games] session heartbeat failed: $e');
    }
  }

  /// Finalizes a play; the server grants the (capped, deduped) reward.
  Future<void> complete(String sessionId, {int? score}) async {
    try {
      await api.dio.post('games/sessions/$sessionId/complete/', data: {
        if (score != null) 'score': score,
      });
    } catch (e) {
      debugPrint('[games] session complete failed: $e');
    }
  }
}
