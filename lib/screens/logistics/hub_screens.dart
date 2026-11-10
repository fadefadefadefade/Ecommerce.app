import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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
                child: LayoutBuilder(builder: (context, box) {
                  final all = _kiosk(d, areas);
                  // Tablet: the design's kiosk dock station — the parcel on the belt on the left, the queue and barangays on the right.
                  if (box.maxWidth < 760) return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: all);
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 8, 24), children: all.sublist(0, _leftEnd))),
                    Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(8, 4, 16, 24), children: all.sublist(_leftEnd))),
                  ]);
                }),
              ),
      ),
    );
  }

  int? _areaFor(Map p) => _chosen[asInt(p['id'])] ?? (p['suggested_area_id'] == null ? null : asInt(p['suggested_area_id']));

  String _areaName(List<Map<String, dynamic>> areas, int? id) =>
      areas.where((a) => asInt(a['id']) == id).map((a) => '${a['name']}').firstOrNull ?? 'Choose a barangay';

  /// Where the kiosk's left column ends on a tablet (after the parcel on the belt and its buttons).
  int _leftEnd = 0;

  /// The design's sorting kiosk: the station's numbers, the parcel on the belt in big type, then the queue.
  List<Widget> _kiosk(Map<String, dynamic> d, List<Map<String, dynamic>> areas) {
    final c = context.bc;
    final pending = asList(d['pending']);
    final ready = areas.fold<int>(0, (n, a) => n + asInt(a['sorted']));
    Widget stat(String label, String value, String sub, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 10.5, letterSpacing: 0.4, fontWeight: FontWeight.w700, color: c.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: Alvy.display(size: 22, color: color, weight: FontWeight.w800)),
              Text(sub, style: TextStyle(fontSize: 11, color: c.textSecondary)),
            ]),
          ),
        );
    final out = <Widget>[
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(radius: 18, backgroundColor: Alvy.slateSoft, child: Icon(Icons.sort, color: Alvy.slate, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Text('Sorting Station', style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            stat('WAITING', '${pending.length}', 'to sort', kOrange),
            const SizedBox(width: 8),
            stat('SORTED', '${d['sorted_today'] ?? 0}', 'today', Alvy.slate),
            const SizedBox(width: 8),
            stat('READY', '$ready', 'for riders', c.text),
          ]),
        ]),
      ),
    ];

    if (pending.isEmpty) {
      out.add(const EmptyNote(Icons.sort, 'No parcels waiting to be sorted.'));
      _leftEnd = out.length;
    } else {
      final p = asMap(pending.first);
      final area = _areaFor(p);
      out.add(Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: cardBox(context, radius: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 6, color: kOrange),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('ASSIGNED BARANGAY', style: TextStyle(fontSize: 11.5, letterSpacing: 0.5, fontWeight: FontWeight.w800, color: c.textSecondary)),
              Text(_areaName(areas, area).toUpperCase(), style: Alvy.display(size: 30, color: kOrange, weight: FontWeight.w800)),
              Text('#${p['tracking']}', style: TextStyle(fontWeight: FontWeight.w700, color: Alvy.slate)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.storefront_outlined, size: 17, color: Alvy.slate),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${p['seller'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: c.text))),
                    if (p['weight_kg'] != null) Text('${p['weight_kg']} kg', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                  ]),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.place_outlined, size: 17, color: kOrange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${p['receiver'] ?? ''} — ${p['dropoff_address'] ?? p['destination'] ?? ''}',
                          style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                    ),
                  ]),
                ]),
              ),
              if (p['covered'] != true)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Alvy.dangerSoft, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Outside your coverage — transfer it', style: TextStyle(color: Alvy.dangerText, fontWeight: FontWeight.w600))),
                  ]),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: area,
                decoration: const InputDecoration(labelText: 'Barangay', isDense: true),
                items: [for (final a in areas) DropdownMenuItem(value: asInt(a['id']), child: Text('${a['name']}', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _chosen[asInt(p['id'])] = v),
              ),
            ]),
          ),
        ]),
      ));
      out.add(BusyButton('Confirm Sorted to ${_areaName(areas, area)}', busy: false, icon: Icons.done_all,
          onPressed: () => act(context, () => LogisticsApi.sort(asInt(p['id']), area ?? 0), then: _load)));
      out.add(const SizedBox(height: 10));
      out.add(OutlinedButton.icon(
        onPressed: () => openParcel(context, asInt(p['id']), _load),
        style: OutlinedButton.styleFrom(
          backgroundColor: Alvy.slateSoft,
          side: BorderSide.none,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(Icons.open_in_new, size: 18, color: Alvy.slate),
        label: Text('Open parcel', style: TextStyle(color: Alvy.slate, fontWeight: FontWeight.w700)),
      ));
      _leftEnd = out.length;

      // The rest of the queue (the design's "recent station scans" list style).
      if (pending.length > 1) {
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
          child: Row(children: [
            Icon(Icons.history, size: 18, color: Alvy.slate),
            const SizedBox(width: 6),
            Text('NEXT IN QUEUE', style: TextStyle(fontSize: 12, letterSpacing: 0.5, fontWeight: FontWeight.w800, color: c.text)),
            const Spacer(),
            Text('${pending.length - 1} more', style: TextStyle(fontSize: 12, color: Alvy.slate, fontWeight: FontWeight.w600)),
          ]),
        ));
        for (final x in pending.skip(1)) {
          final q = asMap(x);
          final qa = _areaFor(q);
          out.add(InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => openParcel(context, asInt(q['id']), _load),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: cardBox(context, radius: 14),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.inventory_2_outlined, size: 18, color: kOrange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#${q['tracking']}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                    Text([if (q['weight_kg'] != null) '${q['weight_kg']} kg', _areaName(areas, qa)].join(' · '),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ]),
                ),
                TextButton(
                  onPressed: qa == null ? null : () => act(context, () => LogisticsApi.sort(asInt(q['id']), qa), then: _load),
                  child: const Text('Sort', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ));
        }
      }
    }

    // Ready for riders, per barangay (busiest first), with the website's "Find a barangay".
    if (areas.isNotEmpty) {
      out.addAll([
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
          child: Text('Ready for riders', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700)),
        ),
        TextField(
          decoration: const InputDecoration(hintText: 'Find a barangay…', prefixIcon: Icon(Icons.search), isDense: true),
          onChanged: (v) => setState(() => _find = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final a in [...areas]..sort((x, y) => asInt(y['sorted']).compareTo(asInt(x['sorted']))))
            if (_find.isEmpty || '${a['name']}'.toLowerCase().contains(_find))
              Pill('${a['name']}: ${a['sorted']}', color: asInt(a['sorted']) > 0 ? Alvy.slate : c.muted),
        ]),
      ]);
    }
    return out;
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
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: FilterPill('All areas (${body['waiting_total'] ?? 0})', selected: _area == null, onTap: () {
              _area = null;
              reload();
            }),
          ),
          // Like the website: parcels waiting in each barangay, the busiest first.
          for (final a in [...asList(body['areas'])]..sort((x, y) => asInt(y['waiting']).compareTo(asInt(x['waiting']))))
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: FilterPill('${a['name']} (${a['waiting'] ?? 0})', selected: _area == asInt(a['id']), onTap: () {
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

