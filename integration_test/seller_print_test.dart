// On a phone / emulator: the seller prints a waybill with the phone's print service.
//
//   1. Start the web on a throwaway database (SampleLogisticsSeeder) and place one order as the sample buyer.
//   2. flutter test integration_test/seller_print_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8095
//
// It accepts and packs the order, opens "Print waybill" (the PDF preview) and taps Print, which opens
// Android's print screen. It stays there for a while so a screenshot can be taken.
library;

import 'package:alvy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:printing/printing.dart';

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final onScreen = find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).toSet().join(' | ');
  fail('Timed out waiting for $finder. On screen: $onScreen');
}

Future<void> tapIt(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seller: print the waybill on the phone', (tester) async {
    await tester.pumpWidget(const MyApp());
    await waitFor(tester, find.text('Log In'));

    final info = await Printing.info();
    debugPrint('PRINTING canPrint=${info.canPrint} canShare=${info.canShare} canRaster=${info.canRaster}');
    expect(info.canPrint, isTrue);

    // The login screen can rebuild once the saved-session check finishes; type after it settles.
    await tester.pump(const Duration(seconds: 3));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'mariaclara.santos@example.com');
    await tester.enterText(fields.at(1), 'Tindahan@2026');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('mariaclara.santos@example.com'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.text('Log In'));
    await waitFor(tester, find.textContaining('Welcome back'));

    await tester.tap(find.text('Orders').last);
    await waitFor(tester, find.textContaining('Juan Miguel Dela Cruz'));
    await tapIt(tester, find.textContaining('Juan Miguel Dela Cruz'));

    await waitFor(tester, find.text('Accept order'));
    await tapIt(tester, find.text('Accept order'));
    await waitFor(tester, find.text('Mark as packed'));
    await tapIt(tester, find.text('Mark as packed'));
    await waitFor(tester, find.text('Print waybill'));
    await tester.pump(const Duration(seconds: 4));   // let the snackbar go
    await tapIt(tester, find.text('Print waybill'));

    // The PDF preview (rendered by the phone).
    await waitFor(tester, find.textContaining('Waybill ALVY'));
    await waitFor(tester, find.text('Share / Save PDF'));
    await tester.pump(const Duration(seconds: 3));
    debugPrint('PREVIEW_READY');
    await tester.pump(const Duration(seconds: 4));

    // Print: Android's print screen opens over the app.
    await tester.tap(find.text('Print'));
    debugPrint('PRINT_TAPPED');
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    debugPrint('PRINT_DIALOG_WINDOW_DONE');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
