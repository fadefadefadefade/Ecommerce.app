import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/courier_service.dart';
import '../../widgets/live_refresh.dart';
import 'courier_delivery_detail_screen.dart';
import 'courier_ui.dart';

/// Active deliveries (To Deliver / Delivering) with today's stats.
/// With [history] true it lists finished deliveries instead.
class CourierDeliveriesScreen extends StatefulWidget {
  final bool history;
  const CourierDeliveriesScreen({super.key, this.history = false});

  @override
  State<CourierDeliveriesScreen> createState() => _CourierDeliveriesScreenState();
}

class _CourierDeliveriesScreenState extends State<CourierDeliveriesScreen> with LiveRefresh {
  List<Map<String, dynamic>> _deliveries = [];
  Map<String, dynamic>? _dashboard;
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
        CourierService.deliveries(tab: widget.history ? 'history' : 'active'),
        if (!widget.history) CourierService.dashboard(),
      ]);
      if (!mounted) return;
      setState(() {
        _deliveries = results[0] as List<Map<String, dynamic>>;
        if (!widget.history) _dashboard = results[1] as Map<String, dynamic>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _deliveries.isEmpty) _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _open(Map<String, dynamic> delivery) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourierDeliveryDetailScreen(deliveryId: delivery['id'])),
    );
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: courierBg,
      appBar: AppBar(
        title: Text(widget.history ? 'Delivery History' : 'My Deliveries'),
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
    if (_loading && _deliveries.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: courierPrimary));
    }
    if (_error != null && _deliveries.isEmpty) {
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

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (!widget.history) _buildHeader(),
        if (_deliveries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(widget.history ? Icons.history : Icons.inventory_2_outlined, size: 56, color: courierMuted),
                const SizedBox(height: 12),
                Text(
                  widget.history ? 'No finished deliveries yet.' : 'No deliveries assigned to you right now.',
                  style: const TextStyle(color: courierMuted),
                ),
              ],
            ),
          )
        else
          for (final d in _deliveries)
            DeliveryCard(delivery: d, onTap: () => _open(d), onChanged: () => _load(silent: true)),
      ],
    );
  }

  Widget _buildHeader() {
    final user = context.watch<AuthProvider>().user;
    final stats = Map<String, dynamic>.from(_dashboard?['stats'] ?? {});
    final rider = Map<String, dynamic>.from(_dashboard?['rider'] ?? {});

    Widget stat(String label, String value, IconData icon) => Expanded(
          child: Column(
            children: [
              Icon(icon, color: Colors.white70, size: 20),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFFFA4E1C), Color(0xFFFF8A50)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hi, ${(rider['full_name'] ?? user?.name ?? 'Rider').toString().split(' ').first}!',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(
            [rider['vehicle_type'], rider['area']].where((e) => e != null && '$e'.isNotEmpty).join(' · '),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('To Deliver', '${stats['to_deliver'] ?? 0}', Icons.inventory_2_outlined),
              stat('Delivering', '${stats['delivering'] ?? 0}', Icons.local_shipping_outlined),
              stat('Done Today', '${stats['delivered_today'] ?? 0}', Icons.check_circle_outline),
              stat('COD to Collect', peso(stats['cod_to_collect']), Icons.payments_outlined),
            ],
          ),
        ],
      ),
    );
  }
}
