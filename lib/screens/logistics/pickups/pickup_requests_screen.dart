import 'package:flutter/material.dart';
import '../../../models/logistics.dart';
import '../../../services/logistics_service.dart';
import '../parcels/parcel_detail_screen.dart';
import '../widgets/logistics_ui.dart';

class PickupRequestsScreen extends StatefulWidget {
  const PickupRequestsScreen({super.key});

  @override
  State<PickupRequestsScreen> createState() => _PickupRequestsScreenState();
}

class _PickupRequestsScreenState extends State<PickupRequestsScreen> {
  final _searchController = TextEditingController();
  String _tab = 'pending';
  String _search = '';
  int _reloadToken = 0;
  final Set<int> _busy = {};

  static const _tabs = {
    'pending': 'Pending',
    'confirmed': 'Confirmed',
    'approved': 'In Pipeline',
    'rejected': 'Rejected',
    'all': 'All',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _act(Parcel parcel, Future<String> Function() action) async {
    setState(() => _busy.add(parcel.id));
    try {
      final message = await action();
      if (!mounted) return;
      showSnack(context, message);
      setState(() => _reloadToken++);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(parcel.id));
    }
  }

  Future<void> _approve(Parcel parcel) async {
    final ok = await confirmAction(
      context,
      title: 'Approve pickup',
      message: 'Approve pickup for ${parcel.trackingNumber}?',
      confirmLabel: 'Approve',
    );
    if (ok) _act(parcel, () => LogisticsService.approvePickup(parcel.id));
  }

  Future<void> _reject(Parcel parcel) async {
    final reason = await askReason(
      context,
      title: 'Reject pickup request?',
      hint: 'Reason (optional)',
      confirmLabel: 'Reject',
    );
    if (reason != null) {
      _act(parcel, () => LogisticsService.rejectPickup(parcel.id, reason.isEmpty ? 'Rejected by admin' : reason));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: logisticsAppBar('Pickup Requests'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LogisticsSearchField(
              controller: _searchController,
              hint: 'Search tracking #…',
              onSubmitted: (v) => setState(() => _search = v.trim()),
            ),
          ),
          FilterChips(
            options: _tabs,
            selected: _tab,
            onSelected: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PagedList<Parcel>(
              key: ValueKey('$_tab|$_search|$_reloadToken'),
              fetch: (page) => LogisticsService.getPickupRequests(page: page, tab: _tab, search: _search),
              emptyMessage: 'No pickup requests.',
              itemBuilder: (context, parcel, reload) => _buildCard(parcel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Parcel parcel) {
    final busy = _busy.contains(parcel.id);
    return ListCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ParcelDetailScreen(parcelId: parcel.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: TrackingText(parcel.trackingNumber)),
              StatusBadge(status: parcel.status, label: parcel.statusLabel),
            ],
          ),
          const SizedBox(height: 8),
          _line(Icons.storefront, parcel.sellerName ?? '—'),
          _line(Icons.upload, parcel.pickupAddress ?? '—'),
          _line(Icons.download, parcel.dropoffAddress ?? '—'),
          _line(Icons.schedule, 'Submitted ${formatDate(parcel.createdAt)}'),
          if (parcel.status == 'pending_pickup') ...[
            const SizedBox(height: 10),
            if (busy)
              const Center(child: CircularProgressIndicator(color: LogisticsColors.primary))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(parcel),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LogisticsColors.danger,
                        side: const BorderSide(color: LogisticsColors.danger),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(parcel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LogisticsColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: LogisticsColors.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
