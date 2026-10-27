import 'package:flutter/material.dart';

/// Light/dark colors for the buyer screens. Use `context.bc.surface` etc.
/// instead of hard-coded Colors.white / Color(0xFF222222) so dark mode works.
class BuyerPalette {
  final Color background; // scaffold
  final Color surface; // cards, app bars, sheets
  final Color subtle; // input fills, chips, image placeholders
  final Color text; // primary text
  final Color textSecondary; // secondary text
  final Color muted; // hints, captions
  final Color border;

  const BuyerPalette({
    required this.background,
    required this.surface,
    required this.subtle,
    required this.text,
    required this.textSecondary,
    required this.muted,
    required this.border,
  });

  static const primary = Color(0xFFfa4e1c);

  // The website's tokens (see theme/app_theme.dart): navy text scale, grey page, white cards, hairline borders.
  static const light = BuyerPalette(
    background: Color(0xFFF5F5F5),
    surface: Colors.white,
    subtle: Color(0xFFF4F7FA),
    text: Color(0xFF002B4D),
    textSecondary: Color(0xFF4A7A94),
    muted: Color(0xFF6B90AA),
    border: Color(0xFFE6EDF2),
  );

  static const dark = BuyerPalette(
    background: Color(0xFF0E1621),
    surface: Color(0xFF16212E),
    subtle: Color(0xFF1D2A3A),
    text: Color(0xFFE8EEF4),
    textSecondary: Color(0xFFB5C6D6),
    muted: Color(0xFF8AA3B8),
    border: Color(0xFF26354A),
  );
}

extension BuyerColorsX on BuildContext {
  BuyerPalette get bc =>
      Theme.of(this).brightness == Brightness.dark ? BuyerPalette.dark : BuyerPalette.light;
}
