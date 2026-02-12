import 'dart:math' show pow;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_score.dart';

/// Service for computing game scores and persisting them to the leaderboard.
///
/// The leaderboard tracks:
///   - `avg_score`      — ELO-like rating (starts at 50, goes up/down based on wins/losses)
///   - `online_score`   — Rolling average of online game scores (for performance tab)
///   - `offline_score`  — Rolling average of offline game scores (for performance tab)
///   - `games_played`   — Total online games (used for ranking)
///   - `online_games`   — Count of online games
///   - `offline_games`  — Count of offline games
///   - `wins`, `losses`, `draws`
class ScoringService {
  static final ScoringService _instance = ScoringService._internal();
  factory ScoringService() => _instance;
  ScoringService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ELO K-factor: how much ratings change per game
  // Higher = more volatile, lower = more stable
  static const double _kFactor = 32.0;

  // Scale factor for expected score calculation
  // In chess ELO it's 400, but our ratings are 0-100 so we use 25
  static const double _eloScale = 25.0;

  // ── Compute a GameScore from raw match data ─────────────────

  /// Build a [GameScore] for a single player from the game context.
  /// [totalMoves] is the number of moves this player made during the game.
  GameScore computeScore({
    required String playerId,
    required String? winnerId,
    required bool isDraw,
    required int playerPiecesRemaining,
    required int opponentPiecesRemaining,
    required double playerRating,
    required double opponentRating,
    required bool isOnline,
    int totalMoves = 0,
    int aiDifficultyIndex = -1,
    String? terminationReason,
  }) {
    String outcome;
    if (isDraw) {
      outcome = 'draw';
    } else if (winnerId == playerId) {
      outcome = 'win';
    } else {
      outcome = 'loss';
    }

    return GameScore(
      outcome: outcome,
      piecesRemaining: playerPiecesRemaining,
      opponentPiecesRemaining: opponentPiecesRemaining,
      totalMoves: totalMoves,
      playerRating: playerRating,
      opponentRating: opponentRating,
      aiDifficultyIndex: aiDifficultyIndex,
      isOnline: isOnline,
      terminationReason: terminationReason,
    );
  }

  // ── Fetch a player's current scores/ratings ─────────────────

  /// Returns a map with keys: avg_score (rating), online_score, offline_score,
  /// games_played, online_games, offline_games, wins, losses, draws
  /// (defaults to 50/0 if missing).
  Future<Map<String, dynamic>> getPlayerScores(String playerId) async {
    try {
      final row = await _client
          .from('leaderboard')
          .select()
          .eq('id', playerId)
          .maybeSingle();

      if (row == null) {
        return {
          'avg_score': 50.0, // This is the overall rating
          'online_score': 50.0, // Average of online game scores
          'offline_score': 50.0, // Average of offline game scores
          'games_played': 0,
          'online_games': 0,
          'offline_games': 0,
          'wins': 0,
          'losses': 0,
          'draws': 0,
        };
      }

      return {
        'avg_score': _toDouble(row['avg_score'], 50.0),
        'online_score': _toDouble(row['online_score'], 50.0),
        'offline_score': _toDouble(row['offline_score'], 50.0),
        'games_played': _toInt(row['games_played'], 0),
        'online_games': _toInt(row['online_games'], 0),
        'offline_games': _toInt(row['offline_games'], 0),
        'wins': _toInt(row['wins'], 0),
        'losses': _toInt(row['losses'], 0),
        'draws': _toInt(row['draws'], 0),
      };
    } catch (e) {
      debugPrint('ScoringService.getPlayerScores error: $e');
      return {
        'avg_score': 50.0,
        'online_score': 50.0,
        'offline_score': 50.0,
        'games_played': 0,
        'online_games': 0,
        'offline_games': 0,
        'wins': 0,
        'losses': 0,
        'draws': 0,
      };
    }
  }

  // ── Persist score to leaderboard ────────────────────────────

  /// Calculate ELO rating change based on outcome and opponent strength.
  /// Returns the new rating.
  double _calculateEloRating({
    required double playerRating,
    required double opponentRating,
    required String outcome,
  }) {
    // Calculate expected score (probability of winning) using ELO formula
    // E = 1 / (1 + 10^((opponentRating - playerRating) / scale))
    final ratingDiff = opponentRating - playerRating;
    final expectedScore = 1.0 / (1.0 + pow(10.0, ratingDiff / _eloScale));

    // Actual score: 1 for win, 0.5 for draw, 0 for loss
    double actualScore;
    switch (outcome) {
      case 'win':
        actualScore = 1.0;
        break;
      case 'draw':
        actualScore = 0.5;
        break;
      case 'loss':
      default:
        actualScore = 0.0;
        break;
    }

    // ELO formula: newRating = oldRating + K * (actualScore - expectedScore)
    // Scale K factor based on our 0-100 rating range (vs standard 0-3000)
    final scaledK = _kFactor / 100.0 * 10.0; // Roughly 3.2 points max change
    final change = scaledK * (actualScore - expectedScore);

    return (playerRating + change).clamp(0.0, 100.0);
  }

  /// Record a [GameScore] for [playerId], updating their ratings.
  /// Returns a map with 'oldRating' and 'newRating' for display.
  Future<Map<String, double>> recordScore({
    required String playerId,
    required String username,
    required GameScore score,
    required bool isOnline,
  }) async {
    double oldRating = 50.0;
    double newRating = 50.0;

    try {
      final existing = await _client
          .from('leaderboard')
          .select()
          .eq('id', playerId)
          .maybeSingle();

      final isWin = score.outcome == 'win';
      final isLoss = score.outcome == 'loss';
      final isDraw = score.outcome == 'draw';
      final gameScore = score.totalScore; // Individual game performance score

      if (existing == null) {
        // ── First game ever — insert ──
        oldRating = 50.0;

        // Calculate ELO rating change (only for online games)
        if (isOnline) {
          newRating = _calculateEloRating(
            playerRating: oldRating,
            opponentRating: score.opponentRating,
            outcome: score.outcome,
          );
        } else {
          newRating = 50.0;
        }

        await _client.from('leaderboard').insert({
          'id': playerId,
          'username': username,
          'score': newRating.round(), // legacy column
          'avg_score': newRating, // Overall ELO rating
          'games_played': isOnline ? 1 : 0,
          'online_score': isOnline
              ? gameScore.toDouble()
              : 50.0, // Avg of game performance scores
          'online_games': isOnline ? 1 : 0,
          'offline_score': !isOnline ? gameScore.toDouble() : 50.0,
          'offline_games': !isOnline ? 1 : 0,
          'wins': isWin ? 1 : 0,
          'losses': isLoss ? 1 : 0,
          'draws': isDraw ? 1 : 0,
          'moves_played': 0,
          'captures': 0,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        // ── Update existing record ──
        oldRating = _toDouble(existing['avg_score'], 50.0);

        // Calculate new ELO rating (only for online games)
        if (isOnline) {
          newRating = _calculateEloRating(
            playerRating: oldRating,
            opponentRating: score.opponentRating,
            outcome: score.outcome,
          );
        } else {
          newRating = oldRating; // Offline games don't affect overall rating
        }

        // Update games played (only online games count for leaderboard)
        final oldGamesPlayed = _toInt(existing['games_played'], 0);
        final newGamesPlayed = isOnline ? oldGamesPlayed + 1 : oldGamesPlayed;

        // Update online/offline score averages
        double newOnlineScore;
        int newOnlineGames;
        double newOfflineScore;
        int newOfflineGames;

        if (isOnline) {
          final oldOnlineGames = _toInt(existing['online_games'], 0);
          final oldOnlineScore = _toDouble(existing['online_score'], 50.0);
          newOnlineGames = oldOnlineGames + 1;
          // Rolling average of game scores for performance tab
          newOnlineScore =
              (oldOnlineScore * oldOnlineGames + gameScore) / newOnlineGames;
          newOfflineGames = _toInt(existing['offline_games'], 0);
          newOfflineScore = _toDouble(existing['offline_score'], 50.0);
        } else {
          final oldOfflineGames = _toInt(existing['offline_games'], 0);
          final oldOfflineScore = _toDouble(existing['offline_score'], 50.0);
          newOfflineGames = oldOfflineGames + 1;
          newOfflineScore =
              (oldOfflineScore * oldOfflineGames + gameScore) / newOfflineGames;
          newOnlineGames = _toInt(existing['online_games'], 0);
          newOnlineScore = _toDouble(existing['online_score'], 50.0);
        }

        final newWins = _toInt(existing['wins'], 0) + (isWin ? 1 : 0);
        final newLosses = _toInt(existing['losses'], 0) + (isLoss ? 1 : 0);
        final newDraws = _toInt(existing['draws'], 0) + (isDraw ? 1 : 0);

        await _client
            .from('leaderboard')
            .update({
              'username': username,
              'score': newRating.round(), // legacy column
              'avg_score': newRating, // Overall rating
              'games_played': newGamesPlayed,
              'online_score': newOnlineScore,
              'online_games': newOnlineGames,
              'offline_score': newOfflineScore,
              'offline_games': newOfflineGames,
              'wins': newWins,
              'losses': newLosses,
              'draws': newDraws,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', playerId);
      }
    } catch (e) {
      debugPrint('ScoringService.recordScore error: $e');
      // Don't rethrow — scoring should never crash the game
    }

    return {'oldRating': oldRating, 'newRating': newRating};
  }

  // ── Helpers ─────────────────────────────────────────────────

  double _toDouble(dynamic v, double fallback) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  int _toInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}
