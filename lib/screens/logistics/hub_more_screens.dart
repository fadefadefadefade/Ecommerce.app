import 'package:flutter/material.dart';

import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import 'hub_screens.dart';
import 'hub_waybill.dart';
import 'logistics_kit.dart';
import 'parcel_detail_screen.dart';

// ── Delivery monitoring ────────────────────────────────────────

/// The web's Delivery Monitoring: every delivery attempt; a logistics override (with a reason), reschedule or return.
class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});
  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  String? _status;
  final _list = GlobalKey<PagedListState>();

  Future<void> _override(BuildContext ctx, Map<String, dynamic> d, VoidCallback reload) async {
    final options = [for (final s in (asMap(d['actions'])['override'] as List? ?? [])) '$s'];
    final labels = {'out_for_delivery': 'Out for Delivery', 'delivered': 'Delivered', 'failed': 'Failed'};
    final status = await showDialog<String>(
      context: ctx,
      builder: (c) => SimpleDialog(title: const Text('Change status'), children: [
        for (final s in options) SimpleDialogOption(onPressed: () => Navigator.pop(c, s), child: Text(labels[s] ?? s)),
      ]),
    );
    if (status == null || !ctx.mounted) return;
    final reason = await showReasonDialog(ctx,
        title: 'Logistics override', message: 'Give the reason (10 to 300 characters), e.g. the rider\'s app was offline.', confirmLabel: 'Save', maxLength: 300);
    if (reason != null && ctx.mounted) act(ctx, () => LogisticsApi.overrideStatus(asInt(d['id']), status, reason), then: reload);
  }

  @override
  Widget build(BuildContext context) {
    const filters = [(null, 'All'), ('assigned', 'Assigned'), ('out_for_delivery', 'Out for delivery'), ('delivered', 'Delivered'), ('failed', 'Failed')];
    return PagedList(
      key: _list,
      title: 'Delivery Monitoring',
      actions: [
        IconButton(
          tooltip: 'Print all waybills',
          icon: const Icon(Icons.print_outlined),
          onPressed: () => openWaybills(context, {
            for (final d in asList(_list.currentState?.body['data']))
              if (asMap(d['parcel'])['id'] != null) asInt(asMap(d['parcel'])['id']),
          }.toList()),
        ),
      ],
      empty: 'No deliveries.',
      fetch: (page, tab) => LogisticsApi.monitoring(status: _status, page: page),
      header: (ctx, body, reload) {
        final s = asMap(body['stats']);
        return Column(children: [
          StatGrid([
            StatTile(label: 'Dispatched', value: '${s['dispatched'] ?? 0}', icon: Icons.assignment_ind_outlined),
            StatTile(label: 'Out for delivery', value: '${s['out_for_delivery'] ?? 0}', icon: Icons.local_shipping_outlined, color: const Color(0xFF2563EB)),
            StatTile(label: 'Delivered today', value: '${s['delivered'] ?? 0}', icon: Icons.check_circle_outline, color: const Color(0xFF15803D)),
            StatTile(label: 'Failed', value: '${s['failed'] ?? 0}', icon: Icons.error_outline, color: const Color(0xFFDC2626)),
          ]),
          SizedBox(
            height: 50,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(vertical: 8), children: [
              for (final f in filters)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text(f.$2), selected: _status == f.$1, onSelected: (_) {
                    _status = f.$1;
                    reload();
                  }),
                ),
            ]),
          ),
        ]);
      },
      itemBuilder: (ctx, d, reload) {
        final p = asMap(d['parcel']);
        final a = asMap(d['actions']);
        return ParcelCard(
          p.isEmpty ? {'tracking': '—', 'status': d['status'], 'status_label': d['status_label']} : {...p, 'status': d['status'], 'status_label': d['status_label']},
          onTap: p.isEmpty ? null : () => openParcel(ctx, asInt(p['id']), reload),
          extra: [
            'Rider ${d['rider'] ?? '—'}',
            'attempt ${d['attempts']} of ${d['max_attempts']}',
            if (d['delivered_at'] != null) 'Delivered ${formatDateTime(d['delivered_at'])}',
            if (asNum(d['cod_collected']) > 0) 'COD collected ${peso(d['cod_collected'])}',
          ],
          actions: [
            if ((a['override'] as List? ?? []).isNotEmpty)
              OutlinedButton(onPressed: () => _override(ctx, d, reload), child: const Text('Override status')),
            if (a['reschedule'] == true)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kOrange),
                onPressed: () async {
                  final r = await act(ctx, () => LogisticsApi.reschedule(asInt(d['id'])), then: reload);
                  if (r.ok && ctx.mounted) {
                    Navigator.push(ctx, MaterialPageRoute(builder: (_) => AssignmentScreen(areaId: asMap(p['area'])['id'] == null ? null : asInt(asMap(p['area'])['id']))));
                  }
                },
                child: const Text('Reschedule'),
              ),
            if (a['return'] == true)
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                onPressed: () async {
                  if (await confirmAction(ctx, 'Return to the seller?', 'The parcel goes to the Return-to-Sender queue.', confirm: 'Return', danger: true)) {
                    if (ctx.mounted) act(ctx, () => LogisticsApi.returnToSender(asInt(d['id'])), then: reload);
                  }
                },
                child: const Text('Return to seller'),
              ),
          ],
        );
      },
    );
  }
}

// ── Return to Sender ───────────────────────────────────────────

class RtsScreen extends StatefulWidget {
  const RtsScreen({super.key});
  @override
  State<RtsScreen> createState() => _RtsScreenState();
}

class _RtsScreenState extends State<RtsScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.rts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = r.body;
        _error = null;
      } else {
        _error = r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Return to Sender', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  Text('Going back to the seller', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                  const SizedBox(height: 6),
                  if (asList(d['parcels']).isEmpty) const EmptyNote(Icons.assignment_return_outlined, 'No parcels waiting to go back.'),
                  for (final p in asList(d['parcels']))
                    ParcelCard(
                      p,
                      onTap: () => openParcel(context, asInt(p['id']), _load),
                      extra: [
                        p['rts_rider'] != null ? 'Rider ${p['rts_rider']}' : 'No rider yet',
                        for (final a in asList(p['attempts'])) 'Attempt ${a['attempt']}: ${a['reason'] ?? a['status']}',
                      ],
                      actions: [
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: kOrange),
                          onPressed: () async {
                            final id = await pickRider(context, asList(d['riders']), note: 'Riders who can take a job now');
                            if (id != null && context.mounted) {
                              final r = await LogisticsApi.assignRts(asInt(p['id']), id);
                              if (!context.mounted) return;
                              showResult(context, r);
                              if (r.ok) setState(() => _d = r.body);
                              if (r.broken) _load();
                            }
                          },
                          child: Text(p['rts_rider'] != null ? 'Change rider' : 'Assign rider'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Text('Handed back, waiting for the seller to confirm', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                  const SizedBox(height: 6),
                  if (asList(d['awaiting']).isEmpty) Text('None.', style: TextStyle(color: c.muted)),
                  for (final p in asList(d['awaiting']))
                    ParcelCard(p, extra: [if (p['returned_at'] != null) 'Handed back ${formatDateTime(p['returned_at'])}'], onTap: () => openParcel(context, asInt(p['id']), _load)),
                ]),
              ),
      ),
    );
  }
}

// ── Shipments ──────────────────────────────────────────────────

/// The web's Shipments list (L1 / L5): status buckets, dates and search by tracking, order number or receiver.
class ShipmentsScreen extends StatefulWidget {
  final String? status;
  const ShipmentsScreen({super.key, this.status});
  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  String? _q, _from, _to;

  @override
  Widget build(BuildContext context) {
    return PagedList(
      title: 'Shipments',
      initialTab: widget.status,
      empty: 'No shipments found.',
      fetch: (page, tab) => LogisticsApi.shipments(status: tab, q: _q, from: _from, to: _to, page: page),
      header: (ctx, body, reload) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(hintText: 'Tracking, order no. or receiver', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
              onSubmitted: (v) {
                _q = v.trim().isEmpty ? null : v.trim();
                reload();
              },
            ),
          ),
          IconButton(
            tooltip: 'Dates',
            icon: Icon(Icons.date_range, color: _from != null ? kOrange : null),
            onPressed: () async {
              final r = await showDateRangePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime.now());
              _from = r == null ? null : ymd(r.start);
              _to = r == null ? null : ymd(r.end);
              reload();
            },
          ),
        ]),
      ),
      itemBuilder: (ctx, p, reload) => ParcelCard(p, onTap: () => openParcel(ctx, asInt(p['id']), reload), extra: [formatDate(p['created_at'])]),
    );
  }
}

