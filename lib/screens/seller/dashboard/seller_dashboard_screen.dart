import 'package:flutter/material.dart';
import '../../../widgets/product_thumb.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() => _isLoading = true);
      
      final data = ApiService.unwrap(await ApiService.get('/seller/dashboard'));
      if (!mounted) return;

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Header
                    _buildHeader(),
                    
                    const SizedBox(height: 24),
                    
                    // Stats Cards
                    _buildStatsCards(),
                    
                    const SizedBox(height: 24),
                    
                    // Commission Info
                    _buildCommissionInfo(),
                    
                    const SizedBox(height: 24),
                    
                    // Recent Orders
                    _buildRecentOrders(),
                    
                    const SizedBox(height: 80), // Bottom navigation padding
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seller Center',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFfa4e1c),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome back, ${authProvider.user?.name ?? 'Seller'}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Platform commission: ${_dashboardData['commissionRate']?.toStringAsFixed(0) ?? '10'}% per sale',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6b90aa),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsCards() {
    final stats = [
      {
        'title': 'My Products',
        'value': '${_dashboardData['totalProducts'] ?? 0}',
        'gradient': const LinearGradient(
          colors: [Color(0xFF002b4d), Color(0xFF003d6b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'title': 'Total Orders', 
        'value': '${_dashboardData['totalOrders'] ?? 0}',
        'gradient': const LinearGradient(
          colors: [Color(0xFFfa4e1c), Color(0xFFfb7048)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'title': 'Gross Revenue',
        'value': '₱${(_dashboardData['grossRevenue'] ?? 0.0).toStringAsFixed(2)}',
        'subtitle': 'Before ${_dashboardData['commissionRate']?.toStringAsFixed(0) ?? '10'}% commission',
        'gradient': const LinearGradient(
          colors: [Color(0xFF002b4d), Color(0xFF004a80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
      {
        'title': 'My Earnings',
        'value': '₱${(_dashboardData['totalEarnings'] ?? 0.0).toStringAsFixed(2)}',
        'subtitle': 'After deducting ₱${(_dashboardData['totalCommission'] ?? 0.0).toStringAsFixed(2)} commission',
        'gradient': const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: stat['gradient'] as Gradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Decorative circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stat['title'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat['value'] as String,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (stat['subtitle'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  stat['subtitle'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommissionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFe8f0f6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFcfdce8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(0xFF002b4d),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Platform commission of ${_dashboardData['commissionRate']?.toStringAsFixed(0) ?? '10'}% is automatically deducted from each sale. Your earnings shown above are net amounts.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF002b4d),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    final recentOrders = _dashboardData['recentOrders'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Orders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 12),
        
        if (recentOrders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 48,
                  color: Color(0xFF8a7a70),
                ),
                SizedBox(height: 12),
                Text(
                  'No orders yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8a7a70),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentOrders.length,
            itemBuilder: (context, index) {
              final order = recentOrders[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6D9CF)),
                ),
                child: Row(
                  children: [
                    if (order['image'] != null)
                      ProductThumb(url: order['image'], size: 40)
                    else
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getStatusColor(order['status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getStatusIcon(order['status']),
                          color: _getStatusColor(order['status']),
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order['id']}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF222222),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order['customer'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6b90aa),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${(order['total'] as num? ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order['status'],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(order['status']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'processing':
        return Icons.inventory;
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }
}