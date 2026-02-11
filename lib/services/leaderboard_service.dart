import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get player ranking and score for matchmaking
  Future<Map<String, dynamic>> getPlayerRanking(String playerId) async {
    try {
      final data = await _client
          .from('leaderboard')
          .select('online_score, online_games')
          .eq('id', playerId)
          .maybeSingle();

      final score = (data?['online_score'] as num?)?.toDouble() ?? 50.0;
      final games = (data?['online_games'] as int?) ?? 0;

      // Get rank by counting players with higher scores using count()
      final higherRankResponse = await _client
          .from('leaderboard')
          .select('id')
          .gt('online_games', 0)
          .gt('online_score', score)
          .count(CountOption.exact);

      final rank = higherRankResponse.count + 1;

      return {
        'score': score,
        'games': games,
        'rank': rank,
      };
    } catch (e) {
      return {'score': 50.0, 'games': 0, 'rank': null};
    }
  }

  /// Get the total count of players on the leaderboard.
  Future<int> getTotalCount() async {
    try {
      // Use Supabase count feature to avoid row limits
      final response = await _client
          .from('leaderboard')
          .select('id')
          .gt('online_games', 0)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      return 0;
    }
  }

  /// Fetch top players ordered by `online_score` descending (online-only ranking).
  /// Only includes players who have played online games.
  Future<List<LeaderboardEntry>> fetchTop({int limit = 20}) async {
    try {
      final data = await _client
          .from('leaderboard')
          .select(
            'id, username, score, avg_score, games_played, '
            'online_score, online_games, offline_score, offline_games, '
            'wins, losses, draws',
          )
          .gt('online_games', 0) // Only players with online games
          .order('online_score', ascending: false)
          .limit(limit);

      if (data.isEmpty) return [];
      return data
          .map(
            (e) =>
                LeaderboardEntry.fromMap(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (e) {
      // If online_score column doesn't exist yet, fall back to legacy ordering
      try {
        final data = await _client
            .from('leaderboard')
            .select('id, username, score, wins, losses')
            .gt('online_games', 0) // Only players with online games
            .order('score', ascending: false)
            .limit(limit);

        if (data.isEmpty) return [];
        return data
            .map(
              (e) =>
                  LeaderboardEntry.fromMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (e2) {
        rethrow;
      }
    }
  }

  /// Fetch a specific player's leaderboard entry by ID.
  Future<LeaderboardEntry?> fetchPlayerEntry(String playerId) async {
    try {
      final data = await _client
          .from('leaderboard')
          .select(
            'id, username, score, avg_score, games_played, '
            'online_score, online_games, offline_score, offline_games, '
            'wins, losses, draws',
          )
          .eq('id', playerId)
          .maybeSingle();

      if (data == null) return null;
      return LeaderboardEntry.fromMap(Map<String, dynamic>.from(data));
    } catch (e) {
      return null;
    }
  }

  /// Fetch players around a given player's rank.
  /// Uses rank-based pagination to get players around the player's position.
  Future<List<LeaderboardEntry>> fetchAroundPlayer(
    String playerId, {
    int range = 10,
  }) async {
    try {
      const selectFields = 'id, username, score, avg_score, games_played, '
          'online_score, online_games, offline_score, offline_games, '
          'wins, losses, draws';

      // Get the player's score
      final playerData = await _client
          .from('leaderboard')
          .select('online_score')
          .eq('id', playerId)
          .maybeSingle();

      final playerScore =
          (playerData?['online_score'] as num?)?.toDouble() ?? 50.0;

      // Get the player's rank by counting players with higher scores
      final higherRankResponse = await _client
          .from('leaderboard')
          .select('id')
          .gt('online_games', 0)
          .gt('online_score', playerScore)
          .count(CountOption.exact);

      final playerRank = higherRankResponse.count + 1;

      // Calculate the offset to start fetching (range entries before the player)
      final offset = (playerRank - range - 1).clamp(0, 999999);

      // Fetch entries around the player's rank using pagination
      final data = await _client
          .from('leaderboard')
          .select(selectFields)
          .gt('online_games', 0)
          .order('online_score', ascending: false)
          .range(offset, offset + (range * 2) + 1);

      final entries = (data as List)
          .map((e) =>
              LeaderboardEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      return entries;
    } catch (e) {
      return [];
    }
  }
}
