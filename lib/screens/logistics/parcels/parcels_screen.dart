import 'package:flutter/material.dart';
import '../../../models/logistics.dart';
import '../../../services/logistics_service.dart';
import '../widgets/logistics_ui.dart';
import 'parcel_detail_screen.dart';

/// Parcels & Sorting: confirm pickups and sort parcels into delivery areas.
class ParcelsScreen extends StatefulWidget {
  const ParcelsScreen({super.key});

  @override
  State<ParcelsScreen> createState() => _ParcelsScreenState();
}

class _ParcelsScreenState extends State<ParcelsScreen> {
  final _searchController = TextEditingController();
  String _status = '';
  String _search = '';
  int _reloadToken = 0;
  final Set<int> _busy = {};
  List<DeliveryArea>? _areas;

  static const _statuses = {
    '': 'All',
    'pickup_approved': 'Pickup Confirmed',
    'picked_up': 'At Sorting Center',
    'sorted': 'Sorted',
    'assigned': 'Assigned',
    'in_transit': 'Out for Delivery',
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

  Future<void> _markPickedUp(Parcel parcel) async {
    final ok = await confirmAction(
      context,
      title: 'Mark as picked up',
      message: '${parcel.trackingNumber} has arrived at the sorting center?',
      confirmLabel: 'Mark Picked Up',
    );
    if (ok) _act(parcel, () => LogisticsService.markPickedUp(parcel.id));
  }

  Future<void> _sort(Parcel parcel) async {
    try {
      _areas ??= await LogisticsService.getAreas();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
      return;
    }
    if (!mounted) return;

    final area = await showModalBottomSheet<DeliveryArea>(
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
                child: Text(
                  'Sort ${parcel.trackingNumber} to area',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _areas!
                      .map((a) => ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(a.name),
                            onTap: () => Navigator.pop(ctx, a),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (area != null) _act(parcel, () => LogisticsService.sortParcel(parcel.id, area.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LogisticsColors.background,
      appBar: logisticsAppBar('Parcels & Sorting'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LogisticsSearchField(
              controller: _searchController,
              hint: 'Tracking #…',
              onSubmitted: (v) => setState(() => _search = v.trim()),
            ),
          ),
          FilterChips(
            options: _statuses,
            selected: _status,
            onSelected: (v) => setState(() => _status = v),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PagedList<Parcel>(
              key: ValueKey('$_status|$_search|$_reloadToken'),
              fetch: (page) => LogisticsService.getParcels(page: page, status: _status, search: _search),
              emptyMessage: 'No parcels found.',
              itemBuilder: (context, parcel, reload) => _buildCard(parcel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Parcel parcel) {
    final busy = _busy.contains(parcel.id);
    Widget? action;
    if (parcel.status == 'pickup_approved') {
      action = ElevatedButton.icon(
        onPressed: () => _markPickedUp(parcel),
        icon: const Icon(Icons.inventory, size: 18),
        label: const Text('Mark Picked Up'),
        style: ElevatedButton.styleFrom(
          backgroundColor: LogisticsColors.primary,
          foregroundColor: Colors.white,
        ),
      );
    } else if (parcel.status == 'picked_up') {
      action = ElevatedButton.icon(
        onPressed: () => _sort(parcel),
        icon: const Icon(Icons.call_split, size: 18),
        label: const Text('Sort to Area'),
        style: ElevatedButton.styleFrom(
          backgroundColor: LogisticsColors.primary,
          foregroundColor: Colors.white,
        ),
      );
    }

    return ListCard(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ParcelDetailScreen(parcelId: parcel.id)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: TrackingText(parcel.trackingNumber)),
              StatusBadge(status: parcel.status, label: parcel.statusLabel),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            parcel.receiverName ?? '—',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'Area: ${parcel.areaName ?? '—'}',
            style: const TextStyle(fontSize: 12, color: LogisticsColors.muted),
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: busy
                  ? const Center(child: CircularProgressIndicator(color: LogisticsColors.primary))
                  : action,
            ),
          ],
        ],
      ),
    );
  }
}
