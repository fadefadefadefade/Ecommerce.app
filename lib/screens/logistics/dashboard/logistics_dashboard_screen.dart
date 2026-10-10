import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/logistics.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/logistics_service.dart';
import '../riders/riders_screen.dart';
import '../widgets/logistics_ui.dart';

class LogisticsDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenPickups;
  final VoidCallback onOpenParcels;
  final VoidCallback onOpenDeliveries;

  const LogisticsDashboardScreen({
    super.key,
    required this.onOpenPickups,
    required this.onOpenParcels,
    required this.onOpenDeliveries,
  });

  @override
  State<LogisticsDashboardScreen> createState() => _LogisticsDashboardScreenState();
}

class _LogisticsDashboardScreenState extends State<LogisticsDashboardScreen> {
  Map<String, int> _stats = {};
  Map<String, int> _byStatus = {};
  List<ParcelDelivery> _recent = [];
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
      final data = await LogisticsService.getDashboard();
      final byStatus = data['parcels_by_status'];
      setState(() {
        _stats = (data['stats'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        _byStatus = byStatus is Map
            ? byStatus.map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0))
            : {};
        _recent = (data['recent_activity'] as List)
            .map((e) => ParcelDelivery.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRiders(String status) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RidersScreen(initialStatus: status)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: logisticsAppBar('ParcelOps', actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: RefreshIndicator(
        color: LogisticsColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text('Welcome back,', style: TextStyle(color: LogisticsColors.muted.withValues(alpha: 0.9))),
            Text(
              user?.name ?? 'Admin',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: LogisticsColors.text),
            ),
            const SizedBox(height: 16),
            if (_loading && _stats.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator(color: LogisticsColors.primary)),
              )
            else if (_error != null && _stats.isEmpty)
              ErrorState(message: _error!, onRetry: _load)
            else ...[
              _buildStats(),
              const SizedBox(height: 16),
              _buildStatusBreakdown(),
              const SizedBox(height: 16),
              _buildRecentActivity(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final cards = [
      StatCard(
        label: 'Pending Rider Applications',
        value: _stats['pending_rider_applications'] ?? 0,
        icon: Icons.person_add_alt,
        color: LogisticsColors.warning,
        onTap: () => _openRiders('pending'),
      ),
      StatCard(
        label: 'Active Riders',
        value: _stats['active_riders'] ?? 0,
        icon: Icons.two_wheeler,
        color: LogisticsColors.success,
        onTap: () => _openRiders('approved'),
      ),
      StatCard(
        label: 'Pending Pickup Requests',
        value: _stats['pending_pickup_requests'] ?? 0,
        icon: Icons.move_to_inbox,
        onTap: widget.onOpenPickups,
      ),
      StatCard(
        label: 'Parcels at Hub',
        value: _stats['incoming_parcels'] ?? 0,
        icon: Icons.warehouse,
        color: LogisticsColors.info,
        onTap: widget.onOpenParcels,
      ),
      StatCard(
        label: 'In Transit',
        value: _stats['in_transit'] ?? 0,
        icon: Icons.local_shipping,
        color: LogisticsColors.info,
        onTap: widget.onOpenDeliveries,
      ),
      StatCard(
        label: 'Delivered Today',
        value: _stats['delivered_today'] ?? 0,
        icon: Icons.check_circle,
        color: LogisticsColors.success,
        onTap: widget.onOpenDeliveries,
      ),
      StatCard(
        label: 'Failed Deliveries',
        value: _stats['failed_deliveries'] ?? 0,
        icon: Icons.cancel,
        color: LogisticsColors.danger,
        onTap: widget.onOpenDeliveries,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: cards,
    );
  }

  Widget _buildStatusBreakdown() {
    if (_byStatus.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Parcels by Status',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _byStatus.entries.map((e) {
          final color = statusColor(e.key);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${humanize(e.key)} · ${e.value}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return SectionCard(
      title: 'Recent Delivery Activity',
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: _recent.isEmpty
          ? const EmptyState(message: 'No delivery activity yet.')
          : Column(
              children: _recent.map((d) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TrackingText(d.trackingNumber ?? '—'),
                            const SizedBox(height: 2),
                            Text(
                              '${d.riderName ?? '—'} · ${timeAgo(d.updatedAt)}',
                              style: const TextStyle(fontSize: 12, color: LogisticsColors.muted),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: d.status),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
