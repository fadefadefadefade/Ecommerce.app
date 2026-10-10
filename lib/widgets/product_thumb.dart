import 'package:flutter/material.dart';
import 'net_image.dart';
import '../config/api_config.dart';

/// Square product photo with a local placeholder when there's no image or it fails to load.
/// Accepts a full URL or a storage path like `products/x.jpg`.
class ProductThumb extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;

  const ProductThumb({super.key, required this.url, this.size = 56, this.radius = 8});

  static String? resolve(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return null;
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    return '${ApiConfig.storageUrl}/${pathOrUrl.replaceFirst(RegExp(r'^/?(storage/)?'), '')}';
  }

  @override
  Widget build(BuildContext context) {
    final src = resolve(url);
    final placeholder = Container(
      width: size,
      height: size,
      color: const Color(0xFFF3EDE4),
      child: Icon(Icons.inventory_2_outlined, size: size * 0.45, color: const Color(0xFFfa4e1c)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: src == null
          ? placeholder
          : NetImage(
              src,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => placeholder,
              loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
            ),
    );
  }
}
