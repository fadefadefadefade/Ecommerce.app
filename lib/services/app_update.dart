import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';

/// The newest published build (Ecommerce.web: `php artisan app:publish-apk`).
class AppRelease {
  final int build;
  final String version;
  final int size;
  final String downloadUrl;
  const AppRelease({required this.build, required this.version, required this.size, required this.downloadUrl});
}

/// In-app update: an older build must update before the app can be used. The app fetches the new APK itself;
/// Android then asks the user to confirm (a sideloaded app cannot skip that).
class AppUpdate {
  AppUpdate._();

  static const _channel = MethodChannel('alvy/app_update');

  static int? _build;

  /// This build's number (pubspec +N), sent to the server as X-App-Build; 0 when unknown.
  static Future<int> buildNumber() async {
    if (_build != null) return _build!;
    try {
      _build = Platform.isAndroid ? (await _channel.invokeMethod<int>('versionCode') ?? 0) : 0;
    } catch (_) {
      _build = 0;
    }
    return _build!;
  }

  /// This build's version, as shown in Settings ("1.4.0").
  static Future<String> versionName() async {
    try {
      return await _channel.invokeMethod<String>('versionName') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// The published release when this phone is on an older build, else null.
  /// Any problem (offline, server down, not Android) lets the app open: an update check must never lock people out.
  static Future<AppRelease?> check() async {
    if (!Platform.isAndroid) return null;
    try {
      final current = await _channel.invokeMethod<int>('versionCode') ?? 0;
      final r = await http.get(Uri.parse('${ApiConfig.apiUrl}/app/version'), headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final d = jsonDecode(r.body) as Map<String, dynamic>;
      final build = (d['build'] as num?)?.toInt() ?? 0;
      if (current <= 0 || build <= current) return null;
      return AppRelease(
        build: build,
        version: '${d['version'] ?? ''}',
        size: (d['size'] as num?)?.toInt() ?? 0,
        downloadUrl: '${ApiConfig.webUrl}${d['download_path'] ?? '/app/download'}',
      );
    } catch (_) {
      return null;
    }
  }

  /// The website's download page: another way to get the same APK (it installs over the app).
  static String get websiteUrl => '${ApiConfig.webUrl}/app';

  /// Once the app is up to date, the downloaded APK is deleted so it does not take up space.
  static Future<void> cleanup() async {
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/apk');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Downloads the APK into the app's cache ([onProgress] gets 0.0–1.0) and returns its path.
  /// A complete file from an earlier try is reused.
  static Future<String> download(AppRelease release, void Function(double) onProgress) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/apk');
    if (await dir.exists()) {
      await for (final old in dir.list()) {
        if (old is File && !old.path.endsWith('ALVY-${release.build}.apk')) await old.delete();
      }
    } else {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/ALVY-${release.build}.apk');
    if (release.size > 0 && await file.exists() && await file.length() == release.size) {
      onProgress(1);
      return file.path;
    }

    final client = http.Client();
    final partial = File('${file.path}.part');
    try {
      final res = await client.send(http.Request('GET', Uri.parse(release.downloadUrl)));
      if (res.statusCode != 200) throw Exception('Server answered ${res.statusCode}');
      final total = res.contentLength ?? release.size;
      final sink = partial.openWrite();
      var got = 0;
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) onProgress((got / total).clamp(0.0, 1.0));
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (release.size > 0 && got != release.size) throw Exception('The download was incomplete.');
      if (await file.exists()) await file.delete();
      await partial.rename(file.path);
      return file.path;
    } finally {
      client.close();
    }
  }

  /// Opens Android's installer. False: the user must first allow ALVY to install apps (Settings was opened).
  static Future<bool> install(String path) async => await _channel.invokeMethod<bool>('install', {'path': path}) ?? false;
}
