import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import 'hub_more_screens.dart';
import 'logistics_kit.dart';
import 'parcel_detail_screen.dart';
import 'hub_screens.dart' show SortingScreen, PickupRequestsScreen;
import 'rider_admin_screens.dart' show DispatchScreen;
import 'tracking_screens.dart' show TrackingBoardScreen;

import '../../widgets/report_download.dart';

// ── Dashboard ──────────────────────────────────────────────────

/// The web's logistics dashboard: shipment counts by status for a date range, today's figures, recent deliveries,
/// and the delivery rate per barangay.
class LogisticsDashboardScreen extends StatefulWidget {
  const LogisticsDashboardScreen({super.key});
  @override
  State<LogisticsDashboardScreen> createState() => _LogisticsDashboardScreenState();
}

class _LogisticsDashboardScreenState extends State<LogisticsDashboardScreen> {
  Map<String, dynamic>? _d;
  String? _error, _from, _to;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.dashboard(from: _from, to: _to);
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
    if (!r.ok && _d != null && mounted) showResult(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    final name = context.watch<AuthProvider>().user?.name ?? '';
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Dashboard', actions: [
        IconButton(
          icon: Icon(Icons.date_range, color: _from != null ? kOrange : null),
          onPressed: () async {
            final r = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
            _from = r == null ? null : ymd(r.start);
            _to = r == null ? null : ymd(r.end);
            _load();
          },
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                  // The design's "HUB COMMAND ● LIVE" header.
                  Row(children: [
                    Text('HUB COMMAND', style: TextStyle(fontSize: 11.5, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: c.textSecondary)),
                    const SizedBox(width: 6),
                    const Icon(Icons.circle, size: 7, color: kOrange),
                    const SizedBox(width: 4),
                    const Text('LIVE', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: kOrange)),
                  ]),
                  Text(name, style: Alvy.display(size: 26, color: c.text, weight: FontWeight.w800)),
                  if (_from != null) Text('${formatDate(_from)} – ${formatDate(_to)}', style: TextStyle(color: c.muted)),
                  const SizedBox(height: 14),
                  // Today's throughput: parcels in, and how many are delivered already.
                  Builder(builder: (_) {
                    final st = asMap(d['stats']);
                    final inToday = asInt(st['total_parcels_today']);
                    final done = asInt(st['delivered_today']);
                    final share = inToday == 0 ? 0.0 : (done / inToday).clamp(0.0, 1.0);
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: cardBox(context, radius: 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text("TODAY'S THROUGHPUT", style: TextStyle(fontSize: 11.5, letterSpacing: 0.5, fontWeight: FontWeight.w700, color: c.textSecondary)),
                              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('$done', style: Alvy.display(size: 28, color: c.text, weight: FontWeight.w800)),
                                Padding(padding: const EdgeInsets.only(bottom: 4, left: 4), child: Text('/ $inToday delivered', style: TextStyle(color: c.textSecondary))),
                              ]),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${(share * 100).toStringAsFixed(0)}%', style: Alvy.display(size: 20, color: kOrange, weight: FontWeight.w800)),
                            Text('of parcels in today', style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
                          ]),
                        ]),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(value: share, minHeight: 10, color: kOrange, backgroundColor: c.subtle),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.local_shipping_outlined, size: 15, color: Alvy.slate),
                          const SizedBox(width: 4),
                          Text('${asInt(st['in_transit'])} out for delivery', style: TextStyle(fontSize: 12, color: Alvy.slate, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('Remaining: ${(inToday - done).clamp(0, 1 << 30)}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                        ]),
                      ]),
                    );
                  }),
                  const SizedBox(height: 12),
                  // The design's 2 × 2 metric cards: an icon square, a chip, the number and what it is.
                  Builder(builder: (_) {
                    final st = asMap(d['stats']);
                    Widget card(IconData icon, String chip, String value, String label, VoidCallback onTap) => Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: onTap,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: cardBox(context, radius: 18),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(10)),
                                    child: Icon(icon, size: 18, color: Alvy.slate),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(99)),
                                    child: Text(chip, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Alvy.orangeDark)),
                                  ),
                                ]),
                                const SizedBox(height: 10),
                                Text(value, style: Alvy.display(size: 24, color: c.text, weight: FontWeight.w800)),
                                Text(label, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                              ]),
                            ),
                          ),
                        );
                    void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => _load());
                    return Column(children: [
                      Row(children: [
                        card(Icons.move_to_inbox_outlined, 'Pickups', '${asInt(st['pending_pickup'])}', 'Pending pickup', () => open(const PickupRequestsScreen())),
                        const SizedBox(width: 12),
                        card(Icons.sort, 'Sort', '${asInt(st['sorting_queue'])}', 'Sorting queue', () => open(const SortingScreen())),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        card(Icons.local_shipping_outlined, 'Today', '${asInt(st['in_transit'])}', 'Out for delivery', () => open(const MonitoringScreen())),
                        const SizedBox(width: 12),
                        card(Icons.two_wheeler, 'Fleet', '${asInt(st['active_riders'])}', 'Active riders', () => open(const DispatchScreen())),
                      ]),
                    ]);
                  }),
                  const SectionTitle('Shipments', padding: EdgeInsets.fromLTRB(0, 18, 0, 12)),
                  // Each status with its count: tap to open that list.
                  SizedBox(
                    height: 44,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      for (final b in asList(d['shipment_counts']))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterPill(
                            '${b['label']}  ${b['count']}',
                            selected: false,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShipmentsScreen(status: '${b['key']}'))),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Recent deliveries',
                    child: asList(d['recent']).isEmpty
                        ? Text('No deliveries yet.', style: TextStyle(color: c.muted))
                        : Column(children: [
                            for (final x in asList(d['recent']))
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: asMap(x['parcel'])['id'] == null ? null : () => openParcel(context, asInt(asMap(x['parcel'])['id']), _load),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('${asMap(x['parcel'])['tracking'] ?? '—'}', style: TextStyle(fontWeight: FontWeight.w700, color: Alvy.slate)),
                                        Text('${x['rider'] ?? '—'} · ${x['area'] ?? '—'}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                                      ]),
                                    ),
                                    Pill('${x['status_label']}', color: parcelColor('${x['status']}')),
                                  ]),
                                ),
                              ),
                          ]),
                  ),
                  SectionCard(
                    title: 'Delivery rate by barangay',
                    child: Column(children: [
                      for (final a in asList(d['area_rates']))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            SizedBox(width: 110, child: Text('${a['name']}', overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(value: asNum(a['rate']) / 100, minHeight: 8, color: kOrange, backgroundColor: c.subtle),
                              ),
                            ),
                            SizedBox(width: 90, child: Text('${a['rate']}% (${a['delivered']}/${a['total']})', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                          ]),
                        ),
                    ]),
                  ),
                  // The design's "COMMAND ACTIONS".
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                    child: Text('COMMAND ACTIONS', style: TextStyle(fontSize: 11.5, letterSpacing: 0.6, fontWeight: FontWeight.w800, color: c.textSecondary)),
                  ),
                  BusyButton('Open Shipment Board', busy: false, icon: Icons.qr_code_scanner,
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackingBoardScreen())).then((_) => _load())),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final (i, (icon, label, page)) in <(IconData, String, Widget)>[
                      (Icons.sort, 'Sort Parcels', const SortingScreen()),
                      (Icons.send_outlined, 'Dispatch', const DispatchScreen()),
                    ].indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => _load()),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: c.surface,
                            side: BorderSide(color: c.border, width: 1.5),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(icon, size: 18, color: kOrange),
                          label: Text(label, style: TextStyle(color: Alvy.slate, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ]),
                ]),
              ),
      ),
    );
  }
}

// ── Coverage ───────────────────────────────────────────────────

/// The web's Coverage: the barangays of the company's municipality it delivers to.
class CoverageScreen extends StatefulWidget {
  const CoverageScreen({super.key});
  @override
  State<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends State<CoverageScreen> {
  Map<String, dynamic>? _d;
  String? _error, _psgc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.areas();
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

  Future<void> _do(Future<dynamic> Function() call) async {
    final r = await call();
    if (!mounted) return;
    showResult(context, r);
    if (r.ok || r.broken) {
      setState(() => _psgc = null);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Coverage'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                // The design's coverage header: how many barangays of the municipality are covered.
                if (d['has_municipality'] == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: cardBox(context, radius: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('DELIVERY COVERAGE', style: TextStyle(fontSize: 11.5, letterSpacing: 0.5, fontWeight: FontWeight.w800, color: c.textSecondary)),
                      Text('${d['municipality']}', style: Alvy.display(size: 21, color: c.text, weight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${asList(d['areas']).length}', style: Alvy.display(size: 28, color: kOrange, weight: FontWeight.w800)),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5, left: 4),
                          child: Text('/ ${d['barangay_total']} barangays covered', style: TextStyle(color: c.textSecondary)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: asInt(d['barangay_total']) == 0 ? 0 : (asList(d['areas']).length / asInt(d['barangay_total'])).clamp(0.0, 1.0),
                          minHeight: 8,
                          color: kOrange,
                          backgroundColor: c.subtle,
                        ),
                      ),
                    ]),
                  ),
                if (d['has_municipality'] != true)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Alvy.warnSoft, borderRadius: BorderRadius.circular(14)),
                    child: Text('Your account has not been assigned a municipality yet. Contact an administrator.', style: TextStyle(color: Alvy.warnText)),
                  )
                else
                  SectionCard(
                    title: 'Add a barangay',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _psgc,
                        decoration: const InputDecoration(labelText: 'Barangay', isDense: true),
                        items: [for (final b in asList(d['barangays'])) DropdownMenuItem(value: '${b['psgc']}', child: Text('${b['name']}'))],
                        onChanged: (v) => setState(() => _psgc = v),
                      ),
                      const SizedBox(height: 8),
                      BusyButton('Add to coverage', busy: false, icon: Icons.add_location_alt_outlined, onPressed: () {
                        final b = asList(d['barangays']).where((x) => '${x['psgc']}' == _psgc).firstOrNull;
                        _do(() => LogisticsApi.addArea(_psgc ?? '', b?['code']?.toString()));
                      }),
                    ]),
                  ),
                if (asList(d['areas']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
                    child: Text('Covered Barangays', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700)),
                  ),
                for (final a in asList(d['areas']))
                  infoRow(
                      context,
                      boxed: false,
                      icon: Icons.place_outlined,
                      title: '${a['name']}',
                      subtitle: '${a['barangay_code'] ?? '—'} · ${a['riders']} rider(s)',
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                        onPressed: () async {
                          if (await confirmAction(context, 'Remove ${a['name']}?', 'It is no longer in your coverage.', confirm: 'Remove', danger: true)) {
                            _do(() => LogisticsApi.removeArea(asInt(a['id'])));
                          }
                        },
                      ),
                  ),
              ]),
      ),
    );
  }
}

// ── Rates and zones ────────────────────────────────────────────

class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});
  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.rates();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = r.body;
      } else {
        _error = r.message;
      }
    });
  }

  Future<Map<String, String>?> _ask(String title, {String first = '', String extra = '', bool name = false}) {
    final f = TextEditingController(text: first), e = TextEditingController(text: extra), n = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (name) TextField(controller: n, decoration: const InputDecoration(labelText: 'Zone name (optional)')),
          TextField(controller: f, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'First kg (₱)')),
          TextField(controller: e, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Each additional kg (₱)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kOrange),
            onPressed: () => Navigator.pop(ctx, {'first': f.text.trim(), 'extra': e.text.trim(), 'name': n.text.trim()}),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _do(Future<dynamic> Function() call) async {
    final r = await call();
    if (!mounted) return;
    showResult(context, r);
    if (r.ok && r.body['rates'] != null) setState(() => _d = r.body);
    if (r.broken) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Shipping Rates'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                Text('SHIPPING RATES', style: TextStyle(fontSize: 11.5, letterSpacing: 0.5, fontWeight: FontWeight.w800, color: c.textSecondary)),
                Text('Rates & Delivery Zones', style: Alvy.display(size: 21, color: c.text, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('A change applies to checkouts started from now on.', style: TextStyle(color: c.textSecondary)),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Rates by route',
                  child: Column(children: [
                    for (final r in asList(d['rates']))
                      infoRow(
                        context,
                        icon: Icons.route_outlined,
                        title: '${r['label']}',
                        subtitle: '${peso(r['first_kg'])} first kg + ${peso(r['additional_kg'])} each additional kg',
                        trailing: Icon(Icons.edit_outlined, size: 18, color: Alvy.slate),
                        onTap: () async {
                          final v = await _ask('${r['label']}', first: '${r['first_kg']}', extra: '${r['additional_kg']}');
                          if (v != null) _do(() => LogisticsApi.updateRate('${r['route']}', v['first']!, v['extra']!));
                        },
                      ),
                  ]),
                ),
                SectionCard(
                  title: 'Delivery zones',
                  child: Column(children: [
                    if (asList(d['zones']).isEmpty) Text('No extra zones yet.', style: TextStyle(color: c.muted)),
                    for (final z in asList(d['zones']))
                      infoRow(context, icon: Icons.map_outlined, navy: true, title: '${z['name']} (${z['province']})',
                          subtitle: '${peso(z['first_kg'])} + ${peso(z['additional_kg'])}/kg'),
                  ]),
                ),
                SectionCard(
                  title: 'Provinces nobody covers yet',
                  child: Column(children: [
                    if (asList(d['uncovered']).isEmpty) Text('Every province is covered.', style: TextStyle(color: c.muted)),
                    for (final u in asList(d['uncovered']))
                      infoRow(
                        context,
                        icon: Icons.add_location_outlined,
                        navy: true,
                        title: '${u['name']}',
                        trailing: TextButton(
                          onPressed: () async {
                            final v = await _ask('Add a zone for ${u['name']}', name: true);
                            if (v != null) _do(() => LogisticsApi.addZone('${u['code']}', v['name']!, v['first']!, v['extra']!));
                          },
                          child: const Text('Add zone'),
                        ),
                      ),
                  ]),
                ),
              ]),
      ),
    );
  }
}

// ── Reports ────────────────────────────────────────────────────

class LogisticsReportsScreen extends StatefulWidget {
  const LogisticsReportsScreen({super.key});
  @override
  State<LogisticsReportsScreen> createState() => _LogisticsReportsScreenState();
}

class _LogisticsReportsScreenState extends State<LogisticsReportsScreen> {
  Map<String, dynamic>? _d;
  String? _error, _from, _to;
  String _tab = 'daily';
  bool _loading = true, _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.reports(from: _from, to: _to);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = r.body;
        _from = '${r.body['from']}';
        _to = '${r.body['to']}';
        _error = null;
      } else if (_d == null) {
        _error = r.message;
      }
    });
  }

  /// The website's download (PDF / XLSX / CSV): saved in the phone's Downloads, then View or Share.
  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    final f = await LogisticsApi.exportReport(_tab, format, from: _from, to: _to);
    if (!mounted) return;
    setState(() => _exporting = false);
    await saveReportDownload(context, f);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    const tabs = [('daily', 'Daily'), ('rider', 'Riders'), ('area', 'Areas'), ('cod', 'COD')];
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Reports', actions: [
        IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () async {
            final r = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (r == null) return;
            _from = ymd(r.start);
            _to = ymd(r.end);
            _load();
          },
        ),
      ]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                Text('${formatDate(_from)} – ${formatDate(_to)}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in tabs) FilterPill(t.$2, selected: _tab == t.$1, onTap: () => setState(() => _tab = t.$1)),
                ]),
                const SizedBox(height: 8),
                SectionCard(child: _table(d)),
                ReportDownloadButtons(busy: _exporting, onDownload: _export),
              ]),
      ),
    );
  }

  Widget _table(Map<String, dynamic> d) {
    final c = context.bc;
    Widget line(String title, String sub, [String? trailing]) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
              ]),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(trailing, style: Alvy.display(size: 16, color: kOrange, weight: FontWeight.w800)),
            ],
          ]),
        );
    final rows = switch (_tab) {
      'rider' => [
          for (final r in asList(d['riders']))
            line('${r['name']} · ${r['area']}', 'Assigned ${r['total']} · delivered ${r['delivered']} · failed ${r['failed']} · returned ${r['returned']}${r['active'] == true ? '' : ' · suspended'}', '${r['rate']}%'),
        ],
      'area' => [
          for (final a in asList(d['areas']))
            line('${a['name']}', 'Assigned ${a['total']} · delivered ${a['delivered']} · failed ${a['failed']} · returned ${a['returned']} · pending ${a['pending']}', '${a['rate']}%'),
        ],
      'cod' => [
          for (final x in asList(d['cod'])) line('${x['tracking']} · ${x['order']}', '${x['rider']} · ${x['date']}', peso(x['amount'])),
        ],
      _ => [
          for (final x in asList(d['daily']))
            line(formatDate('${x['date']}'), 'Received ${x['received']} · sorted ${x['sorted']} · delivered ${x['delivered']} · failed ${x['failed']} · returned ${x['returned']}'),
        ],
    };
    return rows.isEmpty ? Text('No data for these dates.', style: TextStyle(color: c.muted)) : Column(children: rows);
  }
}

// ── Activity log ───────────────────────────────────────────────

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedList(
      title: 'Activity Log',
      empty: 'No activity yet.',
      fetch: (page, tab) => LogisticsApi.activity(page: page),
      itemBuilder: (ctx, l, reload) => infoRow(
        ctx,
        boxed: false,
        navy: true,
        icon: Icons.history,
        title: '${l['action'] ?? ''}${(l['description'] ?? '').toString().isNotEmpty ? ' · ${l['description']}' : ''}',
        subtitle: [
          if (l['old_value'] != null || l['new_value'] != null) '${l['old_value'] ?? '—'} → ${l['new_value'] ?? '—'}',
          if (l['reason'] != null) 'Reason: ${l['reason']}',
          '${formatDateTime(l['created_at'])}${l['ip'] != null ? ' · ${l['ip']}' : ''}',
        ].join('\n'),
      ),
    );
  }
}

// ── Chat ───────────────────────────────────────────────────────

/// The web's logistics chat: riders, couriers, sellers and the admin.
class LogisticsChatScreen extends StatefulWidget {
  const LogisticsChatScreen({super.key});
  @override
  State<LogisticsChatScreen> createState() => _LogisticsChatScreenState();
}

class _LogisticsChatScreenState extends State<LogisticsChatScreen> {
  List<Map<String, dynamic>> _contacts = [];
  String _q = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.chat();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _contacts = asList(r.body['contacts']);
      } else {
        _error = r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = _contacts.where((c) => _q.isEmpty || '${c['name']}'.toLowerCase().contains(_q)).toList()
      ..sort((a, b) => asInt(b['unread']).compareTo(asInt(a['unread'])));
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Messages'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search contacts', prefixIcon: Icon(Icons.search), isDense: true),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              for (final c in list)
                infoRow(
                  context,
                  boxed: false,
                  icon: Icons.chat_bubble_outline,
                  title: '${c['name']}',
                  subtitle: '${c['role']}'.replaceAll('_', ' '),
                  trailing: asInt(c['unread']) > 0 ? Pill('${c['unread']}') : null,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => LogisticsConversationScreen(contactId: asInt(c['id']), name: '${c['name']}')));
                    _load();
                  },
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class LogisticsConversationScreen extends StatefulWidget {
  final int contactId;
  final String name;
  const LogisticsConversationScreen({super.key, required this.contactId, required this.name});
  @override
  State<LogisticsConversationScreen> createState() => _LogisticsConversationScreenState();
}

class _LogisticsConversationScreenState extends State<LogisticsConversationScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  bool _loading = true, _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollNew());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  Future<void> _load() async {
    final r = await LogisticsApi.chat(contactId: widget.contactId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _messages
        ..clear()
        ..addAll(asList(r.body['messages']));
    });
    _toBottom();
  }

  Future<void> _pollNew() async {
    if (!mounted || _loading) return;
    final after = _messages.isEmpty ? null : asInt(_messages.last['id']);
    final r = await LogisticsApi.pollMessages(widget.contactId, after);
    if (!mounted || !r.ok) return;
    final fresh = asList(r.body['messages']).where((m) => !_messages.any((x) => x['id'] == m['id'])).toList();
    if (fresh.isEmpty) return;
    setState(() => _messages.addAll(fresh));
    _toBottom();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final r = await LogisticsApi.sendMessage(widget.contactId, body);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (r.ok) {
        _text.clear();
        _messages
          ..clear()
          ..addAll(asList(r.body['messages']));
      }
    });
    if (!r.ok) showResult(context, r);
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar(widget.name),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kOrange))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final mine = m['mine'] == true;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(color: mine ? kOrange : c.surface, borderRadius: BorderRadius.circular(12), border: mine ? null : Border.all(color: c.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${m['body']}', style: TextStyle(color: mine ? Colors.white : c.text)),
                          Text(formatDate(m['created_at'], 'MMM d · h:mm a'), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : c.muted)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLength: 2000,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Message', isDense: true, counterText: ''),
                ),
              ),
              IconButton(onPressed: _sending ? null : _send, icon: const Icon(Icons.send, color: kOrange)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Account ────────────────────────────────────────────────────

/// The web's logistics Account: name and email. The password is on the Security page (SecurityScreen).
class LogisticsAccountScreen extends StatefulWidget {
  const LogisticsAccountScreen({super.key});
  @override
  State<LogisticsAccountScreen> createState() => _LogisticsAccountScreenState();
}

class _LogisticsAccountScreenState extends State<LogisticsAccountScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true, _saving = false;
  Map<String, String> _errors = {};
  final _name = TextEditingController(), _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> body) {
    _d = body;
    _name.text = '${asMap(body['company'])['name'] ?? ''}';
    _email.text = '${asMap(body['company'])['email'] ?? ''}';
  }

  Future<void> _load() async {
    final r = await LogisticsApi.account();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _fill(r.body);
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors = {};
    });
    final r = await LogisticsApi.updateAccount({
      'name': _name.text.trim(),
      'email': _email.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = r.fieldErrors;
      if (r.ok && r.body['company'] != null) _fill(r.body);
    });
    if (r.ok && r.body['user'] != null) context.read<AuthProvider>().updateUser(asMap(r.body['user']));
    showResult(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    final co = asMap(d?['company']);
    final s = asMap(d?['summary']);
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Account'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                Text('${co['business_name'] ?? co['name']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
                Text('${co['municipality'] ?? 'No municipality assigned'}', style: TextStyle(color: c.muted)),
                const SizedBox(height: 10),
                StatGrid([
                  StatTile(label: 'Barangays', value: '${s['areas']}', icon: Icons.map_outlined),
                  StatTile(label: 'Riders', value: '${s['riders']}', icon: Icons.two_wheeler),
                  StatTile(label: 'Parcels handled', value: '${s['handled']}', icon: Icons.inventory_2_outlined),
                  StatTile(label: 'Delivered', value: '${s['delivered']}', icon: Icons.check_circle_outline, color: const Color(0xFF15803D)),
                ]),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(children: [
                    FormInput(_name, 'Name *', error: _errors['name']),
                    FormInput(_email, 'Email *', keyboard: TextInputType.emailAddress, error: _errors['email']),
                    // The password is on its own Security page now (with the rules checklist), like the website.
                    BusyButton('Save', busy: _saving, onPressed: _save),
                  ]),
                ),
              ]),
      ),
    );
  }
}
