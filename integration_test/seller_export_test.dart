// On a phone / emulator: the seller exports the sales report (the website's CSV), which is saved on the
// phone and opened in Android's share sheet.
//
//   flutter test integration_test/seller_export_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8095
library;

import 'dart:io';

import 'package:alvy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final onScreen = find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).toSet().join(' | ');
  fail('Timed out waiting for $finder. On screen: $onScreen');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seller: export the sales report as CSV', (tester) async {
    await tester.pumpWidget(const MyApp());
    await waitFor(tester, find.text('Log In'));
    await tester.pump(const Duration(seconds: 3));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'mariaclara.santos@example.com');
    await tester.enterText(fields.at(1), 'Tindahan@2026');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Log In'));
    await waitFor(tester, find.textContaining('Welcome back'));

    await tester.tap(find.text('Reports').last);
    await waitFor(tester, find.text('Sales by product'));
    await tester.scrollUntilVisible(find.text('Export CSV'), 300,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    await tester.tap(find.text('Export CSV'));
    await waitFor(tester, find.textContaining('Saved sales-report_'));

    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().whereType<File>().where((f) => f.path.contains('sales-report_') && f.path.endsWith('.csv')).toList();
    expect(files, isNotEmpty);
    final csv = await files.first.readAsString();
    debugPrint('CSV_SAVED ${files.first.path}');
    expect(csv, contains('Product,"Units sold","Gross sales","Net earnings"'));
    expect(csv, contains('Total,'));
    debugPrint('SHARE_OPENING');
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    debugPrint('SHARE_DONE');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
