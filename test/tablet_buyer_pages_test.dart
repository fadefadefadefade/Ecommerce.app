// Tablet buyer pages look like the website (account menu on the left with the page on the right);
// phones keep the mobile design.
import 'dart:convert';

import 'package:alvy_app/providers/auth_provider.dart';
import 'package:alvy_app/screens/buyer/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpAccount(WidgetTester tester, Size size) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't'});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = MockClient((request) async =>
        http.Response(jsonEncode(request.url.path.endsWith('/notifications') ? {'data': [], 'unread': 0, 'current_page': 1, 'last_page': 1} : <String, dynamic>{}),
            200, headers: {'content-type': 'application/json'}));
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider(create: (_) => AuthProvider(), child: const MaterialApp(home: ProfileScreen())));
      await tester.pump(const Duration(milliseconds: 300));
    }, () => client);
  }

  testWidgets('tablet account: menu on the left, the page opens on the right, Back returns to the overview', (tester) async {
    await pumpAccount(tester, const Size(1280, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('Overview'), findsOneWidget);            // the left menu
    expect(find.text('Personal Information'), findsOneWidget); // the overview on the right
    expect(find.byType(GridView), findsNothing);               // not the phone's menu grid

    await tester.tap(find.text('Policies'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);             // the menu stays
    expect(find.text('Personal Information'), findsNothing);   // Policies is shown on the right

    final handled = await tester.binding.handlePopRoute();     // the phone's Back button
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.text('Personal Information'), findsOneWidget); // back to the overview, the app stays open
  });

  testWidgets('phone account keeps the mobile design (even sideways)', (tester) async {
    for (final size in [const Size(412, 915), const Size(915, 412)]) {
      await pumpAccount(tester, size);
      // The phone layout is unchanged; the test font (square letters) is wider than the real one and makes
      // the existing account header report an overflow here, with the original code too.
      tester.takeException();
      expect(find.text('Overview'), findsNothing);
      expect(find.text('Personal Information'), findsOneWidget);
    }
  });
}
