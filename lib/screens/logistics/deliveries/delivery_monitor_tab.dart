import 'package:flutter/material.dart';
import '../../../models/logistics.dart';
import '../../../services/logistics_service.dart';
import '../widgets/logistics_ui.dart';

/// All rider deliveries with status updates.
class DeliveryMonitorTab extends StatefulWidget {
  const DeliveryMonitorTab({super.key});

  @override
  State<DeliveryMonitorTab> createState() => _DeliveryMonitorTabState();
}

class _DeliveryMonitorTabState extends State<DeliveryMonitorTab> with AutomaticKeepAliveClientMixin {
  String _status = '';
  int? _riderId;
  int _reloadToken = 0;
  int _total = 0;
  List<Rider> _riders = [];

  static final _statuses = {
    '': 'All',
    for (final s in ParcelDelivery.statuses) s: humanize(s),
  };

  @override
  bool get wantKeepAlive => true;

  Future<PagedResult<ParcelDelivery>> _fetch(int page) async {
    final result = await LogisticsService.getMonitor(page: page, status: _status, riderId: _riderId);
    if (mounted) {
      setState(() {
        _riders = result.riders;
        _total = result.deliveries.total;
      });
    }
    return result.deliveries;
  }

  Future<void> _updateStatus(ParcelDelivery delivery) async {
    final remarksController = TextEditingController(text: delivery.remarks ?? '');
    String selected = delivery.status;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update ${delivery.trackingNumber ?? 'delivery'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ParcelDelivery.statuses.map((s) {
                      final isSelected = s == selected;
                      return ChoiceChip(
                        label: Text(humanize(s)),
                        selected: isSelected,
                        showCheckmark: false,
                        selectedColor: statusColor(s),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : LogisticsColors.text),
                        onSelected: (_) => setSheetState(() => selected = s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksController,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Remarks (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LogisticsColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Update Status'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final remarks = remarksController.text.trim();
    remarksController.dispose();
    if (confirmed != true) return;

    try {
      final message = await LogisticsService.updateDeliveryStatus(
        delivery.id,
        selected,
        remarks.isEmpty ? null : remarks,
      );
      if (!mounted) return;
      showSnack(context, message);
      setState(() => _reloadToken++);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        const SizedBox(height: 12),
        FilterChips(
          options: _statuses,
          selected: _status,
          onSelected: (v) => setState(() => _status = v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: DropdownButtonFormField<int?>(
            initialValue: _riderId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Rider',
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All Riders')),
              ..._riders.map((r) => DropdownMenuItem<int?>(value: r.id, child: Text(r.fullName))),
            ],
            onChanged: (v) => setState(() => _riderId = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'All deliveries ($_total)',
              style: const TextStyle(fontWeight: FontWeight.w600, color: LogisticsColors.muted),
            ),
          ),
        ),
        Expanded(
          child: PagedList<ParcelDelivery>(
            key: ValueKey('$_status|$_riderId|$_reloadToken'),
            fetch: _fetch,
            emptyMessage: 'No deliveries found.',
            itemBuilder: (context, d, reload) => ListCard(
              onTap: () => _updateStatus(d),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: TrackingText(d.trackingNumber ?? '—')),
                      StatusBadge(status: d.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler, size: 16, color: LogisticsColors.muted),
                      const SizedBox(width: 6),
                      Expanded(child: Text(d.riderName ?? '—')),
                      Text(d.areaName ?? '—', style: const TextStyle(fontSize: 12, color: LogisticsColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.deliveredAt != null
                        ? 'Delivered ${formatDateTime(d.deliveredAt)}'
                        : 'Assigned ${formatDateTime(d.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: LogisticsColors.muted),
                  ),
                  if (d.remarks != null && d.remarks!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('“${d.remarks}”', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Tap to update status',
                      style: TextStyle(fontSize: 11, color: LogisticsColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
