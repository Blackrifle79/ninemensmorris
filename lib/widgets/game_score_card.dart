import 'package:flutter/material.dart';
import '../models/game_score.dart';
import '../utils/app_styles.dart';

/// A themed card that displays a player's per-game score.
/// Shown at the conclusion of every game (online and offline) before
/// returning to the lobby/menu.
class GameScoreCard extends StatelessWidget {
  final GameScore score;
  final String playerName;

  /// Optional: second player's score (for showing both scores side-by-side)
  final GameScore? opponentScore;
  final String? opponentName;

  const GameScoreCard({
    super.key,
    required this.score,
    required this.playerName,
    this.opponentScore,
    this.opponentName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.dialogDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ──
          Text(_headerText, style: AppStyles.headingMedium),
          const SizedBox(height: 8),
          Text(
            _subtitleText,
            style: AppStyles.bodyText,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // ── Score ring(s) ──
          if (opponentScore != null && opponentName != null)
            _buildDualScoreRings()
          else
            _buildSingleScoreRing(score, playerName),
        ],
      ),
    );
  }

  // ── Score Circle ────────────────────────────────────────────

  Widget _buildSingleScoreRing(GameScore gs, String name) {
    return Column(
      children: [
        _scoreCircle(gs.totalScore, 80),
        const SizedBox(height: 8),
        Text(name, style: AppStyles.bodyTextBold),
      ],
    );
  }

  Widget _buildDualScoreRings() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSingleScoreRing(score, playerName),
        const Text('vs', style: AppStyles.bodyText),
        _buildSingleScoreRing(opponentScore!, opponentName!),
      ],
    );
  }

  /// Score circle with progress ring.
  Widget _scoreCircle(int value, double size) {
    final fraction = value / 100.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 6,
              backgroundColor: AppStyles.darkBrown.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(_ringColor(value)),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              color: AppStyles.darkBrown,
            ),
          ),
        ],
      ),
    );
  }

  // ── Color Helpers ───────────────────────────────────────────

  Color _ringColor(int value) {
    if (value >= 80) return const Color(0xFF2E7D32);
    if (value >= 60) return const Color(0xFF558B2F);
    if (value >= 40) return const Color(0xFF6D4C41);
    if (value >= 20) return const Color(0xFF8B0000);
    return const Color(0xFFB71C1C);
  }

  // ── Text Helpers ────────────────────────────────────────────

  String get _headerText {
    switch (score.outcome) {
      case 'win':
        return 'Victory!';
      case 'draw':
        return 'Draw';
      case 'loss':
        return 'Defeat';
      default:
        return 'Game Over';
    }
  }

  String get _subtitleText {
    switch (score.outcome) {
      case 'win':
        return 'Well played!';
      case 'draw':
        return 'A hard-fought match.';
      case 'loss':
        return 'Better luck next time!';
      default:
        return '';
    }
  }
}
