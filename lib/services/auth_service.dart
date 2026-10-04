import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  // Get the stored authentication token
  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  // Save authentication token
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  // Remove authentication token (logout)
  Future<void> removeToken() async {
    await _storage.delete(key: 'auth_token');
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Save user data
  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: 'user_data', value: user.toString());
  }

  // Get user data
  Future<String?> getUser() async {
    return await _storage.read(key: 'user_data');
  }

  // Clear all stored data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}