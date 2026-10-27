// A courier (rider) waiting for approval: Dashboard (application status), Notifications and Profile only;
// Back from another tab returns to the Dashboard, and on the Dashboard it asks before leaving.
import 'dart:convert';

import 'package:alvy_app/providers/auth_provider.dart';
import 'package:alvy_app/screens/courier/courier_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('pending courier: three tabs, back goes to the dashboard', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 't'});
    final client = MockClient((request) async {
      final path = request.url.path;
      final body = path.endsWith('/courier/status')
          ? {
              'application': {'status': 'pending', 'hub': 'Bilis Hatid Express', 'name': 'Ana Reyes', 'email': 'ana@example.com',
                'vehicle_type': 'Motorcycle', 'plate_number': 'XYZ9876', 'submitted_at': '2026-10-21T01:00:00Z'}
            }
          : path.endsWith('/notifications')
              ? {
                  'data': [
                    {'id': 1, 'title': 'Welcome to ALVY', 'body': 'Your application was received.', 'type': 'info', 'read': false, 'created_at': '2026-10-21T01:00:00Z'}
                  ],
                  'unread': 1,
                  'current_page': 1,
                  'last_page': 1,
                }
              : <String, dynamic>{};
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider(create: (_) => AuthProvider(), child: const MaterialApp(home: CourierStatusScreen())));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Dashboard: the application under review, and only these three tabs.
      expect(find.text('Application under review'), findsOneWidget);
      expect(find.textContaining('Bilis Hatid Express'), findsWidgets);
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      for (final t in ['Dashboard', 'Notifications', 'Profile']) {
        expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(t)), findsOneWidget);
      }

      // Notifications.
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Notifications')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Welcome to ALVY'), findsOneWidget);

      // Back from Notifications → Dashboard (not out of the app).
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Application under review'), findsOneWidget);

      // Profile with Log out.
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Courier · waiting for approval'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);

      // Back on the Dashboard asks first.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Leave ALVY?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Application under review'), findsOneWidget);
    }, () => client);
  });
}
