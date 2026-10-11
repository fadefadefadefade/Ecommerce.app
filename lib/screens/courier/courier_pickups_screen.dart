import 'package:flutter/material.dart';
import '../../services/courier_service.dart';
import '../../widgets/live_refresh.dart';
import '../../widgets/product_thumb.dart';
import 'courier_ui.dart';

/// Parcels the rider's sorting center sent them to collect from sellers.
/// The rider marks them Picked Up; the sorting center receives them on arrival.
class CourierPickupsScreen extends StatefulWidget {
  const CourierPickupsScreen({super.key});

  @override
  State<CourierPickupsScreen> createState() => _CourierPickupsScreenState();
}

class _CourierPickupsScreenState extends State<CourierPickupsScreen> with LiveRefresh {
  List<Map<String, dynamic>> _pickups = [];
  bool _history = false;
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Duration get liveInterval => const Duration(seconds: 20);

  @override
  Future<void> onLiveRefresh() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final pickups = await CourierService.pickups(tab: _history ? 'history' : 'active');
      if (!mounted) return;
      setState(() {
        _pickups = pickups;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _pickups.isEmpty) _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickedUp(Map<String, dynamic> pickup) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Picked up?'),
        content: Text('Confirm you collected ${pickup['tracking_number']} from ${pickup['seller_name'] ?? 'the seller'}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: courierPrimary, foregroundColor: Colors.white),
            child: const Text('Picked Up'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final id = pickup['id'] as int;
    setState(() => _busy.add(id));
    try {
      final message = await CourierService.pickedUp(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: courierBg,
      appBar: AppBar(
        title: const Text('My Pickups'),
        backgroundColor: courierPrimary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Active'), icon: Icon(Icons.move_to_inbox_outlined)),
                ButtonSegment(value: true, label: Text('History'), icon: Icon(Icons.history)),
              ],
              selected: {_history},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: courierPrimary,
                selectedForegroundColor: Colors.white,
              ),
              onSelectionChanged: (v) {
                setState(() {
                  _history = v.first;
                  _pickups = [];
                });
                _load();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: courierPrimary,
              onRefresh: () => _load(silent: true),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _pickups.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: courierPrimary));
    }
    if (_error != null && _pickups.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.wifi_off, size: 56, color: courierMuted),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: courierMuted)),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: courierPrimary, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }
    if (_pickups.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(_history ? Icons.history : Icons.move_to_inbox_outlined, size: 56, color: courierMuted),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _history ? 'No finished pickups yet.' : 'No pickups assigned to you right now.',
              style: const TextStyle(color: courierMuted),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [for (final p in _pickups) _buildCard(p)],
    );
  }

  Widget _buildCard(Map<String, dynamic> p) {
    final status = '${p['status']}';
    final center = Map<String, dynamic>.from(p['sorting_center'] ?? {});
    final items = (p['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    final busy = _busy.contains(p['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${p['tracking_number'] ?? '—'}',
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, color: courierText),
                ),
              ),
              DeliveryStatusBadge(status: _badgeStatus(status), label: '${p['status_label']}'),
            ],
          ),
          const SizedBox(height: 10),
          _step(
            Icons.storefront,
            'Pick up from',
            [p['seller_name'], p['seller_phone']].where((e) => e != null && '$e'.isNotEmpty).join('  ·  '),
            '${p['pickup_address'] ?? '—'}',
          ),
          const SizedBox(height: 8),
          _step(
            Icons.warehouse_outlined,
            'Bring to',
            '${center['name'] ?? 'Sorting center'}',
            '${(center['address'] ?? '').toString().isEmpty ? '—' : center['address']}',
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                for (final item in items.take(3))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ProductThumb(url: item['image_url'], size: 36, radius: 6),
                  ),
                Expanded(
                  child: Text(
                    '${items.first['title']}${items.length > 1 ? ' +${items.length - 1} more' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: courierMuted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            switch (status) {
              'received' => 'Received by the sorting center ${shortDate(p['received_at'])}',
              'cancelled' => p['remarks'] ?? 'Cancelled',
              'picked_up' => 'Picked up ${shortDate(p['picked_up_at'])} · the sorting center will check and receive it',
              _ => 'Assigned ${shortDate(p['assigned_at'])}',
            },
            style: const TextStyle(fontSize: 12, color: courierMuted),
          ),
          if (status == 'assigned') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: busy
                  ? const Center(child: CircularProgressIndicator(color: courierPrimary))
                  : ElevatedButton.icon(
                      onPressed: () => _pickedUp(p),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Picked Up', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: courierPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  String _badgeStatus(String status) => switch (status) {
        'picked_up' => 'out_for_delivery',
        'received' => 'delivered',
        'cancelled' => 'failed',
        _ => 'assigned',
      };

  Widget _step(IconData icon, String label, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: courierPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: courierPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: courierMuted)),
              if (title.isNotEmpty)
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: courierText)),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: courierText)),
            ],
          ),
        ),
      ],
    );
  }
}
