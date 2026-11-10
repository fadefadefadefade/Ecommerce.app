import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../services/api_client.dart';
import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import 'logistics_kit.dart';
import 'parcel_detail_screen.dart';
import 'staff_screens.dart';

/// Shows a downloaded document (an image, or a PDF).
Future<void> showDocument(BuildContext context, Future<ApiDownload> download, String title) async {
  final f = await download;
  if (!context.mounted) return;
  if (!f.ok) return showResult(context, f.error!);
  final bytes = Uint8List.fromList(f.bytes);
  final pdf = bytes.length > 4 && String.fromCharCodes(bytes.take(4)) == '%PDF';
  await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: sellerBar(title),
          body: pdf
              ? PdfPreview(build: (_) async => bytes, useActions: false)
              : InteractiveViewer(child: Center(child: Image.memory(bytes, errorBuilder: (_, __, ___) => const Text('This file can\'t be shown.')))),
        ),
      ));
}

// ── Dispatch board ─────────────────────────────────────────────

/// The web's Dispatch: jobs waiting for a rider (60-second offers or manual), the Unassigned queue,
/// jobs not started yet (reassign) and bulk assignment.
class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});
  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;
  final Set<int> _selected = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.dispatch();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = r.body;
        _error = null;
      } else if (_d == null) {
        _error = r.message;
      }
    });
  }

  List<Map<String, dynamic>> get _riders => asList(_d?['riders']);

  Future<void> _do(Future<ApiResponse> Function() call) async {
    final r = await call();
    if (!mounted) return;
    showResult(context, r);
    if (r.ok && r.body['jobs'] != null) {
      setState(() {
        _d = r.body;
        _selected.clear();
      });
    }
    if (r.broken) _load();
  }

  /// The website's "Choose rider" list: available riders to pick, the hub's other riders greyed out with why.
  Future<int?> _choose(String title, {int? except}) {
    final choices = asList(_d?['rider_choices']).where((c) => except == null || asInt(c['id']) != except).toList();
    if (choices.isEmpty) return pickRider(context, _riders, title: title);
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            for (final (available, label) in const [(true, 'Available'), (false, 'Not available')])
              if (choices.any((c) => (c['available'] == true) == available)) ...[
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2), child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: ctx.bc.muted))),
                for (final c in choices.where((c) => (c['available'] == true) == available))
                  ListTile(
                    enabled: available,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: available ? Alvy.orangeSoft : ctx.bc.subtle, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.two_wheeler, size: 21, color: available ? const Color(0xFFFA4E1C) : ctx.bc.muted),
                    ),
                    title:
                        Text(available ? '${c['name']} (${c['active_jobs']} ${asInt(c['active_jobs']) == 1 ? 'job' : 'jobs'})' : '${c['name']} · ${c['why']}'),
                    onTap: available ? () => Navigator.pop(ctx, asInt(c['id'])) : null,
                  ),
              ],
          ]),
        ),
      ),
    );
  }

  Future<void> _assign(Map<String, dynamic> p, {bool reassign = false}) async {
    final id = await _choose(reassign ? 'Reassign to' : 'Assign to', except: reassign && p['rider_id'] != null ? asInt(p['rider_id']) : null);
    if (id == null || !mounted) return;
    await _do(() => reassign ? LogisticsApi.reassign(asInt(p['parcel_id'] ?? p['id']), id) : LogisticsApi.manualAssign(asInt(p['id']), id));
  }

  Widget _job(Map<String, dynamic> p) {
    final id = asInt(p['id']);
    // Who Auto-assign gives it to: the Online rider covering the job's barangay (none: assign manually).
    final barangayRider = p['barangay_rider'] == null ? null : asMap(p['barangay_rider']);
    return ParcelCard(
      p,
      onTap: () => openParcel(context, id, _load),
      extra: [
        '${p['job_kind'] == 'pickup' ? 'Pickup' : 'Delivery'} job',
        barangayRider != null ? 'Barangay rider: ${barangayRider['name']}' : 'No Online barangay rider: assign manually',
      ],
      actions: [
        Checkbox(value: _selected.contains(id), activeColor: kOrange, onChanged: (v) => setState(() => v == true ? _selected.add(id) : _selected.remove(id))),
        if (barangayRider != null) OutlinedButton(onPressed: () => _do(() => LogisticsApi.autoAssign(id)), child: const Text('Auto assign')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => _assign(p), child: const Text('Assign')),
      ],
    );
  }

  /// Auto-assign every waiting pickup or delivery to the rider of its barangay (after a confirm).
  Future<void> _autoAll(String kind, int ready, int waiting) async {
    final what = kind == 'pickup' ? 'pickups' : 'deliveries';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Auto-assign $what?'),
        content: Text('$ready will go to the rider of ${ready == 1 ? 'its' : 'their'} barangay.'
            '${waiting - ready > 0 ? ' ${waiting - ready} without an Online barangay rider stay here for you to assign.' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => Navigator.pop(ctx, true), child: const Text('Auto-assign')),
        ],
      ),
    );
    if (ok == true && mounted) await _do(() => LogisticsApi.autoAssignAll(kind));
  }

  /// The two Auto-assign cards: pickups (by the seller's barangay) and deliveries (by the buyer's barangay).
  Widget _autoCards(Map<String, dynamic> d) {
    final c = context.bc;
    final auto = asMap(d['auto']);
    Widget card(String kind, String label, String sub, IconData icon) {
      final a = asMap(auto[kind]);
      final waiting = asInt(a['waiting']);
      final ready = asInt(a['ready']);
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: cardBox(context, radius: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: kind == 'pickup' ? Alvy.orangeSoft : Alvy.slateSoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: kind == 'pickup' ? kOrange : Alvy.slate),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$label waiting · $waiting', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                Text(sub, style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Text('$ready ${ready == 1 ? 'has' : 'have'} an Online barangay rider${waiting - ready > 0 ? ' · ${waiting - ready} need manual assignment' : ''}.',
              style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
          const SizedBox(height: 10),
          BusyButton('Auto-assign $label', busy: false, icon: Icons.bolt, color: kind == 'pickup' ? kOrange : Alvy.navyFill,
              onPressed: ready == 0 ? null : () => _autoAll(kind, ready, waiting)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      card('pickup', 'Pickups', "Seller → hub, by the seller's barangay", Icons.upload_outlined),
      card('delivery', 'Deliveries', "Hub → buyer, by the buyer's barangay", Icons.local_shipping_outlined),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Dispatch', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: kOrange,
              foregroundColor: Colors.white,
              onPressed: () async {
                final id = await _choose('Assign ${_selected.length} parcel(s) to');
                if (id != null && mounted) await _do(() => LogisticsApi.bulkAssign(id, _selected.toList()));
              },
              icon: const Icon(Icons.group_add_outlined),
              label: Text('Assign ${_selected.length}'),
            ),
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
                  final top = <Widget>[
                    // The design's dispatch header and fleet card.
                    Text('FLEET DISPATCH DESK', style: TextStyle(fontSize: 11.5, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: Alvy.slate)),
                    Text('Dispatch', style: Alvy.display(size: 24, color: c.text, weight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: cardBox(context, radius: 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          const Icon(Icons.two_wheeler, color: kOrange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Active Hub Fleet', style: TextStyle(fontWeight: FontWeight.w800, color: c.text))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(99)),
                            child: Text('${_riders.length} riders', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.textSecondary)),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          for (final (i, (value, label, icon)) in <(String, String, IconData)>[
                            ('${_riders.where((r) => r['online'] == true).length}', 'Online', Icons.wifi_tethering),
                            ('${asList(d['jobs']).length}', 'Waiting', Icons.inventory_2_outlined),
                            ('${asList(d['unassigned']).length}', 'Unassigned', Icons.report_gmailerrorred_outlined),
                          ].indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                                child: Column(children: [
                                  Text(value, style: Alvy.display(size: 20, color: i == 2 && value != '0' ? kOrange : c.text, weight: FontWeight.w800)),
                                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Icon(icon, size: 13, color: Alvy.slate),
                                    const SizedBox(width: 4),
                                    Text(label, style: TextStyle(fontSize: 11.5, color: Alvy.slate, fontWeight: FontWeight.w600)),
                                  ]),
                                ]),
                              ),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 10),
                        Text('Riders are assigned per barangay. Auto-assign gives each job to the Online rider of its barangay; the rest you assign manually.',
                            style: TextStyle(color: c.textSecondary, fontSize: 12)),
                      ]),
                    ),
                    _autoCards(d),
                  ];
                  final jobs = <Widget>[
                    _head('Waiting for a rider', asList(d['jobs']).length),
                    if (asList(d['jobs']).isEmpty) Text('No jobs waiting.', style: TextStyle(color: c.muted)),
                    for (final p in asList(d['jobs'])) _job(p),
                    _head('Returned to the hub', asList(d['unassigned']).length, note: 'Assign these manually'),
                    if (asList(d['unassigned']).isEmpty) Text('None.', style: TextStyle(color: c.muted)),
                    for (final p in asList(d['unassigned'])) _job(p),
                    _head('Given to a rider, not started', asList(d['not_started']).length),
                    if (asList(d['not_started']).isEmpty) Text('None.', style: TextStyle(color: c.muted)),
                    for (final j in asList(d['not_started']))
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                        decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          CircleAvatar(radius: 18, backgroundColor: Alvy.slateSoft, child: Icon(Icons.two_wheeler, size: 18, color: Alvy.slate)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${j['rider']}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                              Text('${j['tracking']} · ${j['kind']} · since ${formatDateTime(j['since'])}',
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            ]),
                          ),
                          TextButton(onPressed: () => _assign(j, reassign: true), child: const Text('Reassign', style: TextStyle(fontWeight: FontWeight.w700))),
                        ]),
                      ),
                  ];
                  final riders = <Widget>[
                    // The design's "Hub Bay Check-in Dock": each rider with jobs and status.
                    _head('Rider Check-in', _riders.length),
                    for (final r in _riders)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: cardBox(context, radius: 14),
                        child: Row(children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(color: r['online'] == true ? Alvy.orangeSoft : c.subtle, borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.two_wheeler, size: 20, color: r['online'] == true ? kOrange : c.muted),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${r['full_name']}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                              Text('${r['area'] ?? '—'}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(8)),
                            child: Text('${r['active_jobs']} job${asInt(r['active_jobs']) == 1 ? '' : 's'}',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.text)),
                          ),
                          const SizedBox(width: 8),
                          Text('${r['status_label']}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: r['online'] == true ? const Color(0xFF15803D) : c.muted)),
                        ]),
                      ),
                  ];
                  // Tablet: the design's dispatch deck — the fleet and rider check-in beside the job queue.
                  if (box.maxWidth < 760) {
                    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [...top, ...jobs, ...riders]);
                  }
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 4, child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 8, 90), children: [...top, ...riders])),
                    Expanded(flex: 5, child: ListView(padding: const EdgeInsets.fromLTRB(8, 0, 16, 90), children: jobs)),
                  ]);
                }),
              ),
      ),
    );
  }

  Widget _head(String title, int count, {String? note}) {
    final c = context.bc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: Text(title, style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: count > 0 ? Alvy.orangeSoft : c.subtle, borderRadius: BorderRadius.circular(99)),
            child: Text('$count', style: TextStyle(fontWeight: FontWeight.w800, color: count > 0 ? Alvy.orangeDark : c.textSecondary)),
          ),
        ]),
        if (note != null) Text(note, style: TextStyle(fontSize: 12, color: c.textSecondary)),
      ]),
    );
  }
}

// ── Riders ─────────────────────────────────────────────────────

class RidersScreen extends StatefulWidget {
  const RidersScreen({super.key});
  @override
  State<RidersScreen> createState() => _RidersScreenState();
}

class _RidersScreenState extends State<RidersScreen> {
  final _list = GlobalKey<PagedListState>();

  Future<void> _add() async {
    final body = _list.currentState?.body ?? {};
    if (body['has_municipality'] != true) {
      return showError(context, 'Assign a municipality to your account before adding riders.');
    }
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AddRiderScreen(barangays: asList(body['barangays']), municipality: '${body['municipality'] ?? ''}'),
        ));
    if (saved == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PagedList(
      key: _list,
      title: 'Riders',
      initialTab: 'all',
      empty: 'No riders here.',
      fab: FloatingActionButton.extended(
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add rider'),
      ),
      fetch: (page, tab) => LogisticsApi.riders(tab: tab ?? 'all', page: page),
      // The design's courier card: initials with a vehicle badge, name and vehicle, status, then the zone strip.
      itemBuilder: (ctx, r, reload) {
        final c = ctx.bc;
        final name = '${r['full_name']}';
        final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
        final online = r['online'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: cardBox(ctx, radius: 18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              await Navigator.push(ctx, MaterialPageRoute(builder: (_) => RiderDetailScreen(riderId: asInt(r['id']))));
              reload();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: c.subtle,
                      child: Text(initials, style: Alvy.display(size: 15, color: Alvy.slate, weight: FontWeight.w800)),
                    ),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: online ? kOrange : c.muted,
                        child: const Icon(Icons.two_wheeler, size: 12, color: Colors.white),
                      ),
                    ),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700)),
                      Text('${r['vehicle_type'] ?? ''} ${r['plate_number'] ?? ''}'.trim(),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                    ]),
                  ),
                  Pill('${r['status_label']}', color: Pill.forState('${r['status_label']}'.toLowerCase() == 'suspended' ? 'off' : '${r['status_label']}')),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: online ? Alvy.orangeSoft : c.subtle, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.circle, size: 8, color: online ? kOrange : c.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child:
                          Text(online ? 'Online' : 'Offline', style: TextStyle(fontWeight: FontWeight.w700, color: online ? Alvy.orangeDark : c.textSecondary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Alvy.navyFill, borderRadius: BorderRadius.circular(6)),
                      child:
                          Text('${r['area'] ?? '—'}'.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ]),
                ),
                if (r['needs_reverification'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB45309)),
                      SizedBox(width: 6),
                      Text('Re-verify vehicle', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                    ]),
                  ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// The web's rider record: approve / reject an application, suspend or reactivate, re-verify the vehicle, documents, COD.
class RiderDetailScreen extends StatefulWidget {
  final int riderId;
  const RiderDetailScreen({super.key, required this.riderId});
  @override
  State<RiderDetailScreen> createState() => _RiderDetailScreenState();
}

class _RiderDetailScreenState extends State<RiderDetailScreen> {
  Map<String, dynamic>? _r;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.rider(widget.riderId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _r = asMap(r.body['rider']);
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _do(String action, [Map<String, dynamic>? body]) async {
    final r = await LogisticsApi.riderAction(widget.riderId, action, body);
    if (!mounted) return;
    showResult(context, r);
    if (r.ok && r.body['rider'] != null) setState(() => _r = asMap(r.body['rider']));
    if (r.broken) _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final c = context.bc;
    Widget row(String l, dynamic v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 120, child: Text(l, style: TextStyle(color: c.muted))),
            Expanded(child: Text('${v ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar(r == null ? 'Rider' : '${r['full_name']}'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: r == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                Row(children: [
                  Pill('${r['status_label']}', color: Pill.forState('${r['status_label']}' == 'Suspended' ? 'off' : '${r['status_label']}')),
                  const SizedBox(width: 6),
                  Pill(r['online'] == true ? 'Online' : 'Offline', color: r['online'] == true ? const Color(0xFF15803D) : const Color(0xFF6B7280)),
                ]),
                const SizedBox(height: 10),
                SectionCard(
                  child: Column(children: [
                    row('Phone', r['phone']),
                    row('Email', r['email']),
                    row('Barangay', r['area']),
                    row('Vehicle', '${r['vehicle_type'] ?? '—'} · ${r['plate_number'] ?? '—'}'),
                    row('License',
                        '${r['license_number'] ?? '—'} · expires ${r['license_expiry'] != null ? formatDate(r['license_expiry'], 'MM/dd/yyyy') : '—'}'),
                    row('Active jobs', r['active_jobs']),
                    row('COD balance', peso(r['cod_balance'])),
                    row('COD to confirm', peso(r['cod_pending'])),
                    row(
                        'Hub transfers',
                        r['can_transport_transfers'] == true
                            ? 'Allowed to carry parcels between sorting centers'
                            : 'Last-mile only (not allowed to carry hub transfers)'),
                    if (r['rejection_reason'] != null) row('Rejected', r['rejection_reason']),
                  ]),
                ),
                if (r['needs_reverification'] == true)
                  Card(
                    color: Alvy.warnSoft,
                    child: ListTile(
                      title: Text('Vehicle changed: check the new OR/CR', style: TextStyle(color: Alvy.warnText)),
                      trailing:
                          FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => _do('verify'), child: const Text('Verified')),
                    ),
                  ),
                Wrap(spacing: 8, children: [
                  if (r['has_license_file'] == true)
                    OutlinedButton.icon(
                      onPressed: () => showDocument(context, LogisticsApi.riderDocument(widget.riderId, 'license'), 'Driver\'s license'),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('License'),
                    ),
                  if (r['has_or_cr_file'] == true)
                    OutlinedButton.icon(
                      onPressed: () => showDocument(context, LogisticsApi.riderDocument(widget.riderId, 'or-cr'), 'OR/CR'),
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('OR/CR'),
                    ),
                ]),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      if (!await confirmAction(context, 'Hub transfers', "Change this rider's transfer permission?")) return;
                      if (!context.mounted) return;
                      await act(context, () => LogisticsApi.toggleTransport(widget.riderId), then: _load);
                    },
                    child: Text(r['can_transport_transfers'] == true ? 'Stop transfers' : 'Allow transfers'),
                  ),
                ),
                const SizedBox(height: 12),
                if (r['application_status'] == 'pending_activation')
                  BusyButton('Resend activation email',
                      busy: false, icon: Icons.forward_to_inbox, onPressed: () => act(context, () => LogisticsApi.resendRiderActivation(widget.riderId))),
                if (r['application_status'] == 'pending') ...[
                  BusyButton('Approve', busy: false, color: const Color(0xFF15803D), onPressed: () => _do('approve')),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final reason = await showReasonDialog(context,
                          title: 'Reject rider', message: 'They are told the reason (10 to 300 characters).', confirmLabel: 'Reject', maxLength: 300);
                      if (reason != null) _do('reject', {'reason': reason});
                    },
                    child: const Text('Reject'),
                  ),
                ],
                if (r['application_status'] == 'approved')
                  r['is_active'] == true
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                          onPressed: () async {
                            final reason = await showReasonDialog(context,
                                title: 'Suspend rider',
                                message: 'They go Offline and get no jobs. Give the reason (10 to 300 characters).',
                                confirmLabel: 'Suspend',
                                maxLength: 300);
                            if (reason != null) _do('toggle', {'reason': reason});
                          },
                          child: const Text('Suspend'),
                        )
                      : BusyButton('Reactivate', busy: false, color: const Color(0xFF15803D), onPressed: () => _do('toggle')),
              ]),
      ),
    );
  }
}

// ── COD remittances ────────────────────────────────────────────

class RemittancesScreen extends StatefulWidget {
  const RemittancesScreen({super.key});
  @override
  State<RemittancesScreen> createState() => _RemittancesScreenState();
}

class _RemittancesScreenState extends State<RemittancesScreen> {
  String? _date;

  @override
  Widget build(BuildContext context) {
    return PagedList(
      title: 'COD Remittances',
      empty: 'No remittances yet.',
      fetch: (page, tab) => LogisticsApi.remittances(date: _date, page: page),
      header: (ctx, body, reload) {
        final c = ctx.bc;
        final riders = asList(body['riders']);
        final onHand = riders.fold<num>(0, (t, r) => t + asNum(r['balance']));
        final toConfirm = riders.fold<num>(0, (t, r) => t + asNum(r['pending']));
        String initials(String n) => n.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // The design's navy vault card: the cash riders still hold.
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Alvy.navyFill, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.verified_user_outlined, size: 16, color: Colors.white70),
                SizedBox(width: 6),
                Text('COD HELD BY RIDERS', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ]),
              const SizedBox(height: 6),
              Text(peso(onHand), style: Alvy.display(size: 28, color: Colors.white, weight: FontWeight.w800)),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.hourglass_bottom, size: 15, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(child: Text('${peso(toConfirm)} waiting for you to confirm', style: const TextStyle(color: Colors.white, fontSize: 12.5))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(99)),
                  child: Text('${riders.length} riders', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ),
              ]),
            ]),
          ),
          // The design's "Next Riders in Counter Queue".
          if (riders.isNotEmpty) ...[
            Text('Rider Counter Queue', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final r in riders)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: cardBox(ctx, radius: 14),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: c.subtle,
                    child: Text(initials('${r['name']}'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Alvy.slate)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r['name']}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                      Text('Collected ${peso(r['collected'])}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(peso(r['balance']), style: Alvy.display(size: 15, color: c.text, weight: FontWeight.w800)),
                    Text(asNum(r['pending']) > 0 ? 'To confirm ${peso(r['pending'])}' : 'Settled',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: asNum(r['pending']) > 0 ? kOrange : Alvy.slate)),
                  ]),
                ]),
              ),
            const SizedBox(height: 8),
          ],
          // The design's "Shift Settlement Ledger": the day's reconciliation.
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: cardBox(ctx, radius: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('Settlement Ledger', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700))),
                InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () async {
                    final p = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: DateTime.now());
                    if (p != null) {
                      _date = ymd(p);
                      reload();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.event, size: 14, color: kOrange),
                      const SizedBox(width: 5),
                      Text(formatDate(body['date']), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              if (asList(body['daily']).isEmpty) Text('No COD collected or remitted on this day.', style: TextStyle(color: c.muted)),
              for (final d in asList(body['daily']))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.payments_outlined, size: 18, color: Alvy.slate),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d['rider']}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                        Text('Collected ${peso(d['collected'])} · remitted ${peso(d['remitted'])}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ]),
                    ),
                    Text(peso(d['difference']),
                        style: TextStyle(fontWeight: FontWeight.w800, color: asNum(d['difference']) < 0 ? const Color(0xFFDC2626) : Alvy.slate)),
                  ]),
                ),
            ]),
          ),
          Text('Remittances', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700)),
          const SizedBox(height: 10),
        ]);
      },
      // Each remittance as the design's clearance card.
      itemBuilder: (ctx, r, reload) {
        final c = ctx.bc;
        final pending = r['status'] == 'pending';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: cardBox(ctx, radius: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(radius: 18, backgroundColor: Alvy.orangeSoft, child: const Icon(Icons.two_wheeler, size: 18, color: kOrange)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['rider']}', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                  Text(formatDateTime(r['created_at']), style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ]),
              ),
              if (!pending) const Pill('Confirmed', color: Color(0xFF15803D)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text('Expected COD', style: TextStyle(color: c.textSecondary))),
                  Text(peso(r['expected']), style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                ]),
                if (asNum(r['shortfall']) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      const Expanded(child: Text('Short', style: TextStyle(color: Color(0xFFDC2626)))),
                      Text('− ${peso(r['shortfall'])}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                    ]),
                  ),
                Divider(color: c.border),
                Row(children: [
                  Expanded(
                      child: Text('CASH HANDED OVER', style: TextStyle(fontSize: 11.5, letterSpacing: 0.4, fontWeight: FontWeight.w800, color: Alvy.slate))),
                  Text(peso(r['amount']), style: Alvy.display(size: 20, color: kOrange, weight: FontWeight.w800)),
                ]),
              ]),
            ),
            if (pending) ...[
              const SizedBox(height: 10),
              BusyButton('Confirm Remittance',
                  busy: false, icon: Icons.verified_outlined, onPressed: () => act(ctx, () => LogisticsApi.confirmRemittance(asInt(r['id'])), then: reload)),
            ],
          ]),
        );
      },
    );
  }
}
