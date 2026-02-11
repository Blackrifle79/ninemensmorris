/// App-wide constants for Nine Men's Morris
/// This file contains magic numbers and configuration values used throughout the app.
library;

class GameConstants {
  // ============================================
  // ANIMATION DURATIONS
  // ============================================

  /// Duration for piece movement animation
  static const Duration pieceMoveDuration = Duration(milliseconds: 400);

  /// Duration to show mill highlight before allowing capture
  static const Duration millHighlightDuration = Duration(milliseconds: 1500);

  /// Duration to show capture highlight before executing capture (AI)
  static const Duration captureHighlightDuration = Duration(milliseconds: 1000);

  /// Delay before AI makes a move (feels more natural)
  static const Duration aiThinkingDelay = Duration(milliseconds: 500);

  // ============================================
  // GAME BOARD
  // ============================================

  /// Tap/click tolerance in pixels for selecting pieces
  static const double tapTolerance = 25.0;

  /// Piece radius for rendering
  static const double pieceRadius = 14.0;

  /// Board size as fraction of available width
  static const double boardSizeFraction = 0.9;

  /// Outer ring size as fraction of board size
  static const double outerRingSizeFraction = 0.45;

  /// Middle ring size as fraction of board size
  static const double middleRingSizeFraction = 0.30;

  /// Inner ring size as fraction of board size
  static const double innerRingSizeFraction = 0.15;

  // ============================================
  // GAME RULES
  // ============================================

  /// Number of pieces each player starts with
  static const int startingPieces = 9;

  /// Minimum pieces required to continue playing
  static const int minimumPieces = 3;

  /// Number of rings on the board
  static const int numberOfRings = 3;

  /// Number of points per ring
  static const int pointsPerRing = 8;

  // ============================================
  // DRAW / REPETITION CONFIG
  // ============================================

  /// Number of consecutive non-capture moves before declaring a draw
  static const int noCaptureThreshold = 40;

  /// Number of repeats of the same position before declaring draw (threefold repetition)
  static const int repetitionThreshold = 3;

  /// Warning thresholds — show a UI warning when approaching a draw
  static const int noCaptureWarningThreshold = 10; // warn when within 10 moves
  static const int repetitionWarningThreshold =
      2; // warn when a position has occurred twice (one more = draw)

  // ============================================
  // GLOW EFFECTS
  // ============================================

  /// Green color for mill highlight
  static const int millHighlightColor = 0xFF4CAF50;

  /// Red color for capture highlight
  static const int captureHighlightColor = 0xFFE53935;
}
