import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
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

/// The website's home page (home/index): search, category shortcuts with item counts, new
/// arrivals and best sellers.
class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> with LiveRefresh {
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
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
    });
  }

  void _searchFor(String q) {
    if (q.trim().isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(initialSearch: q.trim())));
  }

  void _refreshCart() => BuyerMainScreen.of(context)?.refreshCartCount();

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AuthProvider>().user?.name ?? '';
    final first = name.trim().split(' ').first;
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
            // The website's header: navy, the logo, quick links, and the white search bar with the orange button.
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              toolbarHeight: 60,
              expandedHeight: 116,
              titleSpacing: 14,
              title: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Image.asset('assets/images/logo-mark.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                Text('ALVY', style: Alvy.display(size: 22, color: Colors.white)),
              ]),
              actions: [
                IconButton(
                  tooltip: 'Voucher Center',
                  icon: const Icon(Icons.confirmation_number_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherCenterScreen())),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
                IconButton(
                  tooltip: 'Messages',
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())),
                ),
                const SizedBox(width: 4),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: _SearchBar(controller: _search, onSearch: _searchFor),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _hero(first)),
            SliverToBoxAdapter(child: _perks()),
            if (categories.isNotEmpty) ...[
              SliverToBoxAdapter(child: _header('Browse', 'Shop by category', onAll: () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabShop))),
              SliverToBoxAdapter(child: _categoryGrid()),
            ],
            SliverToBoxAdapter(child: _header('Just in', 'New Arrivals', onAll: () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabShop))),
            _grid(featured),
            SliverToBoxAdapter(child: _header('Top picks', 'Best Sellers', onAll: () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabShop))),
            _grid(trending),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ]),
        ),
      ),
    );
  }

  /// The website's orange gradient hero.
  Widget _hero(String first) => Container(
        margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
        decoration: BoxDecoration(gradient: Alvy.gradient, borderRadius: BorderRadius.circular(14), boxShadow: Alvy.buttonShadow),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(first.isEmpty ? 'WELCOME TO ALVY' : 'HI, ${first.toUpperCase()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
              const SizedBox(height: 4),
              Text('Great finds from local sellers', style: Alvy.display(size: 21, color: Colors.white)),
              const SizedBox(height: 4),
              const Text('Vouchers, flash deals and free shipping every day.', style: TextStyle(color: Colors.white, fontSize: 12.5)),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kOrange, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                onPressed: () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabShop),
                child: const Text('Shop now'),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 38),
          ),
        ]),
      );

  /// Quick links to the website's Voucher Center, Wishlist and the shop.
  Widget _perks() {
    final c = context.bc;
    Widget perk(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.text)),
              ]),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border), boxShadow: Alvy.cardShadow),
      child: Row(children: [
        perk(Icons.confirmation_number_outlined, 'Vouchers', kOrange,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherCenterScreen()))),
        perk(Icons.local_shipping_outlined, 'Free shipping', const Color(0xFF0F9F8A),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherCenterScreen()))),
        perk(Icons.favorite_border, 'Wishlist', const Color(0xFFDC2626),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()))),
        perk(Icons.storefront_outlined, 'All shops', Alvy.navy, () => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabShop)),
      ]),
    );
  }

  Widget _categoryGrid() {
    final c = context.bc;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border), boxShadow: Alvy.cardShadow),
      child: SizedBox(
        height: 104,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          itemBuilder: (_, i) {
            final cat = categories[i];
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopScreen(categorySlug: cat['slug'], categoryName: cat['name']))),
              child: SizedBox(
                width: 80,
                child: Column(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: NetImage(cat['image_url'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.category_outlined, color: kOrange)),
                  ),
                  const SizedBox(height: 6),
                  Text(cat['name'], maxLines: 1, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.text)),
                  Text('${cat['count']} items', style: TextStyle(fontSize: 10, color: c.muted)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The website's section heading: an orange eyebrow over a Nunito title, with "See all".
  Widget _header(String eyebrow, String title, {VoidCallback? onAll}) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 22, 6, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(eyebrow.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.7, color: kOrange)),
              const SizedBox(height: 2),
              Text(title, style: Alvy.display(size: 19, color: context.bc.text)),
            ]),
          ),
          if (onAll != null)
            TextButton(
              onPressed: onAll,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('See all'), Icon(Icons.chevron_right, size: 18)]),
            ),
        ]),
      );

  Widget _grid(List items) => items.isEmpty
      ? SliverToBoxAdapter(
          child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No products yet.', style: TextStyle(color: context.bc.muted)))),
        )
      : SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            childAspectRatio: 0.56,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [for (final p in items) BuyerProductCard(product: Map<String, dynamic>.from(p), onCartChanged: _refreshCart)],
          ),
        );
}

/// The website's search bar: white, rounded, with the orange search button.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const SizedBox(width: 12),
        const Icon(Icons.search, color: Alvy.textMuted, size: 20),
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSearch,
            style: const TextStyle(color: Alvy.navy, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Search products, brands, categories…',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: kOrange,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onSearch(controller.text),
              child: const SizedBox(width: 44, height: 36, child: Icon(Icons.search, color: Colors.white, size: 20)),
            ),
          ),
        ),
      ]),
    );
  }
}
