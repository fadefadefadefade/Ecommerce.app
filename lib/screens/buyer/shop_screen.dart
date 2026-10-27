import 'package:flutter/material.dart';

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/buyer_product_card.dart';
import 'buyer_main_screen.dart';
import 'store_screen.dart';

/// The website's Shop (search + filters, shop/index) and category pages (categories/show).
/// Pass [categorySlug] to open a category page; otherwise it searches with [initialSearch].
class ShopScreen extends StatefulWidget {
  final String? initialSearch;
  final String? categorySlug;
  final String? categoryName;

  const ShopScreen({super.key, this.initialSearch, this.categorySlug, this.categoryName});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const _sorts = {
    '': 'Relevance / Latest',
    'newest': 'Latest',
    'best_selling': 'Best selling',
    'price_low': 'Price: Low to High',
    'price_high': 'Price: High to Low',
  };

  late final _search = TextEditingController(text: widget.initialSearch ?? '');
  late String? categorySlug = widget.categorySlug;
  String? categoryTitle;
  String sort = '';
  String? category; // search filter
  String? location;
  int? rating;
  int? store;          // the website's Store filter
  bool soldOut = false; // "Show sold-out items too" (availability=all)
  final _min = TextEditingController();
  final _max = TextEditingController();

  List<dynamic> products = [];
  List<String> categories = [];
  List<String> locations = [];
  List<Map<String, dynamic>> stores = [];
  List<Map<String, dynamic>> matchedStores = [];
  List<String> notes = [];
  String? suggestion;
  int page = 1;
  int last = 1;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    categoryTitle = widget.categoryName;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) setState(() => loading = true);

    if (categorySlug != null) {
      final r = await BuyerApi.category(categorySlug!, sort: sort.isEmpty ? null : sort);
      if (!mounted) return;
      setState(() {
        loading = false;
        error = r.ok ? null : r.message;
        if (!r.ok) return;
        products = r.body['data'];
        categoryTitle = r.body['category']['name'];
        page = last = 1;
        suggestion = null;
        notes = [];
      });
      return;
    }

    final r = await BuyerApi.shop({
      'search': _search.text.trim(),
      'sort': sort.isEmpty ? null : sort,
      'category': category,
      'location': location,
      'rating': rating,
      'store': store,
      'availability': soldOut ? 'all' : null,
      'min_price': _min.text.trim().isEmpty ? null : _min.text.trim(),
      'max_price': _max.text.trim().isEmpty ? null : _max.text.trim(),
      'page': more ? page + 1 : 1,
    });
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (!r.ok) return;
      // A plain category link opens its category page, like the website.
      if (r.body['category_page'] != null) {
        categorySlug = r.body['category_page'];
        categoryTitle = r.body['category']?['name'];
        products = r.body['data'];
        return;
      }
      products = more ? [...products, ...r.body['data']] : List.of(r.body['data']);
      page = r.body['meta']['current_page'];
      last = r.body['meta']['last_page'];
      categories = List<String>.from(r.body['categories'] ?? []);
      locations = List<String>.from(r.body['locations'] ?? []);
      stores = List<Map<String, dynamic>>.from((r.body['stores'] ?? []).map((e) => Map<String, dynamic>.from(e)));
      matchedStores = List<Map<String, dynamic>>.from((r.body['matched_stores'] ?? []).map((e) => Map<String, dynamic>.from(e)));
      notes = List<String>.from((r.body['notes'] ?? []).map((n) => '$n'));
      suggestion = r.body['suggestion'];
    });
  }

  void _refreshCart() => BuyerMainScreen.of(context)?.refreshCartCount();

  @override
  Widget build(BuildContext context) {
    final inCategory = categorySlug != null;
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        title: inCategory
            ? Text(categoryTitle ?? 'Category')
            : TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: context.bc.muted),
                ),
                onSubmitted: (_) => _load(),
              ),
        actions: [
          if (inCategory)
            IconButton(
              tooltip: 'Search all products',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() {
                categorySlug = null;
                _load();
              }),
            )
          else
            IconButton(tooltip: 'Filters', icon: const Icon(Icons.tune), onPressed: _filters),
        ],
      ),
      body: LoadState(
        loading: loading && products.isEmpty,
        error: error,
        onRetry: _load,
        child: RefreshIndicator(
          color: kOrange,
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Row(children: [
              Text(inCategory ? '${products.length} products' : (_search.text.trim().isEmpty ? 'All products' : 'Results for "${_search.text.trim()}"'),
                  style: TextStyle(color: context.bc.muted)),
              const Spacer(),
              DropdownButton<String>(
                value: sort,
                underline: const SizedBox(),
                items: [
                  for (final e in _sorts.entries)
                    if (!inCategory || ['', 'newest', 'price_low', 'price_high'].contains(e.key)) DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) {
                  setState(() => sort = v ?? '');
                  _load();
                },
              ),
            ]),
            if (suggestion != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('No exact matches. Showing results for "$suggestion".', style: const TextStyle(color: Color(0xFFB45309))),
              ),
            for (final n in notes) Text(n, style: TextStyle(fontSize: 12, color: context.bc.muted)),
            // Stores whose name matches the search, above the products (like the website).
            if (!inCategory && matchedStores.isNotEmpty) ...[
              Text('Stores', style: TextStyle(fontWeight: FontWeight.w700, color: context.bc.text)),
              const SizedBox(height: 6),
              for (final st in matchedStores)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFFF1EE),
                      backgroundImage: st['logo_url'] != null ? NetworkImage('${st['logo_url']}') : null,
                      child: st['logo_url'] == null ? const Icon(Icons.storefront, color: kOrange) : null,
                    ),
                    title: Text('${st['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${st['location'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(sellerId: asNum(st['id']).toInt()))),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            if (products.isEmpty && !loading)
              Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('No products found.', style: TextStyle(color: context.bc.muted))))
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.56,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [for (final p in products) BuyerProductCard(product: Map<String, dynamic>.from(p), onCartChanged: _refreshCart)],
              ),
            if (page < last) TextButton(onPressed: () => _load(more: true), child: const Text('Load more')),
          ]),
        ),
      ),
    );
  }

  Future<void> _filters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [const DropdownMenuItem<String?>(value: null, child: Text('All categories')), for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => set(() => category = v),
              ),
              Row(children: [
                Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min ₱'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max ₱'))),
              ]),
              DropdownButtonFormField<int?>(
                initialValue: rating,
                decoration: const InputDecoration(labelText: 'Rating'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Any rating')),
                  for (final s in [5, 4, 3, 2, 1]) DropdownMenuItem(value: s, child: Text('$s★ & up')),
                ],
                onChanged: (v) => set(() => rating = v),
              ),
              DropdownButtonFormField<int?>(
                initialValue: store,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Store'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All stores')),
                  for (final st in stores) DropdownMenuItem(value: asNum(st['id']).toInt(), child: Text('${st['name']}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => set(() => store = v),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: soldOut,
                activeColor: kOrange,
                title: const Text('Show sold-out items too'),
                onChanged: (v) => set(() => soldOut = v == true),
              ),
              DropdownButtonFormField<String?>(
                initialValue: location,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ships from'),
                items: [const DropdownMenuItem<String?>(value: null, child: Text('Anywhere')), for (final l in locations) DropdownMenuItem(value: l, child: Text(l))],
                onChanged: (v) => set(() => location = v),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      set(() {
                        category = location = null;
                        rating = store = null;
                        soldOut = false;
                        _min.clear();
                        _max.clear();
                      });
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white),
                    child: const Text('Apply'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (mounted) _load();
  }
}
