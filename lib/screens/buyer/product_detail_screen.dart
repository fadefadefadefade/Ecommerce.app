import '../../widgets/responsive.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final gallery = PageController();
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
    gallery.dispose();
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
    // Taking it out of the wishlist: ask first (adding needs no question).
    if (p!['wished'] == true &&
        !await confirmRemoval(context, title: 'Remove from wishlist?', message: '"${p!['title']}" will be taken out of your wishlist.')) {
      return;
    }
    if (!mounted) return;
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
          if (p != null && Responsive.isWide(context))
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
      // Tablet: the buttons sit under the quantity, like the website.
      bottomNavigationBar: p == null || Responsive.isWide(context) ? null : _buyBar(),
    );
  }

  Widget _body() {
    final images = List<Map<String, dynamic>>.from(p!['images']);
    final v = variation;
    final price = v != null ? v['price'] : p!['price'];
    final flash = p!['flash'];
    final upcoming = p!['upcoming'];
    final wide = Responsive.isWide(context);   // tablet: the website's product page

    // Photos, then the seller's video: swipe, or tap the arrows, like the website's gallery.
    final hasVideo = p!['video_url'] != null;
    final slides = images.length + (hasVideo ? 1 : 0);
    Widget arrow(IconData icon, int step) => Material(
          color: Colors.white.withValues(alpha: .92),
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => gallery.animateToPage((image + step + slides) % slides,
                duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
            child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 22, color: Alvy.navy)),
          ),
        );
    final galleryBox = Container(
          color: context.bc.surface,
          child: AspectRatio(
            aspectRatio: 1,
            child: slides == 0
                ? Icon(Icons.image_not_supported, size: 64, color: context.bc.muted)
                : Stack(children: [
                    PageView.builder(
                      controller: gallery,
                      itemCount: slides,
                      onPageChanged: (i) => setState(() => image = i),
                      itemBuilder: (_, i) => i < images.length
                          ? NetImage(images[i]['url'], fit: BoxFit.contain)
                          // The video slide: the cover with a play button; it plays in the phone's video player.
                          : GestureDetector(
                              onTap: () => launchUrl(Uri.parse('${p!['video_url']}'), mode: LaunchMode.externalApplication),
                              child: Container(
                                color: Colors.black,
                                child: Stack(alignment: Alignment.center, children: [
                                  if (images.isNotEmpty)
                                    Positioned.fill(child: Opacity(opacity: .45, child: NetImage(images.first['url'], fit: BoxFit.cover))),
                                  Column(mainAxisSize: MainAxisSize.min, children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle),
                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text('Tap to play the product video',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  ]),
                                ]),
                              ),
                            ),
                    ),
                    if (slides > 1) ...[
                      Positioned(left: 8, top: 0, bottom: 0, child: Center(child: arrow(Icons.chevron_left, -1))),
                      Positioned(right: 8, top: 0, bottom: 0, child: Center(child: arrow(Icons.chevron_right, 1))),
                      // Dots: the current slide is a long orange pill.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (var i = 0; i < slides && slides <= 10; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == image ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i == image ? kOrange : Colors.white.withValues(alpha: .85),
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
                              ),
                            ),
                        ]),
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0x991E1B17), borderRadius: BorderRadius.circular(99)),
                          child: Text(hasVideo && image == images.length ? 'Video · ${image + 1} / $slides' : '${image + 1} / $slides',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                    // The wishlist heart on the photo (the design's white round button).
                    if (!wide)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Material(
                          color: Alvy.surface,
                          shape: const CircleBorder(),
                          elevation: 2,
                          shadowColor: const Color(0x332A1A10),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _toggleWish,
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: Icon(p!['wished'] == true ? Icons.favorite : Icons.favorite_border,
                                  size: 21, color: p!['wished'] == true ? kOrange : Alvy.navy),
                            ),
                          ),
                        ),
                      ),
                  ]),
          ),
    );

    final stockNow = v != null ? asNum(v['stock']).toInt() : asNum(p!['stock']).toInt();
    // The design's product header: store (with category) and the rating chip, the name, the price with the
    // struck-through price and "% OFF", then a green "In stock" strip. Phones: one white card; tablets: on the page.
    final header = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        if (p!['seller'] != null) ...[
          Flexible(
            child: Text('${p!['seller']['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Alvy.slate)),
          ),
          const SizedBox(width: 4),
          Icon(Icons.verified_outlined, size: 15, color: Alvy.slate),
        ],
        if (asMap(p!['details'])['Category'] != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(6)),
              child: Text('${asMap(p!['details'])['Category']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.bc.textSecondary)),
            ),
          ),
        ],
        const Spacer(),
        if (p!['rating'] != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Alvy.warnSoft, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_border_rounded, size: 15, color: Color(0xFFF59E0B)),
              Text(' ${asNum(p!['rating']).toStringAsFixed(1)} (${p!['rating_count']})',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.bc.text)),
            ]),
          ),
      ]),
      const SizedBox(height: 10),
      Text(p!['title'], style: Alvy.display(size: wide ? 30 : 26, color: context.bc.text, weight: FontWeight.w600)),
      const SizedBox(height: 10),
      if (flash != null) _flashBanner(flash),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 4, children: [
        Text(
          v == null && p!['price_range'] != null ? '${peso(p!['price_range'][0])} – ${peso(p!['price_range'][1])}' : peso(price),
          style: Alvy.display(size: wide ? 32 : 26, color: kOrange, weight: FontWeight.w700),
        ),
        if (p!['original_price'] != null && (v == null && p!['price_range'] == null)) ...[
          Text(peso(p!['original_price']), style: TextStyle(fontSize: 16, decoration: TextDecoration.lineThrough, color: context.bc.muted)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Alvy.dangerSoft, borderRadius: BorderRadius.circular(20)),
            child: Text('${p!['discount_percent']}% OFF',
                style: TextStyle(fontSize: 11.5, color: Alvy.dangerText, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
      if (p!['sale_ends_at'] != null && flash == null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('Sale ends ${formatDateTime(p!['sale_ends_at'])}', style: TextStyle(fontSize: 12, color: context.bc.muted)),
        ),
      if (upcoming != null) _upcomingBanner(upcoming),
      const SizedBox(height: 12),
      // The stock strip: green when in stock, red when sold out.
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: stockNow > 0 ? Alvy.successSoft : Alvy.dangerSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(stockNow > 0 ? Icons.bolt_rounded : Icons.block, size: 17, color: stockNow > 0 ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stockNow > 0 ? 'In stock · $stockNow available · ${p!['sold']} sold' : 'Out of stock · ${p!['sold']} sold',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: stockNow > 0 ? const Color(0xFF15803D) : Alvy.dangerText),
            ),
          ),
        ]),
      ),
    ]);

    final info = Padding(
          padding: EdgeInsets.fromLTRB(16, wide ? 12 : 4, 16, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (wide) ...[header, const Divider(height: 28)] else SectionCard(padding: const EdgeInsets.all(18), child: header),

            // Options + quantity
            if (hasOptions) _options(),
            // Tablet: the website's quantity box with Wishlist beside it, then Add to cart / Buy now right here.
            if (wide) ...[
              Text('Quantity', style: TextStyle(color: context.bc.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [
                QuantityStepper(value: quantity, max: maxQty, height: 46, onChanged: (n) => setState(() => quantity = n)),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _toggleWish,
                  icon: Icon(p!['wished'] == true ? Icons.favorite : Icons.favorite_border, size: 18, color: p!['wished'] == true ? kOrange : null),
                  label: const Text('Wishlist'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: context.bc.text),
                ),
              ]),
              const SizedBox(height: 14),
              _buyButtons(),
              const SizedBox(height: 14),
            ] else
            SectionCard(
              child: Row(children: [
                Text('Quantity',
                    style: TextStyle(
                        color: context.bc.text, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${v != null ? asNum(v['stock']).toInt() : asNum(p!['stock']).toInt()} available',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.bc.muted),
                  ),
                ),
                // Type the amount for large orders, or tap − / +.
                QuantityStepper(value: quantity, max: maxQty, onChanged: (n) => setState(() => quantity = n)),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Alvy.orangeSoft,
                      child: p!['seller']['logo_url'] != null
                          ? ClipOval(child: NetImage(p!['seller']['logo_url'], width: 48, height: 48, fit: BoxFit.cover))
                          : Text((p!['seller']['name'] as String).substring(0, 1).toUpperCase(), style: Alvy.display(size: 19, color: kOrange)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                            child: Text(p!['seller']['name'], maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: Alvy.display(size: 17, color: context.bc.text, weight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.verified_outlined, size: 16, color: Alvy.slate),
                        ]),
                        Text('Seller', style: TextStyle(fontSize: 12, color: context.bc.textSecondary)),
                      ]),
                    ),
                    if (asNum(p!['rating_count']) > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(asNum(p!['rating']).toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _chat,
                        style: FilledButton.styleFrom(backgroundColor: context.bc.subtle, foregroundColor: context.bc.text, minimumSize: const Size.fromHeight(44)),
                        icon: Icon(Icons.chat_outlined, size: 18, color: Alvy.slate),
                        label: const FittedBox(child: Text('Chat with Shop', maxLines: 1, style: TextStyle(fontWeight: FontWeight.w600))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(sellerId: p!['seller']['id']))),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: context.bc.surface,
                          minimumSize: const Size.fromHeight(44),
                          side: BorderSide(color: context.bc.border, width: 1.5),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('View Store', style: TextStyle(color: context.bc.text, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 16, color: context.bc.text),
                        ]),
                      ),
                    ),
                  ]),
                ]),
              ),

            // Details, specs, description: one card of icon rows, like the design's "Material & Craft" card.
            if (asMap(p!['details']).isNotEmpty || asMap(p!['specs']).isNotEmpty || (p!['description'] ?? '').toString().isNotEmpty)
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  if (asMap(p!['details']).isNotEmpty || asMap(p!['specs']).isNotEmpty)
                    _infoRow(
                      Icons.inventory_2_outlined,
                      'Product Details',
                      Column(children: [
                        for (final e in {...asMap(p!['details']), ...asMap(p!['specs'])}.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              SizedBox(width: 104, child: Text('${e.key}', style: TextStyle(color: context.bc.textSecondary, fontSize: 13))),
                              Expanded(child: Text('${e.value}', style: TextStyle(color: context.bc.text, fontSize: 13, fontWeight: FontWeight.w600))),
                            ]),
                          ),
                      ]),
                    ),
                  if ((asMap(p!['details']).isNotEmpty || asMap(p!['specs']).isNotEmpty) && (p!['description'] ?? '').toString().isNotEmpty)
                    Divider(height: 1, color: context.bc.border),
                  if ((p!['description'] ?? '').toString().isNotEmpty)
                    _infoRow(Icons.notes_rounded, 'Description', Text(p!['description'], style: TextStyle(color: context.bc.text, height: 1.45, fontSize: 13.5))),
                ]),
              ),

            _reviews(),

            if ((p!['related'] as List).isNotEmpty) ...[
              const SectionTitle('You may also like', padding: EdgeInsets.fromLTRB(0, 12, 0, 12)),
              GridView.extent(
                maxCrossAxisExtent: Responsive.productTileMaxFor(context),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final r in p!['related'])
                    BuyerProductCard(product: Map<String, dynamic>.from(r))
                ],
              ),
            ],
          ]),
        );

    return RefreshIndicator(
      color: kOrange,
      onRefresh: _load,
      // Tablet: the website's product page, photos on the left and the details on the right.
      child: Responsive.isWide(context)
          ? ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              // The website's breadcrumb: Home / Category / Product.
              WebWidth(
                child: Container(
                  width: double.infinity,   // on the left, like the website
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text.rich(
                    TextSpan(style: TextStyle(fontSize: 13, color: context.bc.muted), children: [
                      const TextSpan(text: 'Home  /  '),
                      if (asMap(p!['details'])['Category'] != null) TextSpan(text: '${asMap(p!['details'])['Category']}  /  '),
                      TextSpan(text: '${p!['title']}', style: TextStyle(color: context.bc.text, fontWeight: FontWeight.w600)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              WebWidth(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width.clamp(0, Responsive.maxContent) * 0.42).toDouble(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: galleryBox),
                    ),
                  ),
                  Expanded(child: info),
                ]),
              ),
            ])
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              galleryBox,
              // Thumbnails under the photo (the design's gallery strip).
              if (slides > 1)
                Container(
                  color: context.bc.surface,
                  height: 76,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    itemCount: slides,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => gallery.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: i == image ? kOrange : context.bc.border, width: i == image ? 2 : 1),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: i < images.length
                            ? NetImage(images[i]['url'], fit: BoxFit.cover)
                            : Container(color: Colors.black87, child: const Icon(Icons.play_circle_fill, color: Colors.white)),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
              info,
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
          BoxDecoration(gradient: Alvy.gradient, borderRadius: BorderRadius.circular(12)),
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
          color: Alvy.warnSoft,
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Text(
              'Flash sale ${formatDateTime(up['starts_at'])}: ${peso(up['price'])} (${up['quantity']} units)',
              style: TextStyle(fontSize: 12.5, color: Alvy.warnText)),
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
          Text.rich(TextSpan(children: [
            TextSpan(text: '${labels[g]}: ', style: TextStyle(fontWeight: FontWeight.w700, color: context.bc.text)),
            TextSpan(text: chosen[g] ?? 'Choose one', style: TextStyle(fontWeight: FontWeight.w500, color: context.bc.textSecondary)),
          ])),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final part in groups[g])
              ChoiceChip(
                label: Text('$part'),
                selected: chosen[g] == part,
                showCheckmark: false,
                selectedColor: kOrange,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: chosen[g] == part ? Colors.white : context.bc.text),
                backgroundColor: context.bc.subtle,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

  /// One block of the info card: a soft icon disc, the title, then the body under it.
  Widget _infoRow(IconData icon, String title, Widget body) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: Alvy.slateSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: Alvy.slate),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Alvy.display(size: 16.5, color: context.bc.text, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              body,
            ]),
          ),
        ]),
      );

  Widget _reviews() {
    final breakdown = asMap(p!['rating_breakdown']);
    final count = asNum(p!['rating_count']).toInt();
    return SectionCard(
      title: 'Customer Reviews',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (count == 0)
          Text('No reviews yet.', style: TextStyle(color: context.bc.muted))
        else ...[
          Row(children: [
            Text(asNum(p!['rating']).toStringAsFixed(1),
                style: Alvy.display(size: 32, color: context.bc.text)),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Alvy.subtle, borderRadius: BorderRadius.circular(12)),
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
              child: Text('"${r['comment']}"', style: TextStyle(color: context.bc.text, height: 1.45))),
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
                color: context.bc.surface,
                borderRadius: BorderRadius.circular(10)),
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
            color: context.bc.surface,
            boxShadow: const [BoxShadow(color: Color(0x142A1A10), blurRadius: 16, offset: Offset(0, -3))]),
        child: Row(children: [
          // The total for the quantity chosen (the design's "Total ₱88.00").
          if (label == null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Total', style: TextStyle(fontSize: 11.5, color: context.bc.textSecondary)),
                Text(
                  v == null && p!['price_range'] != null
                      ? 'from ${pesoWhole(p!['price_range'][0])}'
                      : peso(asNum(v != null ? v['price'] : p!['price']) * quantity),
                  style: Alvy.display(size: 19, color: kOrange, weight: FontWeight.w700),
                ),
              ]),
            ),
          Expanded(child: _buyButtons(label, optionMissing, optionOut)),
        ]),
      ),
    );
  }

  /// Add to Cart / Buy Now (or why it can't be bought): the phone's bottom bar, the tablet's page (website).
  Widget _buyButtons([String? label, bool? missing, bool? out]) {
    final v = variation;
    final optionMissing = missing ?? (hasOptions && v == null);
    final optionOut = out ?? (v != null && asNum(v['stock']) <= 0);
    label ??= p!['on_vacation'] == true ? 'Store on vacation' : (p!['can_buy'] != true ? 'Sold out' : null);
    return Container(
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
                    icon: const Icon(Icons.add_shopping_cart, size: 20),
                    label: Text(Responsive.isWide(context) ? 'Add to Cart' : 'Cart'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
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
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Buy Now', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 18),
                    ]),
                  ),
                ),
              ]),
    );
  }
}
