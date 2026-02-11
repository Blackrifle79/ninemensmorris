import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../models/piece.dart';
import '../utils/app_styles.dart';

class GameStatus extends StatelessWidget {
  final GameModel gameModel;
  final bool waitingForCapture;
  final bool aiIsThinking;
  final String message;

  const GameStatus({
    super.key,
    required this.gameModel,
    this.waitingForCapture = false,
    this.aiIsThinking = false,
    this.message = '',
  });

  @override
  Widget build(BuildContext context) {
    final bool isWhite = gameModel.currentPlayer == PieceType.white;

    return SizedBox(
      height: 110, // Fixed height to prevent layout jumping
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Current player indicator - 3D piece style
          CustomPaint(
            size: const Size(32, 32),
            painter: _PieceIndicatorPainter(isWhite: isWhite),
          ),
          const SizedBox(height: 4),
          Text(
            isWhite ? 'White' : 'Black',
            style: const TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppStyles.darkBrown,
            ),
          ),
          const SizedBox(height: 4),
          // Game phase and status
          Text(
            _getStatusText(),
            style: TextStyle(
              fontFamily: AppStyles.fontBody,
              fontSize: 14,
              color: AppStyles.textPrimary,
              fontStyle: waitingForCapture
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          ),
          // Always reserve space for message line to prevent jumping
          SizedBox(
            height: 18,
            child: message.isNotEmpty && !waitingForCapture
                ? Text(
                    message,
                    style: TextStyle(
                      fontFamily: AppStyles.fontBody,
                      fontSize: 14,
                      color: AppStyles.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (gameModel.gameState == GameState.gameOver) {
      return '${gameModel.winner == PieceType.white ? 'White' : 'Black'} Wins!';
    }

    if (aiIsThinking) {
      return 'AI is thinking...';
    }

    if (waitingForCapture) {
      return 'Mill! Capture a piece.';
    }

    switch (gameModel.gamePhase) {
      case GamePhase.placing:
        return 'Placing';
      case GamePhase.moving:
      case GamePhase.flying:
        // Check if current player can fly (has exactly 3 pieces)
        int pieceCount = gameModel.board.values
            .where((p) => p.type == gameModel.currentPlayer)
            .length;
        if (pieceCount == 3) {
          return 'Flying';
        }
        return 'Moving';
    }
  }
}

/// Custom painter for 3D piece indicator
class _PieceIndicatorPainter extends CustomPainter {
  final bool isWhite;

  _PieceIndicatorPainter({required this.isWhite});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center + const Offset(2, 2), radius, shadowPaint);

    // Base gradient
    final baseGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.0,
      colors: isWhite
          ? [Colors.white, const Color(0xFFE0E0E0), const Color(0xFFB0B0B0)]
          : [const Color(0xFF4A4A4A), const Color(0xFF2A2A2A), Colors.black],
      stops: const [0.0, 0.6, 1.0],
    );

    final basePaint = Paint()
      ..shader = baseGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, basePaint);

    // Highlight
    final highlightGradient = RadialGradient(
      center: const Alignment(-0.5, -0.5),
      radius: 0.8,
      colors: isWhite
          ? [
              Colors.white.withValues(alpha: 0.9),
              Colors.white.withValues(alpha: 0.0),
            ]
          : [
              Colors.white.withValues(alpha: 0.3),
              Colors.white.withValues(alpha: 0.0),
            ],
    );

    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(
        Rect.fromCircle(center: center, radius: radius * 0.7),
      );
    canvas.drawCircle(
      center + Offset(-radius * 0.2, -radius * 0.2),
      radius * 0.5,
      highlightPaint,
    );

    // Rim
    final rimPaint = Paint()
      ..color = isWhite
          ? Colors.black.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 0.5, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
