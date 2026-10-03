import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'product_detail_screen.dart';

class ShopScreen extends StatefulWidget {
  final String? initialSearch;
  
  const ShopScreen({super.key, this.initialSearch});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<dynamic> products = [];
  bool isLoading = true;
  String searchQuery = '';
  String sortBy = 'newest';
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

  Future<void> _loadProducts() async {
    setState(() => isLoading = true);
    
    try {
      final queryParams = <String, String>{
        if (searchQuery.isNotEmpty) 'search': searchQuery,
        if (sortBy.isNotEmpty) 'sort': sortBy,
        if (_minPriceController.text.isNotEmpty) 'min_price': _minPriceController.text,
        if (_maxPriceController.text.isNotEmpty) 'max_price': _maxPriceController.text,
      };
      
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final result = await ApiService.get(
        '/products${queryString.isNotEmpty ? '?$queryString' : ''}'
      );
      
      if (result['success']) {
        setState(() {
          products = result['data']['products'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF757575), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
          // Search results header
          if (searchQuery.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEFEFEF)),
                ),
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
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
                      style: const TextStyle(color: Color(0xFF222222)),
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
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFEFEFEF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sort buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555),
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
                    const Text(
                      'Price',
                      style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
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
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
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
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–', style: TextStyle(color: Color(0xFF999999))),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _maxPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Max',
                          prefixText: '₱ ',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
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
                : products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🔍', style: TextStyle(fontSize: 60)),
                            const SizedBox(height: 20),
                            Text(
                              searchQuery.isNotEmpty
                                  ? 'No results for "$searchQuery"'
                                  : 'No products found',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF222222),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try checking your spelling or use more general terms',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) =>
                            _buildProductCard(products[index]),
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
            color: isSelected ? const Color(0xFFfa4e1c) : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    final hasDiscount = product['discount_percent'] != null &&
        product['discount_percent'] > 0;
    final stock = product['stock'] ?? 0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(productId: product['id']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFEFEFEF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    child: product['image_url'] != null
                        ? Image.network(
                            product['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_not_supported,
                                  size: 40, color: Color(0xFFCCCCCC)),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.image_not_supported,
                                size: 40, color: Color(0xFFCCCCCC)),
                          ),
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    left: 0,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF002b4d),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        '-${product['discount_percent']}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Product info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF222222),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      '₱${(product['effective_price'] ?? product['price'] ?? 0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFfa4e1c),
                      ),
                    ),
                    if (hasDiscount)
                      Text(
                        '₱${(product['price'] ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                          color: Color(0xFFBBBBBB),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      stock > 0 ? '$stock in stock' : 'Out of stock',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
