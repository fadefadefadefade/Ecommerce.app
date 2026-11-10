// On a phone / emulator: every logistics screen opens and draws without errors (layout overflows fail the test),
// on the sample logistics company's data.
//
//   flutter test integration_test/logistics_screens_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8095
library;

import 'package:alvy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const apiUrl = String.fromEnvironment('API_URL');

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final onScreen = find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).toSet().join(' | ');
  fail('Timed out waiting for $finder. On screen: $onScreen');
}

/// Waits until the screen stops loading (no spinner) for a moment.
Future<void> settled(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty && i > 4) return;
  }
}

Future<void> openAndBack(WidgetTester tester, String menu, Finder shows) async {
  await tester.ensureVisible(find.text(menu).first);
  await tester.tap(find.text(menu).first);
  await tester.pump(const Duration(milliseconds: 500));
  await waitFor(tester, shows);
  await settled(tester);
  debugPrint('SCREEN_OK $menu');
  await tester.pageBack();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every logistics screen opens', (tester) async {
    await tester.pumpWidget(const MyApp());
    await waitFor(tester, find.text('Log In'));
    await tester.pump(const Duration(seconds: 3));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'bilishatid.sample@example.com');
    await tester.enterText(fields.at(1), 'Hatid@2026');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Log In'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Log In'));
    await tester.pump(const Duration(milliseconds: 500));
    await waitFor(tester, find.textContaining('Pending pickup:'), seconds: 45);
    await settled(tester);

    // Hub
    await tester.tap(find.text('Hub').last);
    await waitFor(tester, find.text('Pickup Requests'));
    await openAndBack(tester, 'Pickup Requests', find.textContaining('Pending ('));
    await openAndBack(tester, 'Incoming Parcels', find.text('Receive a parcel'));
    await openAndBack(tester, 'Parcel Sorting', find.textContaining('Sorted today'));
    await openAndBack(tester, 'Delivery Assignment', find.text('All areas'));
    await openAndBack(tester, 'Delivery Monitoring', find.text('Dispatched'));
    await openAndBack(tester, 'Return to Sender', find.text('Going back to the seller'));
    await openAndBack(tester, 'Shipments', find.textContaining('Pending pickup ('));
    await openAndBack(tester, 'Transfers', find.text('Incoming (waiting for you)'));

    // A parcel's page (from Shipments).
    await tester.tap(find.text('Shipments').first);
    await waitFor(tester, find.textContaining('ALVY-'));
    await settled(tester);
    await tester.tap(find.textContaining('ALVY-').first);
    await waitFor(tester, find.textContaining('Order'));
    await settled(tester);
    debugPrint('SCREEN_OK Parcel detail');
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));

    // Riders
    await tester.tap(find.text('Riders').last);
    await waitFor(tester, find.text('Dispatch'));
    await openAndBack(tester, 'Dispatch', find.textContaining('Waiting for a rider'));
    await openAndBack(tester, 'COD Remittances', find.text('Riders\' COD'));
    await openAndBack(tester, 'Courier Applications', find.textContaining('Pending ('));
    await tester.tap(find.text('Riders').first);
    await waitFor(tester, find.text('Pedro Jose Garcia'));
    await settled(tester);
    await tester.tap(find.text('Pedro Jose Garcia').first);
    await waitFor(tester, find.text('COD balance'));
    await settled(tester);
    debugPrint('SCREEN_OK Rider detail');
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Add rider'));
    await tester.pump(const Duration(seconds: 2));
    debugPrint('SCREEN_OK Add rider');
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));

    // More
    await tester.tap(find.text('More').last);
    await waitFor(tester, find.text('Coverage'));
    await openAndBack(tester, 'Coverage', find.byType(ListView));
    await openAndBack(tester, 'Shipping Rates', find.text('Rates by route'));
    await openAndBack(tester, 'Reports', find.text('Export CSV'));
    await openAndBack(tester, 'Activity Log', find.byType(ListView));
    await openAndBack(tester, 'Messages', find.text('Search contacts'));
    await openAndBack(tester, 'Notifications', find.byType(Scaffold));
    await openAndBack(tester, 'Account', find.text('Change password (optional)'));
    debugPrint('ALL_SCREENS_OK');
  }, timeout: const Timeout(Duration(minutes: 8)), skip: apiUrl.isEmpty);
}
