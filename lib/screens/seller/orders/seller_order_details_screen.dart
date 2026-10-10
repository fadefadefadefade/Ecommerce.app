import 'package:flutter/material.dart';
import '../../../widgets/reason_dialog.dart';
import '../../../widgets/order_progress.dart';
import '../../../widgets/product_thumb.dart';
import 'package:intl/intl.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import '../../../services/order_service.dart';

class SellerOrderDetailsScreen extends StatefulWidget {
  final int orderId;
  
  const SellerOrderDetailsScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<SellerOrderDetailsScreen> createState() => _SellerOrderDetailsScreenState();
}

class _SellerOrderDetailsScreenState extends State<SellerOrderDetailsScreen> {
  Order? _order;
  Map<String, dynamic>? _parcel;
  bool _isLoading = true;
  String? _error;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await OrderService.getOrderDetails(widget.orderId);
      
      if (result['success']) {
        setState(() {
          _order = result['order'];
          _parcel = result['parcel'];
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
        _error = 'Failed to load order details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(String newStatus, {String? reason}) async {
    if (_order == null || _isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final result = await OrderService.updateOrderStatus(widget.orderId, newStatus, reason: reason);
      if (!mounted) return;

      if (result['success']) {
        setState(() {
          _order = result['order'];
          _isUpdatingStatus = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isUpdatingStatus = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmShipToWarehouse() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ship to warehouse?'),
        content: const Text(
          'A parcel will be created and sent to the sorting center. '
          'Logistics will assign a courier, who will deliver it to the buyer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: stageColor('warehouse'), foregroundColor: Colors.white),
            child: const Text('Ship to Warehouse'),
          ),
        ],
      ),
    );
    if (ok == true) _updateOrderStatus('Shipped');
  }

  Future<void> _confirmCancel() async {
    final reason = await showReasonDialog(
      context,
      title: 'Cancel this order?',
      message: 'The buyer will see the reason. Items go back to your stock.',
      hint: 'e.g. Item is out of stock',
      confirmLabel: 'Cancel Order',
      cancelLabel: 'Keep Order',
      confirmColor: stageColor('cancelled'),
      maxLength: 300,
    );
    if (reason != null && mounted) _updateOrderStatus('Cancelled', reason: reason);
  }

  /// The seller's next step for the current stage.
  Widget _buildSellerActions() {
    final stage = _order!.stage;
    if (_isUpdatingStatus) return const SizedBox.shrink();

    Widget cancelButton() => TextButton.icon(
          onPressed: _confirmCancel,
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('Cancel Order'),
          style: TextButton.styleFrom(foregroundColor: stageColor('cancelled')),
        );

    Widget primary(String label, IconData icon, String color, VoidCallback onPressed) => SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: stageColor(color),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        );

    switch (stage) {
      case 'pending':
        return Column(children: [
          primary('Start Processing', Icons.inventory_2_outlined, 'processing', () => _updateOrderStatus('Processing')),
          cancelButton(),
        ]);
      case 'processing':
        return Column(children: [
          primary('Ship to Warehouse', Icons.warehouse_outlined, 'warehouse', _confirmShipToWarehouse),
          cancelButton(),
        ]);
      case 'warehouse':
      case 'delivering':
        return _note(Icons.local_shipping_outlined,
            stage == 'warehouse'
                ? 'With logistics. A courier will be assigned and will update the delivery.'
                : 'Out for delivery. The courier will mark it delivered.');
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _note(IconData icon, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1565C0), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF222222)))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfa4e1c),
        foregroundColor: Colors.white,
        title: Text('Order #${widget.orderId}'),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFfa4e1c),
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
              'Error Loading Order',
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
              onPressed: _loadOrderDetails,
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

    if (_order == null) {
      return const Center(child: Text('Order not found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildCustomerCard(),
          const SizedBox(height: 16),
          _buildItemsCard(),
          const SizedBox(height: 16),
          _buildFinancialSummary(),
          if (_order!.delivery != null) ...[
            const SizedBox(height: 16),
            _buildDeliveryCard(),
          ],
          if (_parcel != null) ...[
            const SizedBox(height: 16),
            _buildParcelCard(),
          ],
        ],
      ),
    );
  }

  /// What the seller should know/do at each step.
  static const _sellerStepHints = {
    'pending': 'New order. Confirm it to start processing.',
    'processing': 'Pack the items and hand them over for pickup.',
    'warehouse': 'The parcel is with logistics at the sorting center.',
    'delivering': 'A rider is delivering the parcel to the buyer.',
    'delivered': 'The buyer has received the order.',
  };

  Widget _buildStatusCard() {
    final statusColors = OrderService.getStatusColor(_order!.status);
    
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
                'Order Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(int.parse(statusColors['bg']!.replaceAll('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  OrderService.getStatusBadgeText(_order!.status),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(int.parse(statusColors['text']!.replaceAll('#', '0xFF'))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: const Color(0xFF8a7a70),
              ),
              const SizedBox(width: 4),
              Text(
                'Created: ${DateFormat('MMM d, y - h:mm a').format(_order!.createdAt)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8a7a70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_order!.stage == 'cancelled')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: stageColor('cancelled').withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.cancel, color: stageColor('cancelled')),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'This order was cancelled.',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF222222)),
                    ),
                  ),
                ],
              ),
            )
          else
            OrderProgressTimeline(stage: _order!.stage, hints: _sellerStepHints),
          const SizedBox(height: 16),
          _buildSellerActions(),
          if (_isUpdatingStatus) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFfa4e1c)),
                ),
                SizedBox(width: 8),
                Text('Updating status...', style: TextStyle(color: Color(0xFF8a7a70))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
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
            'Customer Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.person, 'Name', _order!.fullName),
          _buildInfoRow(Icons.email, 'Email', _order!.email),
          _buildInfoRow(Icons.phone, 'Phone', _order!.phone),
          _buildInfoRow(Icons.location_on, 'Address', _order!.fullAddress),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8a7a70)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8a7a70),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
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
          Text(
            'Your Items (${_order!.sellerItems.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 12),
          ..._order!.sellerItems.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEEE8).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductThumb(url: item.product?.primaryImageUrl, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.product?.title ?? 'Product #${item.productId}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Qty: ${item.quantity} × ${item.formattedPrice}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF8a7a70),
                ),
              ),
              Text(
                item.formattedLineTotal,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Commission (${item.commissionPercentage}%)',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8a7a70),
                ),
              ),
              Text(
                '- ${item.formattedCommission}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Earning',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF059669),
                ),
              ),
              Text(
                item.formattedSellerEarning,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
        ],
            ),
          ),
        ],
      ),
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
          const SizedBox(height: 12),
          _buildSummaryRow('Subtotal', OrderService.formatCurrency(_order!.sellerSubtotal)),
          _buildSummaryRow('Platform Commission', '- ${OrderService.formatCurrency(_order!.sellerCommission)}', isNegative: true),
          const Divider(),
          _buildSummaryRow('Your Earnings', OrderService.formatCurrency(_order!.sellerEarnings), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String amount, {bool isNegative = false, bool isTotal = false}) {
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
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal 
                  ? const Color(0xFF059669) 
                  : isNegative 
                      ? Colors.red 
                      : const Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard() {
    final delivery = _order!.delivery!;
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
            'Delivery Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.local_shipping, 'Courier', delivery.courierName),
          if (delivery.trackingNumber != null)
            _buildInfoRow(Icons.confirmation_number, 'Tracking', delivery.trackingNumber!),
          if (delivery.pickupScheduledAt != null)
            _buildInfoRow(Icons.schedule, 'Pickup Scheduled', DateFormat('MMM d, y - h:mm a').format(delivery.pickupScheduledAt!)),
          _buildInfoRow(Icons.info, 'Status', delivery.status),
          if (delivery.notes != null)
            _buildInfoRow(Icons.note, 'Notes', delivery.notes!),
        ],
      ),
    );
  }

  Widget _buildParcelCard() {
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
            'Parcel Tracking',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 12),
          if (_parcel!['tracking_number'] != null)
            _buildInfoRow(Icons.qr_code, 'Parcel ID', _parcel!['tracking_number']),
          if (_parcel!['currentSortingCenter'] != null)
            _buildInfoRow(Icons.business, 'Sorting Center', _parcel!['currentSortingCenter']['name']),
          _buildInfoRow(Icons.info_outline, 'Parcel Status', _parcel!['status_label'] ?? _parcel!['status'] ?? 'Unknown'),
        ],
      ),
    );
  }
}