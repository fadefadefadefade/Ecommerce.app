// Mobile number fields: 09XXXXXXXXX (11 digits) or +639XXXXXXXXX (13 characters); nothing else can be typed.
import 'package:alvy_app/widgets/buyer_kit.dart';
import 'package:flutter_test/flutter_test.dart';

String typed(String text) {
  var value = TextEditingValue.empty;
  for (final f in phoneFormatters) {
    value = f.formatEditUpdate(value, TextEditingValue(text: text));
  }
  return value.text;
}

void main() {
  test('09 numbers stop at 11 digits; letters and symbols are dropped', () {
    expect(typed('091712345678'), '09171234567');
    expect(typed('0917ABC4567'), '09174567');
    expect(typed('0917-123-4567'), '09171234567');
  });

  test('a +63 number can be typed (13 characters)', () {
    expect(typed('+639171234567'), '+639171234567');
    expect(typed('+6391712345678'), '+639171234567');
    expect(typed('09+17'), '0917');   // "+" only in front
  });
}
