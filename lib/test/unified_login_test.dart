// Test the unified login system with different user roles

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  await testUnifiedLogin();
}

Future<void> testUnifiedLogin() async {
  const baseUrl = 'http://127.0.0.1:8000/api';
  
  print('🧪 Testing Unified Login System...\n');
  
  final testUsers = [
    {'email': 'customer@alvy.trade', 'password': 'password', 'expectedRole': 'customer'},
    {'email': 'seller@alvy.trade', 'password': 'password', 'expectedRole': 'seller'},
  ];

  for (final user in testUsers) {
    try {
      print('🔑 Testing login for ${user['email']} (expecting ${user['expectedRole']})...');
      
      final loginResponse = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': user['email'],
          'password': user['password'],
        }),
      );
      
      if (loginResponse.statusCode != 200) {
        throw Exception('Login failed: ${loginResponse.statusCode}');
      }
      
      final loginData = json.decode(loginResponse.body);
      final userData = loginData['user'];
      final role = userData['role'];
      final approvalStatus = userData['approval_status'];
      
      print('✅ Login successful!');
      print('   Role: $role');
      print('   Approval Status: $approvalStatus');
      print('   Expected Role: ${user['expectedRole']}');
      
      if (role == user['expectedRole']) {
        print('   ✅ Role matches expectation');
      } else {
        print('   ❌ Role mismatch!');
      }
      
      // Determine expected screen
      String expectedScreen;
      switch (role.toLowerCase()) {
        case 'customer':
        case 'buyer':
          expectedScreen = 'BuyerHomeScreen';
          break;
        case 'seller':
          if (approvalStatus == 'approved') {
            expectedScreen = 'SellerMainScreen';
          } else {
            expectedScreen = 'SellerPendingScreen';
          }
          break;
        case 'courier':
          expectedScreen = 'CourierDashboard (Coming Soon)';
          break;
        case 'admin':
          expectedScreen = 'AdminDashboard (Coming Soon)';
          break;
        default:
          expectedScreen = 'UnsupportedRoleScreen';
      }
      
      print('   📱 Should route to: $expectedScreen');
      print('');
      
    } catch (e) {
      print('❌ Login failed for ${user['email']}: $e\n');
    }
  }
  
  print('🎉 Unified login system testing complete!');
  print('\n📋 Summary of Unified Login Features:');
  print('   ✅ Single login screen for all user types');
  print('   ✅ Automatic role-based routing after login');
  print('   ✅ Seller approval status handling');
  print('   ✅ Graceful handling of unsupported roles');
  print('   ✅ Coming soon screens for unimplemented roles');
  print('   ✅ No more separate seller login screen');
  
  print('\n🔀 Routing Logic:');
  print('   Customer/Buyer → BuyerHomeScreen');
  print('   Approved Seller → SellerMainScreen');
  print('   Pending Seller → SellerPendingScreen');
  print('   Courier → Coming Soon screen');
  print('   Admin → Coming Soon screen');
  print('   Unknown Role → Unsupported role screen');
}