import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../screens/buyer/home_screen.dart';
import '../screens/seller/seller_main_screen.dart';
import '../screens/logistics/logistics_main_screen.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  
  final _storage = const FlutterSecureStorage();

  @override
  void notifyListeners() {
    debugPrint('🔔 AuthProvider.notifyListeners() called - hasListeners: $hasListeners, user: ${_user?.email ?? 'null'}, isAuthenticated: $isAuthenticated');
    super.notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final userJson = await _storage.read(key: 'user_data');
      if (userJson != null) {
        _user = User.fromJson(jsonDecode(userJson));
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    bool remember = false,
  }) async {
    debugPrint('🔑 Starting login for: $email');
    _isLoading = true;
    notifyListeners();
    
    try {
      final result = await ApiService.login(email, password, remember: remember);
      debugPrint('🔄 API response received: ${result['success']}');
      
      if (result['success']) {
        _user = User.fromJson(result['data']['user']);
        debugPrint('🔑 Login successful for user: ${_user!.email}, role: ${_user!.role}');
        
        await _storage.write(
          key: 'user_data',
          value: jsonEncode(_user!.toJson()),
        );
        
        _isLoading = false;
        debugPrint('📢 About to call notifyListeners() after successful login');
        notifyListeners();
        
        // Force another notifyListeners after a small delay to ensure UI updates
        Future.delayed(const Duration(milliseconds: 100), () {
          debugPrint('🔄 Forcing additional notifyListeners call');
          notifyListeners();
        });
        
        debugPrint('✅ Login process completed successfully');
        return {'success': true, 'user': _user};
      } else {
        _user = null;
        _isLoading = false;
        debugPrint('❌ Login failed: ${result['message']}');
        notifyListeners();
        return {
          'success': false,
          'message': result['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      _user = null;
      _isLoading = false;
      debugPrint('💥 Login exception: $e');
      notifyListeners();
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }

  // Get the appropriate main screen widget for the user's role
  Widget getMainScreenForRole() {
    debugPrint('🔍 getMainScreenForRole called, user: ${_user?.email ?? 'null'}');
    
    if (_user == null) {
      debugPrint('❌ User is null, returning loading screen');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final role = _user!.role.toLowerCase();
    debugPrint('🎯 User role: $role, approval status: ${_user!.approvalStatus}');

    switch (role) {
      case 'customer':
      case 'buyer':
        debugPrint('📱 Routing to BuyerHomeScreen');
        return const BuyerHomeScreen();
      
      case 'seller':
        if (_user!.isApprovedSeller) {
          debugPrint('📱 Routing to SellerMainScreen (approved seller)');
          return const SellerMainScreen();
        } else {
          debugPrint('📱 Routing to SellerPendingScreen (pending/rejected seller)');
          return _buildSellerPendingScreen();
        }
      
      case 'courier':
        debugPrint('📱 Routing to CourierDashboard (coming soon)');
        return _buildComingSoonScreen('Courier Dashboard');
      
      case 'admin':
        debugPrint('📱 Routing to LogisticsMainScreen');
        return const LogisticsMainScreen();
      
      default:
        debugPrint('❌ Unknown role: $role, routing to unsupported screen');
        return _buildUnsupportedRoleScreen();
    }
  }

  Widget _buildSellerPendingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pending,
                  size: 40,
                  color: Colors.orange.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Seller Account Pending',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _user!.isPendingSeller 
                    ? 'Your seller account is under review.\nYou\'ll be notified once approved.'
                    : 'Your seller account was not approved.\nPlease contact support for assistance.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6b90aa),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFfa4e1c),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonScreen(String title) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.construction,
                size: 64,
                color: Color(0xFF8a7a70),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6b90aa),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFfa4e1c),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupportedRoleScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'Unsupported Account Type',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Account role "${_user?.role}" is not supported in this app.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6b90aa),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFfa4e1c),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> logout() async {
    try {
      await ApiService.logout();
    } finally {
      _user = null;
      await _storage.delete(key: 'user_data');
      notifyListeners();
    }
  }

  void updateUser(Map<String, dynamic> userData) {
    _user = User.fromJson(userData);
    _storage.write(
      key: 'user_data',
      value: jsonEncode(_user!.toJson()),
    );
    notifyListeners();
  }
}