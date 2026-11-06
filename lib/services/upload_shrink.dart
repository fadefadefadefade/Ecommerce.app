import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Photos straight from a phone camera are 3–8 MB; uploading several (an ID, a license, OR/CR…) over mobile
/// data is slow. Before an upload, a large JPG/PNG is resized to at most [maxSide] px (JPG re-saved at
/// quality 80; PNG kept as PNG so logos keep their transparency). PDFs, videos and small images are sent as they are.
class UploadShrink {
  static const maxSide = 1600;
  static const minBytes = 700 * 1024;   // smaller files are already fine

  /// The path to upload: a smaller copy in the temp folder, or [path] itself.
  static Future<String> forUpload(String path, {Directory? tempDir}) async {
    final lower = path.toLowerCase();
    final isJpg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');
    final isPng = lower.endsWith('.png');
    if (!isJpg && !isPng) return path;
    try {
      final file = File(path);
      if (await file.length() < minBytes) return path;
      final bytes = await file.readAsBytes();
      final out = await compute(_shrink, (bytes, isPng));
      if (out == null || out.length >= bytes.length) return path;
      final dir = tempDir ?? await getTemporaryDirectory();
      final name = path.split(RegExp(r'[\\/]')).last;
      final target = File('${dir.path}${Platform.pathSeparator}upload_${DateTime.now().microsecondsSinceEpoch}_$name');
      await target.writeAsBytes(out, flush: true);
      return target.path;
    } catch (_) {
      return path;   // never block an upload because shrinking failed
    }
  }
}

/// Runs in a background isolate: decode, turn upright (EXIF), resize, encode.
Uint8List? _shrink((Uint8List, bool) args) {
  final (bytes, isPng) = args;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > UploadShrink.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: UploadShrink.maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: UploadShrink.maxSide, interpolation: img.Interpolation.average);
  }
  return isPng ? img.encodePng(image, level: 6) : img.encodeJpg(image, quality: 80);
}
