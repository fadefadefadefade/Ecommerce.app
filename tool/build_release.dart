// Builds the release APK with the next version, so nobody has to remember to raise it:
//   dart run tool/build_release.dart            1.4.0+5 -> 1.4.1+6
//   dart run tool/build_release.dart --minor    1.4.0+5 -> 1.5.0+6
//   dart run tool/build_release.dart --clean    same, after a full `flutter clean` (slow; only if something looks off)
//   dart run tool/build_release.dart --dry-run  only shows the next version
// The build number only has to be higher than the last published one, so test builds may skip numbers.
// Publishing is separate (Ecommerce.web: php artisan app:publish-apk).
//
// Fast by default: only Flutter's compiled-Dart cache is removed (an incremental release build could keep old
// code there), so Gradle reuses everything else. Phones are ARM, so the x86_64 (emulator) code is left out.
// After the build it checks the compiled app code is new; if not, it fails instead of handing over old code.
import 'dart:convert';
import 'dart:io';

final _versionLine = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*$', multiLine: true);

Future<void> main(List<String> args) async {
  final started = DateTime.now();
  final pubspec = File('pubspec.yaml');
  final original = await pubspec.readAsString();
  final m = _versionLine.firstMatch(original.replaceAll('\r\n', '\n'));
  if (m == null) {
    stderr.writeln('pubspec.yaml has no "version: x.y.z+n" line.');
    exit(1);
  }
  final minor = args.contains('--minor');
  final full = args.contains('--clean');
  final [major, mid, patch, build] = [for (var i = 1; i <= 4; i++) int.parse(m.group(i)!)];
  final next = minor ? '$major.${mid + 1}.0+${build + 1}' : '$major.$mid.${patch + 1}+${build + 1}';
  stdout.writeln('Version: ${m.group(1)}.${m.group(2)}.${m.group(3)}+$build -> $next${full ? ' (full clean build)' : ''}');
  if (args.contains('--dry-run')) return;

  await pubspec.writeAsString(original.replaceFirst(RegExp(r'^version:.*$', multiLine: true), 'version: $next${original.contains('\r\n') ? '\r' : ''}'));

  var code = 0;
  if (full) {
    code = await _flutter(['clean']);
  } else {
    stdout.writeln('Removing the compiled-Dart cache (keeps the Gradle cache)…');
    for (final dir in ['.dart_tool/flutter_build', 'build/app/intermediates/flutter', 'build/app/outputs']) {
      final d = Directory(dir);
      if (await d.exists()) await d.delete(recursive: true);
    }
  }
  // `pub get` first (the new version changes pubspec.yaml); it writes GeneratedPluginRegistrant.java with the test-only
  // plugins (integration_test), which a release build can't compile. Delete it after, so the build writes a release one.
  if (code == 0) code = await _flutter(['pub', 'get']);
  final registrant = File('android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java');
  if (await registrant.exists()) await registrant.delete();
  if (code == 0) code = await _flutter(['build', 'apk', '--release', '--target-platform', 'android-arm,android-arm64']);
  if (code == 0) code = await _check(started, int.parse(next.split('+').last));

  if (code != 0) {
    await pubspec.writeAsString(original);   // a failed build does not use up a version
    stderr.writeln('Build failed; the version was put back.');
    exit(code);
  }
  final took = DateTime.now().difference(started);
  stdout.writeln('Built $next in ${took.inMinutes}m ${took.inSeconds % 60}s: build/app/outputs/flutter-apk/app-release.apk');
}

/// The APK has the new build number and freshly compiled app code.
Future<int> _check(DateTime started, int buildNumber) async {
  final so = File('build/app/intermediates/flutter/release/arm64-v8a/app.so');
  if (!await so.exists() || (await so.lastModified()).isBefore(started)) {
    stderr.writeln('The app code was not recompiled. Build again with --clean.');
    return 2;
  }
  try {
    final meta = jsonDecode(await File('build/app/outputs/apk/release/output-metadata.json').readAsString());
    final got = (meta['elements'] as List).first['versionCode'];
    if (got != buildNumber) {
      stderr.writeln('The APK has build $got, expected $buildNumber.');
      return 2;
    }
  } catch (e) {
    stderr.writeln('Could not read the build output: $e');
    return 2;
  }
  return 0;
}

Future<int> _flutter(List<String> args) async {
  final p = await Process.start('flutter', args, runInShell: true, mode: ProcessStartMode.inheritStdio);
  return p.exitCode;
}
