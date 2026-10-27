// On a phone / emulator, against a throwaway copy of the database: the buyer's vouchers (My Vouchers,
// claim, checkout dropdowns and a typed code) and the seller's store voucher form.
//
//   flutter test integration_test/voucher_flow_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8095
//     --dart-define=BUYER=<email> --dart-define=SELLER=<email> --dart-define=PASSWORD=<password>
library;

import 'package:alvy_app/main.dart';
import 'package:alvy_app/screens/buyer/account/collections_screens.dart';
import 'package:alvy_app/screens/buyer/buyer_main_screen.dart';
import 'package:alvy_app/screens/buyer/checkout_screen.dart';
import 'package:alvy_app/screens/seller/marketing/marketing_screens.dart';
import 'package:alvy_app/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const buyer = String.fromEnvironment('BUYER');
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

Future<void> settle(WidgetTester tester, [int seconds = 3]) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> login(WidgetTester tester, String email, Finder home) async {
  await tester.pumpWidget(const MyApp());
  await waitFor(tester, find.text('Log In'));
  await settle(tester, 2);
  final fields = find.byType(TextFormField);
  await tester.tap(fields.at(0));
  await tester.enterText(fields.at(0), email);
  await tester.tap(fields.at(1));
  await tester.enterText(fields.at(1), password);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, 1);
  await tester.tap(find.text('Log In'));
  await waitFor(tester, home);
}

NavigatorState nav(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('buyer: my vouchers, claim, checkout vouchers', (tester) async {
    await login(tester, buyer, find.byType(BuyerMainScreen));

    nav(tester).push(MaterialPageRoute(builder: (_) => const VouchersScreen()));
    await waitFor(tester, find.text('Claimed'));
    debugPrint('MY_VOUCHERS ${onScreen()}');
    if (find.text('Claim').evaluate().isNotEmpty) {
      await tester.tap(find.text('Claim').first);
      await waitFor(tester, find.textContaining('was added to My Vouchers'));
    }
    await settle(tester, 2);
    nav(tester).pop();
    await settle(tester, 1);

    nav(tester).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
    await waitFor(tester, find.text('Place Order'), seconds: 40);
    debugPrint('CHECKOUT ${onScreen()}');

    // Pick every ALVY / shipping voucher option in turn.
    for (final label in ['ALVY voucher', 'Shipping voucher']) {
      final dropdown = find.widgetWithText(DropdownButtonFormField<String?>, label);
      await tester.scrollUntilVisible(dropdown, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(dropdown);
      await settle(tester, 1);
      final items = find.byType(DropdownMenuItem<String?>);
      debugPrint('DROPDOWN $label: ${items.evaluate().length ~/ 2} options');
      await tester.tap(find.text('No voucher').last);
      await settle(tester, 3);
      debugPrint('AFTER NONE $label ${onScreen()}');
    }

    // A typed code that exists and one that doesn't.
    for (final code in ['ALVY10', 'NOPE123']) {
      final field = find.widgetWithText(TextField, 'Enter a voucher code');
      await tester.scrollUntilVisible(field, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(field);
      await tester.enterText(field, code);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.tap(find.text('Apply'));
      await settle(tester, 4);
      debugPrint('TYPED $code ${onScreen()}');
    }

    // Place the order (throwaway database).
    await tester.scrollUntilVisible(find.text('Place Order'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Place Order'));
    await settle(tester, 8);
    debugPrint('PLACED ${onScreen()}');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('seller: store voucher list and form', (tester) async {
    await ApiClient.clearToken();
    await login(tester, seller, find.textContaining('Welcome back'));

    nav(tester).push(MaterialPageRoute(builder: (_) => const SellerVouchersScreen()));
    await settle(tester, 6);
    debugPrint('SELLER_VOUCHERS ${onScreen()}');

    nav(tester).push(MaterialPageRoute(builder: (_) => const VoucherFormScreen()));
    await waitFor(tester, find.text('New store voucher'));
    final inputs = find.byType(TextField);
    await tester.enterText(inputs.at(0), 'APPVCH1');
    await tester.enterText(inputs.at(1), 'App probe voucher');
    await tester.enterText(inputs.at(2), '20');
    await tester.enterText(inputs.at(3), '100');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.scrollUntilVisible(find.text('Save voucher'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save voucher'));
    await settle(tester, 5);
    debugPrint('SAVED_NEW ${onScreen()}');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
