import 'package:flutter/material.dart';
import '../../../widgets/product_thumb.dart';
import '../../../models/seller_product.dart';
import '../../../services/seller_api_service.dart';
import 'add_edit_product_screen.dart';
import 'product_actions_screen.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  final SellerApiService _apiService = SellerApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<SellerProduct> _products = [];
  Map<String, int> _counts = {
    'active': 0,
    'draft': 0,
    'inactive': 0,
    'low_stock': 0,
    'out_of_stock': 0,
    'archived': 0,
  };
  
  String _currentStatus = 'active';
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMorePages = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMorePages = true;
      _products.clear();
    }

    if (_isLoading || !_hasMorePages) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await _apiService.getProducts(
        page: _currentPage,
        status: _currentStatus,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      final List<SellerProduct> newProducts = result['products'];
      final pagination = result['pagination'];

      setState(() {
        if (_currentPage == 1) {
          _products = newProducts;
        } else {
          _products.addAll(newProducts);
        }
        
        _hasMorePages = _currentPage < (pagination['last_page'] ?? 1);
        _currentPage++;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await _apiService.getProductCounts();
      setState(() {
        _counts = counts;
      });
    } catch (e) {
      // Silently fail for counts
    }
  }

  void _onStatusChanged(String status) {
    if (status != _currentStatus) {
      setState(() {
        _currentStatus = status;
        _products.clear();
        _currentPage = 1;
        _hasMorePages = true;
      });
      _loadProducts();
    }
  }

  void _onSearchChanged() {
    _loadProducts(refresh: true);
  }

  Future<void> _refreshProducts() async {
    await _loadProducts(refresh: true);
    await _loadCounts();
  }

  Future<void> _showProductActions(SellerProduct product) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductActionsScreen(
          product: product,
          onProductUpdated: () => _refreshProducts(),
        ),
      ),
    );
    
    // If product was deleted, refresh the list
    if (result == true) {
      _refreshProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfa4e1c),
        foregroundColor: Colors.white,
        title: const Text('My Products'),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push<SellerProduct>(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEditProductScreen(),
                ),
              );
              if (result != null) {
                _refreshProducts();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status tabs
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildStatusTab('active', 'Active', _counts['active'] ?? 0),
                  const SizedBox(width: 8),
                  _buildStatusTab('draft', 'Drafts', _counts['draft'] ?? 0),
                  const SizedBox(width: 8),
                  _buildStatusTab('inactive', 'Inactive', _counts['inactive'] ?? 0),
                  const SizedBox(width: 8),
                  _buildStatusTab('low_stock', 'Low Stock', _counts['low_stock'] ?? 0),
                  const SizedBox(width: 8),
                  _buildStatusTab('out_of_stock', 'Out of Stock', _counts['out_of_stock'] ?? 0),
                  const SizedBox(width: 8),
                  _buildStatusTab('archived', 'Archived', _counts['archived'] ?? 0),
                ],
              ),
            ),
          ),
          
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFcfdce8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFfa4e1c)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _onSearchChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onSearchChanged,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFfa4e1c),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Search'),
                ),
                if (_searchController.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged();
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
          ),
          
          // Products list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshProducts,
              child: _buildProductsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String status, String label, int count) {
    final isActive = _currentStatus == status;
    return GestureDetector(
      onTap: () => _onStatusChanged(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFfa4e1c) : const Color(0xFFe8f0f6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : const Color(0xFFfa4e1c),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    if (_hasError && _products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFF8a7a70),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading products',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8a7a70),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshProducts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(),
              size: 64,
              color: const Color(0xFF8a7a70),
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptySubtitle(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8a7a70),
              ),
            ),
            if (_currentStatus == 'active') ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push<SellerProduct>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddEditProductScreen(),
                    ),
                  );
                  if (result != null) {
                    _refreshProducts();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFfa4e1c),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add First Product'),
              ),
            ],
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo is ScrollEndNotification &&
            scrollInfo.metrics.extentAfter == 0 &&
            _hasMorePages &&
            !_isLoading) {
          _loadProducts();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _products.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          final product = _products[index];
          return _ProductCard(
            product: product,
            onTap: () => _showProductActions(product),
            onProductUpdated: (updatedProduct) {
              setState(() {
                _products[index] = updatedProduct;
              });
            },
          );
        },
      ),
    );
  }

  IconData _getEmptyIcon() {
    switch (_currentStatus) {
      case 'archived': return Icons.archive_outlined;
      case 'low_stock': return Icons.warning_outlined;
      case 'out_of_stock': return Icons.block;
      case 'draft': return Icons.drafts;
      case 'inactive': return Icons.visibility_off_outlined;
      default: return Icons.inventory_2_outlined;
    }
  }

  String _getEmptyTitle() {
    switch (_currentStatus) {
      case 'archived': return 'No archived products';
      case 'low_stock': return 'No low-stock products';
      case 'out_of_stock': return 'All products are in stock';
      case 'draft': return 'No draft products';
      case 'inactive': return 'No inactive products';
      default: return 'No products listed yet';
    }
  }

  String _getEmptySubtitle() {
    switch (_currentStatus) {
      case 'archived': return 'Archived products will appear here';
      case 'low_stock': return 'Products with low stock will appear here';
      case 'out_of_stock': return 'Out of stock products will appear here';
      case 'draft': return 'Save products as drafts to find them here';
      case 'inactive': return 'Products you hide from buyers will appear here';
      default: return 'Add your first product to get started';
    }
  }
}

// Quick stock update button for low stock items
class _QuickStockButton extends StatefulWidget {
  final SellerProduct product;
  final Function(SellerProduct)? onUpdated;

  const _QuickStockButton({
    required this.product,
    this.onUpdated,
  });

  @override
  State<_QuickStockButton> createState() => _QuickStockButtonState();
}

class _QuickStockButtonState extends State<_QuickStockButton> {
  final _apiService = SellerApiService();
  bool _isUpdating = false;

  Future<void> _quickRestock() async {
    setState(() => _isUpdating = true);
    
    try {
      // Add 10 stock for quick restock
      final newStock = widget.product.stock + 10;
      final updatedProduct = await _apiService.updateStock(widget.product.id!, newStock);
      
      widget.onUpdated?.call(updatedProduct);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock updated to $newStock')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating stock: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isUpdating ? null : _quickRestock,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFfa4e1c).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFfa4e1c), width: 1),
        ),
        child: _isUpdating
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFfa4e1c)),
                ),
              )
            : const Text(
                '+10',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFfa4e1c),
                ),
              ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final SellerProduct product;
  final VoidCallback onTap;
  final Function(SellerProduct)? onProductUpdated;

  const _ProductCard({
    required this.product,
    required this.onTap,
    this.onProductUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = product.statusStyle;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product image
              ProductThumb(url: product.primaryImageUrl, size: 64, radius: 6),
              const SizedBox(width: 12),
              
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.author != null || product.brand != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.author ?? product.brand!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6b90aa),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₱${product.effectivePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFfa4e1c),
                          ),
                        ),
                        if (product.hasDiscount) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₱${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6b90aa),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Stock: ${product.stock}',
                          style: TextStyle(
                            fontSize: 12,
                            color: product.stock == 0 
                                ? const Color(0xFFDC2626)
                                : product.isLowStock() 
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF6b90aa),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quick stock buttons for low/out of stock
                        if (product.stock <= 5) ...[
                          _QuickStockButton(
                            product: product,
                            onUpdated: (updatedProduct) {
                              onProductUpdated?.call(updatedProduct);
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(int.parse(statusStyle['bg']!.substring(1), radix: 16) + 0xFF000000),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusStyle['label']!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(int.parse(statusStyle['color']!.substring(1), radix: 16) + 0xFF000000),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}