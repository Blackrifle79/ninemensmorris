import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/ai_service.dart';
import '../utils/app_styles.dart';

class OptionsDialog extends StatefulWidget {
  const OptionsDialog({super.key});

  @override
  State<OptionsDialog> createState() => _OptionsDialogState();
}

class _OptionsDialogState extends State<OptionsDialog> {
  final AudioService _audioService = AudioService();
  final AIService _aiService = AIService();
  late bool _musicEnabled;
  late double _volume;
  late AIDifficulty _selectedDifficulty;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _musicEnabled = _audioService.isMusicEnabled;
    _volume = _audioService.volume;
    _selectedDifficulty = AIDifficulty.medium;
    _loadDifficulty();
  }

  Future<void> _loadDifficulty() async {
    await _aiService.loadDifficulty();
    if (mounted) {
      setState(() {
        _selectedDifficulty = _aiService.difficulty;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppStyles.sharpBorder),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxWidth: 350,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: AppStyles.dialogDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Options', style: AppStyles.headingMedium),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI Difficulty section
                    const Text('AI Difficulty', style: AppStyles.bodyTextBold),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      ...AIDifficulty.values.map(
                        (difficulty) => _buildDifficultyOption(difficulty),
                      ),

                    const SizedBox(height: 16),
                    const Divider(color: AppStyles.mediumBrown),
                    const SizedBox(height: 12),

                    // Music toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Music', style: AppStyles.bodyTextBold),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _musicEnabled = !_musicEnabled;
                            });
                            _audioService.setMusicEnabled(_musicEnabled);
                          },
                          child: Container(
                            width: 48,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _musicEnabled
                                  ? AppStyles.green
                                  : AppStyles.cream,
                              border: Border.all(
                                color: AppStyles.darkBrown,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _musicEnabled ? 'ON' : 'OFF',
                                style: TextStyle(
                                  fontFamily: AppStyles.fontBody,
                                  color: _musicEnabled
                                      ? AppStyles.cream
                                      : AppStyles.darkBrown,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Volume slider
                    const Text('Volume', style: AppStyles.bodyTextBold),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        thumbShape: const CircleSliderThumbShape(),
                        overlayShape: const CircleSliderOverlayShape(),
                        activeTrackColor: AppStyles.green,
                        inactiveTrackColor: AppStyles.mediumBrown,
                        thumbColor: AppStyles.cream,
                        overlayColor: AppStyles.green.withValues(alpha: 0.2),
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: Slider(
                        value: _volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: _musicEnabled
                            ? (value) {
                                setState(() {
                                  _volume = value;
                                });
                                _audioService.setVolume(value);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: AppStyles.primaryButtonStyle,
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyOption(AIDifficulty difficulty) {
    final isSelected = _selectedDifficulty == difficulty;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedDifficulty = difficulty;
        });
        await _aiService.setDifficulty(difficulty);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppStyles.burgundy.withValues(alpha: 0.8)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppStyles.cream : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppStyles.cream : AppStyles.mediumBrown,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 10,
                        color: AppStyles.burgundy,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficulty.displayName,
                    style: TextStyle(
                      fontFamily: AppStyles.fontBody,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppStyles.cream : AppStyles.darkBrown,
                    ),
                  ),
                  Text(
                    difficulty.description,
                    style: TextStyle(
                      fontFamily: AppStyles.fontBody,
                      fontSize: 14,
                      color: isSelected
                          ? AppStyles.cream.withValues(alpha: 0.8)
                          : AppStyles.mediumBrown,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom 3D circle slider thumb with depth effect
class CircleSliderThumbShape extends SliderComponentShape {
  const CircleSliderThumbShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(24, 24);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final double radius = 12.0;

    // Shadow underneath
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center + const Offset(1, 2), radius, shadowPaint);

    // Base gradient for 3D effect
    final baseGradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 1.0,
      colors: [AppStyles.cream, AppStyles.lightCream, const Color(0xFFD4C4A8)],
      stops: const [0.0, 0.5, 1.0],
    );

    final basePaint = Paint()
      ..shader = baseGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, basePaint);

    // Inner highlight
    final highlightGradient = RadialGradient(
      center: const Alignment(-0.5, -0.5),
      radius: 0.6,
      colors: [
        Colors.white.withValues(alpha: 0.7),
        Colors.white.withValues(alpha: 0.0),
      ],
    );

    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(
        Rect.fromCircle(
          center: center + const Offset(-3, -3),
          radius: radius * 0.6,
        ),
      );
    canvas.drawCircle(
      center + const Offset(-3, -3),
      radius * 0.5,
      highlightPaint,
    );

    // Outer ring
    final ringPaint = Paint()
      ..color = AppStyles.darkBrown.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 0.5, ringPaint);

    // Inner decorative circle
    final innerRingPaint = Paint()
      ..color = AppStyles.burgundy.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.5, innerRingPaint);
  }
}

/// Custom overlay shape for the circle thumb
class CircleSliderOverlayShape extends SliderComponentShape {
  const CircleSliderOverlayShape();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(32, 32);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final double radius = 16.0 * activationAnimation.value;

    if (radius > 0) {
      final paint = Paint()
        ..color =
            (sliderTheme.overlayColor ?? AppStyles.green.withValues(alpha: 0.2))
                .withValues(alpha: 0.2 * activationAnimation.value);
      canvas.drawCircle(center, radius, paint);
    }
  }
}

/// Rounded track shape for the slider
class RoundedRectSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const RoundedRectSliderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final Canvas canvas = context.canvas;
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final double trackHeight = sliderTheme.trackHeight ?? 6;
    final double radius = trackHeight / 2;

    // Inactive track (full background)
    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? AppStyles.mediumBrown;
    final inactiveRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        trackRect.left,
        trackRect.top,
        trackRect.width,
        trackHeight,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(inactiveRRect, inactivePaint);

    // Active track (up to thumb)
    final activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? AppStyles.green;
    final activeRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        trackRect.left,
        trackRect.top,
        thumbCenter.dx - trackRect.left,
        trackHeight,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(activeRRect, activePaint);
  }
}
