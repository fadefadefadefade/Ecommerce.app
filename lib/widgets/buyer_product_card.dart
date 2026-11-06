import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/buyer/product_detail_screen.dart';
import '../services/buyer_api.dart';
import '../theme/app_theme.dart';
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
    // Taking it out of the wishlist: ask first (adding needs no question).
    if (_wished && !await confirmRemoval(context, title: 'Remove from wishlist?', message: '"${p['title']}" will be taken out of your wishlist.')) return;
    if (!mounted) return;
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

    final c = context.bc;
    return Container(
      decoration: cardBox(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: _open,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // The photo on a soft ground, inset inside the card, with the -% tag and the heart.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      color: c.subtle,
                      child: Opacity(
                        opacity: outOfStock ? 0.5 : 1,
                        // The small WebP copy for cards when the server has one (faster lists), else the full picture.
                        child: (p['thumb_url'] ?? p['image_url']) != null
                            ? NetImage(p['thumb_url'] ?? p['image_url'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _NoImage())
                            : const _NoImage(),
                      ),
                    ),
                  ),
                  if (discount > 0 && !outOfStock)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(20)),
                        child: Text('-$discount%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFBA1A1A))),
                      ),
                    ),
                  if (outOfStock)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xCC1E1B17), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Sold out', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 1,
                      shadowColor: const Color(0x332A1A10),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _toggleWish,
                        child: Tooltip(
                          message: _wished ? 'Remove from wishlist' : 'Add to wishlist',
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(_wished ? Icons.favorite : Icons.favorite_border, size: 17, color: _wished ? kOrange : const Color(0xFF5C4039)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (rating != null || sold > 0)
                    Row(children: [
                      if (rating != null) ...[
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                        Text(' ${rating.toStringAsFixed(1)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      ],
                      if (rating != null && sold > 0) Text(' · ', style: TextStyle(fontSize: 11, color: c.muted)),
                      if (sold > 0) Flexible(child: Text('$sold sold', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.muted))),
                    ]),
                  const SizedBox(height: 2),
                  Text(p['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text, height: 1.3)),
                  // One meta line: "Only N left" when few are left (at or below the product's low-stock level), else the category.
                  if (p['low_stock'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Only ${p['stock']} left', maxLines: 1, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                    )
                  else if (p['category'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(p['category'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Alvy.slate)),
                    ),
                  const Spacer(),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (p['original_price'] != null && range == null)
                          Text(peso(p['original_price']),
                              style: TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: c.muted)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            range != null ? '${pesoWhole(range[0])} – ${pesoWhole(range[1])}' : peso(p['price']),
                            style: GoogleFonts.plusJakartaSans(fontSize: range != null ? 14 : 17, fontWeight: FontWeight.w700, color: kOrange),
                          ),
                        ),
                      ]),
                    ),
                    if (onVacation)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(20)),
                        child: const Text('On vacation', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                      )
                    else if (!outOfStock)
                      // The round orange add button.
                      Material(
                        color: kOrange,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _busy ? null : _addToCart,
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: _busy
                                ? const Padding(padding: EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.add, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) => Center(child: Icon(Icons.image_not_supported, size: 40, color: context.bc.muted));
}
