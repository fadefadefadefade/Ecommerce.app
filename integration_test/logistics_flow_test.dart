// On a phone / emulator: the sample logistics company's day on the real web API (throwaway database seeded with
// SampleLogisticsSeeder).
//
//   flutter test integration_test/logistics_flow_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8095
//
// Confirm a pickup → receive a parcel by scanning its tracking number → sort it → assign a rider →
// confirm a rider's COD remittance → export the daily report.
library;

import 'dart:convert';

import 'package:alvy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

Future<void> tapIt(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> hideSnack(WidgetTester tester) async {
  ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).clearSnackBars();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pump(const Duration(seconds: 1));
}

/// The tracking number of a parcel on its way to the hub (what the staff would scan from the waybill).
Future<String> parcelOnTheWay() async {
  final h = {'Accept': 'application/json', 'Content-Type': 'application/json'};
  final login = jsonDecode((await http.post(Uri.parse('$apiUrl/api/v1/auth/login'), headers: h,
          body: jsonEncode({'email': 'bilishatid.sample@example.com', 'password': 'Hatid@2026'})))
      .body);
  final list = jsonDecode((await http.get(Uri.parse('$apiUrl/api/v1/logistics/incoming?tab=in_transit_to_hub'),
          headers: {...h, 'Authorization': 'Bearer ${login['token']}'}))
      .body);
  return '${list['data'][0]['tracking']}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logistics: pickup, receive, sort, assign, COD, report', (tester) async {
    await tester.pumpWidget(const MyApp());
    await waitFor(tester, find.text('Log In'));
    await tester.pump(const Duration(seconds: 3));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'bilishatid.sample@example.com');
    await tester.enterText(fields.at(1), 'Hatid@2026');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.text('Log In'));

    // ── Dashboard ──
    await waitFor(tester, find.text('Shipments'));
    await waitFor(tester, find.textContaining('Pending pickup:'));
    debugPrint('STEP_DASHBOARD');

    // ── Hub → Pickup Requests: confirm one ──
    await tester.tap(find.text('Hub').last);
    await waitFor(tester, find.text('Pickup Requests'));
    await tapIt(tester, find.text('Pickup Requests'));
    await waitFor(tester, find.text('Confirm pickup'));
    await tapIt(tester, find.text('Confirm pickup'));
    await waitFor(tester, find.textContaining('confirmed.'));
    await hideSnack(tester);
    debugPrint('STEP_PICKUP_CONFIRMED');
    await back(tester);

    // ── Incoming: scan the waybill ──
    final tracking = await tester.runAsync(parcelOnTheWay) ?? '';
    await tapIt(tester, find.text('Incoming Parcels'));
    await waitFor(tester, find.text('Receive a parcel'));
    await tester.tap(find.byType(TextField).first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).first, 'ALVY-NOPE');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.widgetWithText(FilledButton, 'Receive'));
    await waitFor(tester, find.text('Parcel ALVY-NOPE not found at your sorting center.'));
    await hideSnack(tester);
    await tester.tap(find.byType(TextField).first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).first, tracking);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.widgetWithText(FilledButton, 'Receive'));
    await waitFor(tester, find.text('$tracking received at the sorting center. Ready for sorting.'));
    await hideSnack(tester);
    debugPrint('STEP_RECEIVED $tracking');
    await back(tester);

    // ── Sorting: sort the parcel just received ──
    await tapIt(tester, find.text('Parcel Sorting'));
    await waitFor(tester, find.text(tracking));
    final card = find.ancestor(of: find.text(tracking), matching: find.byType(Card));
    await tapIt(tester, find.descendant(of: card, matching: find.byType(DropdownButtonFormField<int>)));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(DropdownMenuItem<int>).last);
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.descendant(of: card, matching: find.text('Sort')));
    await waitFor(tester, find.textContaining('$tracking sorted to'));
    await hideSnack(tester);
    debugPrint('STEP_SORTED');
    await back(tester);

    // ── Delivery Assignment: give it to a rider of its barangay ──
    await tapIt(tester, find.text('Delivery Assignment'));
    await waitFor(tester, find.text(tracking));
    final row = find.ancestor(of: find.text(tracking), matching: find.byType(Card));
    await tapIt(tester, find.descendant(of: row, matching: find.text('Assign rider')));
    await waitFor(tester, find.textContaining('Riders of'));
    await tester.pump(const Duration(seconds: 1));
    final riders = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile));
    if (riders.evaluate().isEmpty) {
      debugPrint('STEP_NO_RIDER_FOR_AREA');
      await tester.tapAt(const Offset(20, 100));
      await tester.pump(const Duration(seconds: 1));
    } else {
      await tester.tap(riders.first);
      await waitFor(tester, find.textContaining('$tracking assigned to'));
      await hideSnack(tester);
      debugPrint('STEP_ASSIGNED');
    }
    await back(tester);

    // ── Riders → COD Remittances: confirm one ──
    await tester.tap(find.text('Riders').last);
    await waitFor(tester, find.text('COD Remittances'));
    await tapIt(tester, find.text('COD Remittances'));
    await waitFor(tester, find.text('Remittances'));
    final confirm = find.widgetWithText(FilledButton, 'Confirm');
    if (confirm.evaluate().isNotEmpty) {
      await tapIt(tester, confirm);
      await waitFor(tester, find.textContaining('Remittance confirmed.'));
      await hideSnack(tester);
      debugPrint('STEP_REMITTANCE_CONFIRMED');
    }
    await back(tester);

    // ── More → Reports → Export CSV (saved on the phone, then the share sheet opens) ──
    await tester.tap(find.text('More').last);
    await waitFor(tester, find.text('Reports'));
    await tapIt(tester, find.text('Reports'));
    await waitFor(tester, find.text('Export CSV'));
    await tapIt(tester, find.text('Export CSV'));
    await waitFor(tester, find.textContaining('Saved sc-daily-report_'));
    debugPrint('STEP_EXPORTED');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }, timeout: const Timeout(Duration(minutes: 6)), skip: apiUrl.isEmpty);
}
