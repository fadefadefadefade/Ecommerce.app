import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../screens/buyer/buyer_main_screen.dart';
import '../screens/seller/seller_main_screen.dart';
import '../screens/seller/panel/panel_screens.dart';
import '../screens/logistics/logistics_main_screen.dart';
import '../screens/courier/courier_main_screen.dart';
import '../screens/courier/courier_screens.dart';

/// What a sign-in, code or sign-up step answered (the web's rules and messages).
class AuthResult {
  /// ok (signed in), otp_required (enter the emailed code), pending_approval / submitted (wait for
  /// approval, no sign-in yet) or error.
  final String status;
  final String message;
  final Map<String, String> fieldErrors;
  final String? otpToken;
  final String? maskedEmail;
  final int cooldown;

  const AuthResult(this.status, this.message,
      {this.fieldErrors = const {}, this.otpToken, this.maskedEmail, this.cooldown = 0});

  bool get ok => status == 'ok';
  bool get needsOtp => status == 'otp_required';
  bool get isError => status == 'error';

  factory AuthResult.from(ApiResponse r) {
    if (!r.ok) return AuthResult('error', r.message, fieldErrors: r.fieldErrors);
    return AuthResult(
      (r.body['status'] as String?) ?? 'ok',
      (r.body['message'] as String?) ?? '',
      otpToken: r.body['otp_token'] as String?,
      maskedEmail: r.body['masked_email'] as String?,
      cooldown: (r.body['cooldown'] as num?)?.toInt() ?? 0,
    );
  }
}

class AuthProvider with ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _notice;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  /// A message for the login screen (e.g. "Your session expired"), shown once.
  String? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  final _storage = const FlutterSecureStorage();

  AuthProvider() {
    // 30 minutes without use (A22) or a revoked token: back to the login screen with the reason.
    ApiClient.onUnauthorized = (message) => _signOutLocally(notice: message);
  }

  /// On start: keep the saved login only if the server still accepts it.
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (await ApiClient.token() != null) {
        final res = await ApiClient.get('/me');
        if (res.ok) {
          await _setUser(User.fromJson(res.body['user']));
        } else if (res.unauthorized) {
          // e.g. the app was closed for more than 30 minutes (A22).
          await _storage.delete(key: 'user_data');
          _notice = 'Your session expired. Please log in again.';
        } else if (res.status == 0) {
          // Offline: keep the saved account so the app still opens.
          final saved = await _storage.read(key: 'user_data');
          if (saved != null) _user = User.fromJson(jsonDecode(saved));
        }
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// One login for every account, like the website's /login; user.home says where the account belongs.
  Future<AuthResult> login(String email, String password) async {
    final res = await ApiClient.post('/auth/login', {
      'email': email,
      'password': password,
      'device_name': 'ALVY app',
    });
    return _finish(res);
  }

  Future<AuthResult> verifyOtp(String otpToken, String code) async {
    return _finish(await ApiClient.post('/auth/otp/verify', {'otp_token': otpToken, 'otp': code}));
  }

  Future<AuthResult> resendOtp(String otpToken) async {
    return AuthResult.from(await ApiClient.post('/auth/otp/resend', {'otp_token': otpToken}));
  }

  /// The web's sign-up form: [fields] as on the website, [files] maps upload field → local file path.
  Future<AuthResult> register(Map<String, String> fields, Map<String, String> files) async {
    return AuthResult.from(await ApiClient.multipart('/auth/register', fields, files: files));
  }

  Future<AuthResult> _finish(ApiResponse res) async {
    final result = AuthResult.from(res);
    if (result.ok && res.body['token'] != null) {
      await ApiClient.saveToken(res.body['token']);
      await _setUser(User.fromJson(res.body['user']));
      notifyListeners();
    }
    return result;
  }

  Future<void> _setUser(User user) async {
    _user = user;
    await _storage.write(key: 'user_data', value: jsonEncode(user.toJson()));
  }

  // Get the appropriate main screen widget for where this account belongs (user.home from the web).
  Widget getMainScreenForRole() {
    if (_user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (_user!.home) {
      case 'buyer':
        return const BuyerMainScreen();
      case 'seller':
        return const SellerMainScreen();
      case 'seller_status':
        return const SellerStatusScreen();
      case 'rider':
      case 'courier':
      case 'linehaul':
        return const CourierMainScreen();
      case 'courier_status':
        return const CourierStatusScreen();
      case 'logistics':
        return const LogisticsMainScreen();
      case 'admin':
        return _buildStatusScreen(
          icon: Icons.admin_panel_settings,
          title: 'Admin',
          body: 'The ALVY admin panel is on the website.\nPlease sign in at the website to continue.',
        );
      default:
        return _buildStatusScreen(
          icon: Icons.error_outline,
          title: 'Unsupported Account Type',
          body: 'Account type "${_user?.role}" is not supported in this app.',
        );
    }
  }

  Widget _buildStatusScreen({required IconData icon, required String title, required String body}) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(color: Color(0xFFFFFBEB), shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: const Color(0xFFB45309)),
              ),
              const SizedBox(height: 24),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF002B4D))),
              const SizedBox(height: 12),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Color(0xFF6b90aa))),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: logout,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFfa4e1c), foregroundColor: Colors.white),
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
      await ApiClient.post('/auth/logout');
    } catch (e) {
      debugPrint('Logout API failed, clearing local session anyway: $e');
    }
    await _signOutLocally();
  }

  Future<void> _signOutLocally({String? notice}) async {
    final wasSignedIn = _user != null;
    _user = null;
    _notice = wasSignedIn ? notice : null;
    await ApiClient.clearToken();
    await _storage.delete(key: 'user_data');
    notifyListeners();
  }

  /// Profile screens still on the old API send back a user without "home": keep where the account belongs.
  void updateUser(Map<String, dynamic> userData) {
    final merged = {...?_user?.toJson(), ...userData};
    if (userData['home'] == null) {
      merged['home'] = _user?.home;
      merged['rider_id'] = _user?.riderId;
    }
    _user = User.fromJson(merged);
    _storage.write(key: 'user_data', value: jsonEncode(_user!.toJson()));
    notifyListeners();
  }
}
