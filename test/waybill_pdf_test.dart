import 'dart:async';

import 'package:alvy_app/screens/seller/orders/waybill_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// The waybill PDF builds with the bundled font (it has the ₱ sign) and a real barcode.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('waybill PDF builds for a COD order', () async {
    final warnings = <String>[];
    final pdf = await runZonedPrint(warnings, () => WaybillPdf.build({
          'order_number': '#000018',
          'tracking': 'ALVY-20261016-0018',
          'payment_method': 'COD',
          'buyer_note': 'Please call first',
          'weight_kg': 1.5,
          'seller': {'name': 'Maria Clara Handicrafts', 'phone': '09171234567', 'address': 'Bagumbayan, Quezon City'},
          'buyer': {'name': 'Juan Miguel Dela Cruz', 'phone': '09171234567', 'address': '45 Kalayaan Ave., Quezon City'},
          'cod': 500,
          'items': [
            {'title': 'Rattan Fruit Basket', 'variation': null, 'quantity': 1},
          ],
        }));
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(2000));
    // The pdf package prints a warning when the font can't draw a character (like ₱).
    expect(warnings.where((w) => w.contains('Unable to find a font') || w.contains('no Unicode support')), isEmpty);
  });
}

Future<T> runZonedPrint<T>(List<String> sink, Future<T> Function() body) =>
    Zone.current.fork(specification: ZoneSpecification(print: (self, parent, zone, line) => sink.add(line))).run(body);
