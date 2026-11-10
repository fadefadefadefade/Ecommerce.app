// On a phone / emulator: the logistics actions not covered by logistics_flow_test, on the real web API
// (throwaway database seeded with SampleLogisticsSeeder; the company covers Quezon City and a second hub exists).
//
//   flutter test integration_test/logistics_actions_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8095
//
// Coverage → add rider → transfer a parcel → mark a parcel Damaged with a photo → Return-to-Sender rider →
// dispatch (auto) → chat → shipping rate. Only the camera is replaced (it returns a real image file).
library;

import 'dart:io';

import 'package:alvy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:printing/printing.dart';

const apiUrl = String.fromEnvironment('API_URL');

class _FakeCamera extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async {
    final doc = pw.Document()..addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('Damaged box'))));
    final page = await Printing.raster(await doc.save(), dpi: 30).first;
    final file = File('${(await getTemporaryDirectory()).path}/damage_test.png');
    await file.writeAsBytes(await page.toPng());
    return XFile(file.path, mimeType: 'image/png');
  }
}

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
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> typeInto(WidgetTester tester, Finder field, String text) async {
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> done(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> hideSnack(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).clearSnackBars();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pump(const Duration(seconds: 1));
}

/// Opens a dropdown and picks the item with [label] (or the first one).
Future<void> pick<T>(WidgetTester tester, Finder dropdown, {String? label}) async {
  await tapIt(tester, dropdown);
  await tester.pump(const Duration(seconds: 1));
  final items = find.byType(DropdownMenuItem<T>);
  final target = label == null ? items.last : find.descendant(of: items, matching: find.text(label)).last;
  await tester.tap(target);
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logistics actions', (tester) async {
    ImagePickerPlatform.instance = _FakeCamera();
    await tester.pumpWidget(const MyApp());
    await waitFor(tester, find.text('Log In'));
    await tester.pump(const Duration(seconds: 3));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'bilishatid.sample@example.com');
    await tester.enterText(fields.at(1), 'Hatid@2026');
    await done(tester);
    await tapIt(tester, find.text('Log In'));
    await waitFor(tester, find.textContaining('Pending pickup:'), seconds: 45);

    // ── Coverage: add a barangay of Quezon City ──
    await tester.tap(find.text('More').last);
    await waitFor(tester, find.text('Coverage'));
    await tapIt(tester, find.text('Coverage'));
    await waitFor(tester, find.text('Add a barangay of Quezon City'));
    await pick<String>(tester, find.byType(DropdownButtonFormField<String>), label: 'Alicia');
    await tapIt(tester, find.text('Add to coverage'));
    await waitFor(tester, find.text('Alicia added to your coverage.'));
    await hideSnack(tester);
    debugPrint('STEP_COVERAGE');
    await back(tester);

    // ── Shipping rate ──
    await tapIt(tester, find.text('Shipping Rates'));
    await waitFor(tester, find.text('NCR → NCR'));
    await tapIt(tester, find.text('NCR → NCR'));
    await waitFor(tester, find.text('First kg (₱)'));
    await typeInto(tester, find.byType(TextField).at(0), '0');
    await tapIt(tester, find.text('Save'));
    await waitFor(tester, find.text('The first-kg rate must be an amount of at least ₱0.01.'));
    await hideSnack(tester);
    await tapIt(tester, find.text('NCR → NCR'));
    await waitFor(tester, find.text('First kg (₱)'));
    await typeInto(tester, find.byType(TextField).at(0), '55');
    await tapIt(tester, find.text('Save'));
    await waitFor(tester, find.text('Rate for NCR → NCR saved. It applies to checkouts started from now on.'));
    await hideSnack(tester);
    debugPrint('STEP_RATE');
    await back(tester);

    // ── Chat with a rider ──
    await tapIt(tester, find.text('Messages'));
    await waitFor(tester, find.text('Pedro Jose Garcia'));
    await tapIt(tester, find.text('Pedro Jose Garcia'));
    await waitFor(tester, find.text('Message'));
    await typeInto(tester, find.byType(TextField).last, 'Pakidala sa hub bago mag-5.');
    await tapIt(tester, find.byIcon(Icons.send));
    await waitFor(tester, find.text('Pakidala sa hub bago mag-5.'));
    debugPrint('STEP_CHAT');
    await back(tester);
    await back(tester);

    // ── Riders → Add rider for Alicia ──
    await tester.tap(find.text('Riders').last);
    await waitFor(tester, find.text('Dispatch'));
    await tapIt(tester, find.text('Riders').first);
    await waitFor(tester, find.text('Add rider'));
    await tester.pump(const Duration(seconds: 2));
    await tapIt(tester, find.text('Add rider'));
    await waitFor(tester, find.text('Add a rider'));
    await typeInto(tester, find.byType(TextField).at(0), 'Rosa Dela Pena');
    await typeInto(tester, find.byType(TextField).at(1), '09171230000');
    await done(tester);
    await pick<String>(tester, find.byType(DropdownButtonFormField<String>).at(0), label: 'Motorcycle');
    await pick<String>(tester, find.byType(DropdownButtonFormField<String>).at(1), label: 'Alicia');
    await tapIt(tester, find.descendant(of: find.byType(BottomSheet), matching: find.text('Add rider')));
    await waitFor(tester, find.text('Rosa Dela Pena added as a rider for Alicia.'));
    await hideSnack(tester);
    await waitFor(tester, find.text('Rosa Dela Pena'));
    debugPrint('STEP_ADD_RIDER');
    await back(tester);

    // ── Dispatch: auto-assign the first waiting job ──
    await tapIt(tester, find.text('Dispatch'));
    await waitFor(tester, find.textContaining('Waiting for a rider'));
    await tester.pump(const Duration(seconds: 2));
    final auto = find.text('Auto assign');
    if (auto.evaluate().isNotEmpty) {
      await tapIt(tester, auto);
      await waitFor(tester, find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains('offered to') || (w is Text && (w.data ?? '').contains('No rider can take'))));
      await hideSnack(tester);
      debugPrint('STEP_DISPATCH');
    }
    await back(tester);

    // ── Hub → Transfers: send a parcel to the other hub ──
    await tester.tap(find.text('Hub').last);
    await waitFor(tester, find.text('Transfers'));
    await tapIt(tester, find.text('Transfers'));
    await waitFor(tester, find.text('Parcels you can transfer'));
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.widgetWithText(OutlinedButton, 'Transfer'));
    await waitFor(tester, find.text('To sorting center'));
    await pick<int>(tester, find.byType(DropdownButtonFormField<int>), label: 'Agila Hub Caloocan · Caloocan');
    await typeInto(tester, find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Closer to the buyer');
    await done(tester);
    await tapIt(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('Transfer')));
    await waitFor(tester, find.textContaining('Awaiting their acceptance.'));
    await hideSnack(tester);
    debugPrint('STEP_TRANSFER');
    await back(tester);

    // ── Return to Sender: give the return trip to a rider ──
    await tapIt(tester, find.text('Return to Sender'));
    await waitFor(tester, find.text('Going back to the seller'));
    await tester.pump(const Duration(seconds: 1));
    final rts = find.byWidgetPredicate((w) => w is Text && (w.data == 'Assign rider' || w.data == 'Change rider'));
    if (rts.evaluate().isNotEmpty) {
      await tapIt(tester, rts);
      await waitFor(tester, find.text('Choose a rider'));
      await tester.pump(const Duration(seconds: 1));
      final riders = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile));
      if (riders.evaluate().isNotEmpty) {
        await tester.tap(riders.first);
        await waitFor(tester, find.byWidgetPredicate((w) => w is Text && ((w.data ?? '').contains('will be returned to the seller by') || (w.data ?? '').contains('already has this return') || (w.data ?? '').contains('is offline') || (w.data ?? '').contains('active jobs'))));
        await hideSnack(tester);
        debugPrint('STEP_RTS');
      } else {
        debugPrint('STEP_RTS_NO_ELIGIBLE_RIDER');
        await tester.tapAt(const Offset(20, 100));
        await tester.pump(const Duration(seconds: 1));
      }
    }
    await back(tester);

    // ── Shipments → a parcel → Mark Damaged with a photo ──
    await tapIt(tester, find.text('Shipments'));
    await waitFor(tester, find.text('In transit (0)').evaluate().isEmpty ? find.textContaining('In transit (') : find.textContaining('In transit ('));
    await tapIt(tester, find.textContaining('In transit ('));
    await waitFor(tester, find.textContaining('ALVY-'));
    await tester.pump(const Duration(seconds: 1));
    final tracking = (tester.widget<Text>(find.textContaining('ALVY-').first).data ?? '');
    await tapIt(tester, find.textContaining('ALVY-'));
    await waitFor(tester, find.text('Mark Lost or Damaged'));
    await tapIt(tester, find.text('Mark Lost or Damaged'));
    await waitFor(tester, find.text('Lost or damaged parcel'));
    await tapIt(tester, find.text('Damaged'));
    await typeInto(tester, find.byType(TextField).last, 'Box crushed in the truck');
    await done(tester);
    await tapIt(tester, find.text('Mark Damaged'));
    await waitFor(tester, find.text('Add a photo of the damage.'));
    await hideSnack(tester);
    await tapIt(tester, find.text('Mark Lost or Damaged'));
    await waitFor(tester, find.text('Lost or damaged parcel'));
    await tapIt(tester, find.text('Damaged'));
    await typeInto(tester, find.byType(TextField).last, 'Box crushed in the truck');
    await done(tester);
    await tapIt(tester, find.text('Photo of the damage (required)'));
    await waitFor(tester, find.text('Retake photo'));
    await tapIt(tester, find.text('Mark Damaged'));
    await waitFor(tester, find.text('$tracking marked Damaged. The buyer and seller were notified.'));
    await waitFor(tester, find.text('Photo'));
    debugPrint('STEP_DAMAGED $tracking');
    await tester.pump(const Duration(seconds: 2));
  }, timeout: const Timeout(Duration(minutes: 8)), skip: apiUrl.isEmpty);
}
