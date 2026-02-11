import 'package:flutter/material.dart';

/// Small 3D-style piece used in UI labels.
class MiniPieceIcon extends StatelessWidget {
  final bool isWhite;
  final bool isCaptured;
  final double size;

  const MiniPieceIcon({
    super.key,
    required this.isWhite,
    this.isCaptured = false,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MiniPiecePainter(isWhite: isWhite, isCaptured: isCaptured),
    );
  }
}

/// Custom painter for mini 3D pieces
class _MiniPiecePainter extends CustomPainter {
  final bool isWhite;
  final bool isCaptured;

  _MiniPiecePainter({required this.isWhite, this.isCaptured = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Shadow (smaller for mini pieces)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isCaptured ? 0.15 : 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(center + const Offset(1, 1), radius, shadowPaint);

    // Base gradient
    final baseGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.0,
      colors: isWhite
          ? (isCaptured
                ? [
                    const Color(0xFFCCCCCC),
                    const Color(0xFFAAAAAA),
                    const Color(0xFF888888),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFE0E0E0),
                    const Color(0xFFB0B0B0),
                  ])
          : (isCaptured
                ? [
                    const Color(0xFF3A3A3A),
                    const Color(0xFF222222),
                    const Color(0xFF111111),
                  ]
                : [
                    const Color(0xFF4A4A4A),
                    const Color(0xFF2A2A2A),
                    Colors.black,
                  ]),
      stops: const [0.0, 0.6, 1.0],
    );

    final basePaint = Paint()
      ..shader = baseGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, basePaint);

    // Highlight (subtle for mini)
    if (!isCaptured) {
      final highlightGradient = RadialGradient(
        center: const Alignment(-0.5, -0.5),
        radius: 0.8,
        colors: isWhite
            ? [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0.0)]
            : [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.0)],
      );

      final highlightPaint = Paint()
        ..shader = highlightGradient.createShader(
          Rect.fromCircle(center: center, radius: radius * 0.6),
        );
      canvas.drawCircle(
        center + Offset(-radius * 0.15, -radius * 0.15),
        radius * 0.4,
        highlightPaint,
      );
    }

    // Rim
    final rimPaint = Paint()
      ..color = isWhite
          ? Colors.black.withValues(alpha: isCaptured ? 0.1 : 0.15)
          : Colors.white.withValues(alpha: isCaptured ? 0.05 : 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 0.5, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
