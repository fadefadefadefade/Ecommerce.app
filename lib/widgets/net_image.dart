import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Network image that downloads the bytes itself and retries on failure.
///
/// Flutter's built-in NetworkImage fails against the local `php artisan serve`
/// server on the Android emulator ("Connection closed while receiving data")
/// for larger photos. Fetching with `Connection: close` and retrying, then
/// showing the bytes with Image.memory, loads them reliably.
class NetImage extends StatefulWidget {
  final String src;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final int maxRetries;

  const NetImage(
    this.src, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
    this.maxRetries = 3,
  });

  // Small in-memory cache shared by all NetImages (URL -> bytes).
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List>> _inFlight = {};
  static final HttpClient _client = HttpClient()
    ..autoUncompress = true
    ..connectionTimeout = const Duration(seconds: 15);

  /// Downloads [url], retrying up to [retries] times. Concurrent calls share one download.
  static Future<Uint8List> load(String url, {int retries = 3}) {
    final cached = _cache[url];
    if (cached != null) return Future.value(cached);
    return _inFlight[url] ??= _download(url, retries).whenComplete(() => _inFlight.remove(url));
  }

  static Future<Uint8List> _download(String url, int retries) async {
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0) await Future.delayed(Duration(milliseconds: 300 * attempt));
      var received = 0;
      try {
        final request = await _client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 10));
        request.headers.set(HttpHeaders.connectionHeader, 'close');
        final response = await request.close().timeout(const Duration(seconds: 10));
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
        }
        final builder = BytesBuilder(copy: false);
        // A stalled transfer must fail (and retry) instead of waiting forever,
        // otherwise every later request for this URL would share the stuck download.
        await for (final chunk in response.timeout(const Duration(seconds: 10))) {
          builder.add(chunk);
          received += chunk.length;
        }
        final bytes = builder.takeBytes();
        if (response.contentLength > 0 && bytes.length != response.contentLength) {
          throw HttpException('Incomplete: ${bytes.length}/${response.contentLength} bytes', uri: Uri.parse(url));
        }
        _cache[url] = bytes;
        return bytes;
      } catch (e) {
        lastError = e;
        if (kDebugMode) debugPrint('NetImage attempt ${attempt + 1} failed ($received bytes) for $url: $e');
      }
    }
    throw lastError ?? Exception('Failed to load $url');
  }

  @override
  State<NetImage> createState() => _NetImageState();
}

class _NetImageState extends State<NetImage> {
  late Future<Uint8List> _future;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _failed = false;
    _future = NetImage.load(widget.src, retries: widget.maxRetries);
    _future.catchError((Object _) {
      _failed = true;
      return Uint8List(0);
    });
  }

  @override
  void didUpdateWidget(NetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New URL, or the parent rebuilt (e.g. list refresh) after a failed load: try again.
    if (oldWidget.src != widget.src || _failed) _start();
  }

  Widget _box() => SizedBox(width: widget.width, height: widget.height);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (c, e, s) => widget.errorBuilder?.call(c, e, s) ?? _box(),
          );
        }
        if (snapshot.hasError) {
          return widget.errorBuilder?.call(context, snapshot.error!, snapshot.stackTrace) ?? _box();
        }
        return widget.loadingBuilder?.call(
              context,
              _box(),
              const ImageChunkEvent(cumulativeBytesLoaded: 0, expectedTotalBytes: null),
            ) ??
            _box();
      },
    );
  }
}
