import 'package:flutter/material.dart';
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

  Future<void> _updateOrderStatus(String newStatus) async {
    if (_order == null || _isUpdatingStatus) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final result = await OrderService.updateOrderStatus(widget.orderId, newStatus);
      
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

  void _showStatusUpdateDialog() {
    if (_order == null) return;
    
    final possibleStatuses = OrderService.getNextPossibleStatuses(_order!.status);
    
    if (possibleStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No status updates available for this order'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Status: ${_order!.status}'),
            const SizedBox(height: 16),
            const Text('Select new status:'),
            ...possibleStatuses.map((status) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(status),
              onTap: () {
                Navigator.pop(context);
                _updateOrderStatus(status);
              },
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSchedulePickupDialog() {
    if (_order == null) return;

    final courierController = TextEditingController();
    final trackingController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Pickup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: courierController,
                decoration: const InputDecoration(
                  labelText: 'Courier Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: trackingController,
                decoration: const InputDecoration(
                  labelText: 'Tracking Number (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setDialogState) => InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule),
                        const SizedBox(width: 8),
                        Text(DateFormat('MMM d, y - h:mm a').format(selectedDate)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (courierController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter courier name')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              final result = await OrderService.schedulePickup(
                widget.orderId,
                courierName: courierController.text,
                trackingNumber: trackingController.text.isEmpty ? null : trackingController.text,
                pickupScheduledAt: selectedDate,
                notes: notesController.text.isEmpty ? null : notesController.text,
              );
              
              if (result['success']) {
                setState(() {
                  _order = result['order'];
                  _parcel = result['parcel'];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFfa4e1c)),
            child: const Text('Schedule Pickup'),
          ),
        ],
      ),
    );
  }

  Future<void> _markHandedOver() async {
    final result = await OrderService.markHandedOver(widget.orderId);
    
    if (result['success']) {
      setState(() {
        _order = result['order'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBEEE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFfa4e1c),
        foregroundColor: Colors.white,
        title: Text('Order #${widget.orderId}'),
        elevation: 0,
        actions: [
          if (_order != null && !_isUpdatingStatus)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                if (OrderService.getNextPossibleStatuses(_order!.status).isNotEmpty)
                  const PopupMenuItem(
                    value: 'update_status',
                    child: Row(
                      children: [
                        Icon(Icons.update),
                        SizedBox(width: 8),
                        Text('Update Status'),
                      ],
                    ),
                  ),
                if (_order!.status == 'Pending' || _order!.status == 'Processing')
                  const PopupMenuItem(
                    value: 'schedule_pickup',
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping),
                        SizedBox(width: 8),
                        Text('Schedule Pickup'),
                      ],
                    ),
                  ),
                if (_order!.status == 'Processing' && _order!.delivery != null)
                  const PopupMenuItem(
                    value: 'mark_handed_over',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 8),
                        Text('Mark Handed Over'),
                      ],
                    ),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'update_status':
                    _showStatusUpdateDialog();
                    break;
                  case 'schedule_pickup':
                    _showSchedulePickupDialog();
                    break;
                  case 'mark_handed_over':
                    _markHandedOver();
                    break;
                }
              },
            ),
        ],
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
          _buildInfoRow(Icons.info_outline, 'Parcel Status', _parcel!['status'] ?? 'Unknown'),
        ],
      ),
    );
  }
}