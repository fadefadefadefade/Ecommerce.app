// GCash paid by receipt sends the checkout as a form: nested maps and lists become the website's key[sub] names.
import 'package:alvy_app/services/buyer_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nested values become key[sub] form fields', () {
    final f = BuyerApi.formFields({
      'payment_method': 'gcash_receipt',
      'prices': {'12': 450, '13': {'7': 199.5}},
      'buyer_notes': {'5': 'Please wrap it'},
      'seller_vouchers': [3, 4],
      'gift': true,
      'skip': null,
    });
    expect(f['payment_method'], 'gcash_receipt');
    expect(f['prices[12]'], '450');
    expect(f['prices[13][7]'], '199.5');
    expect(f['buyer_notes[5]'], 'Please wrap it');
    expect(f['seller_vouchers[0]'], '3');
    expect(f['seller_vouchers[1]'], '4');
    expect(f['gift'], '1');
    expect(f.containsKey('skip'), isFalse);
  });
}
