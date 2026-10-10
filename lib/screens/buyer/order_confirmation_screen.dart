import 'package:flutter/material.dart';
import '../../widgets/net_image.dart';
import '../../theme/buyer_colors.dart';
import '../../services/api_service.dart';
import 'buyer_main_screen.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final int orderId;

  const OrderConfirmationScreen({super.key, required this.orderId});

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  Map<String, dynamic>? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final response = ApiService.unwrap(await ApiService.get('/orders/${widget.orderId}'));
      if (!mounted) return;
      setState(() {
        _order = response['order'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFA500);
      case 'confirmed':
      case 'processing':
        return const Color(0xFF3B82F6);
      case 'shipped':
      case 'out for delivery':
        return const Color(0xFF8B5CF6);
      case 'delivered':
      case 'completed':
        return const Color(0xFF059669);
      case 'cancelled':
      case 'failed':
        return const Color(0xFFDC2626);
      default:
        return context.bc.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button, use home button instead
        return false;
      },
      child: Scaffold(
        backgroundColor: context.bc.background,
        appBar: AppBar(
          title: const Text('Order Confirmation'),
          backgroundColor: const Color(0xFFFA4E1C),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _order == null
                ? const Center(child: Text('Order not found'))
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        // Success Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFA4E1C).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 48,
                            color: Color(0xFFFA4E1C),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Title
                        Text(
                          'Order Placed!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: context.bc.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Message
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 15,
                                color: context.bc.textSecondary,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Your order has been placed successfully.\nPlease prepare ',
                                ),
                                TextSpan(
                                  text: '₱${(_order!['total_price'] ?? 0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFA4E1C),
                                  ),
                                ),
                                const TextSpan(
                                  text: '\n(including ₱50.00 delivery fee) upon delivery.',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Order Number
                        Text(
                          'Order #${_order!['order_number']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.bc.muted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Status Badges
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildStatusBadge(
                              'Order: ${_order!['status']}',
                              _getStatusColor(_order!['status']),
                            ),
                            _buildStatusBadge(
                              'Payment: ${_order!['payment_status']}',
                              const Color(0xFFFA4E1C),
                            ),
                            _buildStatusBadge(
                              '💵 Cash on Delivery',
                              context.bc.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Order Details Card
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: context.bc.surface,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Items Ordered
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Items Ordered',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: context.bc.text,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ...(_order!['items'] as List).map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: NetImage(
                                                item['product']['image_url'] ?? '',
                                                width: 40,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  width: 40,
                                                  height: 50,
                                                  color: context.bc.subtle,
                                                  child: const Icon(
                                                    Icons.shopping_bag,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['product']['title'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: context.bc.text,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Qty: ${item['quantity']} × ₱${(item['price'] ?? 0).toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: context.bc.muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '₱${(item['subtotal'] ?? 0).toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFFA4E1C),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    const Divider(height: 24),
                                    // Price Breakdown
                                    _buildPriceRow(
                                      'Subtotal',
                                      _order!['subtotal'],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildPriceRow(
                                      'Delivery Fee',
                                      _order!['shipping_fee'],
                                    ),
                                    const Divider(height: 24),
                                    _buildPriceRow(
                                      'Total (COD)',
                                      _order!['total_price'],
                                      isBold: true,
                                      isLarge: true,
                                    ),
                                  ],
                                ),
                              ),
                              // Shipping Info
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: context.bc.subtle,
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shipping To',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: context.bc.text,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _order!['full_name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: context.bc.text,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_order!['phone']} · ${_order!['email']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.bc.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _order!['shipping_address'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.bc.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Track Order Note
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFA4E1C).withOpacity(0.06),
                            border: Border.all(color: const Color(0xFFFDB49E)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Track your order anytime from My Profile → Order History',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.bc.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Navigate to home and clear all previous routes
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (context) => const BuyerMainScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF002B4D),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Continue Shopping',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    // TODO: Navigate to orders history
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Order history coming soon...'),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFFA4E1C),
                                    side: const BorderSide(
                                      color: Color(0xFFFA4E1C),
                                      width: 2,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'View Orders',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, dynamic amount, {bool isBold = false, bool isLarge = false}) {
    final price = (amount ?? 0).toDouble();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? context.bc.text : context.bc.textSecondary,
          ),
        ),
        Text(
          '₱${price.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isLarge ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? const Color(0xFFFA4E1C) : context.bc.text,
          ),
        ),
      ],
    );
  }
}

