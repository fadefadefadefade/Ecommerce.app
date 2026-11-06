// The product edit screen with the website's real answer for a product (test/fixtures/seller_product_form.json):
// the shipping weight and size are filled in, and saving sends them back unchanged.
import 'dart:convert';
import 'dart:io';

import 'package:alvy_app/providers/auth_provider.dart';
import 'package:alvy_app/screens/seller/products/add_edit_product_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('edit keeps the weight, length, width and height', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't'});
    final answer = File('test/fixtures/seller_product_form.json').readAsStringSync();
    final product = jsonDecode(answer)['product'] as Map<String, dynamic>;
    final sent = <String, String>{};

    final client = MockClient.streaming((request, body) async {
      if (request.method == 'POST') {
        // The multipart save: collect the fields.
        final raw = utf8.decode(await body.toBytes(), allowMalformed: true);
        for (final m in RegExp(r'name="([^"]+)"\r\n\r\n([^\r]*)\r\n').allMatches(raw)) {
          sent[m[1]!] = m[2]!;
        }
        return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode({'message': 'Saved.', 'product': product}))), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.StreamedResponse(Stream.value(utf8.encode(answer)), 200, headers: {'content-type': 'application/json'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => AuthProvider(), child: MaterialApp(home: AddEditProductScreen(productId: product['id'] as int))));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      String field(String label) => tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;
      await tester.scrollUntilVisible(find.text('Weight (kg) *'), 300, scrollable: find.byType(Scrollable).first);
      final shown = [field('Weight (kg) *'), field('L (cm)'), field('W (cm)'), field('H (cm)')];
      debugPrint('SHOWN $shown  API ${[product['weight_kg'], product['length_cm'], product['width_cm'], product['height_cm']]}');
      expect(shown, ['20', '15', '10', '11']);

      // Saving sends them back as they are.
      await tester.scrollUntilVisible(find.text('Save as draft'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Save as draft'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      debugPrint('SENT ${[sent['weight_kg'], sent['length_cm'], sent['width_cm'], sent['height_cm']]}');
      expect([sent['weight_kg'], sent['length_cm'], sent['width_cm'], sent['height_cm']], ['20', '15', '10', '11']);
    }, () => client);
  });

  testWidgets('Category lists the store\'s categories first, then the other ALVY categories', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't'});
    final body = jsonDecode(File('test/fixtures/seller_product_form.json').readAsStringSync()) as Map<String, dynamic>;
    final cats = (body['categories'] as List).cast<Map>();
    final mine = asIds(cats.where((c) => c['name'] == 'Health & Beauty' || c['name'] == 'Automotive & Motorcycle'));
    body['my_category_ids'] = mine;
    final client = MockClient((_) async => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'}));

    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => AuthProvider(), child: MaterialApp(home: AddEditProductScreen(productId: (body['product'] as Map)['id'] as int))));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // The menu's items, in order (the open menu only builds what is on screen).
      final button = tester.widget<DropdownButton<int>>(
          find.descendant(of: find.byWidgetPredicate((w) => w is DropdownButtonFormField<int> && w.key.toString().contains('category:')), matching: find.byType(DropdownButton<int>)));
      final texts = [for (final i in button.items!) (i.child as Text).data!];
      final yours = texts.indexOf('Your store categories');
      final other = texts.indexWhere((t) => t.startsWith('Other ALVY categories'));
      expect(yours, 0);
      expect(texts.sublist(yours + 1, other), ['Automotive & Motorcycle', 'Health & Beauty']);
      expect(texts.sublist(other + 1), isNot(contains('Health & Beauty')));
      // The headers can't be picked.
      expect(button.items!.where((i) => !i.enabled).length, 2);
    }, () => client);
  });

  testWidgets('the sale is one of: no sale, a sale price or a discount %; no limit or condition', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't'});
    final answer = File('test/fixtures/seller_product_form.json').readAsStringSync();
    final product = jsonDecode(answer)['product'] as Map<String, dynamic>;   // #85: sale price ₱120 and 25% saved
    final sent = <String, String>{};
    final client = MockClient.streaming((request, body) async {
      if (request.method == 'POST') {
        final raw = utf8.decode(await body.toBytes(), allowMalformed: true);
        for (final m in RegExp(r'name="([^"]+)"\r\n\r\n([^\r]*)\r\n').allMatches(raw)) {
          sent[m[1]!] = m[2]!;
        }
        return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode({'message': 'Saved.', 'product': product}))), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.StreamedResponse(Stream.value(utf8.encode(answer)), 200, headers: {'content-type': 'application/json'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider(
          create: (_) => AuthProvider(), child: MaterialApp(home: AddEditProductScreen(productId: product['id'] as int))));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Limit per buyer'), findsNothing);
      expect(find.text('Condition'), findsNothing);

      final segments = find.byType(SegmentedButton<String>);
      await tester.scrollUntilVisible(segments, 300, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<SegmentedButton<String>>(segments).selected, {'price'});   // the saved sale price
      expect(find.widgetWithText(TextField, 'Sale price *'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Discount % *'), findsNothing);

      final percent = find.descendant(of: segments, matching: find.text('Discount %'));
      await tester.ensureVisible(percent);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(percent);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<SegmentedButton<String>>(segments).selected, {'percent'});
      expect(find.widgetWithText(TextField, 'Sale price *'), findsNothing);
      expect(find.widgetWithText(TextField, 'Discount % *'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Save as draft'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Save as draft'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect([sent['sale_type'], sent['discount_percent']], ['percent', '25']);
      expect(sent['sale_price'] ?? '', '');   // no sale price with a discount
      expect(sent.containsKey('purchase_limit'), isFalse);
      expect(sent.containsKey('condition'), isFalse);
    }, () => client);
  });
}


List<int> asIds(Iterable<Map> cats) => [for (final c in cats) c['id'] as int];
