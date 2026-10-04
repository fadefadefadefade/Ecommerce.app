import 'package:flutter/material.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import 'seller_order_details_screen.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Order> _orders = [];
  Map<String, int> _statusCounts = {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String _selectedStatus = 'all';
  String _searchQuery = '';
  int _currentPage = 1;
  bool _hasMoreData = true;

  // Tab options with status filters
  final List<Map<String, String>> _tabs = [
    {'key': 'all', 'label': 'All', 'status': ''},
    {'key': 'pending', 'label': 'Pending', 'status': 'Pending'},
    {'key': 'processing', 'label': 'Processing', 'status': 'Processing'},
    {'key': 'shipped', 'label': 'Shipped', 'status': 'Shipped'},
    {'key': 'delivered', 'label': 'Delivered', 'status': 'Delivered'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedStatus = _tabs[_tabController.index]['key']!;
        _currentPage = 1;
        _hasMoreData = true;
      });
      _loadOrders(refresh: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreOrders();
      }
    }
  }

  Future<void> _loadOrders({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _orders.clear();
        _currentPage = 1;
        _hasMoreData = true;
      });
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await OrderService.getSellerOrders(
        page: _currentPage,
        status: _selectedStatus == 'all' ? null : _tabs.firstWhere((tab) => tab['key'] == _selectedStatus)['status'],
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (result['success']) {
        final List<Order> newOrders = result['orders'];
        setState(() {
          if (refresh || _currentPage == 1) {
            _orders = newOrders;
          } else {
            _orders.addAll(newOrders);
          }
          _statusCounts = Map<String, int>.from(result['statusCounts'] ?? {});
          _hasMoreData = newOrders.length >= 20; // Assuming 20 is page limit
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load orders: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      final result = await OrderService.getSellerOrders(
        page: _currentPage,
        status: _selectedStatus == 'all' ? null : _tabs.firstWhere((tab) => tab['key'] == _selectedStatus)['status'],
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (result['success']) {
        final List<Order> newOrders = result['orders'];
        setState(() {
          _orders.addAll(newOrders);
          _hasMoreData = newOrders.length >= 20;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _currentPage--; // Revert page increment
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _currentPage--; // Revert page increment
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
      _hasMoreData = true;
    });
    _loadOrders(refresh: true);
  }

  Future<void> _refreshOrders() async {
    await _loadOrders(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfa4e1c),
        foregroundColor: Colors.white,
        title: const Text('My Orders'),
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search orders...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.7)),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
              // Status Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: _tabs.map((tab) {
                  final count = _statusCounts[tab['key']] ?? 0;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tab['label']!),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count.toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        color: const Color(0xFFfa4e1c),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFfa4e1c),
        ),
      );
    }

    if (_error != null && _orders.isEmpty) {
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
            Text(
              'Error Loading Orders',
              style: const TextStyle(
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
              onPressed: _refreshOrders,
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

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: const Color(0xFF8a7a70).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No orders found for "$_searchQuery"'
                  : _selectedStatus == 'all' 
                      ? 'No orders yet'
                      : 'No ${_tabs.firstWhere((tab) => tab['key'] == _selectedStatus)['label']?.toLowerCase()} orders',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8a7a70),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search terms'
                  : 'Orders will appear here once customers place them',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF8a7a70).withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _orders.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFfa4e1c),
              ),
            ),
          );
        }

        return _buildOrderCard(_orders[index]);
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    final statusColors = OrderService.getStatusColor(order.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SellerOrderDetailsScreen(orderId: order.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222222),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(int.parse(statusColors['bg']!.replaceAll('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      OrderService.getStatusBadgeText(order.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(int.parse(statusColors['text']!.replaceAll('#', '0xFF'))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Customer Info
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: const Color(0xFF8a7a70),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8a7a70),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Date
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: const Color(0xFF8a7a70),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    OrderService.formatOrderDate(order.createdAt),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8a7a70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Order Items Summary
              Text(
                '${order.sellerItems.length} item${order.sellerItems.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8a7a70),
                ),
              ),
              const SizedBox(height: 8),
              
              // Financial Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Earnings',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8a7a70),
                        ),
                      ),
                      Text(
                        OrderService.formatCurrency(order.sellerEarnings),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Value',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8a7a70),
                        ),
                      ),
                      Text(
                        OrderService.formatCurrency(order.sellerSubtotal),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}