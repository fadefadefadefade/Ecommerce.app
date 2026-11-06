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

  static const primary = Color(0xFFFA4E1C);

  // The design's tokens (see theme/app_theme.dart): warm ink text, cream page, white cards, warm beige fills.
  static const light = BuyerPalette(
    background: Color(0xFFFFF8F2),
    surface: Colors.white,
    subtle: Color(0xFFF4EDE6),
    text: Color(0xFF1E1B17),
    textSecondary: Color(0xFF5C4039),
    muted: Color(0xFF8A716A),
    border: Color(0xFFEEE7E0),
  );

  static const dark = BuyerPalette(
    background: Color(0xFF15110E),
    surface: Color(0xFF211C18),
    subtle: Color(0xFF2B2520),
    text: Color(0xFFF2E6DE),
    textSecondary: Color(0xFFD6C2B8),
    muted: Color(0xFFA48F85),
    border: Color(0xFF3A322C),
  );
}

extension BuyerColorsX on BuildContext {
  BuyerPalette get bc =>
      Theme.of(this).brightness == Brightness.dark ? BuyerPalette.dark : BuyerPalette.light;
}
