import 'package:flutter/material.dart';
import '../models/game_score.dart';
import '../utils/app_styles.dart';

/// Full-page screen displaying game results (victory, defeat, or draw).
/// Shows winner, game scores, and rating change (for online games).
class GameResultScreen extends StatelessWidget {
  final GameScore score;
  final String playerName;
  final GameScore? opponentScore;
  final String? opponentName;
  final VoidCallback? onNewGame;
  final VoidCallback? onBackToMenu;
  final bool showNewGameButton;

  /// Which color won: 'white', 'black', or null for draw
  final String? winnerColor;

  /// For online games: old and new rating to show change
  final double? oldRating;
  final double? newRating;

  /// For online games: old and new ranking
  final int? oldRank;
  final int? newRank;

  const GameResultScreen({
    super.key,
    required this.score,
    required this.playerName,
    this.opponentScore,
    this.opponentName,
    this.onNewGame,
    this.onBackToMenu,
    this.showNewGameButton = true,
    this.winnerColor,
    this.oldRating,
    this.newRating,
    this.oldRank,
    this.newRank,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppStyles.burgundy.withValues(alpha: 0.8),
        elevation: 0,
        foregroundColor: AppStyles.cream,
        centerTitle: true,
        title: Text(_headerText, style: AppStyles.headingMediumLight),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Tavern background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/tavern.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Parchment overlay at 30% opacity
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage(
                  'assets/DD Grunge Texture 90878_DD-Grunge-Texture-90878-Preview.jpg',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.7),
                  BlendMode.dstIn,
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: AppStyles.dialogDecoration,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Game scores section
                      _buildScoresSection(),

                      // Rating change section (online games only)
                      if (oldRating != null && newRating != null) ...[
                        const SizedBox(height: 24),
                        _buildRatingSection(),
                      ],

                      const SizedBox(height: 24),

                      // Buttons
                      if (showNewGameButton && onNewGame != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: AppStyles.primaryButtonStyle,
                            onPressed: onNewGame,
                            child: const Text('New Game'),
                          ),
                        ),
                      if (showNewGameButton && onNewGame != null)
                        const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: AppStyles.primaryButtonStyle,
                          onPressed:
                              onBackToMenu ??
                              () {
                                Navigator.of(context).pop();
                              },
                          child: const Text('Exit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scores Section ──────────────────────────────────────────

  Widget _buildScoresSection() {
    return Column(
      children: [
        // Player's score
        _buildPlayerScore(playerName, score.totalScore, score.outcome == 'win'),

        if (opponentScore != null && opponentName != null) ...[
          const SizedBox(height: 16),
          const Text('vs', style: AppStyles.bodyText),
          const SizedBox(height: 16),
          // Opponent's score
          _buildPlayerScore(
            opponentName!,
            opponentScore!.totalScore,
            opponentScore!.outcome == 'win',
          ),
        ],
      ],
    );
  }

  Widget _buildPlayerScore(String name, int gameScore, bool isWinner) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.emoji_events, color: Color(0xFFD4AF37), size: 24),
          ),
        Column(
          children: [
            Text(name, style: AppStyles.bodyTextBold),
            const SizedBox(height: 4),
            _scoreCircle(gameScore, 70),
          ],
        ),
        if (isWinner)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(width: 24), // Balance the trophy icon
          ),
      ],
    );
  }

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
              strokeWidth: 5,
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

  // ── Rating Section ──────────────────────────────────────────

  Widget _buildRatingSection() {
    final change = newRating! - oldRating!;
    final isPositive = change > 0;
    final changeText = isPositive
        ? '+${change.toStringAsFixed(1)}'
        : change.toStringAsFixed(1);
    final changeColor = isPositive
        ? AppStyles.green
        : change < 0
        ? AppStyles.burgundy
        : AppStyles.mediumBrown;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyles.cream.withValues(alpha: 0.5),
        border: Border.all(color: AppStyles.mediumBrown.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('Online Rating', style: AppStyles.labelText),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Old rating
              Text(
                oldRating!.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 24,
                  color: AppStyles.mediumBrown,
                ),
              ),
              const SizedBox(width: 12),
              // Arrow
              Icon(Icons.arrow_forward, color: AppStyles.mediumBrown, size: 20),
              const SizedBox(width: 12),
              // New rating
              Text(
                newRating!.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: AppStyles.fontBody,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.darkBrown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Change indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: changeColor.withValues(alpha: 0.15),
            ),
            child: Text(
              changeText,
              style: TextStyle(
                fontFamily: AppStyles.fontBody,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: changeColor,
              ),
            ),
          ),
          // Ranking section
          if (newRank != null) ...[
            const SizedBox(height: 16),
            const Divider(color: AppStyles.mediumBrown, thickness: 0.5),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.leaderboard,
                  color: AppStyles.mediumBrown,
                  size: 20,
                ),
                const SizedBox(width: 8),
                if (oldRank != null) ...[
                  // Show old rank → new rank with change
                  Text(
                    '#$oldRank',
                    style: TextStyle(
                      fontFamily: AppStyles.fontBody,
                      fontSize: 18,
                      color: AppStyles.mediumBrown,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    color: AppStyles.mediumBrown,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '#$newRank',
                    style: TextStyle(
                      fontFamily: AppStyles.fontBody,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.darkBrown,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (oldRank != newRank) ...[
                    // Lower rank number = better, so negative change = improvement
                    Text(
                      oldRank! > newRank!
                          ? '▲${oldRank! - newRank!}' // Improved (went up)
                          : '▼${newRank! - oldRank!}', // Dropped (went down)
                      style: TextStyle(
                        fontFamily: AppStyles.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: oldRank! > newRank!
                            ? AppStyles.green
                            : AppStyles.burgundy,
                      ),
                    ),
                  ] else ...[
                    // No change
                    Text(
                      '—',
                      style: TextStyle(
                        fontFamily: AppStyles.fontBody,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.mediumBrown,
                      ),
                    ),
                  ],
                ] else ...[
                  // Just show new rank if no old rank
                  Text(
                    'Rank: #$newRank',
                    style: TextStyle(
                      fontFamily: AppStyles.fontBody,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.darkBrown,
                    ),
                  ),
                ],
              ],
            ),
          ],
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
    if (score.outcome == 'draw') return 'Draw';
    if (winnerColor == 'white') return 'White Wins';
    if (winnerColor == 'black') return 'Black Wins';
    // Fallback if winnerColor not provided
    switch (score.outcome) {
      case 'win':
        return 'You Win';
      case 'loss':
        return 'You Lose';
      default:
        return 'Game Over';
    }
  }
}
