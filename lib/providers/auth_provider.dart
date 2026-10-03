import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  
  final _storage = const FlutterSecureStorage();

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
    _isLoading = true;
    notifyListeners();
    
    try {
      final result = await ApiService.login(email, password, remember: remember);
      
      if (result['success']) {
        _user = User.fromJson(result['data']['user']);
        await _storage.write(
          key: 'user_data',
          value: jsonEncode(_user!.toJson()),
        );
        _isLoading = false;
        notifyListeners();
        return {'success': true};
      } else {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': result['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
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