import 'package:flutter/material.dart';
import '../../theme/buyer_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/buyer_product_card.dart';
import '../../widgets/live_refresh.dart';
import 'buyer_main_screen.dart';

class ShopScreen extends StatefulWidget {
  final String? initialSearch;
  final int? categoryId;
  final String? categoryName;

  const ShopScreen({super.key, this.initialSearch, this.categoryId, this.categoryName});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with LiveRefresh {
  List<dynamic> products = [];
  bool isLoading = true;
  String searchQuery = '';
  String sortBy = 'newest';
  late int? categoryId = widget.categoryId;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch != null) {
      searchQuery = widget.initialSearch!;
      _searchController.text = searchQuery;
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  int? get liveTab => BuyerMainScreenState.tabShop;

  @override
  Future<void> onLiveRefresh() => _loadProducts(silent: true);

  Future<void> _loadProducts({bool silent = false}) async {
    if (!silent) setState(() => isLoading = true);

    try {
      final queryParams = <String, String>{
        if (searchQuery.isNotEmpty) 'search': searchQuery,
        if (sortBy.isNotEmpty) 'sort': sortBy,
        if (categoryId != null) 'category_id': '$categoryId',
        if (_minPriceController.text.isNotEmpty) 'min_price': _minPriceController.text,
        if (_maxPriceController.text.isNotEmpty) 'max_price': _maxPriceController.text,
      };
      
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final data = ApiService.unwrap(await ApiService.get(
        '/products${queryString.isNotEmpty ? '?$queryString' : ''}'
      ));
      if (!mounted) return;
      setState(() {
        products = data['products'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  void _performSearch() {
    setState(() {
      searchQuery = _searchController.text;
    });
    _loadProducts();
  }

  void _applyFilters() {
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(
        backgroundColor: context.bc.surface,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: context.bc.subtle,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              hintStyle: TextStyle(color: context.bc.muted, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: context.bc.textSecondary, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFFfa4e1c)),
            onPressed: _performSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active category filter (opened from a Home category)
          if (categoryId != null)
            Container(
              width: double.infinity,
              color: context.bc.surface,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  label: Text('Category: ${widget.categoryName ?? categoryId}'),
                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  backgroundColor: const Color(0xFFfa4e1c),
                  deleteIconColor: Colors.white,
                  side: BorderSide.none,
                  onDeleted: () {
                    setState(() => categoryId = null);
                    _loadProducts();
                  },
                ),
              ),
            ),

          // Search results header
          if (searchQuery.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.bc.surface,
                border: Border(
                  bottom: BorderSide(color: context.bc.border),
                ),
              ),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: context.bc.textSecondary),
                  children: [
                    const TextSpan(text: 'Search results for '),
                    TextSpan(
                      text: '"$searchQuery"',
                      style: const TextStyle(
                        color: Color(0xFFfa4e1c),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' — '),
                    TextSpan(
                      text: '${products.length} item${products.length != 1 ? 's' : ''} found',
                      style: TextStyle(color: context.bc.text),
                    ),
                  ],
                ),
              ),
            ),

          // Sort bar
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.bc.subtle,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: context.bc.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sort buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.bc.textSecondary,
                      ),
                    ),
                    _buildSortButton('Relevance', 'newest'),
                    _buildSortButton('Price: Low to High', 'price_low'),
                    _buildSortButton('Price: High to Low', 'price_high'),
                  ],
                ),
                const SizedBox(height: 12),
                // Price range
                Row(
                  children: [
                    Text(
                      'Price',
                      style: TextStyle(fontSize: 12, color: context.bc.muted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _minPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Min',
                          prefixText: '₱ ',
                          filled: true,
                          fillColor: context.bc.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: context.bc.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: context.bc.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–', style: TextStyle(color: context.bc.muted)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _maxPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Max',
                          prefixText: '₱ ',
                          filled: true,
                          fillColor: context.bc.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: context.bc.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: context.bc.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFfa4e1c),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Products grid
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFfa4e1c),
                    ),
                  )
                : RefreshIndicator(
                    color: const Color(0xFFfa4e1c),
                    onRefresh: () => _loadProducts(silent: true),
                    child: products.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Column(
                          children: [
                            const Text('🔍', style: TextStyle(fontSize: 60)),
                            const SizedBox(height: 20),
                            Text(
                              searchQuery.isNotEmpty
                                  ? 'No results for "$searchQuery"'
                                  : 'No products found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.bc.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try checking your spelling or use more general terms',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.bc.muted,
                              ),
                            ),
                          ],
                          ),
                        ],
                      )
                    : GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) =>
                            BuyerProductCard(product: Map<String, dynamic>.from(products[index])),
                      ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton(String label, String value) {
    final isSelected = sortBy == value;
    return InkWell(
      onTap: () {
        setState(() => sortBy = value);
        _loadProducts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFfa4e1c) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFFfa4e1c) : context.bc.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : context.bc.textSecondary,
          ),
        ),
      ),
    );
  }
}
