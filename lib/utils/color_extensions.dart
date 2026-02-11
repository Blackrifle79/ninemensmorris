import 'package:flutter/material.dart';

/// Small compatibility extension: many older files used `.withValues(alpha: x)`
/// - Provide `.withValues({required double alpha})` that creates a proper color with alpha.
/// This is temporary and makes it safe to change files incrementally.
extension ColorExtensions on Color {
  Color withValues({required double alpha}) => Color.fromARGB(
    (alpha * 255).round(),
    (r * 255).round(),
    (g * 255).round(),
    (b * 255).round(),
  );
}
