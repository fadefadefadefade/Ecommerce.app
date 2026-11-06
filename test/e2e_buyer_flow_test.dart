// End-to-end check of the buyer app against a running ALVY web server (no mocks for the API).
//
//   1. Start the web on a throwaway database seeded with SampleLogisticsSeeder.
//   2. flutter test test/e2e_buyer_flow_test.dart --dart-define=API_URL=http://127.0.0.1:8095
//
// It signs in as the sample buyer and goes through the screens like a person would:
// home → product → add to cart → cart → checkout → place order → order page → cancel.
library;

import 'dart:io';

import 'package:alvy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets real network calls finish, then draws the frames that follow.
Future<void> settle(WidgetTester tester, [int ms = 1500]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Waits (up to [seconds]) until [finder] shows up.
Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 2; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await settle(tester, 500);
  }
  final onScreen = find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).toSet().join(' | ');
  final spinners = find.byType(CircularProgressIndicator).evaluate().length;
  fail('Timed out waiting for $finder. Spinners: $spinners. On screen: $onScreen');
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump();
}

void main() {
  setUpAll(() {
    // Real HTTP to the local web (the test binding blocks it by default).
    HttpOverrides.global = null;
    FlutterSecureStorage.setMockInitialValues({});
  });

  // Only when a web is given with --dart-define=API_URL=…; a plain `flutter test` skips it.
  const apiUrl = String.fromEnvironment('API_URL');

  testWidgets('buyer: sign in, buy the Rattan basket, then cancel the order', skip: apiUrl.isEmpty, (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());
    await waitFor(tester, find.text('Log In'));

    // ── Login (the web's rules: a wrong password is refused with its message) ──
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'juanmiguel.delacruz@example.com');
    await tester.enterText(fields.at(1), 'wrong-password');
    await tapVisible(tester, find.text('Log In'));
    await waitFor(tester, find.text('These credentials do not match our records.'));

    await tester.enterText(fields.at(1), 'Mamimili@2026');
    await tapVisible(tester, find.text('Log In'));

    // ── Home: products from the web ──
    await waitFor(tester, find.text('New Arrivals'));
    await waitFor(tester, find.text('Rattan Fruit Basket'));
    expect(find.text('Hi, Juan!'), findsOneWidget);

    // ── Product page ──
    await tapVisible(tester, find.text('Rattan Fruit Basket'));
    await waitFor(tester, find.text('Add to Cart'));
    expect(find.text('₱450.00'), findsWidgets);
    expect(find.text('Sold by'), findsOneWidget);
    expect(find.text('Maria Clara Handicrafts'), findsOneWidget);

    await tapVisible(tester, find.text('Add to Cart'));
    await waitFor(tester, find.text('"Rattan Fruit Basket" added to your cart.'));
    // Let the message go away (it covers the bottom bar for a few seconds, as on a phone).
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    // ── Cart ──
    await tester.pageBack();
    await settle(tester);
    await tapVisible(tester, find.text('Cart'));
    await waitFor(tester, find.text('Check Out (1)'));
    expect(find.text('Maria Clara Handicrafts'), findsOneWidget);

    // ── Checkout: address, shipping and total worked out by the web ──
    await tapVisible(tester, find.text('Check Out (1)'));
    await waitFor(tester, find.text('Place Order'));
    expect(find.text('Delivery Address'), findsOneWidget);
    expect(find.textContaining('Juan Miguel Dela Cruz'), findsWidgets);
    expect(find.text('₱500.00'), findsWidgets); // ₱450 + ₱50 shipping within NCR

    await tapVisible(tester, find.text('Place Order'));
    await waitFor(tester, find.text('Thank you! Your order was placed.'));

    // ── The order page ──
    await tapVisible(tester, find.text('View order'));
    await waitFor(tester, find.text('Order timeline'));
    expect(find.text('Order placed'), findsWidgets);

    // The buttons are at the bottom of the page.
    await tester.scrollUntilVisible(find.text('Cancel order'), 300, scrollable: find.byType(Scrollable).last);
    await tester.pump();
    await tapVisible(tester, find.text('Cancel order'));
    await settle(tester, 500);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await settle(tester, 500);
    await tester.tap(find.text('Changed my mind').last);
    await settle(tester, 500);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel order').last);
    await waitFor(tester, find.text('Your order has been cancelled.'));
    // The page now shows the order as the web has it: Cancelled, with the reason on the timeline.
    await tester.scrollUntilVisible(find.text('Cancelled'), -300, scrollable: find.byType(Scrollable).last);
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.text('Order cancelled'), findsWidgets);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
