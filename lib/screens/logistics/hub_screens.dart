import 'package:flutter/material.dart';

import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/waybill_scanner.dart';
import 'hub_waybill.dart';
import 'logistics_kit.dart';
import 'parcel_detail_screen.dart';
import 'tracking_screens.dart';

// ── Pickup requests ────────────────────────────────────────────

/// The web's Pickup Requests: confirm a seller's pickup (the company takes responsibility) or reject it with a reason.
class PickupRequestsScreen extends StatelessWidget {
  const PickupRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedList(
      title: 'Pickup Requests',
      initialTab: 'pending',
      empty: 'No pickup requests here.',
      fetch: (page, tab) => LogisticsApi.pickupRequests(tab: tab ?? 'pending', page: page),
      itemBuilder: (ctx, p, reload) => ParcelCard(
        p,
        onTap: () => openParcel(ctx, asInt(p['id']), reload),
        extra: [if (p['created_at'] != null) 'Requested ${formatDateTime(p['created_at'])}'],
        actions: [
          if (p['status'] == 'pending_pickup') ...[
            OutlinedButton(
              onPressed: () async {
                final reason = await showReasonDialog(ctx, title: 'Reject pickup', message: 'The seller is told the reason and can reschedule.', confirmLabel: 'Reject');
                if (reason != null && ctx.mounted) act(ctx, () => LogisticsApi.rejectPickup(asInt(p['id']), reason), then: reload);
              },
              child: const Text('Reject'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kOrange),
              onPressed: () => act(ctx, () => LogisticsApi.approvePickup(asInt(p['id'])), then: reload),
              child: const Text('Confirm pickup'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Incoming (receive / scan) ──────────────────────────────────

/// The web's Incoming Parcels: scanning (or typing) a waybill finds the parcel and opens its page, where receipt is
/// confirmed after checking it. Recent scans and "Print all" waybills, like the website.
class IncomingScreen extends StatefulWidget {
  const IncomingScreen({super.key});
  @override
  State<IncomingScreen> createState() => _IncomingScreenState();
}

class _IncomingScreenState extends State<IncomingScreen> {
  final _list = GlobalKey<PagedListState>();
  final _scan = TextEditingController();
  bool _busy = false;
  String? _search;
  // Which of the company's hubs is receiving (the buyer's timeline then says "At Hub (HUB-QC)").
  List<Map<String, dynamic>> _hubs = [];
  int? _hub;

  @override
  void initState() {
    super.initState();
    LogisticsApi.hubs().then((r) {
      if (!mounted || !r.ok) return;
      setState(() {
        _hubs = asList(r.body['hubs']);
        if (_hubs.length == 1) _hub = asInt(_hubs.first['id']);
      });
    });
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  Future<void> _receiveScanned([String? code]) async {
    final t = (code ?? _scan.text).trim();
    if (t.isEmpty || _busy) return;
    setState(() => _busy = true);
    final r = await act(context, () => LogisticsApi.scan(t, hubId: _hub), then: () => _scan.clear());
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok && r.body['parcel_id'] != null) await openTracking(context, asInt(r.body['parcel_id']));
    _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [('all', 'All'), ('pickup_approved', 'Awaiting'), ('in_transit_to_hub', 'On the way'), ('picked_up', 'Received'), ('sorted', 'Sorted')];
    return PagedList(
      key: _list,
      title: 'Incoming Parcels',
      initialTab: 'all',
      actions: [
        IconButton(
          tooltip: 'Print all waybills',
          icon: const Icon(Icons.print_outlined),
          onPressed: () => openWaybills(context, [for (final p in asList(_list.currentState?.body['data'])) asInt(p['id'])]),
        ),
      ],
      fetch: (page, tab) => LogisticsApi.incoming(tab: tab ?? 'all', search: _search, page: page),
      header: (ctx, body, reload) {
        final s = asMap(body['stats']);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StatGrid([
            StatTile(label: 'Awaiting arrival', value: '${s['awaiting'] ?? 0}', icon: Icons.schedule),
            StatTile(label: 'Received today', value: '${s['received'] ?? 0}', icon: Icons.move_to_inbox_outlined, color: const Color(0xFF15803D)),
            StatTile(label: 'For sorting', value: '${s['for_sorting'] ?? 0}', icon: Icons.sort, color: const Color(0xFF2563EB)),
            StatTile(label: 'Sorted', value: '${s['sorted'] ?? 0}', icon: Icons.check_circle_outline, color: const Color(0xFF9333EA)),
          ]),
          const SizedBox(height: 10),
          if (_hubs.length > 1) ...[
            DropdownButtonFormField<int>(
              initialValue: _hub,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Receiving at', border: OutlineInputBorder(), isDense: true),
              items: [for (final h in _hubs) DropdownMenuItem(value: asInt(h['id']), child: Text('${h['label']}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _hub = v),
            ),
            const SizedBox(height: 8),
          ],
          SectionCard(
            title: 'Receive a parcel',
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _scan,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _receiveScanned(),   // a barcode scanner types the number and presses Enter
                  decoration: const InputDecoration(hintText: 'Scan or type a waybill / tracking number', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              IconButton(
                tooltip: 'Camera',
                onPressed: _busy
                    ? null
                    : () async {
                        final code = await scanWaybill(context);
                        if (code != null) _receiveScanned(code);
                      },
                icon: const Icon(Icons.qr_code_scanner, color: kOrange),
              ),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: _busy ? null : _receiveScanned, child: const Text('Find')),
            ]),
          ),
          if (asList(body['recent_scans']).isNotEmpty)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                title: Text('Recent scans (${asList(body['recent_scans']).length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                children: [
                  for (final s in asList(body['recent_scans']))
                    ListTile(
                      dense: true,
                      onTap: s['parcel_id'] == null ? null : () => openTracking(ctx, asInt(s['parcel_id']), reload),
                      title: Text('${s['code']}', style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: Text('${formatDateTime(s['at'])} · ${s['parcel_status'] ?? '—'}'),
                      trailing: Pill('${s['result_label']}', color: switch (s['result']) {
                        'found' => const Color(0xFF15803D),
                        'duplicate' => const Color(0xFFB45309),
                        'not_found' => const Color(0xFFDC2626),
                        _ => const Color(0xFF6B7280),
                      }),
                    ),
                ],
              ),
            ),
          SizedBox(
            height: 46,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final t in tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 6),
                  child: ChoiceChip(
                    label: Text(t.$2),
                    selected: (_list.currentState?.tab ?? 'all') == t.$1,
                    selectedColor: kOrange.withValues(alpha: 0.15),
                    onSelected: (_) => _list.currentState?.setTab(t.$1),
                  ),
                ),
            ]),
          ),
          TextField(
            decoration: const InputDecoration(hintText: 'Search tracking no. or receiver', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
            onSubmitted: (v) {
              _search = v.trim().isEmpty ? null : v.trim();
              reload();
            },
          ),
          const SizedBox(height: 8),
        ]);
      },
      itemBuilder: (ctx, p, reload) => ParcelCard(
        p,
        onTap: () => openTracking(ctx, asInt(p['id']), reload),
        extra: [if (p['received_at'] != null) 'Received ${formatDateTime(p['received_at'])}'],
        actions: [
          // Receipt is confirmed on the parcel's page, after checking it (condition, notes).
          if (p['status'] == 'pickup_approved' || p['status'] == 'in_transit_to_hub')
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kOrange),
              onPressed: () => openTracking(ctx, asInt(p['id']), reload),
              child: const Text('Check & receive'),
            ),
        ],
      ),
    );
  }
}

// ── Sorting ────────────────────────────────────────────────────

/// The web's Parcel Sorting: each received parcel goes to one of the company's barangays (a suggestion is shown).
class SortingScreen extends StatefulWidget {
  const SortingScreen({super.key});
  @override
  State<SortingScreen> createState() => _SortingScreenState();
}

class _SortingScreenState extends State<SortingScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;
  final Map<int, int?> _chosen = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.sorting();
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
    final areas = asList(d?['areas']);
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Parcel Sorting', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
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
                  Text('Sorted today: ${d['sorted_today']}', style: TextStyle(color: c.muted)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final a in areas) Pill('${a['name']}: ${a['sorted']}', color: const Color(0xFF2563EB))]),
                  const SizedBox(height: 10),
                  if (asList(d['pending']).isEmpty) const EmptyNote(Icons.sort, 'No parcels waiting to be sorted.'),
                  for (final p in asList(d['pending']))
                    ParcelCard(
                      p,
                      onTap: () => openParcel(context, asInt(p['id']), _load),
                      extra: [if (p['covered'] != true) 'Outside your coverage — transfer it'],
                      actions: [
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: _chosen[asInt(p['id'])] ?? (p['suggested_area_id'] == null ? null : asInt(p['suggested_area_id'])),
                            decoration: const InputDecoration(labelText: 'Barangay', isDense: true, border: OutlineInputBorder()),
                            items: [for (final a in areas) DropdownMenuItem(value: asInt(a['id']), child: Text('${a['name']}', overflow: TextOverflow.ellipsis))],
                            onChanged: (v) => setState(() => _chosen[asInt(p['id'])] = v),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: kOrange),
                          onPressed: () {
                            final area = _chosen[asInt(p['id'])] ?? (p['suggested_area_id'] == null ? null : asInt(p['suggested_area_id']));
                            act(context, () => LogisticsApi.sort(asInt(p['id']), area ?? 0), then: _load);
                          },
                          child: const Text('Sort'),
                        ),
                      ],
                    ),
                ]),
              ),
      ),
    );
  }
}

// ── Delivery assignment ────────────────────────────────────────

/// The web's Delivery Assignment: give a sorted parcel to an active rider of its barangay.
class AssignmentScreen extends StatefulWidget {
  final int? areaId;
  const AssignmentScreen({super.key, this.areaId});
  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  late int? _area = widget.areaId;
  final _list = GlobalKey<PagedListState>();

  @override
  Widget build(BuildContext context) {
    return PagedList(
      key: _list,
      title: 'Delivery Assignment',
      empty: 'No sorted parcels waiting for a rider.',
      actions: [
        IconButton(
          tooltip: 'Print all waybills',
          icon: const Icon(Icons.print_outlined),
          onPressed: () => openWaybills(context, [for (final p in asList(_list.currentState?.body['data'])) asInt(p['id'])]),
        ),
      ],
      fetch: (page, tab) => LogisticsApi.assignment(areaId: _area, page: page),
      header: (ctx, body, reload) => SizedBox(
        height: 46,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 6),
            child: ChoiceChip(label: const Text('All areas'), selected: _area == null, onSelected: (_) {
              _area = null;
              reload();
            }),
          ),
          for (final a in asList(body['areas']))
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 6),
              child: ChoiceChip(label: Text('${a['name']}'), selected: _area == asInt(a['id']), onSelected: (_) {
                _area = asInt(a['id']);
                reload();
              }),
            ),
        ]),
      ),
      itemBuilder: (ctx, p, reload) => ParcelCard(
        p,
        onTap: () => openParcel(ctx, asInt(p['id']), reload),
        extra: [if (p['sorted_at'] != null) 'Sorted ${formatDateTime(p['sorted_at'])}'],
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kOrange),
            onPressed: () async {
              final all = asList(_list.currentState?.body['riders']);
              final area = asMap(p['area'])['id'];
              final riders = all.where((r) => area == null || r['area_id'] == area).toList();
              final id = await pickRider(ctx, riders, note: 'Riders of ${asMap(p['area'])['name'] ?? 'this barangay'}');
              if (id != null && ctx.mounted) act(ctx, () => LogisticsApi.assign(asInt(p['id']), id), then: reload);
            },
            child: const Text('Assign rider'),
          ),
        ],
      ),
    );
  }
}

