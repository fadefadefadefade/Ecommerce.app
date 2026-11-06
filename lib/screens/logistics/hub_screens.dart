import 'package:flutter/material.dart';

import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import 'hub_waybill.dart';
import 'logistics_kit.dart';
import 'parcel_detail_screen.dart';

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
  String _find = '';   // barangay search

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
                  // The website's summary: what to sort, what was sorted, what waits for riders, busy barangays.
                  StatGrid([
                    StatTile(label: 'Waiting to sort', value: '${asList(d['pending']).length}', icon: Icons.inbox_outlined, color: kOrange),
                    StatTile(label: 'Sorted today', value: '${d['sorted_today'] ?? 0}', icon: Icons.check_circle_outline, color: const Color(0xFF15803D)),
                    StatTile(label: 'Ready for riders', value: '${areas.fold<int>(0, (n, a) => n + asInt(a['sorted']))}', icon: Icons.sort, color: const Color(0xFF2563EB)),
                    StatTile(label: 'Barangays with parcels', value: '${areas.where((a) => asInt(a['sorted']) > 0).length} / ${areas.length}', icon: Icons.place_outlined, color: const Color(0xFF6D4AA5)),
                  ]),
                  const SizedBox(height: 12),
                  // Ready for riders, per barangay (busiest first), with the website's "Find a barangay".
                  if (areas.isNotEmpty) ...[
                    TextField(
                      decoration: const InputDecoration(hintText: 'Find a barangay…', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
                      onChanged: (v) => setState(() => _find = v.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final a in [...areas]..sort((x, y) => asInt(y['sorted']).compareTo(asInt(x['sorted']))))
                        if (_find.isEmpty || '${a['name']}'.toLowerCase().contains(_find))
                          Pill('${a['name']}: ${a['sorted']}', color: asInt(a['sorted']) > 0 ? const Color(0xFF2563EB) : c.muted),
                    ]),
                    const SizedBox(height: 14),
                  ],
                  Row(children: [
                    Text('Sorting queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(width: 8),
                    Pill('${asList(d['pending']).length} ${asList(d['pending']).length == 1 ? 'parcel' : 'parcels'}',
                        color: asList(d['pending']).isEmpty ? const Color(0xFF15803D) : kOrange),
                  ]),
                  const SizedBox(height: 8),
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
            child: ChoiceChip(label: Text('All areas (${body['waiting_total'] ?? 0})'), selected: _area == null, onSelected: (_) {
              _area = null;
              reload();
            }),
          ),
          // Like the website: parcels waiting in each barangay, the busiest first.
          for (final a in [...asList(body['areas'])]..sort((x, y) => asInt(y['waiting']).compareTo(asInt(x['waiting']))))
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 6),
              child: ChoiceChip(label: Text('${a['name']} (${a['waiting'] ?? 0})'), selected: _area == asInt(a['id']), onSelected: (_) {
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
              var riders = all.where((r) => area == null || r['area_id'] == area).map((r) => asMap(r)).toList();
              var note = 'Riders of ${asMap(p['area'])['name'] ?? 'this barangay'}';
              // No rider in this barangay: the company's riders, nearest to the buyer first (like the website).
              final nearest = asList(p['nearest_riders']);
              if (riders.isEmpty && nearest.isNotEmpty) {
                final byId = {for (final r in all) asInt(r['id']): asMap(r)};
                riders = [for (final n in nearest) {...?byId[asInt(n['rider_id'])], 'km': n['km']}];
                note = 'No rider in ${asMap(p['area'])['name'] ?? 'this barangay'} — the nearest riders, closest first.';
              }
              final id = await pickRider(ctx, riders, note: note);
              if (id != null && ctx.mounted) act(ctx, () => LogisticsApi.assign(asInt(p['id']), id), then: reload);
            },
            child: const Text('Assign rider'),
          ),
        ],
      ),
    );
  }
}

