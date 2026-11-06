import 'package:flutter/widgets.dart';

/// Tablet layout: on a wide screen the buyer side looks like the website (top header, wider grids,
/// two-column product page); phones keep the phone layout.
class Responsive {
  /// A tablet: its shorter side is at least this wide. Phones (even held sideways) stay below it.
  static const double tabletMinShortestSide = 600;

  /// ...and the screen must be this wide right now for the website's layout to fit
  /// (a small tablet held upright keeps the phone layout).
  static const double wideMin = 720;

  /// The website's content width; wider screens centre it.
  static const double maxContent = 1280;

  /// A product card is at most this wide: 2 per row on phones, 4 to 6 on tablets.
  static const double productTileMax = 210;

  /// The website's layout: only on a tablet, never on a phone.
  static bool isWide(BuildContext context) => isWideSize(MediaQuery.sizeOf(context));

  static bool isWideSize(Size size) => size.shortestSide >= tabletMinShortestSide && size.width >= wideMin;

  /// Product grids: 2 per row on phones (upright or sideways, like before); 4 to 6 on tablets.
  static double productTileMaxFor(BuildContext context) =>
      isWide(context) ? productTileMax : MediaQuery.sizeOf(context).width / 2;
}

/// Keeps a page at the website's width in the middle of a wide screen (no change on phones).
class WebWidth extends StatelessWidget {
  final Widget child;
  const WebWidth({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: Responsive.maxContent), child: child),
      );
}
