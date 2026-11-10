import '../../widgets/responsive.dart';
import 'package:flutter/material.dart';
import '../../widgets/allie.dart';
import '../../theme/app_theme.dart';

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/buyer_product_card.dart';
import 'buyer_main_screen.dart';
import 'assistant_screen.dart';
import 'store_screen.dart';

/// The website's Shop (search + filters, shop/index) and category pages (categories/show).
/// Pass [categorySlug] to open a category page; otherwise it searches with [initialSearch].
class ShopScreen extends StatefulWidget {
  final String? initialSearch;
  final String? categorySlug;
  final String? categoryName;
  /// One subcategory of [categorySlug] (the website's ?sub=), e.g. from All Categories.
  final String? subcategory;

  const ShopScreen({super.key, this.initialSearch, this.categorySlug, this.categoryName, this.subcategory});

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
  // Category page: its subcategories as pills ("All" + each), and the one chosen.
  List<String> subcategories = [];
  late String? sub = widget.subcategory;
  int page = 1;
  int last = 1;
  int total = 0;   // every match, not just this page (the website's "300 items")
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
      final r = await BuyerApi.category(categorySlug!, sort: sort.isEmpty ? null : sort, sub: sub);
      if (!mounted) return;
      setState(() {
        loading = false;
        error = r.ok ? null : r.message;
        if (!r.ok) return;
        products = r.body['data'];
        categoryTitle = r.body['category']['name'];
        subcategories = [for (final x in (r.body['subcategories'] as List? ?? const [])) '$x'];
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
      total = asNum(r.body['meta']['total'] ?? products.length).toInt();
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
    // Tablet: the filters sit in a sidebar (website), and the Shop tab uses the web header's search.
    final wide = Responsive.isWide(context) && !inCategory;
    final isTab = !Navigator.canPop(context);
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: wide && isTab ? null : AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        title: Text(inCategory ? (categoryTitle ?? 'Category') : 'Shop'),
        actions: [
          if (inCategory)
            IconButton(
              tooltip: 'Search all products',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() {
                categorySlug = null;
                _load();
              }),
            ),
        ],
        // The design's search row: a beige search shell and a Filters pill beside it.
        bottom: inCategory || wide
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(62),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search, color: context.bc.muted, size: 21),
                          Expanded(
                            child: TextField(
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              style: TextStyle(color: context.bc.text, fontSize: 14.5),
                              decoration: const InputDecoration(
                                hintText: 'Search products…',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                              ),
                              onSubmitted: (_) => _load(),
                            ),
                          ),
                          if (_search.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear',
                              icon: Icon(Icons.close, size: 19, color: context.bc.muted),
                              onPressed: () {
                                _search.clear();
                                _load();
                              },
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: context.bc.subtle,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _filters,
                        child: SizedBox(
                          height: 48,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(children: [
                              Icon(Icons.tune, size: 20, color: context.bc.text),
                              const SizedBox(width: 6),
                              Text('Filters', style: TextStyle(fontWeight: FontWeight.w600, color: context.bc.text)),
                              if (_activeFilters.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: kOrange,
                                  child: Text('${_activeFilters.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
      ),
      body: LoadState(
        loading: loading && products.isEmpty,
        error: error,
        onRetry: _load,
        child: RefreshIndicator(
          color: kOrange,
          onRefresh: _load,
          child: (wide ? (Widget list) => WebWidth(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [_sidebar(), Expanded(child: list)])) : (Widget list) => list)(
            ListView(padding: EdgeInsets.fromLTRB(wide ? 12 : 16, 12, wide ? 12 : 16, 24), children: [
            // Tablet: the website's "All products — 300 items" line and the Sort by pills.
            if (wide) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                child: Text(
                    '${_search.text.trim().isEmpty ? 'All products' : 'Results for "${_search.text.trim()}"'} — $total ${total == 1 ? 'item' : 'items'}',
                    style: TextStyle(fontSize: 15, color: context.bc.muted)),
              ),
              _sortPills(),
            ] else ...[
            if (!inCategory)
              SizedBox(
                height: 46,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(bottom: 8), children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterPill('All Items', selected: _activeFilters.isEmpty, onTap: () {
                      setState(_clearFilters);
                      _load();
                    }),
                  ),
                  for (final (label, clear) in _activeFilters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () {
                          setState(clear);
                          _load();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(99)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(label, style: const TextStyle(color: Alvy.orangeDark, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            const Icon(Icons.cancel_outlined, size: 16, color: Alvy.orangeDark),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            if (inCategory && subcategories.isNotEmpty)
              SizedBox(
                height: 46,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(bottom: 8), children: [
                  for (final x in [null, ...subcategories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterPill(x ?? 'All', selected: sub == x, onTap: () {
                        setState(() => sub = x);
                        _load();
                      }),
                    ),
                ]),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
              Icon(location != null ? Icons.place_outlined : Icons.inventory_2_outlined, size: 17, color: kOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    inCategory
                        ? '${products.length} items'
                        : (_search.text.trim().isEmpty ? '$total items' : '$total results for "${_search.text.trim()}"') + (location != null ? ' in $location' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: context.bc.text)),
              ),
              // Sort: a white pill with a dropdown.
              Container(
                padding: const EdgeInsets.only(left: 12, right: 4),
                decoration: cardBox(context, radius: 20),
                child: DropdownButton<String>(
                value: sort,
                underline: const SizedBox(),
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                isDense: true,
                items: [
                  for (final e in _sorts.entries)
                    if (!inCategory || ['', 'newest', 'price_low', 'price_high'].contains(e.key)) DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) {
                  setState(() => sort = v ?? '');
                  _load();
                },
              ),
              ),
            ]),
            ),
            if (suggestion != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('No exact matches. Showing results for "$suggestion".', style: const TextStyle(color: Color(0xFFB45309))),
              ),
            for (final n in notes) Text(n, style: TextStyle(fontSize: 12, color: context.bc.muted)),
            // Stores whose name matches the search, above the products (like the website).
            if (!inCategory && matchedStores.isNotEmpty) ...[
              const SectionTitle('Stores', padding: EdgeInsets.fromLTRB(0, 4, 0, 12)),
              for (final st in matchedStores)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: cardBox(context),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: Alvy.orangeSoft,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Column(children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.search_off_rounded, size: 40, color: kOrange),
                  ),
                  const SizedBox(height: 14),
                  Text('No products found', style: Alvy.display(size: 18, color: context.bc.text, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Try other words or fewer filters.', style: TextStyle(color: context.bc.textSecondary)),
                ]),
              )
            else
              GridView.extent(
                maxCrossAxisExtent: Responsive.productTileMaxFor(context),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.6,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [for (final p in products) BuyerProductCard(product: Map<String, dynamic>.from(p), onCartChanged: _refreshCart)],
              ),
            if (page < last) TextButton(onPressed: () => _load(more: true), child: const Text('Load more')),
            if (!wide && products.isNotEmpty && page >= last)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Alvy.orange, Alvy.orangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: Alvy.buttonShadow,
                    ),
                    child: Row(children: [
                      const CircleAvatar(radius: 24, backgroundColor: Colors.white, child: AllieAvatar(size: 40)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('ALVY CONCIERGE', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                          const SizedBox(height: 2),
                          Text("Can't find what you need?", style: Alvy.display(size: 19, color: Colors.white, weight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          const Text('Ask the ALVY Assistant to help you find it.', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(radius: 18, backgroundColor: Colors.white.withValues(alpha: 0.2), child: const Icon(Icons.arrow_forward, color: Colors.white, size: 18)),
                    ]),
                  ),
                ),
              ),
          ])),
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
              KeyedSubtree(
                key: ValueKey(_filtersVersion),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _filterFields(set)),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => set(_clearFilters),
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

  int _filtersVersion = 0;   // a new number rebuilds the filter fields, so "Clear" shows the cleared values

  List<(String, VoidCallback)> get _activeFilters => [
        if (category != null) (category!, () => category = null),
        if (location != null) (location!, () => location = null),
        if (rating != null) ('$rating★ & up', () => rating = null),
        if (store != null) (stores.where((x) => x['id'] == store).map((x) => '${x['name']}').firstOrNull ?? 'Store', () => store = null),
        if (_min.text.trim().isNotEmpty || _max.text.trim().isNotEmpty)
          (
            _min.text.trim().isNotEmpty && _max.text.trim().isNotEmpty
                ? '₱${_min.text.trim()} – ₱${_max.text.trim()}'
                : _min.text.trim().isNotEmpty
                    ? 'From ₱${_min.text.trim()}'
                    : 'Under ₱${_max.text.trim()}',
            () {
              _min.clear();
              _max.clear();
            }
          ),
        if (soldOut) ('Sold out too', () => soldOut = false),
      ];

  void _clearFilters() {
    _filtersVersion++;
    category = location = null;
    rating = store = null;
    soldOut = false;
    _min.clear();
    _max.clear();
  }

  /// The filters (the same in the phone's bottom sheet and the tablet's sidebar).
  List<Widget> _filterFields(StateSetter set) => [
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
      ];

  /// Tablet: the website's filter list (headings, price range, star ratings, then the lists), in its order.
  List<Widget> _webFilterFields() {
    final c = context.bc;
    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text)),
        );
    Widget stars(int n) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 5; i++) Icon(Icons.star_rounded, size: 17, color: i < n ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB)),
        ]);
    InputDecoration box(String hint) => InputDecoration(hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10));
    return [
      heading('Price range'),
      Row(children: [
        Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: box('₱ Min'))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
        Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: box('₱ Max'))),
      ]),
      heading('Rating'),
      for (final n in [5, 4, 3])
        InkWell(
          onTap: () => setState(() => rating = rating == n ? null : n),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(rating == n ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 18, color: rating == n ? kOrange : c.muted),
              const SizedBox(width: 8),
              stars(n),
              if (n < 5) Text('  & up', style: TextStyle(fontSize: 13, color: c.muted)),
            ]),
          ),
        ),
      heading('Category'),
      DropdownButtonFormField<String?>(
        initialValue: category,
        isExpanded: true,
        decoration: box(''),
        items: [const DropdownMenuItem<String?>(value: null, child: Text('All categories')), for (final x in categories) DropdownMenuItem(value: x, child: Text(x))],
        onChanged: (v) => setState(() => category = v),
      ),
      heading('Shipped from'),
      DropdownButtonFormField<String?>(
        initialValue: location,
        isExpanded: true,
        decoration: box(''),
        items: [const DropdownMenuItem<String?>(value: null, child: Text('Anywhere')), for (final l in locations) DropdownMenuItem(value: l, child: Text(l))],
        onChanged: (v) => setState(() => location = v),
      ),
      heading('Store'),
      DropdownButtonFormField<int?>(
        initialValue: store,
        isExpanded: true,
        decoration: box(''),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('All stores')),
          for (final st in stores) DropdownMenuItem(value: asNum(st['id']).toInt(), child: Text('${st['name']}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => store = v),
      ),
      heading('Availability'),
      InkWell(
        onTap: () => setState(() => soldOut = !soldOut),
        child: Row(children: [
          Checkbox(value: soldOut, activeColor: kOrange, visualDensity: VisualDensity.compact, onChanged: (v) => setState(() => soldOut = v == true)),
          const Expanded(child: Text('Show sold-out items too')),
        ]),
      ),
    ];
  }

  /// Tablet: the website's "Sort by" pills above the products.
  Widget _sortPills() {
    const web = {'newest': 'Latest', 'best_selling': 'Best selling', 'price_low': 'Price: Low to High', 'price_high': 'Price: High to Low'};
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: cardBox(context),
      child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Sort by', style: TextStyle(color: context.bc.muted)),
        for (final e in web.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: (sort.isEmpty ? 'newest' : sort) == e.key,
            selectedColor: kOrange,
            labelStyle: TextStyle(color: (sort.isEmpty ? 'newest' : sort) == e.key ? Colors.white : context.bc.text, fontWeight: FontWeight.w600),
            showCheckmark: false,
            onSelected: (_) {
              setState(() => sort = e.key);
              _load();
            },
          ),
      ]),
    );
  }

  /// Tablet: the website's Shop sidebar with the filters next to the products.
  Widget _sidebar() => SizedBox(
        width: 260,
        child: Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 0, 12),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.bc.text)),
              const SizedBox(height: 6),
              KeyedSubtree(
                key: ValueKey(_filtersVersion),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _webFilterFields()),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white),
                child: const Text('Apply'),
              ),
              TextButton(
                onPressed: () {
                  setState(_clearFilters);
                  _load();
                },
                child: const Text('Clear filters'),
              ),
            ]),
          ),
        ),
      );
}
