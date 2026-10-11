import 'package:flutter/material.dart';
import '../../../models/logistics.dart';
import '../../../services/logistics_service.dart';
import '../../../widgets/reason_dialog.dart';
import '../widgets/logistics_ui.dart';
import 'pickup_requests_screen.dart';

/// Sorting center sends its riders to sellers, then checks parcels in when they arrive.
class PickupAssignScreen extends StatefulWidget {
  const PickupAssignScreen({super.key});

  @override
  State<PickupAssignScreen> createState() => _PickupAssignScreenState();
}

class _PickupAssignScreenState extends State<PickupAssignScreen> {
  final _searchController = TextEditingController();
  String _tab = 'to_assign';
  String _search = '';
  int _reloadToken = 0;
  Map<String, int> _counts = {};
  final Set<int> _busy = {};

  static const _tabs = {
    'to_assign': 'Unassigned',
    'with_rider': 'With Rider',
    'received': 'Received',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<PagedResult<PickupParcel>> _fetch(int page) async {
    final result = await LogisticsService.getPickups(page: page, tab: _tab, search: _search);
    if (mounted && page == 1) setState(() => _counts = result.counts);
    return result.parcels;
  }

  void _reload() => setState(() => _reloadToken++);

  Future<void> _act(int parcelId, Future<String> Function() action) async {
    setState(() => _busy.add(parcelId));
    try {
      final message = await action();
      if (!mounted) return;
      showSnack(context, message);
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(parcelId));
    }
  }

  Future<void> _assign(PickupParcel parcel) async {
    List<PickupRider> riders;
    try {
      riders = await LogisticsService.getPickupRiders();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
      return;
    }
    if (!mounted) return;

    final rider = await showModalBottomSheet<PickupRider>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Send a Rider to Pick Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${parcel.trackingNumber} · ${parcel.sellerName ?? 'Seller'}',
                      style: const TextStyle(color: LogisticsColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: riders.isEmpty
                    ? const EmptyState(
                        message: 'No active riders in your sorting center yet.\nApprove riders in the Riders page first.',
                        icon: Icons.two_wheeler,
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: riders.map((r) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: LogisticsColors.primary.withValues(alpha: 0.12),
                              child: const Icon(Icons.two_wheeler, color: LogisticsColors.primary),
                            ),
                            title: Text(r.fullName),
                            subtitle: Text([
                              if (r.vehicleType != null) humanize(r.vehicleType!),
                              if (r.area != null) r.area!,
                            ].join(' · ')),
                            trailing: StatusBadge(
                              status: r.openPickups == 0 ? 'approved' : 'pending',
                              label: r.openPickups == 0 ? 'Free' : '${r.openPickups} pickup${r.openPickups == 1 ? '' : 's'}',
                            ),
                            onTap: () => Navigator.pop(ctx, r),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (rider == null) return;
    _act(parcel.id, () => LogisticsService.assignPickup(parcel.id, rider.id));
  }

  Future<void> _receive(PickupParcel parcel) async {
    final pickup = parcel.pickup!;
    final remarks = await showReasonDialog(
      context,
      title: 'Receive ${parcel.trackingNumber}?',
      message: pickup.status == 'assigned'
          ? 'The rider has not marked this as picked up yet. Check the item before receiving it.'
          : 'Check the item from ${pickup.riderName ?? 'the rider'}. Once received, the buyer will see it as Shipped to Warehouse.',
      hint: 'Remarks after checking (optional)',
      confirmLabel: 'Received',
      confirmColor: LogisticsColors.success,
      required: false,
    );
    if (remarks == null) return;
    _act(parcel.id, () => LogisticsService.receivePickup(pickup.id, remarks: remarks));
  }

  Future<void> _unassign(PickupParcel parcel) async {
    final ok = await confirmAction(
      context,
      title: 'Unassign rider?',
      message: '${parcel.pickup?.riderName ?? 'The rider'} will no longer pick up ${parcel.trackingNumber}.',
      confirmLabel: 'Unassign',
      destructive: true,
    );
    if (ok) _act(parcel.id, () => LogisticsService.unassignPickup(parcel.pickup!.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: logisticsAppBar('Rider Pickups', actions: [
        IconButton(
          tooltip: 'Pickup Requests',
          icon: const Icon(Icons.fact_check_outlined),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const PickupRequestsScreen()));
            if (mounted) _reload();
          },
        ),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LogisticsSearchField(
              controller: _searchController,
              hint: 'Search tracking # or buyer…',
              onSubmitted: (v) => setState(() => _search = v.trim()),
            ),
          ),
          FilterChips(
            options: _tabs.map((k, v) => MapEntry(k, _counts[k] == null ? v : '$v (${_counts[k]})')),
            selected: _tab,
            onSelected: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PagedList<PickupParcel>(
              key: ValueKey('$_tab|$_search|$_reloadToken'),
              fetch: _fetch,
              emptyMessage: switch (_tab) {
                'with_rider' => 'No riders are out on pickups.',
                'received' => 'Nothing received yet.',
                _ => 'No parcels waiting for a pickup rider.',
              },
              itemBuilder: (context, parcel, reload) => _buildCard(parcel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(PickupParcel parcel) {
    final pickup = parcel.pickup;
    final busy = _busy.contains(parcel.id);

    return ListCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: TrackingText(parcel.trackingNumber)),
              pickup != null
                  ? StatusBadge(status: _badgeStatus(pickup.status), label: pickup.statusLabel)
                  : StatusBadge(status: parcel.status, label: parcel.statusLabel),
            ],
          ),
          const SizedBox(height: 8),
          _line(Icons.storefront, [parcel.sellerName ?? 'Seller', if (parcel.sellerPhone?.isNotEmpty == true) parcel.sellerPhone!].join(' · ')),
          _line(Icons.upload, 'Pick up at: ${parcel.pickupAddress ?? '—'}'),
          _line(Icons.person_outline, 'For ${parcel.receiverName ?? '—'}${parcel.destination?.isNotEmpty == true ? ' · ${parcel.destination}' : ''}'),
          if (pickup != null) ...[
            const Divider(height: 20),
            _line(Icons.two_wheeler, [pickup.riderName ?? 'Rider', if (pickup.riderPhone?.isNotEmpty == true) pickup.riderPhone!].join(' · ')),
            _line(Icons.schedule, switch (pickup.status) {
              'received' => 'Received ${formatDateTime(pickup.receivedAt)}',
              'picked_up' => 'Picked up ${timeAgo(pickup.pickedUpAt)} · on the way to you',
              _ => 'Assigned ${timeAgo(pickup.assignedAt)} · going to the seller',
            }),
            if (pickup.remarks?.isNotEmpty == true) _line(Icons.notes, pickup.remarks!),
          ] else
            _line(Icons.schedule, 'Ready since ${formatDateTime(parcel.createdAt)}'),
          if (_tab != 'received') ...[
            const SizedBox(height: 12),
            if (busy)
              const Center(child: CircularProgressIndicator(color: LogisticsColors.primary))
            else
              _buildActions(parcel),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(PickupParcel parcel) {
    final pickup = parcel.pickup;

    if (pickup == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _assign(parcel),
          icon: const Icon(Icons.person_pin_circle, size: 18),
          label: const Text('Assign Rider'),
          style: ElevatedButton.styleFrom(
            backgroundColor: LogisticsColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    final receive = ElevatedButton.icon(
      onPressed: () => _receive(parcel),
      icon: const Icon(Icons.fact_check, size: 18),
      label: const Text('Check & Receive'),
      style: ElevatedButton.styleFrom(
        backgroundColor: LogisticsColors.success,
        foregroundColor: Colors.white,
      ),
    );

    if (pickup.status == 'picked_up') {
      return SizedBox(width: double.infinity, child: receive);
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _unassign(parcel),
            style: OutlinedButton.styleFrom(
              foregroundColor: LogisticsColors.danger,
              side: const BorderSide(color: LogisticsColors.danger),
            ),
            child: const Text('Unassign'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: receive),
      ],
    );
  }

  String _badgeStatus(String pickupStatus) => switch (pickupStatus) {
        'received' => 'delivered',
        'picked_up' => 'in_transit',
        _ => 'assigned',
      };

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
