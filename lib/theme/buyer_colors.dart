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

  static const light = BuyerPalette(
    background: Color(0xFFF5F5F5),
    surface: Colors.white,
    subtle: Color(0xFFF5F5F5),
    text: Color(0xFF222222),
    textSecondary: Color(0xFF555555),
    muted: Color(0xFF8a7a70),
    border: Color(0xFFE6E6E6),
  );

  static const dark = BuyerPalette(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    subtle: Color(0xFF2A2A2A),
    text: Color(0xFFEDEDED),
    textSecondary: Color(0xFFC4C4C4),
    muted: Color(0xFF9E9E9E),
    border: Color(0xFF333333),
  );
}

extension BuyerColorsX on BuildContext {
  BuyerPalette get bc =>
      Theme.of(this).brightness == Brightness.dark ? BuyerPalette.dark : BuyerPalette.light;
}
