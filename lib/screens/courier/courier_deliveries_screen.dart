import 'package:flutter/material.dart';
import '../../services/courier_service.dart';
import '../../widgets/live_refresh.dart';
import 'courier_delivery_detail_screen.dart';
import 'courier_ui.dart';

/// What the rider has to deliver (To Deliver / Delivering). Stats are on the Dashboard tab.
/// With [history] true it lists finished deliveries instead.
class CourierDeliveriesScreen extends StatefulWidget {
  final bool history;
  const CourierDeliveriesScreen({super.key, this.history = false});

  @override
  State<CourierDeliveriesScreen> createState() => _CourierDeliveriesScreenState();
}

class _CourierDeliveriesScreenState extends State<CourierDeliveriesScreen> with LiveRefresh {
  List<Map<String, dynamic>> _deliveries = [];
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
      final deliveries = await CourierService.deliveries(tab: widget.history ? 'history' : 'active');
      if (!mounted) return;
      setState(() {
        _deliveries = deliveries;
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
}
