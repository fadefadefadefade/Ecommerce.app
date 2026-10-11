import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/courier_service.dart';
import '../../widgets/live_refresh.dart';
import 'courier_ui.dart';

/// Rider home: who they work for, today's numbers, and what's next.
/// Pickups and deliveries themselves live on their own tabs.
class CourierDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenDeliveries;
  final VoidCallback onOpenPickups;

  const CourierDashboardScreen({
    super.key,
    required this.onOpenDeliveries,
    required this.onOpenPickups,
  });

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> with LiveRefresh {
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _pickups = [];
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        CourierService.dashboard(),
        CourierService.deliveries(),
        CourierService.pickups(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = results[0] as Map<String, dynamic>;
        _deliveries = results[1] as List<Map<String, dynamic>>;
        _pickups = results[2] as List<Map<String, dynamic>>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _dashboard == null) _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  int _stat(String key) => ((_dashboard?['stats'] ?? {})[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: courierBg,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: courierPrimary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        color: courierPrimary,
        onRefresh: () => _load(silent: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _dashboard == null) {
      return const Center(child: CircularProgressIndicator(color: courierPrimary));
    }
    if (_error != null && _dashboard == null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
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

    final stats = Map<String, dynamic>.from(_dashboard?['stats'] ?? {});

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildHeader(),
        const SizedBox(height: 14),
        _sectionTitle('Today'),
        Row(
          children: [
            _tile('Delivered', '${_stat('delivered_today')}', Icons.check_circle_outline, const Color(0xFF2E7D32)),
            const SizedBox(width: 10),
            _tile('Picked Up', '${_stat('pickups_today')}', Icons.move_to_inbox_outlined, const Color(0xFF00838F)),
          ],
        ),
        const SizedBox(height: 14),
        _workCard(
          title: 'Pickups',
          subtitle: 'From sellers to your sorting center',
          icon: Icons.move_to_inbox,
          onTap: widget.onOpenPickups,
          figures: [
            ('To Pick Up', '${_stat('to_pick_up')}'),
            ('Carrying', '${_stat('carrying')}'),
          ],
        ),
        const SizedBox(height: 10),
        _workCard(
          title: 'Deliveries',
          subtitle: 'From your sorting center to buyers',
          icon: Icons.local_shipping,
          onTap: widget.onOpenDeliveries,
          figures: [
            ('To Deliver', '${_stat('to_deliver')}'),
            ('Delivering', '${_stat('delivering')}'),
            ('COD to Collect', peso(stats['cod_to_collect'])),
          ],
        ),
        const SizedBox(height: 14),
        _sectionTitle('Next Up'),
        _buildNextUp(),
        const SizedBox(height: 14),
        _sectionTitle('All Time'),
        Row(
          children: [
            _tile('Delivered', '${_stat('delivered_total')}', Icons.inventory_2_outlined, courierPrimary),
            const SizedBox(width: 10),
            _tile('Pickups', '${_stat('pickups_total')}', Icons.warehouse_outlined, courierPrimary),
            const SizedBox(width: 10),
            _tile('Failed', '${_stat('failed_total')}', Icons.error_outline, const Color(0xFFC62828)),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHeader() {
    final user = context.watch<AuthProvider>().user;
    final rider = Map<String, dynamic>.from(_dashboard?['rider'] ?? {});
    final center = rider['sorting_center'] is Map ? Map<String, dynamic>.from(rider['sorting_center']) : null;
    final active = rider['is_active'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFFFA4E1C), Color(0xFFFF8A50)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hi, ${(rider['full_name'] ?? user?.name ?? 'Rider').toString().split(' ').first}!',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: active ? const Color(0xFFB9F6CA) : Colors.white54),
                    const SizedBox(width: 6),
                    Text(active ? 'Active' : 'Inactive',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [rider['vehicle_type'], rider['area']].where((e) => e != null && '$e'.isNotEmpty).join(' · '),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (center != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warehouse_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${center['name']}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      if ('${center['address'] ?? ''}'.isNotEmpty)
                        Text('${center['address']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextUp() {
    final pickups = _pickups.where((p) => p['status'] == 'assigned').take(3).toList();
    final deliveries = _deliveries.take(3).toList();

    if (pickups.isEmpty && deliveries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: const Column(
          children: [
            Icon(Icons.task_alt, size: 40, color: courierMuted),
            SizedBox(height: 8),
            Text('All caught up. New work from your sorting center will show here.',
                textAlign: TextAlign.center, style: TextStyle(color: courierMuted)),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          for (final p in pickups)
            _nextRow(
              icon: Icons.move_to_inbox_outlined,
              title: 'Pick up · ${p['tracking_number'] ?? ''}',
              subtitle: '${p['seller_name'] ?? 'Seller'} — ${p['pickup_address'] ?? ''}',
              status: 'assigned',
              label: '${p['status_label'] ?? 'To Pick Up'}',
              onTap: widget.onOpenPickups,
            ),
          for (final d in deliveries)
            _nextRow(
              icon: Icons.local_shipping_outlined,
              title: 'Deliver · ${(d['parcel'] ?? {})['tracking_number'] ?? ''}',
              subtitle: '${(d['parcel'] ?? {})['receiver_name'] ?? 'Buyer'} — ${(d['parcel'] ?? {})['dropoff_address'] ?? ''}',
              status: '${d['status']}',
              label: '${d['status_label'] ?? ''}',
              onTap: widget.onOpenDeliveries,
            ),
        ],
      ),
    );
  }

  Widget _nextRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: courierPrimary.withValues(alpha: 0.1),
        child: Icon(icon, color: courierPrimary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: DeliveryStatusBadge(status: status, label: label),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: courierText)),
      );

  Widget _tile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: courierText)),
            Text(label, style: const TextStyle(fontSize: 12, color: courierMuted)),
          ],
        ),
      ),
    );
  }

  Widget _workCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required List<(String, String)> figures,
  }) {
    return Material(
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
                  Icon(icon, color: courierPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: courierMuted)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: courierMuted),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (label, value) in figures)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(value,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: courierText)),
                          ),
                          Text(label, style: const TextStyle(fontSize: 12, color: courierMuted)),
                        ],
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
