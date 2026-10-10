import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../theme/buyer_colors.dart';
import 'account_ui.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const _steps = ['Pending', 'Processing', 'Shipped', 'Delivered'];

  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = ApiService.unwrap(await ApiService.get('/orders/${widget.orderId}'));
      if (!mounted) return;
      setState(() {
        _order = Map<String, dynamic>.from(data['order']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  String _address(Map<String, dynamic> o) {
    final parts = <String>[];
    final shipping = o['shipping_address'];
    if (shipping is Map) {
      for (final key in ['house_number', 'street', 'barangay', 'city', 'province', 'region', 'zip_code']) {
        final v = shipping[key];
        if (v != null && '$v'.trim().isNotEmpty) parts.add('$v');
      }
    } else if (shipping is String && shipping.isNotEmpty) {
      parts.add(shipping);
    }
    if (parts.isEmpty) {
      for (final key in ['address_line', 'city', 'province', 'zip_code']) {
        final v = o[key];
        if (v != null && '$v'.trim().isNotEmpty) parts.add('$v');
      }
    }
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: accountAppBar(_order != null ? 'Order #${_order!['order_number']}' : 'Order Details'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: BuyerPalette.primary))
          : _error != null
              ? AccountEmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load order',
                  message: _error!,
                  action: ElevatedButton(onPressed: _load, child: const Text('Retry')),
                )
              : RefreshIndicator(
                  color: BuyerPalette.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _buildStatus(),
                      const SizedBox(height: 12),
                      _buildItems(),
                      const SizedBox(height: 12),
                      _buildShipping(),
                      const SizedBox(height: 12),
                      _buildPayment(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatus() {
    final c = context.bc;
    final status = '${_order!['status'] ?? ''}';
    final cancelled = ['cancelled', 'failed', 'returned'].contains(status.toLowerCase());
    final current = _steps.indexWhere((s) => s.toLowerCase() == status.toLowerCase());

    return AccountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Placed ${formatDate(_order!['created_at'])}',
                    style: TextStyle(color: c.muted, fontSize: 12)),
              ),
              OrderStatusBadge(status),
            ],
          ),
          const SizedBox(height: 16),
          if (cancelled)
            Row(
              children: [
                Icon(Icons.cancel, color: orderStatusColor(status)),
                const SizedBox(width: 8),
                Text('This order was $status.', style: TextStyle(color: c.text)),
              ],
            )
          else
            Row(
              children: List.generate(_steps.length * 2 - 1, (i) {
                if (i.isOdd) {
                  final done = current >= (i ~/ 2) + 1;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: done ? BuyerPalette.primary : c.border,
                    ),
                  );
                }
                final step = i ~/ 2;
                final done = current >= step;
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: done ? BuyerPalette.primary : c.border,
                      child: Icon(done ? Icons.check : Icons.circle, size: done ? 14 : 6, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _steps[step],
                      style: TextStyle(
                        fontSize: 10,
                        color: done ? c.text : c.muted,
                        fontWeight: step == current ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildItems() {
    final c = context.bc;
    final items = (_order!['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    return AccountCard(
      title: 'Items (${items.length})',
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No items on this order.', style: TextStyle(color: c.muted)),
            )
          : Column(
              children: items.map((item) {
                final product = Map<String, dynamic>.from(item['product'] ?? {});
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 52,
                          height: 52,
                          color: c.subtle,
                          child: product['image_url'] != null
                              ? Image.network(
                                  product['image_url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(Icons.inventory_2, color: c.muted),
                                )
                              : Icon(Icons.inventory_2, color: c.muted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product['title'] ?? '—',
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text)),
                            Text('${peso(item['price'])} × ${item['quantity']}',
                                style: TextStyle(fontSize: 12, color: c.muted)),
                          ],
                        ),
                      ),
                      Text(peso(item['subtotal']), style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildShipping() {
    final c = context.bc;
    final o = _order!;
    return AccountCard(
      title: 'Shipping Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.person_outline, o['full_name'] ?? '—'),
          _infoRow(Icons.phone_outlined, o['phone'] ?? '—'),
          _infoRow(Icons.email_outlined, o['email'] ?? '—'),
          _infoRow(Icons.location_on_outlined, _address(o)),
        ].map((w) => DefaultTextStyle.merge(style: TextStyle(color: c.text), child: w)).toList(),
      ),
    );
  }

  Widget _buildPayment() {
    final c = context.bc;
    final o = _order!;
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(label, style: TextStyle(color: bold ? c.text : c.textSecondary, fontWeight: bold ? FontWeight.w700 : null)),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: bold ? BuyerPalette.primary : c.text,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  fontSize: bold ? 16 : 14,
                ),
              ),
            ],
          ),
        );

    return AccountCard(
      title: 'Payment',
      child: Column(
        children: [
          row('Method', '${o['payment_method'] ?? '—'}'),
          row('Payment status', '${o['payment_status'] ?? '—'}'),
          Divider(color: c.border),
          if (o['subtotal'] != null) row('Subtotal', peso(o['subtotal'])),
          if (o['shipping_fee'] != null) row('Shipping fee', peso(o['shipping_fee'])),
          row('Total', peso(o['total_price']), bold: true),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.bc.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
