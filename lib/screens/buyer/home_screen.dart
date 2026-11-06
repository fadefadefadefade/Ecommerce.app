import 'dart:math';

import '../../widgets/responsive.dart';
import '../../widgets/route_watch.dart';
import 'all_categories_screen.dart';
import '../../widgets/web_banner_carousel.dart';
import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';
import '../../theme/app_theme.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/buyer_product_card.dart';
import '../../widgets/live_refresh.dart';
import '../../widgets/net_image.dart';
import 'account/collections_screens.dart' show VoucherCenterScreen, WishlistScreen;
import 'account/notifications_screen.dart';
import 'buyer_main_screen.dart';
import 'chat_screen.dart';
import 'shop_screen.dart';

/// The home page (the design's "Home Marketplace"): search, the photo hero, category tiles and the category
/// rail, quick links, new arrivals and best sellers.
class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> with LiveRefresh, RouteAware {
  @override
  int? get liveTab => BuyerMainScreenState.tabHome;

  @override
  Duration get liveInterval => const Duration(seconds: 30);

  @override
  Future<void> onLiveRefresh() => _load(silent: true);

  final _search = TextEditingController();
  List<dynamic> featured = [];
  List<dynamic> trending = [];
  List<dynamic> categories = [];
  List<dynamic> banners = [];
  // The two category tiles under the banner: picked at random, and again each time the user comes back to Home
  // (from another tab or a page opened on top) — not on the 30-second refresh.
  List<String> _tileSlugs = [];
  BuyerMainScreenState? _shell;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
    final shell = BuyerMainScreen.of(context);
    if (shell != _shell) {
      _shell?.tabNotifier.removeListener(_onTab);
      _shell = shell?..tabNotifier.addListener(_onTab);
    }
  }

  void _onTab() {
    if (_shell?.tabNotifier.value == BuyerMainScreenState.tabHome && mounted) setState(_pickTiles);
  }

  /// Back on Home from a page opened on top of it.
  @override
  void didPopNext() {
    if (mounted) setState(_pickTiles);
  }

  /// Two random categories that have items (other ones than now when there are enough).
  void _pickTiles() {
    final pool = categories.where((c) => c['image_url'] != null && (c['count'] ?? 0) > 0).map((c) => '${c['slug']}').toList();
    if (pool.length < 2) {
      _tileSlugs = pool;
      return;
    }
    final fresh = pool.where((s) => !_tileSlugs.contains(s)).toList();
    final from = fresh.length >= 2 ? fresh : pool;
    from.shuffle(Random());
    _tileSlugs = from.take(2).toList();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _shell?.tabNotifier.removeListener(_onTab);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    final r = await BuyerApi.home();
    if (!mounted) return;
    setState(() {
      loading = false;
      if (!r.ok) {
        if (!silent) error = r.message;
        return;
      }
      error = null;
      featured = r.body['featured'];
      trending = r.body['trending'];
      categories = r.body['categories'];
      banners = r.body['banners'] as List? ?? const [];
      if (_tileSlugs.isEmpty) _pickTiles();
    });
  }

  void _searchFor(String q) {
    if (q.trim().isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(initialSearch: q.trim())));
  }

  void _refreshCart() => BuyerMainScreen.of(context)?.refreshCartCount();

  void _openCategory(dynamic cat) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(categorySlug: cat['slug'], categoryName: cat['name'])));

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.isWide(context);
    return Scaffold(
      backgroundColor: context.bc.background,
      body: LoadState(
        loading: loading && featured.isEmpty,
        error: featured.isEmpty ? error : null,
        onRetry: _load,
        child: RefreshIndicator(
          color: kOrange,
          onRefresh: _load,
          child: CustomScrollView(slivers: [
            // The design's header: a white bar with the logo tile, ALVY and the quick icons, the search shell
            // under it. (On a tablet the main screen shows the wide header instead.)
            if (!wide)
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                toolbarHeight: 64,
                expandedHeight: 128,
                titleSpacing: 16,
                title: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(12)),
                    child: Image.asset('assets/images/logo-mark.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 10),
                  Text('ALVY', style: Alvy.display(size: 23, color: context.bc.text)),
                ]),
                actions: [
                  IconButton(
                    tooltip: 'Voucher Center',
                    icon: const Icon(Icons.confirmation_number_outlined),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherCenterScreen())),
                  ),
                  IconButton(
                    tooltip: 'Wishlist',
                    icon: const Icon(Icons.favorite_border_rounded),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen())),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                  ),
                  IconButton(
                    tooltip: 'Messages',
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())),
                  ),
                  const SizedBox(width: 6),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(64),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _SearchBar(controller: _search, onSearch: _searchFor),
                  ),
                ),
              ),
            // The photo hero (phones and tablets).
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: WebBannerCarousel(
                  banners: banners,
                  onShop: (s) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => s.categorySlug == null
                          ? const AllCategoriesScreen()
                          : ShopScreen(categorySlug: s.categorySlug, categoryName: s.categoryName),
                    ),
                  ),
                ),
              ),
            ),
            // Category photo tiles under the hero.
            if (categories.length >= 2) SliverToBoxAdapter(child: _miniTiles()),
            SliverToBoxAdapter(child: _perks()),
            if (categories.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionTitle('Categories',
                    action: 'All categories', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllCategoriesScreen()))),
              ),
              SliverToBoxAdapter(child: _categoryCircles()),
            ],
            SliverToBoxAdapter(
              child: SectionTitle('New Arrivals', action: 'See all', onAction: () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabShop)),
            ),
            _grid(featured),
            SliverToBoxAdapter(
              child: SectionTitle('Best Sellers', action: 'See all', onAction: () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabShop)),
            ),
            _grid(trending),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ]),
        ),
      ),
    );
  }

  /// Two category photo tiles (random, see _pickTiles): the name and "N items • Shop now →" over a dark fade.
  Widget _miniTiles() {
    final picks = [for (final slug in _tileSlugs) ...categories.where((c) => '${c['slug']}' == slug)];
    if (picks.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        for (var i = 0; i < picks.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _openCategory(picks[i]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 128,
                  child: Stack(fit: StackFit.expand, children: [
                    NetImage(picks[i]['wide_image_url'] ?? picks[i]['image_url'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Alvy.navyLight)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xD91E1B17), Color(0x661E1B17), Color(0x001E1B17)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text(picks[i]['name'], maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.2)),
                        const SizedBox(height: 2),
                        Text('${picks[i]['count']} item${picks[i]['count'] == 1 ? '' : 's'} • Shop now →',
                            style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  /// Quick links: Voucher Center, free shipping, wishlist and the shops.
  Widget _perks() {
    final c = context.bc;
    Widget perk(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.10), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 7),
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.text)),
              ]),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: cardBox(context),
      child: Row(children: [
        perk(Icons.confirmation_number_outlined, 'Vouchers', kOrange,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherCenterScreen()))),
        perk(Icons.local_shipping_outlined, 'Free shipping', Alvy.slate,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherCenterScreen()))),
        perk(Icons.favorite_border, 'Wishlist', const Color(0xFFDC2626),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()))),
        perk(Icons.storefront_outlined, 'All shops', const Color(0xFF16A34A), () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabShop)),
      ]),
    );
  }

  /// The category rail: round photos on a white ring with the name under each.
  Widget _categoryCircles() {
    final c = context.bc;
    final wide = Responsive.isWide(context);
    final size = wide ? 80.0 : 64.0;
    return SizedBox(
      height: wide ? 140 : 114,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openCategory(cat),
            child: SizedBox(
              width: wide ? 112 : 80,
              child: Column(children: [
                const SizedBox(height: 4),
                Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.surface,
                    boxShadow: const [BoxShadow(color: Color(0x142A1A10), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: ClipOval(
                    child: NetImage(cat['image_url'], fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Alvy.orangeSoft, child: const Icon(Icons.category_outlined, color: kOrange))),
                  ),
                ),
                const SizedBox(height: 7),
                Text(cat['name'], maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: wide ? 13 : 11.5, fontWeight: FontWeight.w500, color: c.text, height: 1.25)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _grid(List items) => items.isEmpty
      ? SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No products yet.', style: TextStyle(color: context.bc.muted)))),
        )
      : SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.extent(
            maxCrossAxisExtent: Responsive.productTileMaxFor(context),
            childAspectRatio: 0.6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [for (final p in items) BuyerProductCard(product: Map<String, dynamic>.from(p), onCartChanged: _refreshCart)],
          ),
        );
}

/// The design's search shell: beige, rounded, with the orange search button inside.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Container(
      height: 48,
      decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(Icons.search, color: c.muted, size: 21),
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSearch,
            style: TextStyle(color: c.text, fontSize: 14.5),
            decoration: const InputDecoration(
              hintText: 'Search products, brands, categories…',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 13),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(5),
          child: Material(
            color: kOrange,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSearch(controller.text),
              child: const SizedBox(width: 44, height: 38, child: Icon(Icons.search, color: Colors.white, size: 20)),
            ),
          ),
        ),
      ]),
    );
  }
}
