// On a phone / emulator, against a throwaway database where one of the seller's products has 10 or fewer
// left: the dashboard warning, the bell's unread count with the alert, and the Low stock tab.
//
//   flutter test integration_test/seller_low_stock_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8095
//     --dart-define=SELLER=<email> --dart-define=PASSWORD=<password>
library;

import 'package:alvy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const seller = String.fromEnvironment('SELLER');
const password = String.fromEnvironment('PASSWORD');

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder. On screen: ${onScreen()}');
}

String onScreen() => find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).toSet().join(' | ');

Future<void> settle(WidgetTester tester, [int seconds = 2]) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seller: low-stock warning, bell and Low stock tab', (tester) async {
    await tester.pumpWidget(const MyApp());
    await waitFor(tester, find.text('Log In'));
    await settle(tester);
    final fields = find.byType(TextFormField);
    await tester.tap(fields.at(0));
    await tester.enterText(fields.at(0), seller);
    await tester.tap(fields.at(1));
    await tester.enterText(fields.at(1), password);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, 1);
    await tester.tap(find.text('Log In'));
    await waitFor(tester, find.text('Low stock warning'));
    debugPrint('DASHBOARD ${onScreen()}');
    expect(find.textContaining('or fewer left'), findsOneWidget);
    await settle(tester, 2);

    // The bell shows the unread count; the alert is in Notifications.
    expect(find.byType(Badge), findsWidgets);
    await tester.tap(find.byTooltip('Notifications'));
    await waitFor(tester, find.textContaining('alert at 10 or fewer'));
    debugPrint('NOTIFICATIONS ${onScreen()}');
    await tester.pageBack();
    await settle(tester, 3);

    // The warning opens the Low stock tab.
    await tester.tap(find.text('Low stock warning'));
    await waitFor(tester, find.text('Low stock').last);
    await settle(tester, 4);
    debugPrint('LOW_STOCK_TAB ${onScreen()}');
    expect(find.widgetWithText(Container, 'Low stock'), findsWidgets);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
