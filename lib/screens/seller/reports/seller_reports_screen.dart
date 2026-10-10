import 'package:flutter/material.dart';
import '../../../widgets/product_thumb.dart';
import 'package:intl/intl.dart';
import '../../../services/report_service.dart';
import '../../../widgets/date_range_picker_widget.dart';

class SellerReportsScreen extends StatefulWidget {
  const SellerReportsScreen({super.key});

  @override
  State<SellerReportsScreen> createState() => _SellerReportsScreenState();
}

class _SellerReportsScreenState extends State<SellerReportsScreen> {
  SalesReport? _salesReport;
  bool _isLoading = false;
  String? _error;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  bool _showFilters = false;
  
  @override
  void initState() {
    super.initState();
    _loadSalesReport();
  }

  Future<void> _loadSalesReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ReportService.getSalesReport(
        from: _fromDate,
        to: _toDate,
      );
      
      if (!mounted) return;
      if (result['success']) {
        setState(() {
          _salesReport = result['report'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load sales report: $e';
        _isLoading = false;
      });
    }
  }

  void _onDateRangeChanged(DateTime from, DateTime to) {
    setState(() {
      _fromDate = from;
      _toDate = to;
    });
    _loadSalesReport();
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfa4e1c),
        foregroundColor: Colors.white,
        title: const Text('Reports & Analytics'),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_outlined),
            onPressed: _toggleFilters,
            tooltip: 'Date Filters',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _showExportOptions();
              } else if (value == 'refresh') {
                _loadSalesReport();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export Report'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSalesReport,
        color: const Color(0xFFfa4e1c),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Expandable Filters Section
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _showFilters ? null : 0,
          child: _showFilters
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: DateRangePickerWidget(
                    initialFromDate: _fromDate,
                    initialToDate: _toDate,
                    onDateRangeChanged: _onDateRangeChanged,
                  ),
                )
              : null,
        ),
        
        // Main Content
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFfa4e1c),
            ),
            SizedBox(height: 16),
            Text(
              'Loading analytics...',
              style: TextStyle(
                color: Color(0xFF8a7a70),
              ),
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
              'Error Loading Reports',
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
              onPressed: _loadSalesReport,
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

    if (_salesReport == null) {
      return const Center(
        child: Text('No data available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_showFilters) _buildDateRangeHeader(),
          if (!_showFilters) const SizedBox(height: 16),
          _buildMetricsOverview(),
          const SizedBox(height: 16),
          _buildFinancialSummary(),
          const SizedBox(height: 16),
          _buildPerformanceMetrics(),
          if (_salesReport!.productPerformance.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTopProductsSection(),
          ],
          if (_salesReport!.salesTrend.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSalesTrendSection(),
          ],
          const SizedBox(height: 16),
          _buildInsightsSection(),
        ],
      ),
    );
  }

  Widget _buildDateRangeHeader() {
    final formatter = DateFormat('MMM d, y');
    final daysDiff = _toDate.difference(_fromDate).inDays;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Report Period',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFfa4e1c).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${daysDiff + 1} days',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFfa4e1c),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.date_range,
                size: 16,
                color: const Color(0xFF8a7a70),
              ),
              const SizedBox(width: 8),
              Text(
                '${formatter.format(_fromDate)} - ${formatter.format(_toDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8a7a70),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _toggleFilters,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Change'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFfa4e1c),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    final insights = _generateInsights();
    if (insights.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: const Color(0xFFfa4e1c),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Insights & Recommendations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...insights.map((insight) => _buildInsightItem(insight)),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEEE8).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFfa4e1c).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFfa4e1c),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF222222),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _generateInsights() {
    if (_salesReport == null) return [];
    
    final insights = <String>[];
    final report = _salesReport!;
    
    // Profit margin insights
    if (report.profitMargin < 30) {
      insights.add('Your profit margin is ${report.profitMargin.toStringAsFixed(1)}%. Consider optimizing pricing or reducing costs.');
    } else if (report.profitMargin > 70) {
      insights.add('Excellent profit margin of ${report.profitMargin.toStringAsFixed(1)}%! Your pricing strategy is working well.');
    }
    
    // Order volume insights
    if (report.totalOrders < 5) {
      insights.add('Low order volume detected. Consider promoting your products or improving visibility.');
    } else if (report.totalOrders > 50) {
      insights.add('Great job! You have ${report.totalOrders} orders in this period. Keep up the momentum.');
    }
    
    // Product performance insights
    if (report.productPerformance.length == 1) {
      insights.add('Consider diversifying your product portfolio to increase sales opportunities.');
    } else if (report.productPerformance.isNotEmpty) {
      final topProduct = report.productPerformance.first;
      final topProductShare = (topProduct.revenue / report.totalRevenue) * 100;
      if (topProductShare > 70) {
        insights.add('${topProduct.title} generates ${topProductShare.toStringAsFixed(0)}% of your revenue. Consider promoting other products too.');
      }
    }
    
    // Average order value insights
    if (report.averageOrderValue < 500) {
      insights.add('Average order value is ₱${report.averageOrderValue.toStringAsFixed(0)}. Try bundling products or upselling to increase it.');
    }
    
    return insights;
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Export Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                // Implement PDF export
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF export feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export as Excel'),
              onTap: () {
                Navigator.pop(context);
                // Implement Excel export
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Excel export feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Report'),
              onTap: () {
                Navigator.pop(context);
                // Implement sharing
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sharing feature coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsOverview() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Total Orders',
            value: _salesReport!.totalOrders.toString(),
            icon: Icons.shopping_cart_outlined,
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Avg Order',
            value: _salesReport!.formattedAverageOrderValue,
            icon: Icons.trending_up,
            color: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Financial Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 16),
          _buildFinancialRow(
            'Gross Revenue',
            _salesReport!.formattedTotalRevenue,
            const Color(0xFF3B82F6),
          ),
          _buildFinancialRow(
            'Platform Commission (${_salesReport!.commissionRate}%)',
            '- ${_salesReport!.formattedTotalCommission}',
            Colors.red,
          ),
          const Divider(height: 24),
          _buildFinancialRow(
            'Net Earnings',
            _salesReport!.formattedTotalEarnings,
            const Color(0xFF10B981),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    final profitMargin = _salesReport!.profitMargin;
    final productCount = _salesReport!.productPerformance.length;
    
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Profit Margin',
            value: '${profitMargin.toStringAsFixed(1)}%',
            icon: Icons.percent,
            color: profitMargin >= 50 ? const Color(0xFF10B981) : 
                   profitMargin >= 30 ? const Color(0xFFF59E0B) : Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Products Sold',
            value: productCount.toString(),
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductsSection() {
    final topProducts = _salesReport!.productPerformance.take(5).toList();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Products',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to detailed product performance
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...topProducts.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            return _buildProductRow(product, index + 1);
          }),
        ],
      ),
    );
  }

  Widget _buildProductRow(ProductPerformance product, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEEE8).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rank <= 3 ? const Color(0xFFfa4e1c) : const Color(0xFF8a7a70),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                rank.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ProductThumb(url: product.product?.primaryImageUrl, size: 40, radius: 6),
          const SizedBox(width: 10),
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
                const SizedBox(height: 4),
                Text(
                  '${product.quantity} sold • ${product.formattedEarnings} earned',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8a7a70),
                  ),
                ),
              ],
            ),
          ),
          Text(
            product.formattedRevenue,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTrendSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildSimpleChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleChart() {
    final trends = _salesReport!.salesTrend;
    if (trends.isEmpty) {
      return const Center(
        child: Text(
          'No trend data available',
          style: TextStyle(color: Color(0xFF8a7a70)),
        ),
      );
    }

    final maxEarnings = trends.map((t) => t.earnings).reduce((a, b) => a > b ? a : b);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: trends.take(10).map((trend) {
        final height = maxEarnings > 0 ? (trend.earnings / maxEarnings) * 160 : 0.0;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 20,
              height: height > 4 ? height : 4,
              decoration: BoxDecoration(
                color: const Color(0xFFfa4e1c),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              trend.date.length > 6 ? trend.date.substring(0, 6) : trend.date,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8a7a70),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8a7a70),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String amount, Color color, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? const Color(0xFF222222) : const Color(0xFF8a7a70),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}