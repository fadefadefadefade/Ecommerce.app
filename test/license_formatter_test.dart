// Driver's license numbers on Add Rider / Add Courier: the LTO form A00-00-000000, dashes added while typing.
import 'package:alvy_app/screens/logistics/staff_screens.dart';
import 'package:flutter_test/flutter_test.dart';

String typed(String text) => LicenseFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text)).text;

void main() {
  test('one capital letter, then 11 digits with the dashes put in', () {
    expect(typed('n0123456789'), 'N01-23-456789');
    expect(typed('N01-23-456789'), 'N01-23-456789');
    expect(typed('N01-23-4567890'), 'N01-23-456789'); // a 12th digit is dropped
  });

  test('a number with no letter or a letter at the end cannot be typed as such', () {
    expect(typed('101-23-456789'), '10-12-345678'); // no letter in front: the server refuses it
    expect(typed('N0123456789X'), 'N01-23-456789');
  });
}
