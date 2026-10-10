import 'package:flutter/material.dart';
import '../../../widgets/net_image.dart';
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

  static const _stepHints = {
    'pending': 'Waiting for the seller to confirm your order.',
    'processing': 'The seller is preparing your items.',
    'warehouse': 'Your parcel is on its way to or at the sorting center.',
    'delivering': 'A rider is delivering your parcel.',
    'delivered': 'Your order has been delivered.',
  };

  static const _cancelReasons = [
    'Changed my mind',
    'Ordered by mistake',
    'Found a better price elsewhere',
    'Need to change the delivery address',
    'Delivery takes too long',
  ];

  Future<void> _cancelOrder() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bc.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CancelReasonSheet(reasons: _cancelReasons),
    );
    if (reason == null || !mounted) return;

    try {
      final data = ApiService.unwrap(
        await ApiService.post('/orders/${widget.orderId}/cancel', body: {'cancellation_reason': reason}),
      );
      if (!mounted) return;
      showAccountSnack(context, data['message'] ?? 'Your order has been cancelled.');
    } catch (e) {
      if (mounted) showAccountSnack(context, errorText(e), error: true);
    }
    _load();
  }

  Widget _buildStatus() {
    final c = context.bc;
    final stage = '${_order!['stage'] ?? ''}';
    final cancelled = stage == 'cancelled';
    final canCancel = _order!['can_cancel'] == true;

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
              StageBadge(stage, label: _order!['stage_label']),
            ],
          ),
          const SizedBox(height: 16),
          if (cancelled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: stageColor('cancelled').withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cancel, color: stageColor('cancelled')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This order was cancelled.',
                            style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
                        if ((_order!['cancellation_reason'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Reason: ${_order!['cancellation_reason']}',
                              style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            OrderProgressTimeline(stage: stage, hints: _stepHints),
          if (canCancel) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelOrder,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel Order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: stageColor('cancelled'),
                  side: BorderSide(color: stageColor('cancelled')),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You can cancel while the order is Pending or Processing.',
              style: TextStyle(fontSize: 11, color: c.muted),
            ),
          ],
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
                              ? NetImage(
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

/// Bottom sheet to pick (or type) a cancellation reason. Pops the reason, or null.
class _CancelReasonSheet extends StatefulWidget {
  final List<String> reasons;
  const _CancelReasonSheet({required this.reasons});

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String? _selected;
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  String? get _reason {
    if (_selected != 'Other') return _selected;
    final text = _other.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cancel order?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 4),
              Text('Tell us why you are cancelling.', style: TextStyle(color: c.muted)),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                child: Column(
                  children: [
                    for (final r in [...widget.reasons, 'Other'])
                      RadioListTile<String>(
                        value: r,
                        title: Text(r, style: TextStyle(color: c.text)),
                        activeColor: BuyerPalette.primary,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              if (_selected == 'Other')
                TextField(
                  controller: _other,
                  maxLength: 500,
                  maxLines: 2,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Your reason',
                    filled: true,
                    fillColor: c.subtle,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Keep Order'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _reason == null ? null : () => Navigator.pop(context, _reason),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: stageColor('cancelled'),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel Order'),
                    ),
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
