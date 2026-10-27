import 'package:flutter/material.dart';

import '../screens/buyer/product_detail_screen.dart';
import '../services/buyer_api.dart';
import '../theme/buyer_colors.dart';
import 'buyer_kit.dart';
import 'net_image.dart';

/// The website's product card (components/product-card): price (or option range) after the sale or
/// flash sale, the -% tag, rating and units sold, the wishlist heart, and add to cart.
class BuyerProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onCartChanged;

  const BuyerProductCard({super.key, required this.product, this.onCartChanged});

  @override
  State<BuyerProductCard> createState() => _BuyerProductCardState();
}

class _BuyerProductCardState extends State<BuyerProductCard> {
  late bool _wished = widget.product['wished'] == true;
  bool _busy = false;

  Map<String, dynamic> get p => widget.product;

  void _open() => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: p['slug'] ?? '${p['id']}')));

  Future<void> _toggleWish() async {
    final next = !_wished;
    setState(() => _wished = next);
    final r = await BuyerApi.toggleWish(p['id'], on: next);
    if (!mounted) return;
    if (!r.ok) setState(() => _wished = !next);
    showResult(context, r);
  }

  Future<void> _addToCart() async {
    setState(() => _busy = true);
    final r = await BuyerApi.addToCart(p['id']);
    if (!mounted) return;
    setState(() => _busy = false);
    // A product with options needs one chosen: open its page, like the website asks.
    if (!r.ok && r.message == 'Please select a variation.') {
      _open();
      return;
    }
    showResult(context, r);
    if (r.ok) widget.onCartChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final range = p['price_range'] as List?;
    final discount = asNum(p['discount_percent']).toInt();
    final outOfStock = p['out_of_stock'] == true;
    final onVacation = p['on_vacation'] == true;
    final rating = p['rating'] != null ? asNum(p['rating']) : null;
    final sold = asNum(p['sold']).toInt();

    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: context.bc.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.bc.border),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AspectRatio(
              aspectRatio: 1,
              child: Opacity(
                opacity: outOfStock ? 0.5 : 1,
                child: p['image_url'] != null
                    ? NetImage(p['image_url'], fit: BoxFit.contain, errorBuilder: (_, __, ___) => const _NoImage())
                    : const _NoImage(),
              ),
            ),
            if (discount > 0 && !outOfStock)
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFA4E1C), borderRadius: BorderRadius.circular(4)),
                  child: Text('-$discount%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            Positioned(
              right: 4,
              top: 4,
              child: Material(
                color: Colors.white.withValues(alpha: 0.9),
                shape: const CircleBorder(),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(_wished ? Icons.favorite : Icons.favorite_border, size: 18, color: _wished ? kOrange : const Color(0xFF6B90AA)),
                  tooltip: _wished ? 'Remove from wishlist' : 'Add to wishlist',
                  onPressed: _toggleWish,
                ),
              ),
            ),
          ]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (p['category'] != null)
                  Text(p['category'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF6B90AA))),
                Text(p['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.bc.text, height: 1.3)),
                if (rating != null || sold > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      if (rating != null) ...[
                        const Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                        Text(' ${rating.toStringAsFixed(1)}', style: TextStyle(fontSize: 10.5, color: context.bc.muted)),
                      ],
                      if (rating != null && sold > 0) Text(' · ', style: TextStyle(fontSize: 10.5, color: context.bc.muted)),
                      if (sold > 0) Text('$sold sold', style: TextStyle(fontSize: 10.5, color: context.bc.muted)),
                    ]),
                  ),
                // Few left (at or below the product's low-stock level), like the website's card.
                if (p['low_stock'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Only ${p['stock']} left', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                  ),
                const Spacer(),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        range != null ? '${pesoWhole(range[0])} – ${pesoWhole(range[1])}' : peso(p['price']),
                        style: TextStyle(fontSize: range != null ? 13 : 15.5, fontWeight: FontWeight.w800, color: kOrange),
                      ),
                      if (p['original_price'] != null && range == null)
                        Text(peso(p['original_price']),
                            style: TextStyle(fontSize: 10.5, decoration: TextDecoration.lineThrough, color: context.bc.muted)),
                    ]),
                  ),
                  if (onVacation)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(4)),
                      child: const Text('On vacation', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                    )
                  else if (outOfStock)
                    Text('Sold out', style: TextStyle(fontSize: 10.5, color: context.bc.muted))
                  else
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _addToCart,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0xFFFFF1EE),
                          side: const BorderSide(color: Color(0xFFFFD9CC)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _busy
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kOrange))
                            : const Icon(Icons.add_shopping_cart, size: 16, color: kOrange),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) => Center(child: Icon(Icons.image_not_supported, size: 40, color: context.bc.muted));
}
