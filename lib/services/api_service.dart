import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();

  // Without a timeout an unreachable server leaves the app stuck loading.
  static const _timeout = Duration(seconds: 15);

  static Exception _networkError(Object e) {
    if (e is TimeoutException || e is SocketException) {
      return Exception(
        'Cannot reach the server at ${ApiConfig.baseUrl}. '
        'Make sure the API is running and the address is correct.',
      );
    }
    return Exception('Network error: $e');
  }
  
  static Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }
  
  static Future<void> _saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }
  
  static Future<void> _deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }
  
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      throw _networkError(e);
    }
  }
  
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      throw _networkError(e);
    }
  }
  
  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      throw _networkError(e);
    }
  }
  
  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      throw _networkError(e);
    }
  }
  
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      throw _networkError(e);
    }
  }
  
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, 'data': data};
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'An error occurred',
        'errors': data['errors'],
      };
    }
  }
  
  /// Returns the response body of a successful call, or throws with the API's message.
  /// get/post/put/patch/delete wrap the body as {'success': .., 'data': ..}.
  static Map<String, dynamic> unwrap(Map<String, dynamic> result) {
    if (result['success'] == true) {
      final data = result['data'];
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    }
    throw Exception(result['message'] ?? 'Something went wrong');
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password, {
    bool remember = false,
  }) async {
    final result = await post(
      ApiConfig.login,
      body: {
        'email': email,
        'password': password,
        'remember': remember,
      },
    );
    
    if (result['success'] && result['data']['token'] != null) {
      await _saveToken(result['data']['token']);
    }
    
    return result;
  }
  
  static Future<void> logout() async {
    try {
      await post(ApiConfig.logout);
    } finally {
      await _deleteToken();
    }
  }
}
