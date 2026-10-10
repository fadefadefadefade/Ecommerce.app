// Debug script to test login flow
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🐛 Debug Login Flow Test...\n');
  
  const email = 'seller@alvy.trade';
  const password = 'password';
  
  try {
    print('1. Testing API login directly...');
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    
    print('2. Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('3. Response body: ${json.encode(data)}');
      
      if (data['success'] == true) {
        final user = data['user'];
        print('4. ✅ API login successful');
        print('   - User ID: ${user['id']}');
        print('   - Email: ${user['email']}');
        print('   - Role: ${user['role']}');
        print('   - Approval Status: ${user['approval_status']}');
        
        // Check what screen should be shown
        final role = user['role'];
        final approvalStatus = user['approval_status'];
        
        if (role == 'seller' && approvalStatus == 'approved') {
          print('5. 🎯 Should route to: SellerMainScreen');
        } else if (role == 'seller' && approvalStatus != 'approved') {
          print('5. 🎯 Should route to: SellerPendingScreen');
        } else if (role == 'customer' || role == 'buyer') {
          print('5. 🎯 Should route to: BuyerHomeScreen');
        }
      } else {
        print('4. ❌ API returned success=false');
        print('   - Message: ${data['message']}');
      }
    } else {
      print('3. ❌ HTTP error: ${response.statusCode}');
      print('   - Body: ${response.body}');
    }
    
  } catch (e) {
    print('❌ Error during test: $e');
  }
}