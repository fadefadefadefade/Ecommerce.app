import 'package:alvy_app/providers/auth_provider.dart';
import 'package:alvy_app/screens/courier/courier_screens.dart';
import 'package:alvy_app/screens/courier/rider_screens.dart';
import 'package:alvy_app/screens/logistics/rider_admin_screens.dart';
import 'package:alvy_app/screens/seller/marketing/marketing_screens.dart';
import 'package:alvy_app/screens/seller/orders/seller_order_details_screen.dart';
import 'package:alvy_app/screens/seller/products/add_edit_product_screen.dart';
import 'package:alvy_app/widgets/web_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A notification's website link opens the matching app screen (seller and rider / courier pages too).
void main() {
  setUpAll(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> open(WidgetTester tester, String link) async {
    late BuildContext ctx;
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: Text('home'));
      })),
    ));
    final opened = openWebPath(ctx, link);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    opened.ignore();
  }

  final cases = <String, Type>{
    'https://alvy.trade/seller/orders/18': SellerOrderDetailsScreen,
    'https://alvy.trade/seller/books/7/edit': AddEditProductScreen,
    'https://alvy.trade/seller/vouchers': SellerVouchersScreen,
    'https://alvy.trade/courier/rider/cod': RiderCodScreen,
    'https://alvy.trade/courier/rider/deliveries/5': RiderDeliveryScreen,
    'https://alvy.trade/courier/deliveries/3': CourierDeliveryScreen,
    'https://alvy.trade/courier/profit': CourierProfitScreen,
    'https://alvy.trade/courier/status': CourierStatusScreen,
    'https://alvy.trade/sc/remittances': RemittancesScreen,
    'https://alvy.trade/sc/riders/4': RiderDetailScreen,
  };

  for (final c in cases.entries) {
    testWidgets('opens ${Uri.parse(c.key).path}', (tester) async {
      await open(tester, c.key);
      expect(find.byType(c.value), findsOneWidget);
    });
  }

  testWidgets('/courier opens the courier dashboard for a direct courier', (tester) async {
    await open(tester, 'https://alvy.trade/courier');
    expect(find.byType(CourierDashboardScreen), findsOneWidget);
  });
}
