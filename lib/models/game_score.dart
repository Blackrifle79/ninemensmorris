/// Simplified per-game scoring system for Nine Men's Morris.
///
/// Score range: 0–100. Higher scores indicate better performance in that game.
///
/// ## Component Breakdown (max 100)
///
/// | Component          | Max | Description                                      |
/// |--------------------|-----|--------------------------------------------------|
/// | Outcome            |  40 | Win/Draw/Loss base points                        |
/// | Efficiency         |  15 | Fewer moves = more efficient victory (winners)   |
/// | Pieces Remaining   |  15 | More surviving pieces = more dominant (winners)  |
/// | Opponent Strength  |  30 | Heavy bonus for beating stronger opponents       |
///
/// ## Forfeit Handling
/// - If your opponent forfeits: You get full win credit (40)
/// - If you forfeit: You get minimal points (10) as penalty
///
class GameScore {
  // ── Inputs ──────────────────────────────────────────────────

  /// 'win', 'loss', or 'draw'
  final String outcome;

  /// Number of this player's pieces still on the board at game end
  final int piecesRemaining;

  /// Number of opponent's pieces still on the board at game end
  final int opponentPiecesRemaining;

  /// Total moves made by THIS player during the game
  final int totalMoves;

  /// This player's current online rating (before this game)
  final double playerRating;

  /// Opponent's current online rating (before this game)
  final double opponentRating;

  /// For offline games: AI difficulty index (0-4) or -1 for local multiplayer
  final int aiDifficultyIndex;

  /// Whether this is an online game
  final bool isOnline;

  /// How the game ended: 'insufficient_pieces', 'no_moves', 'threefold_repetition',
  /// 'no_capture_threshold', 'timeout', 'forfeit'
  final String? terminationReason;

  // ── Computed Sub-Scores ─────────────────────────────────────

  late final int outcomeScore;
  late final int efficiencyScore;
  late final int piecesScore;
  late final int opponentStrengthScore;
  late final int totalScore;

  GameScore({
    required this.outcome,
    required this.piecesRemaining,
    required this.opponentPiecesRemaining,
    this.totalMoves = 0,
    this.playerRating = 50.0,
    this.opponentRating = 50.0,
    this.aiDifficultyIndex = -1,
    this.isOnline = true,
    this.terminationReason,
  }) {
    _compute();
  }

  // ── Core Calculation ────────────────────────────────────────

  void _compute() {
    outcomeScore = _calcOutcome();
    efficiencyScore = _calcEfficiency();
    piecesScore = _calcPieces();
    opponentStrengthScore = _calcOpponentStrength();
    totalScore = (outcomeScore +
            efficiencyScore +
            piecesScore +
            opponentStrengthScore)
        .clamp(0, 100);
  }

  // ── 1. Outcome (0–40) ──────────────────────────────────────
  //
  // Win: 40 (full credit)
  // Draw: 28
  // Loss: 20
  // Loss (I forfeited/timed out): 10 (penalty for quitting)

  int _calcOutcome() {
    final iForfeited =
        (terminationReason == 'timeout' || terminationReason == 'forfeit');

    switch (outcome) {
      case 'win':
        // Full credit whether opponent quit or I beat them fairly
        return 40;
      case 'draw':
        return 28;
      case 'loss':
        if (iForfeited) {
          // I forfeited/timed out - penalty
          return 10;
        }
        // Opponent beat me fairly
        return 20;
      default:
        return 0;
    }
  }

  // ── 2. Efficiency (0–15) ────────────────────────────────────
  //
  // Only winners get efficiency points.
  // Fewer moves = more efficient = higher score.
  // Typical game is 30-60 moves per player.
  // <20 moves = max 15, >60 moves = min 3

  int _calcEfficiency() {
    if (outcome != 'win') return 0;
    if (totalMoves <= 0) return 8; // Default if not tracked

    // Map moves: fewer is better
    // 15 moves or less = 15 points
    // 60 moves or more = 3 points
    if (totalMoves <= 15) return 15;
    if (totalMoves >= 60) return 3;

    // Linear interpolation between 15 and 60 moves
    final ratio = (60 - totalMoves) / 45.0;
    return (3 + ratio * 12).round().clamp(3, 15);
  }

  // ── 3. Pieces Remaining (0–15) ─────────────────────────────
  //
  // Only winners get points for pieces remaining.
  // More pieces left = more dominant victory.
  // 9 pieces = 15, 3 pieces = 3

  int _calcPieces() {
    if (outcome != 'win') return 0;

    // piecesRemaining ranges from 3-9 (can't win with < 3)
    // Map 3-9 to 3-15
    return _mapRange(piecesRemaining.toDouble(), 3, 9, 3, 15);
  }

  // ── 4. Opponent Strength (0–30) ────────────────────────────
  //
  // Online: Based on opponent's rating relative to yours
  //   Beating much stronger = big bonus (up to 30)
  //   Beating weaker = smaller bonus
  //   Losing to stronger = moderate points
  //   Losing to much weaker = minimal points
  //
  // Offline (AI): Based on difficulty level

  int _calcOpponentStrength() {
    if (!isOnline && aiDifficultyIndex >= 0) {
      // Offline AI - scale difficulty to 0-30
      const difficultyScores = [6, 12, 18, 24, 30];
      final idx = aiDifficultyIndex.clamp(0, 4);
      return difficultyScores[idx];
    }

    if (!isOnline && aiDifficultyIndex < 0) {
      // Local multiplayer — neutral 15
      return 15;
    }

    // Online: relative strength system
    final diff = opponentRating - playerRating;
    // diff > 0 means opponent is stronger
    // diff < 0 means opponent is weaker

    if (outcome == 'win') {
      // Winning against stronger opponent = higher bonus
      // Base 15, +1 for every 3 points stronger, capped at 30
      final bonus = (diff / 3).round();
      return (15 + bonus).clamp(5, 30);
    } else if (outcome == 'draw') {
      // Draw against stronger = small bonus, against weaker = small penalty
      final bonus = (diff / 5).round();
      return (15 + bonus).clamp(5, 25);
    } else {
      // Loss: losing to much weaker = low points, to stronger = more points
      final bonus = (diff / 4).round();
      return (15 + bonus).clamp(0, 20);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────

  /// Linearly map [value] from [inMin..inMax] to [outMin..outMax], clamped.
  static int _mapRange(
    double value,
    double inMin,
    double inMax,
    double outMin,
    double outMax,
  ) {
    if (inMax == inMin) return outMax.round();
    final t = ((value - inMin) / (inMax - inMin)).clamp(0.0, 1.0);
    return (outMin + t * (outMax - outMin)).round();
  }

  // ── Serialization ───────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'outcome': outcome,
        'pieces_remaining': piecesRemaining,
        'opponent_pieces_remaining': opponentPiecesRemaining,
        'total_moves': totalMoves,
        'player_rating': playerRating,
        'opponent_rating': opponentRating,
        'ai_difficulty_index': aiDifficultyIndex,
        'is_online': isOnline,
        'termination_reason': terminationReason,
        'outcome_score': outcomeScore,
        'efficiency_score': efficiencyScore,
        'pieces_score': piecesScore,
        'opponent_strength_score': opponentStrengthScore,
        'total_score': totalScore,
      };

  factory GameScore.fromJson(Map<String, dynamic> json) {
    return GameScore(
      outcome: json['outcome'] as String? ?? 'loss',
      piecesRemaining: json['pieces_remaining'] as int? ?? 0,
      opponentPiecesRemaining: json['opponent_pieces_remaining'] as int? ?? 0,
      totalMoves: json['total_moves'] as int? ?? 0,
      playerRating: (json['player_rating'] as num?)?.toDouble() ?? 50.0,
      opponentRating: (json['opponent_rating'] as num?)?.toDouble() ?? 50.0,
      aiDifficultyIndex: json['ai_difficulty_index'] as int? ?? -1,
      isOnline: json['is_online'] as bool? ?? true,
      terminationReason: json['termination_reason'] as String?,
    );
  }
}
