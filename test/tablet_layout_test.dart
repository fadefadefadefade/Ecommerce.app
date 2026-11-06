import 'package:alvy_app/widgets/buyer_web_header.dart';
import 'package:alvy_app/widgets/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tablets get the website's layout: the header (no page links: those are the bottom tabs) fits every tablet width, and product grids
/// stay 2 per row on phones but widen on tablets.
void main() {
  Future<void> pumpAt(WidgetTester tester, double width, Widget child, {double height = 900}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
  }

  for (final width in [720.0, 800.0, 1024.0, 1280.0, 1600.0]) {
    testWidgets('web header fits at $width px', (tester) async {
      await pumpAt(
        tester,
        width,
        Scaffold(
          appBar: BuyerWebHeader(
            currentTab: 0,
            cartCount: 3,
            onTab: (_) {},
            onMessages: () {},
            onNotifications: () {},
            onSearch: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);   // no "RenderFlex overflowed"
      expect(find.text('Home'), findsNothing);   // the page links are the bottom tabs
      expect(find.byType(TextField), findsOneWidget);
    });
  }

  test('phones always keep the mobile design; tablets get the website layout', () {
    // Phones, held upright and sideways.
    for (final s in [const Size(360, 800), const Size(800, 360), const Size(412, 915), const Size(915, 412), const Size(430, 932), const Size(932, 430)]) {
      expect(Responsive.isWideSize(s), isFalse, reason: '$s is a phone');
    }
    // Tablets.
    expect(Responsive.isWideSize(const Size(800, 1280)), isTrue);    // 10" upright
    expect(Responsive.isWideSize(const Size(1280, 800)), isTrue);    // 10" sideways
    expect(Responsive.isWideSize(const Size(1024, 1366)), isTrue);   // 12" upright
    expect(Responsive.isWideSize(const Size(960, 600)), isTrue);     // 7" sideways
    expect(Responsive.isWideSize(const Size(600, 960)), isFalse);    // 7" upright: too narrow, phone layout
  });

  int columns(WidgetTester tester) {
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate = grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
    final box = tester.getSize(find.byType(GridView));
    return (box.width / (delegate.maxCrossAxisExtent + delegate.crossAxisSpacing)).ceil();
  }

  for (final (width, expected) in [(360.0, 2), (412.0, 2), (800.0, 4), (1280.0, 6)]) {
    testWidgets('product grid has $expected per row at $width px', (tester) async {
      await pumpAt(
        tester,
        width,
        Scaffold(
          body: GridView.extent(
            padding: const EdgeInsets.all(12),
            maxCrossAxisExtent: Responsive.productTileMax,
            childAspectRatio: 0.56,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: List.generate(8, (i) => Container(key: ValueKey(i))),
          ),
        ),
      );
      expect(columns(tester), expected);
    });
  }
}
