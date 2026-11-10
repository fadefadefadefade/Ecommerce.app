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
import 'account/notifications_screen.dart';
import 'buyer_main_screen.dart';
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
                toolbarHeight: 68,
                titleSpacing: 16,
                title: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Alvy.isDark ? const Color(0xFFFFE4DC) : Alvy.orangeSoft, borderRadius: BorderRadius.circular(12)),
                    child: Image.asset('assets/images/logo-mark.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 8),
                  Text('ALVY', style: Alvy.display(size: 21, color: context.bc.text, weight: FontWeight.w800)),
                ]),
                // The design's header icons: search, notifications, the cart with its count, the profile button.
                actions: [
                  IconButton(
                    tooltip: 'Search',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabShop),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _shell?.cartNotifier ?? ValueNotifier<int>(0),
                    builder: (_, n, __) => IconButton(
                      tooltip: 'Cart',
                      visualDensity: VisualDensity.compact,
                      icon: Badge(
                        isLabelVisible: n > 0,
                        label: Text(n > 99 ? '99+' : '$n'),
                        backgroundColor: kOrange,
                        child: const Icon(Icons.shopping_bag_outlined),
                      ),
                      onPressed: () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabCart),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 12),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabAccount),
                      child: const CircleAvatar(radius: 15, backgroundColor: kOrange, child: Icon(Icons.person_outline, color: Colors.white, size: 20)),
                    ),
                  ),
                ],
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
            _row(featured),
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

  /// The category rail: round photos on a white ring with the name under each.
  Widget _categoryCircles() {
    final c = context.bc;
    final wide = Responsive.isWide(context);
    final size = wide ? 84.0 : 70.0;
    return SizedBox(
      height: wide ? 146 : 122,
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
              width: wide ? 112 : 86,
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

  /// A horizontal row of product cards (the design's "Flash Deals" strip): two cards on screen, swipe for more.
  Widget _row(List items) {
    if (items.isEmpty) return _grid(items);
    final w = Responsive.isWide(context) ? 200.0 : (MediaQuery.of(context).size.width - 44) / 2;
    return SliverToBoxAdapter(
      child: SizedBox(
        height: w / 0.6,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(
            width: w,
            child: BuyerProductCard(product: Map<String, dynamic>.from(items[i]), onCartChanged: _refreshCart),
          ),
        ),
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
