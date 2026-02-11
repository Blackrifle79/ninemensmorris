import 'package:flutter/material.dart';
import '../models/game_model.dart';
import '../models/position.dart';
import '../models/piece.dart';
import '../utils/app_styles.dart';
import '../utils/constants.dart';

/// Represents an animated piece movement
class PieceAnimation {
  final Position from;
  final Position to;
  final PieceType pieceType;

  PieceAnimation({
    required this.from,
    required this.to,
    required this.pieceType,
  });
}

class GameBoard extends StatefulWidget {
  final GameModel gameModel;
  final Function(Position) onPositionTapped;
  final Set<Position>?
  millHighlight; // Positions to highlight green (mill formed)
  final Position?
  captureHighlight; // Position to highlight red (piece being captured)
  final bool waitingForCapture; // Whether player needs to capture a piece

  const GameBoard({
    super.key,
    required this.gameModel,
    required this.onPositionTapped,
    this.millHighlight,
    this.captureHighlight,
    this.waitingForCapture = false,
  });

  @override
  State<GameBoard> createState() => GameBoardState();
}

class GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  // Animation controller for piece movement
  AnimationController? _moveController;
  Animation<double>? _moveAnimation;
  Animation<double>? _scaleAnimation;

  // Current animation data
  PieceAnimation? _currentAnimation;

  // Track board state to detect moves
  Map<Position, Piece> _previousBoard = {};

  // Skip animation on initial sync to avoid false "move" detection
  // when room data passed via navigation differs from realtime state
  bool _initialSyncDone = false;

  // Hover state for capture mode
  Position? _hoveredPosition;

  @override
  void initState() {
    super.initState();
    _previousBoard = Map.from(widget.gameModel.board);
  }

  @override
  void didUpdateWidget(GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _detectAndAnimateMove();
  }

  void _detectAndAnimateMove() {
    final currentBoard = widget.gameModel.board;
    final gamePhase = widget.gameModel.gamePhase;

    // Skip animation detection on first few updates - the initial room data
    // passed via navigation might be stale compared to realtime state.
    // We skip the first 2 updates to be safe against rapid realtime events.
    if (!_initialSyncDone) {
      _initialSyncDone = true;
      _previousBoard = Map.from(currentBoard);
      return;
    }

    // Only animate moves during the moving/flying phase - during placing phase,
    // pieces should only appear (not move), so any detected "move" is a sync artifact
    if (gamePhase == GamePhase.placing) {
      _previousBoard = Map.from(currentBoard);
      return;
    }

    // Count total changes - if more than 2 pieces changed, it's a puzzle reset, not a move
    int changesCount = 0;
    for (final entry in _previousBoard.entries) {
      if (!currentBoard.containsKey(entry.key) ||
          currentBoard[entry.key]?.type != entry.value.type) {
        changesCount++;
      }
    }
    for (final entry in currentBoard.entries) {
      if (!_previousBoard.containsKey(entry.key)) {
        changesCount++;
      }
    }

    // Skip animation if too many changes (puzzle was reset)
    if (changesCount > 2) {
      _previousBoard = Map.from(currentBoard);
      return;
    }

    // Find what changed
    Position? removedFrom;
    Position? addedTo;
    PieceType? movedPieceType;

    // Find removed piece (was in previous, not in current)
    for (final entry in _previousBoard.entries) {
      if (!currentBoard.containsKey(entry.key)) {
        // This piece was removed - could be a move or a capture
        // Check if a piece of the same type appeared somewhere new
        removedFrom = entry.key;
        movedPieceType = entry.value.type;
        break;
      }
    }

    // Find added piece (in current, not in previous)
    for (final entry in currentBoard.entries) {
      if (!_previousBoard.containsKey(entry.key)) {
        addedTo = entry.key;
        movedPieceType ??= entry.value.type;
        break;
      }
    }

    // If we found both a removal and addition of the same piece type, it's a move
    // Also verify the positions are adjacent (or player is flying with 3 pieces)
    if (removedFrom != null &&
        addedTo != null &&
        movedPieceType != null &&
        currentBoard[addedTo]?.type == movedPieceType) {
      _animateMove(
        PieceAnimation(
          from: removedFrom,
          to: addedTo,
          pieceType: movedPieceType,
        ),
      );
    }

    // Update previous board state
    _previousBoard = Map.from(currentBoard);
  }

  /// Public method to trigger animation for a move (can be called externally)
  void animateMove(Position from, Position to, PieceType pieceType) {
    _animateMove(PieceAnimation(from: from, to: to, pieceType: pieceType));
  }

  void _animateMove(PieceAnimation animation) {
    // Cancel any existing animation
    _moveController?.dispose();

    // Create new animation controller
    _moveController = AnimationController(
      duration: GameConstants.pieceMoveDuration,
      vsync: this,
    );

    // Movement animation with ease in/out
    _moveAnimation = CurvedAnimation(
      parent: _moveController!,
      curve: Curves.easeInOutCubic,
    );

    // Scale animation: lift up then drop down
    // 0.0 -> 0.5: scale up (lifting)
    // 0.5 -> 1.0: scale down (dropping)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.25,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.25,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_moveController!);

    setState(() {
      _currentAnimation = animation;
    });

    _moveController!.forward().then((_) {
      if (mounted) {
        setState(() {
          _currentAnimation = null;
        });
      }
    });

    // Add listener for continuous updates during animation
    _moveController!.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _moveController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        _handleHover(event.localPosition, context);
      },
      onExit: (_) {
        setState(() {
          _hoveredPosition = null;
        });
      },
      child: CustomPaint(
        painter: GameBoardPainter(
          gameModel: widget.gameModel,
          onPositionTapped: widget.onPositionTapped,
          animatingPosition: _currentAnimation?.to,
          millHighlight: widget.millHighlight,
          captureHighlight: widget.captureHighlight,
          hoveredPosition: _hoveredPosition,
          waitingForCapture: widget.waitingForCapture,
        ),
        child: Stack(
          children: [
            // Gesture detector for taps - must be opaque to capture all taps
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _handleTap(details.localPosition, context);
              },
            ),
            // Animated piece overlay
            if (_currentAnimation != null &&
                _moveAnimation != null &&
                _scaleAnimation != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final positions = _getPositionOffsets(size);
                  final fromOffset = positions[_currentAnimation!.from]!;
                  final toOffset = positions[_currentAnimation!.to]!;

                  // Interpolate position
                  final currentOffset = Offset.lerp(
                    fromOffset,
                    toOffset,
                    _moveAnimation!.value,
                  )!;

                  final scale = _scaleAnimation!.value;
                  final isWhite =
                      _currentAnimation!.pieceType == PieceType.white;

                  return CustomPaint(
                    painter: AnimatedPiecePainter(
                      offset: currentOffset,
                      scale: scale,
                      isWhite: isWhite,
                    ),
                    size: size,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _handleHover(Offset localPosition, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    Position? hoveredPos = _getPositionFromOffset(localPosition, size);
    if (hoveredPos != _hoveredPosition) {
      setState(() {
        _hoveredPosition = hoveredPos;
      });
    }
  }

  void _handleTap(Offset localPosition, BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    Position? tappedPosition = _getPositionFromOffset(localPosition, size);
    if (tappedPosition != null) {
      widget.onPositionTapped(tappedPosition);
    }
  }

  Position? _getPositionFromOffset(Offset offset, Size size) {
    final positions = _getPositionOffsets(size);

    for (final entry in positions.entries) {
      final distance = (entry.value - offset).distance;
      if (distance < GameConstants.tapTolerance) {
        return entry.key;
      }
    }
    return null;
  }

  Map<Position, Offset> _getPositionOffsets(Size size) {
    final Map<Position, Offset> positions = {};
    final center = Offset(size.width / 2, size.height / 2);
    final boardSize = size.width * GameConstants.boardSizeFraction;

    // Calculate ring sizes (half-width of each square)
    final outerRingSize = boardSize * GameConstants.outerRingSizeFraction;
    final middleRingSize = boardSize * GameConstants.middleRingSizeFraction;
    final innerRingSize = boardSize * GameConstants.innerRingSizeFraction;

    final ringSizes = [outerRingSize, middleRingSize, innerRingSize];

    // All 3 rings have all 8 points (4 corners + 4 midpoints)
    for (int ring = 0; ring < 3; ring++) {
      final ringSize = ringSizes[ring];

      for (int point = 0; point < 8; point++) {
        Offset positionOffset = _calculatePositionOffset(
          center,
          ringSize,
          point,
        );
        positions[Position(ring: ring, point: point)] = positionOffset;
      }
    }

    return positions;
  }

  /// Calculate position offset for a point on a square
  /// Points are arranged around a square:
  /// 7 --- 0 --- 1
  /// |           |
  /// 6           2
  /// |           |
  /// 5 --- 4 --- 3
  Offset _calculatePositionOffset(Offset center, double halfSize, int point) {
    switch (point) {
      case 0: // Top center (midpoint)
        return Offset(center.dx, center.dy - halfSize);
      case 1: // Top-right corner
        return Offset(center.dx + halfSize, center.dy - halfSize);
      case 2: // Right center (midpoint)
        return Offset(center.dx + halfSize, center.dy);
      case 3: // Bottom-right corner
        return Offset(center.dx + halfSize, center.dy + halfSize);
      case 4: // Bottom center (midpoint)
        return Offset(center.dx, center.dy + halfSize);
      case 5: // Bottom-left corner
        return Offset(center.dx - halfSize, center.dy + halfSize);
      case 6: // Left center (midpoint)
        return Offset(center.dx - halfSize, center.dy);
      case 7: // Top-left corner
        return Offset(center.dx - halfSize, center.dy - halfSize);
      default:
        return center;
    }
  }
}

/// Painter for the animated piece during movement
class AnimatedPiecePainter extends CustomPainter {
  final Offset offset;
  final double scale;
  final bool isWhite;

  AnimatedPiecePainter({
    required this.offset,
    required this.scale,
    required this.isWhite,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double baseRadius = 14.0;
    final double radius = baseRadius * scale;

    // Shadow grows and gets softer as piece lifts
    final shadowOffset = Offset(2 + (scale - 1) * 8, 2 + (scale - 1) * 8);
    final shadowBlur = 3.0 + (scale - 1) * 10;
    final shadowOpacity = 0.3 + (scale - 1) * 0.2;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: shadowOpacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);
    canvas.drawCircle(offset + shadowOffset, radius, shadowPaint);

    // Base color gradient for 3D effect
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
        Rect.fromCircle(center: offset, radius: radius),
      );
    canvas.drawCircle(offset, radius, basePaint);

    // Highlight on top-left for shine
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
      stops: const [0.0, 1.0],
    );

    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(
        Rect.fromCircle(center: offset, radius: radius * 0.7),
      );
    canvas.drawCircle(
      offset + Offset(-radius * 0.2, -radius * 0.2),
      radius * 0.5,
      highlightPaint,
    );

    // Subtle rim/edge highlight
    final rimPaint = Paint()
      ..color = isWhite
          ? Colors.black.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(offset, radius - 0.5, rimPaint);
  }

  @override
  bool shouldRepaint(covariant AnimatedPiecePainter oldDelegate) {
    return oldDelegate.offset != offset ||
        oldDelegate.scale != scale ||
        oldDelegate.isWhite != isWhite;
  }
}

class GameBoardPainter extends CustomPainter {
  final GameModel gameModel;
  final Function(Position) onPositionTapped;
  final Position? animatingPosition;
  final Set<Position>? millHighlight;
  final Position? captureHighlight;
  final Position? hoveredPosition;
  final bool waitingForCapture;

  GameBoardPainter({
    required this.gameModel,
    required this.onPositionTapped,
    this.animatingPosition,
    this.millHighlight,
    this.captureHighlight,
    this.hoveredPosition,
    this.waitingForCapture = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppStyles.textPrimary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final boardSize = size.width * 0.9;

    // Calculate ring sizes (half-width of each square) - must match _getPositionOffsets
    final outerRingSize = boardSize * 0.45;
    final middleRingSize = boardSize * 0.30;
    final innerRingSize = boardSize * 0.15;

    // Draw the three concentric squares (using full width = 2 * halfSize)
    _drawSquare(canvas, paint, center, outerRingSize * 2);
    _drawSquare(canvas, paint, center, middleRingSize * 2);
    _drawSquare(canvas, paint, center, innerRingSize * 2);

    // Draw connecting lines between rings (at midpoints only)
    _drawConnectingLines(
      canvas,
      paint,
      center,
      outerRingSize,
      middleRingSize,
      innerRingSize,
    );

    // Draw position points and pieces
    _drawPositionsAndPieces(canvas, size);
  }

  void _drawSquare(Canvas canvas, Paint paint, Offset center, double size) {
    final rect = Rect.fromCenter(center: center, width: size, height: size);
    canvas.drawRect(rect, paint);
  }

  void _drawConnectingLines(
    Canvas canvas,
    Paint paint,
    Offset center,
    double outerSize,
    double middleSize,
    double innerSize,
  ) {
    // Draw lines connecting midpoints between all three rings
    // These are the only lines that connect between rings

    // Top connecting lines (point 0)
    canvas.drawLine(
      Offset(center.dx, center.dy - outerSize),
      Offset(center.dx, center.dy - innerSize),
      paint,
    );

    // Right connecting lines (point 2)
    canvas.drawLine(
      Offset(center.dx + outerSize, center.dy),
      Offset(center.dx + innerSize, center.dy),
      paint,
    );

    // Bottom connecting lines (point 4)
    canvas.drawLine(
      Offset(center.dx, center.dy + outerSize),
      Offset(center.dx, center.dy + innerSize),
      paint,
    );

    // Left connecting lines (point 6)
    canvas.drawLine(
      Offset(center.dx - outerSize, center.dy),
      Offset(center.dx - innerSize, center.dy),
      paint,
    );
  }

  void _drawPositionsAndPieces(Canvas canvas, Size size) {
    final positions = _getPositionOffsets(size);

    // First pass: draw position points and highlights BELOW pieces
    for (final entry in positions.entries) {
      final position = entry.key;
      final offset = entry.value;

      // Draw position point
      _drawPositionPointBase(canvas, offset);

      // Draw selection highlight (yellow ring) BELOW piece
      if (gameModel.selectedPosition == position) {
        _drawSelectionHighlight(canvas, offset);
      }

      // Draw mill highlight (green ring) BELOW piece
      if (millHighlight != null && millHighlight!.contains(position)) {
        _drawHighlightRing(
          canvas,
          offset,
          const Color(GameConstants.millHighlightColor),
        );
      }

      // Draw capture highlight (red ring) BELOW piece - static highlight
      if (captureHighlight == position) {
        _drawHighlightRing(
          canvas,
          offset,
          const Color(GameConstants.captureHighlightColor),
        );
      }

      // Draw hover red ring for potential capture targets (only during capture mode)
      if (waitingForCapture &&
          hoveredPosition == position &&
          captureHighlight == null &&
          millHighlight == null) {
        // Check if this is an opponent piece that can be captured (not in a mill)
        final piece = gameModel.board[position];
        if (piece != null &&
            piece.type != gameModel.currentPlayer &&
            !gameModel.isInMill(position)) {
          _drawHighlightRing(
            canvas,
            offset,
            const Color(GameConstants.captureHighlightColor),
          );
        }
      }
    }

    // Second pass: draw pieces ON TOP of highlights
    for (final entry in positions.entries) {
      final position = entry.key;
      final offset = entry.value;

      // Draw piece if present (skip if this position is being animated)
      if (gameModel.board.containsKey(position) &&
          position != animatingPosition) {
        _drawPiece(canvas, offset, gameModel.board[position]!);
      }
    }
  }

  /// Draw a ring highlight around a piece (similar to selection ring)
  void _drawHighlightRing(Canvas canvas, Offset offset, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset, 18, paint);
  }

  /// Draw the base position point (without selection)
  void _drawPositionPointBase(Canvas canvas, Offset offset) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw position point (circle)
    paint.color = AppStyles.textPrimary;
    canvas.drawCircle(offset, 8, paint);

    // Inner circle
    paint.color = AppStyles.cream;
    canvas.drawCircle(offset, 5, paint);
  }

  /// Draw selection highlight ring around a piece
  void _drawSelectionHighlight(Canvas canvas, Offset offset) {
    final paint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset, 18, paint);
  }

  void _drawPiece(Canvas canvas, Offset offset, Piece piece) {
    final bool isWhite = piece.type == PieceType.white;
    final double radius = 14.0;

    // Shadow underneath the piece
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(offset + const Offset(2, 2), radius, shadowPaint);

    // Base color gradient for 3D effect
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
        Rect.fromCircle(center: offset, radius: radius),
      );
    canvas.drawCircle(offset, radius, basePaint);

    // Highlight on top-left for shine
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
      stops: const [0.0, 1.0],
    );

    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(
        Rect.fromCircle(center: offset, radius: radius * 0.7),
      );
    canvas.drawCircle(
      offset + Offset(-radius * 0.2, -radius * 0.2),
      radius * 0.5,
      highlightPaint,
    );

    // Subtle rim/edge highlight
    final rimPaint = Paint()
      ..color = isWhite
          ? Colors.black.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(offset, radius - 0.5, rimPaint);
  }

  Map<Position, Offset> _getPositionOffsets(Size size) {
    final Map<Position, Offset> positions = {};
    final center = Offset(size.width / 2, size.height / 2);
    final boardSize = size.width * 0.9;

    // Calculate ring sizes (half-width of each square) - must match paint method
    final outerRingSize = boardSize * 0.45;
    final middleRingSize = boardSize * 0.30;
    final innerRingSize = boardSize * 0.15;

    final ringSizes = [outerRingSize, middleRingSize, innerRingSize];

    // All 3 rings have all 8 points (4 corners + 4 midpoints)
    for (int ring = 0; ring < 3; ring++) {
      final ringSize = ringSizes[ring];

      for (int point = 0; point < 8; point++) {
        Offset positionOffset = _calculatePositionOffsetPainter(
          center,
          ringSize,
          point,
        );
        positions[Position(ring: ring, point: point)] = positionOffset;
      }
    }

    return positions;
  }

  /// Calculate position offset for a point on a square
  /// Points are arranged around a square:
  /// 7 --- 0 --- 1
  /// |           |
  /// 6           2
  /// |           |
  /// 5 --- 4 --- 3
  Offset _calculatePositionOffsetPainter(
    Offset center,
    double halfSize,
    int point,
  ) {
    switch (point) {
      case 0: // Top center (midpoint)
        return Offset(center.dx, center.dy - halfSize);
      case 1: // Top-right corner
        return Offset(center.dx + halfSize, center.dy - halfSize);
      case 2: // Right center (midpoint)
        return Offset(center.dx + halfSize, center.dy);
      case 3: // Bottom-right corner
        return Offset(center.dx + halfSize, center.dy + halfSize);
      case 4: // Bottom center (midpoint)
        return Offset(center.dx, center.dy + halfSize);
      case 5: // Bottom-left corner
        return Offset(center.dx - halfSize, center.dy + halfSize);
      case 6: // Left center (midpoint)
        return Offset(center.dx - halfSize, center.dy);
      case 7: // Top-left corner
        return Offset(center.dx - halfSize, center.dy - halfSize);
      default:
        return center;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
