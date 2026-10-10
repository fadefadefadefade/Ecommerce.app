import 'package:flutter/material.dart';
import 'net_image.dart';
import '../theme/buyer_colors.dart';
import '../screens/buyer/product_detail_screen.dart';

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// Product tile shared by the buyer Home and Shop screens.
class BuyerProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const BuyerProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final discount = _num(product['discount_percent']);
    final price = _num(product['price']);
    final effective = product['effective_price'] != null ? _num(product['effective_price']) : price;
    final hasDiscount = discount > 0 || effective < price;
    final stock = _num(product['stock']).toInt();

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product['id'])),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.bc.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: context.bc.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.bc.subtle,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    child: product['image_url'] != null
                        ? NetImage(
                            product['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const _NoImage(),
                          )
                        : const _NoImage(),
                  ),
                ),
                if (stock <= 0)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'OUT OF STOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (hasDiscount)
                  Positioned(
                    left: 0,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF002b4d),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        discount > 0
                            ? '-${discount.toStringAsFixed(0)}%'
                            : '-${((1 - effective / price) * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['title'] ?? '',
                      style: TextStyle(fontSize: 12, color: context.bc.text, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '₱${effective.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFfa4e1c),
                      ),
                    ),
                    if (hasDiscount)
                      Text(
                        '₱${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                          color: context.bc.muted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      stock <= 0
                          ? 'Out of stock'
                          : stock <= 5
                              ? 'Only $stock left!'
                              : '$stock in stock',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: stock <= 5 ? FontWeight.w700 : FontWeight.normal,
                        color: stock <= 0
                            ? const Color(0xFFC62828)
                            : stock <= 5
                                ? const Color(0xFFEF6C00)
                                : context.bc.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.image_not_supported, size: 40, color: context.bc.muted),
    );
  }
}
