import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/buyer_product_card.dart';
import '../../widgets/live_refresh.dart';
import '../../widgets/net_image.dart';
import 'chat_screen.dart';
import 'checkout_screen.dart';
import 'store_screen.dart';

/// The website's product page (products/show): photos, price (sale, flash sale, coming flash sale),
/// options by group, quantity within stock and the buyer's limit, store vouchers, Add to Cart /
/// Buy Now, the seller, details, description, ratings and reviews, and related products.
class ProductDetailScreen extends StatefulWidget {
  final String? slug;
  final int? productId;

  const ProductDetailScreen({super.key, this.slug, this.productId})
      : assert(slug != null || productId != null);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with LiveRefresh {
  Map<String, dynamic>? p;
  bool loading = true;
  String? error;
  int quantity = 1;
  List<String?> chosen = [];
  int image = 0;
  bool busy = false;
  List<dynamic> reviews = [];
  int reviewPage = 1;
  int reviewLast = 1;
  Timer? ticker;

  String get _key => widget.slug ?? '${widget.productId}';

  @override
  void initState() {
    super.initState();
    _load();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && p?['flash'] != null) setState(() {});
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Future<void> onLiveRefresh() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    final r = await BuyerApi.product(_key);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (!r.ok) {
        error = r.status == 404
            ? 'This product is no longer available.'
            : r.message;
        return;
      }
      error = null;
      final first = p == null;
      p = Map<String, dynamic>.from(r.body['product']);
      if (first) {
        chosen =
            List<String?>.filled((p!['variation_groups'] as List).length, null);
        reviews = List.of(p!['reviews']['data']);
        reviewLast = p!['reviews']['meta']['last_page'];
      }
      final max = asNum(p!['max_quantity']).toInt();
      if (quantity > max) quantity = max;
    });
  }

  Future<void> _moreReviews() async {
    final r = await BuyerApi.product('$_key?reviews_page=${reviewPage + 1}');
    if (!mounted || !r.ok) return;
    setState(() {
      reviewPage++;
      reviews.addAll(r.body['product']['reviews']['data']);
    });
  }

  /// The option matching every chosen part (e.g. "Natural / M").
  Map<String, dynamic>? get variation {
    final list = (p?['variations'] as List?) ?? [];
    if (list.isEmpty || chosen.any((c) => c == null)) return null;
    for (final v in list) {
      final parts = List<String>.from(v['parts']);
      if (parts.length == chosen.length &&
          List.generate(parts.length, (i) => parts[i] == chosen[i])
              .every((x) => x)) {
        return Map<String, dynamic>.from(v);
      }
    }
    return null;
  }

  bool get hasOptions => ((p?['variations'] as List?) ?? []).isNotEmpty;

  int get maxQty {
    final v = variation;
    final stock =
        v != null ? asNum(v['stock']).toInt() : asNum(p!['stock']).toInt();
    final allowance =
        p!['allowance'] != null ? asNum(p!['allowance']).toInt() : 1 << 30;
    return [stock, allowance].reduce((a, b) => a < b ? a : b).clamp(1, 99999);
  }

  Future<void> _buy({required bool buyNow}) async {
    setState(() => busy = true);
    final r = await BuyerApi.addToCart(p!['id'],
        quantity: quantity, variationId: variation?['id'], buyNow: buyNow);
    if (!mounted) return;
    setState(() => busy = false);
    if (r.ok && buyNow) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const CheckoutScreen(buyNow: true)));
      return;
    }
    showResult(context, r);
    if (!r.ok) _load(silent: true);
  }

  Future<void> _toggleWish() async {
    final r = await BuyerApi.toggleWish(p!['id'], on: p!['wished'] != true);
    if (!mounted) return;
    if (r.ok) setState(() => p!['wished'] = r.body['wished']);
    showResult(context, r);
  }

  Future<void> _claim(Map v) async {
    final r = await BuyerApi.claimVoucher(v['id']);
    if (!mounted) return;
    showResult(context, r);
    if (r.ok) setState(() => v['claimed'] = true);
  }

  Future<void> _remind() async {
    final r = await BuyerApi.remindFlashSale(p!['upcoming']['id']);
    if (!mounted) return;
    showResult(context, r);
    if (r.ok) setState(() => p!['upcoming']['reminded'] = r.body['reminded']);
  }

  Future<void> _chat() async {
    final seller = p!['seller'];
    final r = await BuyerApi.startChat(seller['id'], productId: p!['id']);
    if (!mounted) return;
    if (!r.ok) return showResult(context, r);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatScreen(
                type: r.body['type'],
                id: r.body['id'],
                title: seller['name'])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(
        title: Text(p?['title'] ?? 'Product',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16)),
        actions: [
          if (p != null)
            IconButton(
              icon: Icon(
                  p!['wished'] == true ? Icons.favorite : Icons.favorite_border,
                  color: p!['wished'] == true ? kOrange : null),
              tooltip: p!['wished'] == true
                  ? 'Remove from wishlist'
                  : 'Add to wishlist',
              onPressed: _toggleWish,
            ),
        ],
      ),
      body: LoadState(
        loading: loading && p == null,
        error: p == null ? error : null,
        onRetry: _load,
        child: p == null ? const SizedBox() : _body(),
      ),
      bottomNavigationBar: p == null ? null : _buyBar(),
    );
  }

  Widget _body() {
    final images = List<Map<String, dynamic>>.from(p!['images']);
    final v = variation;
    final price = v != null ? v['price'] : p!['price'];
    final flash = p!['flash'];
    final upcoming = p!['upcoming'];

    return RefreshIndicator(
      color: kOrange,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        // Photos
        Container(
          color: Colors.white,
          child: Column(children: [
            AspectRatio(
              aspectRatio: 1,
              child: images.isEmpty
                  ? Icon(Icons.image_not_supported,
                      size: 64, color: context.bc.muted)
                  : PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => image = i),
                      itemBuilder: (_, i) =>
                          NetImage(images[i]['url'], fit: BoxFit.contain),
                    ),
            ),
            if (images.length > 1)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('${image + 1} / ${images.length}',
                    style: TextStyle(color: context.bc.muted, fontSize: 12)),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (asMap(p!['details'])['Category'] != null)
              Text(asMap(p!['details'])['Category'],
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B90AA))),
            Text(p!['title'],
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: context.bc.text)),
            const SizedBox(height: 6),
            Row(children: [
              if (p!['rating'] != null) ...[
                Stars(asNum(p!['rating'])),
                Text(
                    ' ${asNum(p!['rating']).toStringAsFixed(1)} (${p!['rating_count']})',
                    style: TextStyle(fontSize: 12, color: context.bc.muted)),
                Text('  ·  ', style: TextStyle(color: context.bc.muted)),
              ],
              Text('${p!['sold']} sold',
                  style: TextStyle(fontSize: 12, color: context.bc.muted)),
            ]),
            const SizedBox(height: 12),

            // Price
            SectionCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (flash != null) _flashBanner(flash),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(
                        v == null && p!['price_range'] != null
                            ? '${peso(p!['price_range'][0])} – ${peso(p!['price_range'][1])}'
                            : peso(price),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: kOrange),
                      ),
                      if (p!['original_price'] != null &&
                          (v == null && p!['price_range'] == null)) ...[
                        const SizedBox(width: 8),
                        Text(peso(p!['original_price']),
                            style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: context.bc.muted)),
                        const SizedBox(width: 6),
                        Text('-${p!['discount_percent']}%',
                            style: const TextStyle(
                                color: Color(0xFFE0431A),
                                fontWeight: FontWeight.w700)),
                      ],
                    ]),
                    if (p!['sale_ends_at'] != null && flash == null)
                      Text('Sale ends ${formatDateTime(p!['sale_ends_at'])}',
                          style:
                              TextStyle(fontSize: 12, color: context.bc.muted)),
                    if (upcoming != null) _upcomingBanner(upcoming),
                  ]),
            ),

            // Options + quantity
            if (hasOptions) _options(),
            SectionCard(
              child: Row(children: [
                Text('Quantity',
                    style: TextStyle(
                        color: context.bc.text, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                    onPressed:
                        quantity > 1 ? () => setState(() => quantity--) : null,
                    icon: const Icon(Icons.remove)),
                Text('$quantity',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(
                    onPressed: quantity < maxQty
                        ? () => setState(() => quantity++)
                        : null,
                    icon: const Icon(Icons.add)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${v != null ? asNum(v['stock']).toInt() : asNum(p!['stock']).toInt()} available',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.bc.muted),
                  ),
                ),
              ]),
            ),
            Builder(builder: (_) {
              final n = v != null ? asNum(v['stock']).toInt() : asNum(p!['stock']).toInt();
              final at = asNum(p!['low_stock_at']).toInt();
              return n > 0 && at > 0 && n <= at
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Only $n left · order soon', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                    )
                  : const SizedBox.shrink();
            }),
            if (p!['purchase_limit'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Limit ${p!['purchase_limit']} per buyer${p!['allowance'] != null ? ' — you can buy ${p!['allowance']} more.' : '.'}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
              ),

            // Store vouchers
            if ((p!['vouchers'] as List).isNotEmpty)
              SectionCard(
                title: 'Store vouchers',
                child: Column(children: [
                  for (final vc in p!['vouchers'])
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.confirmation_number_outlined,
                          color: kOrange),
                      title: Text('${vc['code']} · ${vc['label']}'),
                      subtitle: Text('Min. spend ${peso(vc['min_spend'])}'),
                      trailing: vc['claimed'] == true
                          ? const Text('Claimed',
                              style: TextStyle(
                                  color: Color(0xFF15803D),
                                  fontWeight: FontWeight.w600))
                          : TextButton(
                              onPressed: () => _claim(vc),
                              child: const Text('Claim')),
                    ),
                ]),
              ),

            // Seller
            if (p!['seller'] != null)
              SectionCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFF4F7FA),
                          child: Text(
                              (p!['seller']['name'] as String)
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(color: Color(0xFF4A7A94))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sold by',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B90AA))),
                                Text(p!['seller']['name'],
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: context.bc.text)),
                              ]),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                          onPressed: _chat,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: kOrange,
                              side: const BorderSide(color: kOrange)),
                          child: const Text('Chat'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(
                            child: OutlinedButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => StoreScreen(
                                      sellerId: p!['seller']['id']))),
                          child: const Text('View store'),
                        )),
                      ]),
                    ]),
              ),

            // Details, specs, description
            if (asMap(p!['details']).isNotEmpty ||
                asMap(p!['specs']).isNotEmpty)
              SectionCard(
                title: 'Product details',
                child: Column(children: [
                  for (final e in {
                    ...asMap(p!['details']),
                    ...asMap(p!['specs'])
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 110,
                                child: Text('${e.key}',
                                    style: TextStyle(
                                        color: context.bc.muted,
                                        fontSize: 13))),
                            Expanded(
                                child: Text('${e.value}',
                                    style: TextStyle(
                                        color: context.bc.text, fontSize: 13))),
                          ]),
                    ),
                ]),
              ),
            if ((p!['description'] ?? '').toString().isNotEmpty)
              SectionCard(
                  title: 'Description',
                  child: Text(p!['description'],
                      style: TextStyle(color: context.bc.text, height: 1.4))),

            _reviews(),

            if ((p!['related'] as List).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('You may also like',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.bc.text)),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.56,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final r in p!['related'])
                    BuyerProductCard(product: Map<String, dynamic>.from(r))
                ],
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _flashBanner(Map flash) {
    final ends = DateTime.tryParse(flash['ends_at'] ?? '')?.toLocal();
    final left = ends?.difference(DateTime.now());
    String two(int n) => n.toString().padLeft(2, '0');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        const Icon(Icons.flash_on, color: Colors.white, size: 18),
        const Text(' FLASH SALE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (left != null && !left.isNegative)
          Text(
              'Ends in ${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        Text('  ·  ${flash['remaining']} of ${flash['quantity']} left',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    );
  }

  Widget _upcomingBanner(Map up) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Expanded(
          child: Text(
              'Flash sale ${formatDateTime(up['starts_at'])}: ${peso(up['price'])} (${up['quantity']} units)',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF9A3412))),
        ),
        TextButton(
            onPressed: _remind,
            child: Text(up['reminded'] == true ? 'Reminder set' : 'Remind me')),
      ]),
    );
  }

  Widget _options() {
    final groups = List<List<dynamic>>.from(p!['variation_groups']);
    final labels = List<String>.from(p!['variation_labels']);
    final v = variation;
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var g = 0; g < groups.length; g++) ...[
          Text(labels[g],
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: context.bc.text)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final part in groups[g])
              ChoiceChip(
                label: Text('$part'),
                selected: chosen[g] == part,
                selectedColor: const Color(0xFFFFF1EE),
                onSelected: (_) => setState(() {
                  chosen[g] = chosen[g] == part ? null : '$part';
                  quantity = 1;
                }),
              ),
          ]),
          const SizedBox(height: 10),
        ],
        if (v != null)
          Text(
              asNum(v['stock']) <= 0
                  ? '"${v['name']}" is out of stock.'
                  : '${v['name']} · ${peso(v['price'])}',
              style: TextStyle(
                  color: asNum(v['stock']) <= 0
                      ? const Color(0xFFDC2626)
                      : context.bc.muted,
                  fontSize: 12.5)),
      ]),
    );
  }

  Widget _reviews() {
    final breakdown = asMap(p!['rating_breakdown']);
    final count = asNum(p!['rating_count']).toInt();
    return SectionCard(
      title: 'Ratings & reviews',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (count == 0)
          Text('No reviews yet.', style: TextStyle(color: context.bc.muted))
        else ...[
          Row(children: [
            Text(asNum(p!['rating']).toStringAsFixed(1),
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stars(asNum(p!['rating'])),
              Text('$count rating${count == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: context.bc.muted)),
            ]),
          ]),
          const SizedBox(height: 8),
          for (final s in ['5', '4', '3', '2', '1'])
            Row(children: [
              SizedBox(
                  width: 22,
                  child: Text('$s★', style: const TextStyle(fontSize: 12))),
              Expanded(
                child: LinearProgressIndicator(
                  value: count == 0 ? 0 : asNum(breakdown[s]) / count,
                  color: const Color(0xFFF59E0B),
                  backgroundColor: context.bc.subtle,
                ),
              ),
              SizedBox(
                  width: 30,
                  child: Text(' ${asNum(breakdown[s]).toInt()}',
                      style: const TextStyle(fontSize: 12))),
            ]),
          const Divider(),
          for (final r in reviews) _review(Map<String, dynamic>.from(r)),
          if (reviewPage < reviewLast)
            TextButton(
                onPressed: _moreReviews, child: const Text('More reviews')),
        ],
      ]),
    );
  }

  Widget _review(Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(r['user'] ?? 'Buyer',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Stars(asNum(r['rating']), size: 12),
          const Spacer(),
          Text(formatDate(r['created_at']),
              style: TextStyle(fontSize: 11, color: context.bc.muted)),
        ]),
        if ((r['comment'] ?? '').toString().isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(r['comment'])),
        if ((r['photos'] as List).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, children: [
              for (final ph in r['photos'])
                ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child:
                        NetImage(ph, width: 64, height: 64, fit: BoxFit.cover)),
            ]),
          ),
        if (r['seller_reply'] != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: context.bc.subtle,
                borderRadius: BorderRadius.circular(6)),
            child: Text('Seller: ${r['seller_reply']}',
                style: const TextStyle(fontSize: 12.5)),
          ),
      ]),
    );
  }

  Widget _buyBar() {
    final canBuy = p!['can_buy'] == true;
    final v = variation;
    final optionMissing = hasOptions && v == null;
    final optionOut = v != null && asNum(v['stock']) <= 0;
    final label = p!['on_vacation'] == true
        ? 'Store on vacation'
        : (!canBuy ? 'Sold out' : null);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
            color: context.bc.surface,
            border: Border(top: BorderSide(color: context.bc.border))),
        child: label != null
            ? SizedBox(
                height: 46,
                child: Center(
                    child: Text(label,
                        style: TextStyle(
                            color: context.bc.muted,
                            fontWeight: FontWeight.w600))))
            : Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy || optionOut
                        ? null
                        : () => optionMissing
                            ? showError(context, 'Please select a variation.')
                            : _buy(buyNow: false),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to Cart'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: kOrange,
                        side: const BorderSide(color: kOrange),
                        minimumSize: const Size.fromHeight(46)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy || optionOut
                        ? null
                        : () => optionMissing
                            ? showError(context, 'Please select a variation.')
                            : _buy(buyNow: true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46)),
                    child: const Text('Buy Now',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
      ),
    );
  }
}
