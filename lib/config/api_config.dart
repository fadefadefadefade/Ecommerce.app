import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // ── The ALVY web (Ecommerce.web) ─────────────────────────────
  // The app runs on the web's own API (/api/v1): one backend and one server for the website and the app.
  // Built-in: the live site (https://alvy.trade, the tunnel to Ecommerce.web on port 8000).
  // For development pick another one when building (flutter run --dart-define=API_URL=…) or in the app (Login → Server):
  //   Android emulator: http://10.0.2.2:8000 · phone on USB: `adb reverse tcp:8000 tcp:8000`, then http://127.0.0.1:8000
  static const String defaultUrl = String.fromEnvironment('API_URL', defaultValue: 'https://alvy.trade');

  static const _key = 'server_url';
  static String _saved = '';

  /// The server chosen in the app (Login → Server), else the one the app was built with.
  static String get webUrl => _saved.isNotEmpty ? _saved : defaultUrl;
  static bool get isCustom => _saved.isNotEmpty;

  /// Reads the saved server; call once before the app starts.
  static Future<void> load() async {
    try {
      _saved = (await SharedPreferences.getInstance()).getString(_key) ?? '';
    } catch (_) {
      _saved = '';
    }
  }

  /// Saves the server address ("" goes back to the built-in one). Returns the address in use.
  static Future<String> setServer(String url) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && !u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    _saved = u == defaultUrl ? '' : u;
    final prefs = await SharedPreferences.getInstance();
    _saved.isEmpty ? await prefs.remove(_key) : await prefs.setString(_key, _saved);
    return webUrl;
  }

  /// The app API (token sign-in). See Ecommerce.web/routes/api.php.
  static String get apiUrl => '$webUrl/api/v1';

  /// Address pickers (PSA PSGC dataset), shared with the website's forms.
  static String get psgcUrl => '$webUrl/api/psgc';

  /// Uploaded files (product images, photos) served by the web.
  static String get storageUrl => '$webUrl/storage';
}
