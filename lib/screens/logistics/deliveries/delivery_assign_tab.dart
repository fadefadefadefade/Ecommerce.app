import 'package:flutter/material.dart';
import '../../../models/logistics.dart';
import '../../../services/logistics_service.dart';
import '../widgets/logistics_ui.dart';

/// Sorted parcels ready to be handed to a rider.
class DeliveryAssignTab extends StatefulWidget {
  const DeliveryAssignTab({super.key});

  @override
  State<DeliveryAssignTab> createState() => _DeliveryAssignTabState();
}

class _DeliveryAssignTabState extends State<DeliveryAssignTab> with AutomaticKeepAliveClientMixin {
  int? _areaId;
  int _reloadToken = 0;
  int _total = 0;
  List<DeliveryArea> _areas = [];
  List<Rider> _riders = [];
  final Set<int> _busy = {};

  @override
  bool get wantKeepAlive => true;

  Future<PagedResult<Parcel>> _fetch(int page) async {
    final result = await LogisticsService.getAssignment(page: page, areaId: _areaId);
    if (mounted) {
      setState(() {
        _areas = result.areas;
        _riders = result.riders;
        _total = result.parcels.total;
      });
    }
    return result.parcels;
  }

  Future<void> _assign(Parcel parcel) async {
    // Riders covering the parcel's area first, then everyone else.
    final riders = [..._riders]
      ..sort((a, b) {
        final aMatch = a.areaId == parcel.areaId ? 0 : 1;
        final bMatch = b.areaId == parcel.areaId ? 0 : 1;
        return aMatch.compareTo(bMatch);
      });

    final rider = await showModalBottomSheet<Rider>(
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
                    const Text('Assign to Rider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${parcel.trackingNumber} · ${parcel.areaName ?? 'no area'}',
                      style: const TextStyle(color: LogisticsColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: riders.isEmpty
                    ? const EmptyState(message: 'No active riders available.')
                    : ListView(
                        shrinkWrap: true,
                        children: riders.map((r) {
                          final sameArea = r.areaId != null && r.areaId == parcel.areaId;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: LogisticsColors.primary.withValues(alpha: 0.12),
                              child: const Icon(Icons.two_wheeler, color: LogisticsColors.primary),
                            ),
                            title: Text(r.fullName),
                            subtitle: Text(r.areaName ?? 'no area'),
                            trailing: sameArea
                                ? const StatusBadge(status: 'approved', label: 'Same area')
                                : null,
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

    setState(() => _busy.add(parcel.id));
    try {
      final message = await LogisticsService.assignRider(parcel.id, rider.id);
      if (!mounted) return;
      showSnack(context, message);
      setState(() => _reloadToken++);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(parcel.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: DropdownButtonFormField<int?>(
            initialValue: _areaId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Filter by Area',
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All Areas')),
              ..._areas.map((a) => DropdownMenuItem<int?>(value: a.id, child: Text(a.name))),
            ],
            onChanged: (v) => setState(() => _areaId = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sorted parcels ready for assignment ($_total)',
              style: const TextStyle(fontWeight: FontWeight.w600, color: LogisticsColors.muted),
            ),
          ),
        ),
        Expanded(
          child: PagedList<Parcel>(
            key: ValueKey('$_areaId|$_reloadToken'),
            fetch: _fetch,
            emptyMessage: 'No sorted parcels waiting for assignment.',
            itemBuilder: (context, parcel, reload) {
              final busy = _busy.contains(parcel.id);
              return ListCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: TrackingText(parcel.trackingNumber)),
                        Text(parcel.areaName ?? '—', style: const TextStyle(color: LogisticsColors.muted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(parcel.receiverName ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      parcel.dropoffAddress ?? '—',
                      style: const TextStyle(fontSize: 12, color: LogisticsColors.muted),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: busy
                          ? const Center(child: CircularProgressIndicator(color: LogisticsColors.primary))
                          : ElevatedButton.icon(
                              onPressed: () => _assign(parcel),
                              icon: const Icon(Icons.person_pin_circle, size: 18),
                              label: const Text('Assign Rider'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: LogisticsColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
