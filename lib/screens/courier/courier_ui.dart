import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/courier_service.dart';
import '../../utils/num_utils.dart';
import '../../widgets/product_thumb.dart';

// Shared pieces for the courier (rider) screens.

const courierPrimary = Color(0xFFFA4E1C);
const courierBg = Color(0xFFF5F5F5);
const courierText = Color(0xFF222222);
const courierMuted = Color(0xFF8a7a70);

Color deliveryColor(String status) {
  switch (status) {
    case 'out_for_delivery':
      return const Color(0xFF00838F);
    case 'delivered':
      return const Color(0xFF2E7D32);
    case 'failed':
    case 'returned':
      return const Color(0xFFC62828);
    default:
      return const Color(0xFFEF6C00);
  }
}

String peso(dynamic v) => '₱${NumberFormat('#,##0.00').format(asDouble(v))}';

String shortDate(dynamic v) {
  final d = v == null ? null : DateTime.tryParse('$v')?.toLocal();
  return d == null ? '—' : DateFormat('MMM d · h:mm a').format(d);
}

class DeliveryStatusBadge extends StatelessWidget {
  final String status;
  final String label;
  const DeliveryStatusBadge({super.key, required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = deliveryColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Start / Delivered / Failed buttons for a delivery. Calls [onChanged] after a successful action.
class DeliveryActions extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final VoidCallback onChanged;
  const DeliveryActions({super.key, required this.delivery, required this.onChanged});

  @override
  State<DeliveryActions> createState() => _DeliveryActionsState();
}

class _DeliveryActionsState extends State<DeliveryActions> {
  bool _busy = false;

  int get _id => widget.delivery['id'] as int;

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (!mounted) return;
      _snack(message);
      widget.onChanged();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
      ));
  }

  Future<bool> _confirm(String title, String message, String action, Color color) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _start() async {
    if (await _confirm('Start delivery?', 'The buyer will see the order as Delivering.', 'Start',
        deliveryColor('out_for_delivery'))) {
      _run(() => CourierService.start(_id));
    }
  }

  Future<void> _deliver() async {
    final order = widget.delivery['order'] as Map?;
    final cod = order != null &&
        '${order['payment_method']}'.toUpperCase() == 'COD' &&
        order['payment_status'] != 'Paid';
    if (await _confirm(
      'Mark as delivered?',
      cod ? 'Collect ${peso(order['total_price'])} cash from the buyer before confirming.' : 'Confirm the parcel was handed to the buyer.',
      'Delivered',
      deliveryColor('delivered'),
    )) {
      _run(() => CourierService.deliver(_id));
    }
  }

  Future<void> _fail() async {
    const reasons = ['Buyer not available', 'Wrong or incomplete address', 'Buyer refused the parcel', 'Unable to reach the area'];
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Why couldn\'t you deliver?'),
        children: [
          for (final r in reasons)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, r), child: Text(r)),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back', style: TextStyle(color: courierMuted)),
          ),
        ],
      ),
    );
    if (reason != null) _run(() => CourierService.fail(_id, reason));
  }

  @override
  Widget build(BuildContext context) {
    final status = '${widget.delivery['status']}';
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator(color: courierPrimary)),
      );
    }
    if (status != 'assigned' && status != 'out_for_delivery') return const SizedBox.shrink();

    final starting = status == 'assigned';
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: starting ? _start : _deliver,
            icon: Icon(starting ? Icons.local_shipping : Icons.check_circle),
            label: Text(starting ? 'Start Delivery' : 'Delivered'),
            style: ElevatedButton.styleFrom(
              backgroundColor: deliveryColor(starting ? 'out_for_delivery' : 'delivered'),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (!starting) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _fail,
              style: OutlinedButton.styleFrom(
                foregroundColor: deliveryColor('failed'),
                side: BorderSide(color: deliveryColor('failed')),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Failed'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Card for one delivery in the courier's lists.
class DeliveryCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  const DeliveryCard({super.key, required this.delivery, required this.onTap, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final parcel = Map<String, dynamic>.from(delivery['parcel'] ?? {});
    final order = Map<String, dynamic>.from(delivery['order'] ?? {});
    final items = (order['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    final status = '${delivery['status']}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        parcel['tracking_number'] ?? '—',
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, color: courierText),
                      ),
                    ),
                    DeliveryStatusBadge(status: status, label: '${delivery['status_label']}'),
                  ],
                ),
                const SizedBox(height: 10),
                _line(Icons.person_outline, '${parcel['receiver_name'] ?? '—'}  ·  ${parcel['receiver_phone'] ?? ''}'),
                _line(Icons.location_on_outlined, parcel['dropoff_address'] ?? '—'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final item in items.take(3))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ProductThumb(url: item['image_url'], size: 36, radius: 6),
                      ),
                    Expanded(
                      child: Text(
                        items.isEmpty
                            ? 'Order #${order['order_number'] ?? ''}'
                            : '${items.first['title']}${items.length > 1 ? ' +${items.length - 1} more' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: courierMuted),
                      ),
                    ),
                    if (order.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(peso(order['total_price']),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: courierPrimary)),
                          Text(
                            '${order['payment_method']}'.toUpperCase() == 'COD' && order['payment_status'] != 'Paid'
                                ? 'Collect (COD)'
                                : '${order['payment_status'] ?? ''}',
                            style: const TextStyle(fontSize: 11, color: courierMuted),
                          ),
                        ],
                      ),
                  ],
                ),
                if (status == 'assigned' || status == 'out_for_delivery') ...[
                  const SizedBox(height: 12),
                  DeliveryActions(delivery: delivery, onChanged: onChanged),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: courierMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: courierText))),
          ],
        ),
      );
}
