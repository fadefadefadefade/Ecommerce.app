import 'package:flutter/material.dart';
import '../../theme/buyer_colors.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/buyer_product_card.dart';
import '../../widgets/live_refresh.dart';
import 'buyer_main_screen.dart';
import 'shop_screen.dart';

/// Buyer home: Shop-style search + categories, featured row and a suggested grid.
class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> with LiveRefresh {
  @override
  int? get liveTab => BuyerMainScreenState.tabHome;

  @override
  Future<void> onLiveRefresh() => _loadHomeData(silent: true);

  static const _primary = Color(0xFFfa4e1c);

  final _searchController = TextEditingController();
  List<dynamic> featured = [];
  List<dynamic> suggested = [];
  List<dynamic> categories = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        isLoading = true;
        error = null;
      });
    }
    try {
      final data = ApiService.unwrap(await ApiService.get(ApiConfig.home));
      if (!mounted) return;
      setState(() {
        featured = data['featured'] ?? [];
        suggested = data['suggested'] ?? data['bestSellers'] ?? [];
        categories = data['categories'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _search(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShopScreen(initialSearch: q)),
    );
  }

  void _openCategory(Map<String, dynamic> category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopScreen(categoryId: category['id'], categoryName: category['name']),
      ),
    );
  }

  void _openShopTab() => BuyerMainScreen.of(context)?.goTo(BuyerMainScreenState.tabShop);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      // Same search bar as the Shop screen
      appBar: AppBar(
        backgroundColor: context.bc.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: context.bc.subtle,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search products...',
              hintStyle: TextStyle(color: context.bc.muted, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: context.bc.textSecondary, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onSubmitted: _search,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: _primary),
            onPressed: () => _search(_searchController.text),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading && featured.isEmpty && suggested.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (error != null && featured.isEmpty && suggested.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 56, color: context.bc.muted),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center, style: TextStyle(color: context.bc.muted)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadHomeData,
                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadHomeData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildBanner()),
          if (categories.isNotEmpty) SliverToBoxAdapter(child: _buildCategories()),
          if (featured.isNotEmpty) SliverToBoxAdapter(child: _buildFeatured()),
          SliverToBoxAdapter(
            child: _sectionHeader('Suggested for You', icon: Icons.auto_awesome, onSeeAll: _openShopTab),
          ),
          if (suggested.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No products yet.', style: TextStyle(color: context.bc.muted))),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => BuyerProductCard(product: Map<String, dynamic>.from(suggested[i])),
                  childCount: suggested.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              child: OutlinedButton(
                onPressed: _openShopTab,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('See More Products'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    final name = context.watch<AuthProvider>().user?.name ?? 'Guest';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFFfa4e1c), Color(0xFFff8a50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${name.split(' ').first}!',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Discover great deals picked just for you.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _openShopTab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Shop Now', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Icon(Icons.shopping_bag, size: 64, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {required IconData icon, VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.bc.text),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text(
                'See All →',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Categories', icon: Icons.category),
        Container(
          color: context.bc.surface,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            height: 92,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final category = Map<String, dynamic>.from(categories[i]);
                return InkWell(
                  onTap: () => _openCategory(category),
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 78,
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_categoryIcon(category['name'] ?? ''), color: _primary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          category['name'] ?? '',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: context.bc.text, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatured() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Featured', icon: Icons.local_fire_department, onSeeAll: _openShopTab),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: 150,
              child: BuyerProductCard(product: Map<String, dynamic>.from(featured[i])),
            ),
          ),
        ),
      ],
    );
  }

  static IconData _categoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('electronic')) return Icons.devices;
    if (n.contains('cloth') || n.contains('fashion')) return Icons.checkroom;
    if (n.contains('book')) return Icons.menu_book;
    if (n.contains('home') || n.contains('garden')) return Icons.chair;
    if (n.contains('sport')) return Icons.sports_basketball;
    if (n.contains('toy') || n.contains('game')) return Icons.toys;
    if (n.contains('health') || n.contains('beauty')) return Icons.spa;
    if (n.contains('auto') || n.contains('car')) return Icons.directions_car;
    if (n.contains('food') || n.contains('beverage')) return Icons.restaurant;
    if (n.contains('office')) return Icons.work_outline;
    return Icons.category;
  }
}
