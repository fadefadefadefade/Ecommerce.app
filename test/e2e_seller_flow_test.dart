// End-to-end check of the seller app against a running ALVY web server (no mocks for the API).
//
//   1. Start the web on a throwaway database seeded with SampleLogisticsSeeder, and place one order
//      for the Rattan Fruit Basket as the sample buyer.
//   2. flutter test test/e2e_seller_flow_test.dart --dart-define=API_URL=http://127.0.0.1:8095
//
// It signs in as the sample seller: dashboard → products (update stock) → orders (accept, pack, cancel)
// → Seller Center → new store voucher.
library;

import 'dart:io';

import 'package:alvy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle(WidgetTester tester, [int ms = 1500]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 2; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await settle(tester, 500);
  }
  final onScreen = find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).toSet().join(' | ');
  fail('Timed out waiting for $finder. On screen: $onScreen');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump();
}

/// Hides the snackbar so it doesn't cover buttons.
Future<void> dismissSnack(WidgetTester tester) async {
  final ctx = tester.element(find.byType(Scaffold).last);
  ScaffoldMessenger.of(ctx).clearSnackBars();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    FlutterSecureStorage.setMockInitialValues({});
  });

  const apiUrl = String.fromEnvironment('API_URL');

  testWidgets('seller: stock, accept and pack an order, cancel it, add a voucher', skip: apiUrl.isEmpty, (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());
    await waitFor(tester, find.text('Log In'));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'mariaclara.santos@example.com');
    await tester.enterText(fields.at(1), 'Tindahan@2026');
    await tapVisible(tester, find.text('Log In'));

    // ── Dashboard ──
    await waitFor(tester, find.text('Welcome back, Maria Clara Santos'));
    expect(find.textContaining('order(s) to ship'), findsOneWidget);

    // ── Products: update the stock ──
    await tester.tap(find.text('Products').last);
    await tester.pump();
    await waitFor(tester, find.text('Rattan Fruit Basket'));
    final row = find.ancestor(of: find.text('Rattan Fruit Basket'), matching: find.byType(Card));
    await tapVisible(tester, find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)));
    await settle(tester, 300);
    await tapVisible(tester, find.text('Update stock'));
    await settle(tester, 300);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), '30');
    await tapVisible(tester, find.text('Save'));
    await waitFor(tester, find.text('Stock updated to 30.'));
    await waitFor(tester, find.text('Stock 30'));
    await dismissSnack(tester);

    // ── Orders: the buyer's order is New ──
    await tester.tap(find.text('Orders').last);
    await tester.pump();
    await waitFor(tester, find.text('New (1)'));
    await waitFor(tester, find.textContaining('Juan Miguel Dela Cruz'));
    await tapVisible(tester, find.textContaining('Juan Miguel Dela Cruz'));

    await waitFor(tester, find.text('Accept order'));
    expect(find.text('You earn'), findsOneWidget);
    await tapVisible(tester, find.text('Accept order'));
    await waitFor(tester, find.text('Mark as packed'));
    await dismissSnack(tester);
    await tapVisible(tester, find.text('Mark as packed'));
    await waitFor(tester, find.text('Book pickup'));
    expect(find.text('Print waybill'), findsOneWidget);
    await dismissSnack(tester);

    // Cancel: a reason is required (the web's message), then the order is cancelled.
    await tapVisible(tester, find.text('Cancel order'));
    await settle(tester, 300);
    await tapVisible(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel order')));
    await waitFor(tester, find.text('Please choose a reason for cancelling.'));
    await dismissSnack(tester);
    await tapVisible(tester, find.text('Cancel order'));
    await settle(tester, 300);
    await tapVisible(tester, find.text('Out of stock'));
    await tapVisible(tester, find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel order')));
    await waitFor(tester, find.text('Cancelled'));
    await tester.scrollUntilVisible(find.text('Cancelled by the seller: Out of stock'), -300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Accept order'), findsNothing);
    await dismissSnack(tester);

    await tester.pageBack();
    await settle(tester);

    // ── Seller Center → Vouchers → new voucher ──
    await tester.tap(find.text('More').last);
    await tester.pump();
    await waitFor(tester, find.text('Vouchers'));
    await tapVisible(tester, find.text('Vouchers'));
    await waitFor(tester, find.text('New voucher'));
    await tapVisible(tester, find.text('New voucher'));
    await waitFor(tester, find.text('Voucher code *'));
    final inputs = find.byType(TextField);
    await tester.enterText(inputs.at(0), 'MCH75');
    await tester.enterText(inputs.at(1), 'Maria Clara ₱75 off');
    await tester.enterText(inputs.at(2), '75');
    await tester.enterText(inputs.at(3), '500');
    final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    await tester.scrollUntilVisible(find.text('Save voucher'), 300, scrollable: page.first);
    await tapVisible(tester, find.text('Save voucher'));
    await waitFor(tester, find.text('Store voucher MCH75 created.'));
    await waitFor(tester, find.textContaining('MCH75 ·'));
  });
}
