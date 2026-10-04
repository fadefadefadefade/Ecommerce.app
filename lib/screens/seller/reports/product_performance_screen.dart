import 'package:flutter/material.dart';
import '../../../services/report_service.dart';
import '../../../widgets/product_performance_widgets.dart';
import '../../../widgets/date_range_picker_widget.dart';

class ProductPerformanceScreen extends StatefulWidget {
  const ProductPerformanceScreen({super.key});

  @override
  State<ProductPerformanceScreen> createState() => _ProductPerformanceScreenState();
}

class _ProductPerformanceScreenState extends State<ProductPerformanceScreen> {
  List<ProductPerformance> _products = [];
  SalesReport? _salesReport;
  bool _isLoading = false;
  String? _error;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String _sortBy = 'revenue'; // revenue, earnings, quantity, profitMargin
  bool _sortDescending = true;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadProductPerformance();
  }

  Future<void> _loadProductPerformance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [productResult, reportResult] = await Future.wait([
        ReportService.getProductPerformance(
          from: _fromDate,
          to: _toDate,
          limit: 50,
        ),
        ReportService.getSalesReport(
          from: _fromDate,
          to: _toDate,
        ),
      ]);

      if (productResult['success'] && reportResult['success']) {
        setState(() {
          _products = productResult['products'];
          _salesReport = reportResult['report'];
          _sortProducts();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = productResult['message'] ?? reportResult['message'] ?? 'Failed to load data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load product performance: $e';
        _isLoading = false;
      });
    }
  }

  void _sortProducts() {
    _products.sort((a, b) {
      double valueA, valueB;
      
      switch (_sortBy) {
        case 'revenue':
          valueA = a.revenue;
          valueB = b.revenue;
          break;
        case 'earnings':
          valueA = a.earnings;
          valueB = b.earnings;
          break;
        case 'quantity':
          valueA = a.quantity.toDouble();
          valueB = b.quantity.toDouble();
          break;
        case 'profitMargin':
          valueA = a.profitMargin;
          valueB = b.profitMargin;
          break;
        default:
          valueA = a.revenue;
          valueB = b.revenue;
      }

      return _sortDescending ? valueB.compareTo(valueA) : valueA.compareTo(valueB);
    });
  }

  void _onDateRangeChanged(DateTime from, DateTime to) {
    setState(() {
      _fromDate = from;
      _toDate = to;
    });
    _loadProductPerformance();
  }

  void _changeSortOrder(String newSortBy) {
    setState(() {
      if (_sortBy == newSortBy) {
        _sortDescending = !_sortDescending;
      } else {
        _sortBy = newSortBy;
        _sortDescending = true;
      }
      _sortProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfa4e1c),
        foregroundColor: Colors.white,
        title: const Text('Product Performance'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_outlined),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: _changeSortOrder,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'revenue',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'revenue' ? Icons.check : Icons.attach_money,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort by Revenue'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'earnings',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'earnings' ? Icons.check : Icons.account_balance_wallet,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort by Earnings'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'quantity',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'quantity' ? Icons.check : Icons.shopping_cart,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort by Units Sold'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'profitMargin',
                child: Row(
                  children: [
                    Icon(
                      _sortBy == 'profitMargin' ? Icons.check : Icons.percent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sort by Profit Margin'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProductPerformance,
        color: const Color(0xFFfa4e1c),
        child: Column(
          children: [
            // Filters Section
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showFilters ? null : 0,
              child: _showFilters
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          DateRangePickerWidget(
                            initialFromDate: _fromDate,
                            initialToDate: _toDate,
                            onDateRangeChanged: _onDateRangeChanged,
                          ),
                          const SizedBox(height: 16),
                          _buildSortControls(),
                        ],
                      ),
                    )
                  : null,
            ),
            
            // Main Content
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sort & Filter Options',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSortChip('Revenue', 'revenue'),
              _buildSortChip('Earnings', 'earnings'),
              _buildSortChip('Units Sold', 'quantity'),
              _buildSortChip('Profit Margin', 'profitMargin'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Order:',
                style: TextStyle(fontSize: 14, color: Color(0xFF8a7a70)),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('High to Low'),
                selected: _sortDescending,
                onSelected: (selected) {
                  setState(() {
                    _sortDescending = true;
                    _sortProducts();
                  });
                },
                selectedColor: const Color(0xFFfa4e1c).withOpacity(0.2),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Low to High'),
                selected: !_sortDescending,
                onSelected: (selected) {
                  setState(() {
                    _sortDescending = false;
                    _sortProducts();
                  });
                },
                selectedColor: const Color(0xFFfa4e1c).withOpacity(0.2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => _changeSortOrder(value),
      selectedColor: const Color(0xFFfa4e1c).withOpacity(0.2),
      checkmarkColor: const Color(0xFFfa4e1c),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFfa4e1c)),
            SizedBox(height: 16),
            Text(
              'Loading product analytics...',
              style: TextStyle(color: Color(0xFF8a7a70)),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Product Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8a7a70),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProductPerformance,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFfa4e1c),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Color(0xFF8a7a70),
            ),
            SizedBox(height: 16),
            Text(
              'No Product Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No products sold in the selected period',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8a7a70),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats
          QuickProductStatsWidget(products: _products),
          const SizedBox(height: 16),
          
          // Product Comparison Chart
          ProductComparisonWidget(
            products: _products,
            comparisonMetric: _sortBy,
          ),
          const SizedBox(height: 16),
          
          // Insights
          ProductAnalyticsInsightsWidget(
            products: _products,
            salesReport: _salesReport,
          ),
          const SizedBox(height: 16),
          
          // Sort indicator and product count
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_products.length} Products',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Sorted by ${_getSortDisplayName(_sortBy)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8a7a70),
                      ),
                    ),
                    Icon(
                      _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 16,
                      color: const Color(0xFF8a7a70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Product List
          ...List.generate(_products.length, (index) {
            final product = _products[index];
            return ProductPerformanceCard(
              product: product,
              rank: index + 1,
              onTap: () => _showProductDetails(product),
            );
          }),
        ],
      ),
    );
  }

  String _getSortDisplayName(String sortBy) {
    switch (sortBy) {
      case 'revenue':
        return 'Revenue';
      case 'earnings':
        return 'Earnings';
      case 'quantity':
        return 'Units Sold';
      case 'profitMargin':
        return 'Profit Margin';
      default:
        return 'Revenue';
    }
  }

  void _showProductDetails(ProductPerformance product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product header
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                      if (product.product?.brand != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.product!.brand!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8a7a70),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      
                      // Detailed metrics
                      _buildDetailedMetrics(product),
                      const SizedBox(height: 20),
                      
                      // Product trend (if available)
                      if (_salesReport?.salesTrend.isNotEmpty == true)
                        ProductTrendWidget(
                          trends: _salesReport!.salesTrend,
                          productName: product.title,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedMetrics(ProductPerformance product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEEE8).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDetailMetric(
                  'Units Sold',
                  product.quantity.toString(),
                  Icons.shopping_cart_outlined,
                ),
              ),
              Expanded(
                child: _buildDetailMetric(
                  'Total Revenue',
                  product.formattedRevenue,
                  Icons.attach_money,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailMetric(
                  'Your Earnings',
                  product.formattedEarnings,
                  Icons.account_balance_wallet,
                ),
              ),
              Expanded(
                child: _buildDetailMetric(
                  'Commission Paid',
                  product.formattedCommission,
                  Icons.receipt_long,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailMetric(
                  'Avg Price',
                  product.formattedAveragePrice,
                  Icons.price_change,
                ),
              ),
              Expanded(
                child: _buildDetailMetric(
                  'Profit Margin',
                  '${product.profitMargin.toStringAsFixed(1)}%',
                  Icons.percent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFfa4e1c), size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8a7a70),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}