import 'package:flutter/material.dart';
import '../../services/courier_service.dart';
import '../../widgets/order_progress.dart';
import '../../widgets/product_thumb.dart';
import 'courier_ui.dart';

class CourierDeliveryDetailScreen extends StatefulWidget {
  final int deliveryId;
  const CourierDeliveryDetailScreen({super.key, required this.deliveryId});

  @override
  State<CourierDeliveryDetailScreen> createState() => _CourierDeliveryDetailScreenState();
}

class _CourierDeliveryDetailScreenState extends State<CourierDeliveryDetailScreen> {
  Map<String, dynamic>? _delivery;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await CourierService.delivery(widget.deliveryId);
      if (mounted) setState(() => _delivery = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _delivery;
    return Scaffold(
      backgroundColor: courierBg,
      appBar: AppBar(
        title: Text(d == null ? 'Delivery' : '${d['parcel']?['tracking_number'] ?? 'Delivery'}'),
        backgroundColor: courierPrimary,
        foregroundColor: Colors.white,
      ),
      body: d == null
          ? Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: courierMuted))
                  : const CircularProgressIndicator(color: courierPrimary),
            )
          : RefreshIndicator(
              color: courierPrimary,
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(12), children: _content(d)),
            ),
    );
  }

  List<Widget> _content(Map<String, dynamic> d) {
    final parcel = Map<String, dynamic>.from(d['parcel'] ?? {});
    final order = Map<String, dynamic>.from(d['order'] ?? {});
    final items = (order['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    final status = '${d['status']}';
    final cod = '${order['payment_method']}'.toUpperCase() == 'COD' && order['payment_status'] != 'Paid';

    return [
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Order #${order['order_number'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: courierText)),
                ),
                DeliveryStatusBadge(status: status, label: '${d['status_label']}'),
              ],
            ),
            const SizedBox(height: 14),
            if (order['stage'] == 'cancelled')
              const Text('This order was cancelled.', style: TextStyle(color: Color(0xFFC62828)))
            else
              OrderProgressTimeline(
                stage: '${order['stage'] ?? 'warehouse'}',
                hints: const {
                  'warehouse': 'Assigned to you. Pick it up and start the delivery.',
                  'delivering': 'On the way. Mark it delivered once handed over.',
                  'delivered': 'Delivered to the buyer.',
                },
              ),
            if (status == 'failed' && (d['remarks'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Failed: ${d['remarks']}', style: const TextStyle(color: Color(0xFFC62828))),
            ],
            const SizedBox(height: 12),
            DeliveryActions(delivery: d, onChanged: _load),
          ],
        ),
      ),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Deliver to'),
            _row(Icons.person_outline, parcel['receiver_name'] ?? '—'),
            _row(Icons.phone_outlined, parcel['receiver_phone'] ?? '—'),
            _row(Icons.location_on_outlined, parcel['dropoff_address'] ?? '—'),
            if ((parcel['notes'] ?? '').toString().trim().isNotEmpty) _row(Icons.notes, '${parcel['notes']}'.trim()),
            const Divider(height: 24),
            _title('Pick up from'),
            _row(Icons.storefront_outlined, parcel['pickup_address'] ?? '—'),
            if (d['area'] != null) _row(Icons.map_outlined, 'Area: ${d['area']}'),
          ],
        ),
      ),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Items (${items.length})'),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    ProductThumb(url: item['image_url'], size: 44),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${item['title']}', style: const TextStyle(color: courierText))),
                    Text('×${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const Divider(height: 24),
            Row(
              children: [
                Text(cod ? 'Cash to collect' : 'Order total', style: const TextStyle(color: courierMuted)),
                const Spacer(),
                Text(peso(order['total_price']),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: courierPrimary)),
              ],
            ),
            Text(
              '${order['payment_method'] ?? ''} · ${order['payment_status'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: courierMuted),
            ),
          ],
        ),
      ),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title('Timeline'),
            _row(Icons.assignment_ind_outlined, 'Assigned ${shortDate(d['assigned_at'])}'),
            if (d['picked_up_at'] != null) _row(Icons.local_shipping_outlined, 'Started ${shortDate(d['picked_up_at'])}'),
            if (d['delivered_at'] != null) _row(Icons.check_circle_outline, 'Delivered ${shortDate(d['delivered_at'])}'),
          ],
        ),
      ),
    ];
  }

  Widget _card(Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: courierText)),
      );

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: courierMuted),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(color: courierText))),
          ],
        ),
      );
}
