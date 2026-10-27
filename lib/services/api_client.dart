import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'upload_shrink.dart';

/// The answer of an /api/v1 call: the HTTP status, the JSON body, and the web's messages.
class ApiResponse {
  final int status;
  final Map<String, dynamic> body;

  /// The answer didn't arrive whole (cut off, or the connection dropped): safe to ask again for a GET.
  final bool broken;

  ApiResponse(this.status, this.body, {this.broken = false});

  bool get ok => status >= 200 && status < 300;
  bool get unauthorized => status == 401;

  /// The message the web shows (a flash message or the first validation error).
  String get message {
    final errors = fieldErrors;
    if (!ok && errors.isNotEmpty) return errors.values.first;
    return (body['message'] as String?) ?? (ok ? '' : 'Something went wrong. Please try again.');
  }

  /// Validation errors per field, e.g. {'contact_no': 'Please enter a valid mobile number…'}.
  Map<String, String> get fieldErrors {
    final raw = body['errors'];
    if (raw is! Map) return {};
    return raw.map((key, value) => MapEntry(
          key.toString(),
          value is List && value.isNotEmpty ? value.first.toString() : value.toString(),
        ));
  }
}

/// A downloaded file, or the error the web answered with.
class ApiDownload {
  final List<int> bytes;
  final String filename;
  final ApiResponse? error;

  ApiDownload(this.bytes, this.filename, this.error);
  ApiDownload.failed(ApiResponse this.error)
      : bytes = const [],
        filename = '';

  bool get ok => error == null;
}

/// Calls the web's /api/v1 with the signed-in token (Authorization: Bearer …).
class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _timeout = Duration(seconds: 20);
  static const _uploadTimeout = Duration(minutes: 2);
  static const _cutOff = "ALVY's answer was cut off, so the app couldn't confirm it. The page was refreshed: check whether it went through.";

  /// Called when the server says the login is no longer valid (e.g. 30 idle minutes, A22).
  static void Function(String message)? onUnauthorized;

  static Future<String?> token() => _storage.read(key: _tokenKey);
  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('${ApiConfig.apiUrl}$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      for (final e in query.entries)
        if (e.value != null) e.key: e.value.toString(),
    });
  }

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final t = await token();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  /// A GET is asked again (up to twice, on a fresh connection) when the answer arrives cut off — this happens
  /// with larger answers between the Android emulator and a local development server.
  static Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) async {
    for (var attempt = 0;; attempt++) {
      final r = await _send(() async => http.get(_uri(path, query), headers: {...await _headers(), if (attempt > 0) 'Connection': 'close'}));
      if (!r.broken || attempt >= 2) return r;
      await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }
  }

  static Future<ApiResponse> post(String path, [Map<String, dynamic>? body]) =>
      _send(() async => http.post(_uri(path), headers: await _headers(), body: jsonEncode(body ?? {})));

  static Future<ApiResponse> put(String path, [Map<String, dynamic>? body]) =>
      _send(() async => http.put(_uri(path), headers: await _headers(), body: jsonEncode(body ?? {})));

  static Future<ApiResponse> patch(String path, [Map<String, dynamic>? body]) =>
      _send(() async => http.patch(_uri(path), headers: await _headers(), body: jsonEncode(body ?? {})));

  static Future<ApiResponse> delete(String path) =>
      _send(() async => http.delete(_uri(path), headers: await _headers()));

  /// A form with files (sign-up documents, photos). [files] maps field name → local file path.
  static Future<ApiResponse> multipart(String path, Map<String, String> fields, {Map<String, String> files = const {}}) =>
      _send(() async {
        final request = http.MultipartRequest('POST', _uri(path))
          ..headers.addAll(await _headers(json: false))
          ..fields.addAll(fields);
        for (final f in files.entries) {
          // Big camera photos are made smaller first (see UploadShrink).
          request.files.add(await http.MultipartFile.fromPath(f.key, await UploadShrink.forUpload(f.value)));
        }
        // Uploads get longer than other requests: several photos over mobile data take a while.
        return http.Response.fromStream(await request.send().timeout(_uploadTimeout));
      }, timeout: _uploadTimeout);

  /// A file the web sends back (e.g. a report export). On an error, [ApiDownload.error] has the web's message.
  static Future<ApiDownload> download(String path, {Map<String, dynamic>? query}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path, query), headers: await _headers(json: false)).timeout(_timeout);
    } on TimeoutException {
      return ApiDownload.failed(ApiResponse(0, {'message': 'ALVY at ${ApiConfig.webUrl} took too long to answer. Check the server address (Login → Server) and your connection.'}));
    } on SocketException {
      return ApiDownload.failed(ApiResponse(0, {'message': 'Cannot reach ALVY at ${ApiConfig.webUrl}. Make sure the website is running and the server address is right (Login → Server).'}));
    }
    final type = res.headers['content-type'] ?? '';
    if (res.statusCode != 200 || type.contains('application/json')) {
      Map<String, dynamic> body;
      try {
        body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
      } catch (_) {
        body = {'message': 'Unexpected answer from the server (${res.statusCode}).'};
      }
      return ApiDownload.failed(ApiResponse(res.statusCode, body));
    }
    final name = RegExp(r'filename="?([^";]+)"?').firstMatch(res.headers['content-disposition'] ?? '')?.group(1);
    return ApiDownload(res.bodyBytes, name ?? path.split('/').last, null);
  }

  static Future<ApiResponse> _send(Future<http.Response> Function() call, {Duration timeout = _timeout}) async {
    http.Response res;
    try {
      res = await call().timeout(timeout);
    } on TimeoutException {
      return ApiResponse(0, {'message': 'ALVY at ${ApiConfig.webUrl} took too long to answer. Check the server address (Login → Server) and your connection.'});
    } on SocketException {
      return ApiResponse(0, {'message': 'Cannot reach ALVY at ${ApiConfig.webUrl}. Make sure the website is running and the server address is right (Login → Server).'});
    } on http.ClientException {
      // e.g. "Connection closed while receiving data"
      return ApiResponse(0, {'message': _cutOff}, broken: true);
    }

    Map<String, dynamic> body;
    var broken = false;
    try {
      final decoded = jsonDecode(res.body);
      body = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } catch (_) {
      // A JSON answer that doesn't parse arrived cut off.
      broken = (res.headers['content-type'] ?? '').contains('json');
      body = {'message': broken ? _cutOff : 'Unexpected answer from the server (${res.statusCode}).'};
    }

    // A cut-off answer is not a success, even with status 200 (the page would look empty instead of showing an error).
    final response = ApiResponse(broken ? 0 : res.statusCode, body, broken: broken);
    if (response.unauthorized && (await token()) != null) {
      await clearToken();
      onUnauthorized?.call('Your session expired. Please log in again.');
    }
    return response;
  }
}
