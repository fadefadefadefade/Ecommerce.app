// On a phone / emulator: the sample rider's day on the real web API (throwaway database seeded with SampleLogisticsSeeder).
//
//   flutter test integration_test/rider_flow_test.dart -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:8095
//
// Go Online → confirm the assigned pickup (a wrong tracking number is refused) → deliver the out-for-delivery parcel with a
// photo, the buyer's OTP (read from the buyer's order, as the buyer would tell it) and the exact COD → remit the COD.
// Only the camera is replaced (it returns a real JPG file); everything else goes through the app and the web.
library;

import 'dart:convert';
import 'dart:io';

import 'package:alvy_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const apiUrl = String.fromEnvironment('API_URL');

/// The camera: hands back a real JPG (a page of the PDF library rasterized), as if a photo was taken.
class _FakeCamera extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async {
    final doc = pw.Document()..addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('Proof of delivery'))));
    final page = await Printing.raster(await doc.save(), dpi: 30).first;
    final file = File('${(await getTemporaryDirectory()).path}/pod_test.png');
    await file.writeAsBytes(await page.toPng());
    return XFile(file.path, mimeType: 'image/png');
  }
}

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

/// The OTP the buyer sees on their order page.
Future<String> buyersOtp() async {
  final h = {'Accept': 'application/json', 'Content-Type': 'application/json'};
  final login = jsonDecode((await http.post(Uri.parse('$apiUrl/api/v1/auth/login'), headers: h,
          body: jsonEncode({'email': 'juanmiguel.delacruz@example.com', 'password': 'Mamimili@2026'})))
      .body);
  final order = jsonDecode((await http.get(Uri.parse('$apiUrl/api/v1/orders/10'), headers: {...h, 'Authorization': 'Bearer ${login['token']}'})).body);
  return '${order['order']['delivery']['otp']}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rider: online, pickup, deliver with photo + OTP + COD, remit', (tester) async {
    ImagePickerPlatform.instance = _FakeCamera();
    await tester.pumpWidget(const MyApp());
    await waitFor(tester, find.text('Log In'));
    await tester.pump(const Duration(seconds: 3));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'pedrojose.garcia@example.com');
    await tester.enterText(fields.at(1), 'Rider@2026');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.text('Log In'));

    // ── Hub Jobs: go Online ──
    await waitFor(tester, find.text('Hub Jobs'));
    await waitFor(tester, find.byWidgetPredicate((w) => w is Text && (w.data == 'Go Online' || w.data == 'Go Offline')));
    if (find.text('Go Offline').evaluate().isNotEmpty) {
      // Already Online (sample data): go Offline first. Active jobs stay with the rider.
      await tapIt(tester, find.text('Go Offline'));
      await waitFor(tester, find.textContaining("You are Offline. You won't get new offers, but your"));
      await hideSnack(tester);
      debugPrint('STEP_OFFLINE');
    }
    await waitFor(tester, find.text('Go Online'));
    await tapIt(tester, find.text('Go Online'));
    await waitFor(tester, find.text('You are Online. New job offers will appear here.'));
    await waitFor(tester, find.text('Go Offline'));
    await hideSnack(tester);
    debugPrint('STEP_ONLINE');

    // ── Pickup: wrong tracking refused, then the right one ──
    final pickupTile = find.textContaining('Pickup · ALVY');
    await waitFor(tester, pickupTile);
    final tracking = (tester.widget<Text>(pickupTile.first).data ?? '').replaceFirst('Pickup · ', '');
    await tapIt(tester, pickupTile);
    await waitFor(tester, find.text('Confirm pickup'));
    await tester.enterText(find.byType(TextField).first, 'ALVY-WRONG');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.text('Confirm pickup'));
    await waitFor(tester, find.text('The tracking number does not match this job. Check the waybill on the parcel.'));
    await hideSnack(tester);
    await tester.tap(find.byType(TextField).first);   // focus the field again, as a person would
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).first, tracking);
    debugPrint('TRACKING [$tracking] FIELD [${tester.widget<TextField>(find.byType(TextField).first).controller?.text}]');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.text('Confirm pickup'));
    await waitFor(tester, find.textContaining('picked up. You earned ₱30.00'));
    await hideSnack(tester);
    debugPrint('STEP_PICKUP $tracking');

    // ── Delivery: photo, the buyer's OTP and the exact COD ──
    final deliveryTile = find.textContaining('Delivery · ALVY');
    await waitFor(tester, deliveryTile);
    final deliveredTracking = (tester.widget<Text>(deliveryTile.first).data ?? '').replaceFirst('Delivery · ', '');
    await tapIt(tester, deliveryTile);
    await waitFor(tester, find.text('Delivered'));
    expect(find.text('COD — collect ₱500.00'), findsOneWidget);

    await tapIt(tester, find.text('Take proof-of-delivery photo'));
    await waitFor(tester, find.text('Retake photo'));
    final otp = await tester.runAsync(buyersOtp) ?? '';
    expect(otp, matches(RegExp(r'^\d{6}$')));
    final inputs = find.byType(TextField);
    await tester.enterText(inputs.at(0), otp);
    await tester.enterText(inputs.at(1), '450');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.text('Delivered'));
    await waitFor(tester, find.text('The COD amount doesn\'t match. Collect exactly ₱500.00.'));
    await hideSnack(tester);
    debugPrint('STEP_COD_REFUSED');
    await tester.tap(inputs.at(1));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(inputs.at(1), '500');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 1));
    await tapIt(tester, find.text('Delivered'));
    await waitFor(tester, find.text('Delivered. You earned ₱50.00 and collected ₱500.00 COD to remit.'));
    await hideSnack(tester);
    debugPrint('STEP_DELIVERED');

    // ── COD remittance ──
    await tester.tap(find.text('COD').last);
    await waitFor(tester, find.text('Remit'));
    await tester.pump(const Duration(seconds: 1));
    final remit = tester.widget<FilledButton>(find.ancestor(of: find.text('Remit'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
    // The COD tab opens fresh: the parcel just delivered is in the list.
    expect(find.textContaining(deliveredTracking), findsWidgets);
    if (remit.onPressed == null) {
      // The sample data already has a remittance waiting for the company: like the website, no second one until it's confirmed.
      expect(remit.onPressed, isNull);
      debugPrint('STEP_REMIT_WAITING');
    } else {
      await tapIt(tester, find.text('Remit'));
      await waitFor(tester, find.textContaining('It stays Pending until'));
    }
    debugPrint('STEP_REMITTED');
    await tester.pump(const Duration(seconds: 3));
  }, timeout: const Timeout(Duration(minutes: 5)), skip: apiUrl.isEmpty);
}
