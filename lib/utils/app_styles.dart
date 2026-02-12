import 'package:flutter/material.dart';
export 'color_extensions.dart';

/// App-wide style constants
/// This file serves as the single source of truth for all styling in the app.
class AppStyles {
  // ============================================
  // FONTS
  // ============================================

  static const String fontHeadline = 'Hadriatic';
  static const String fontBody = 'AvenirNext';

  // ============================================
  // COLORS (from color_scheme)
  // ============================================

  /// Dark brown - for text on light backgrounds
  static const Color darkBrown = Color(0xFF3D2314);

  /// Medium brown
  static const Color mediumBrown = Color(0xFF6B4423);

  /// Green - for buttons and accents
  static const Color green = Color(0xFF4A5D23);

  /// Burgundy - for header bars
  static const Color burgundy = Color(0xFF722F37);

  /// Cream/tan - for button text and light accents
  static const Color cream = Color(0xFFF5E6C8);

  /// Light cream - lighter variant
  static const Color lightCream = Color(0xFFFAF3E3);

  /// Primary background color (fallback)
  static const Color background = Color(0xFF2A2A2A);

  /// Surface color for dialogs, cards
  static const Color surface = Color(0xFF4A3728);

  /// Primary text color - dark brown
  static const Color textPrimary = darkBrown;

  /// Secondary/muted text color
  static const Color textSecondary = mediumBrown;

  /// Light text for dark backgrounds
  static const Color textLight = cream;

  // ============================================
  // TYPOGRAPHY
  // ============================================

  static const TextStyle headingLarge = TextStyle(
    fontFamily: fontHeadline,
    color: textPrimary,
    fontSize: 36,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: fontHeadline,
    color: textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle bodyText = TextStyle(
    fontFamily: fontBody,
    color: textPrimary,
    fontSize: 16,
  );

  static const TextStyle bodyTextBold = TextStyle(
    fontFamily: fontBody,
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  /// Label/caption text - 14px minimum readable size
  static const TextStyle labelText = TextStyle(
    fontFamily: fontBody,
    color: textSecondary,
    fontSize: 14,
  );

  /// Secondary/caption text for metadata (same as labelText)
  static const TextStyle captionText = TextStyle(
    fontFamily: fontBody,
    color: textSecondary,
    fontSize: 14,
  );

  // ============================================
  // TYPOGRAPHY — LIGHT (for dark backgrounds)
  // ============================================

  static const TextStyle headingLargeLight = TextStyle(
    fontFamily: fontHeadline,
    color: cream,
    fontSize: 36,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingMediumLight = TextStyle(
    fontFamily: fontHeadline,
    color: cream,
    fontSize: 26,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle bodyTextLight = TextStyle(
    fontFamily: fontBody,
    color: cream,
    fontSize: 16,
  );

  static const TextStyle bodyTextBoldLight = TextStyle(
    fontFamily: fontBody,
    color: cream,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle labelTextLight = TextStyle(
    fontFamily: fontBody,
    color: lightCream,
    fontSize: 14,
  );

  /// Secondary/caption text for metadata on dark backgrounds
  static const TextStyle captionTextLight = TextStyle(
    fontFamily: fontBody,
    color: lightCream,
    fontSize: 14,
  );

  /// Button text style - cream on green
  static const TextStyle buttonText = TextStyle(
    fontFamily: fontBody,
    color: cream,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  // ============================================
  // BORDERS & SHAPES
  // ============================================

  /// No rounded corners
  static const double borderRadius = 0.0;

  static const BorderRadius sharpBorder = BorderRadius.zero;

  // ============================================
  // SPACING
  // ============================================

  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  // ============================================
  // COMPONENT STYLES
  // ============================================

  /// Container decoration (no rounded corners, subtle background)
  static BoxDecoration containerDecoration = BoxDecoration(
    color: surface.withValues(alpha: 0.8),
    borderRadius: sharpBorder,
  );

  /// Dialog decoration with subtle background and no borders
  static BoxDecoration dialogDecoration = const BoxDecoration(
    color: cream,
    borderRadius: sharpBorder,
  );

  /// Button style - green with cream text and cream border
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: green.withValues(alpha: 0.8),
    foregroundColor: cream,
    side: const BorderSide(color: cream, width: 2),
    shape: const RoundedRectangleBorder(borderRadius: sharpBorder),
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
    textStyle: const TextStyle(
      fontFamily: fontBody,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    ),
  );

  static ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: green,
    shape: const RoundedRectangleBorder(borderRadius: sharpBorder),
    textStyle: const TextStyle(fontFamily: fontBody, fontSize: 16),
  );

  /// Helper to ensure message ends with a period
  static String _ensurePeriod(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.endsWith('.') ||
        trimmed.endsWith('!') ||
        trimmed.endsWith('?')) {
      return trimmed;
    }
    return '$trimmed.';
  }

  /// Styled SnackBar - success (shows above footer)
  static SnackBar successSnackBar(String message) => SnackBar(
    content: Text(
      _ensurePeriod(message),
      style: const TextStyle(color: cream, fontFamily: fontBody),
      textAlign: TextAlign.center,
    ),
    backgroundColor: burgundy.withValues(alpha: 0.8),
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 60, left: 16, right: 16),
    shape: const RoundedRectangleBorder(borderRadius: sharpBorder),
  );

  /// Styled SnackBar - error (shows above footer)
  static SnackBar errorSnackBar(String message) => SnackBar(
    content: Text(
      _ensurePeriod(message),
      style: const TextStyle(color: cream, fontFamily: fontBody),
      textAlign: TextAlign.center,
    ),
    backgroundColor: burgundy.withValues(alpha: 0.8),
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 60, left: 16, right: 16),
    shape: const RoundedRectangleBorder(borderRadius: sharpBorder),
  );

  /// Styled SnackBar - info (shows above footer)
  static SnackBar infoSnackBar(String message) => SnackBar(
    content: Text(
      _ensurePeriod(message),
      style: const TextStyle(color: cream, fontFamily: fontBody),
      textAlign: TextAlign.center,
    ),
    backgroundColor: burgundy.withValues(alpha: 0.8),
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 60, left: 16, right: 16),
    shape: const RoundedRectangleBorder(borderRadius: sharpBorder),
  );

  /// Standard input decoration for text fields on cream/light backgrounds
  static InputDecoration inputDecoration({
    required String label,
    IconData? icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: mediumBrown) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: lightCream,
      border: const OutlineInputBorder(
        borderRadius: sharpBorder,
        borderSide: BorderSide(color: darkBrown, width: 2),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: sharpBorder,
        borderSide: BorderSide(color: darkBrown, width: 2),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: sharpBorder,
        borderSide: BorderSide(color: darkBrown, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: sharpBorder,
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: sharpBorder,
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      labelStyle: const TextStyle(
        color: mediumBrown,
        fontFamily: fontBody,
        fontSize: 16,
      ),
      errorStyle: const TextStyle(
        color: Colors.red,
        fontFamily: fontBody,
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  /// Themed alert dialog (replaces unstyled AlertDialogs)
  static Widget styledAlertDialog({
    required String title,
    required String content,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(borderRadius: sharpBorder),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: dialogDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: headingMedium),
            const SizedBox(height: 16),
            Text(content, style: bodyText, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}
