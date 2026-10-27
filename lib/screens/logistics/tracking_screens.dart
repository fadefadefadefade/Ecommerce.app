import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/report_download.dart' show saveReportDownload;
import '../../widgets/waybill_scanner.dart';
import 'hub_waybill.dart';
import 'logistics_kit.dart';
import 'rider_admin_screens.dart' show DispatchScreen;

/// Open a parcel's tracking page (the website opens it after a scan, and to confirm receipt).
Future<void> openTracking(BuildContext context, int id, [VoidCallback? onBack]) async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingDetailScreen(parcelId: id)));
  onBack?.call();
}

// ── Shipment Board ─────────────────────────────────────────────

/// The website's Shipment Board: only the parcels and transfers this center is responsible for, by stage, with
/// one next step per row. Scanning (or typing) a waybill only finds the parcel; receipt is confirmed on its page.
class TrackingBoardScreen extends StatefulWidget {
  const TrackingBoardScreen({super.key});
  @override
  State<TrackingBoardScreen> createState() => _TrackingBoardScreenState();
}

class _TrackingBoardScreenState extends State<TrackingBoardScreen> {
  final _list = GlobalKey<PagedListState>();
  final _scan = TextEditingController();
  String? _q;
  String? _status;
  bool _busy = false;

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  Future<void> _find([String? code]) async {
    final t = (code ?? _scan.text).trim();
    if (t.isEmpty || _busy) return;
    setState(() => _busy = true);
    final r = await LogisticsApi.scan(t);
    if (!mounted) return;
    setState(() => _busy = false);
    showResult(context, r);
    if (r.ok && r.body['parcel_id'] != null) {
      _scan.clear();
      await openTracking(context, asInt(r.body['parcel_id']));
    }
    _list.currentState?.reload();
  }

  Widget _rowAction(BuildContext ctx, Map<String, dynamic> p, VoidCallback reload) {
    final id = asInt(p['id']);
    final t = asMap(p['transfer']);
    FilledButton blue(String label, VoidCallback onTap) =>
        FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)), onPressed: onTap, child: Text(label));
    return switch (p['row_action']) {
      'receive' => blue('Check & receive', () => openTracking(ctx, id, reload)),
      'start_sorting' => blue('Start sorting', () async {
          if (await confirmAction(ctx, 'Start sorting?', 'Start sorting ${p['tracking']}?') && ctx.mounted) {
            act(ctx, () => LogisticsApi.startSorting(id), then: reload);
          }
        }),
      'dispatch' => blue('Confirm dispatch', () async {
          if (await confirmAction(ctx, 'Confirm dispatch?', 'Confirm ${p['tracking']} is leaving for ${t['to']} now?') && ctx.mounted) {
            act(ctx, () => LogisticsApi.transferAction(asInt(t['id']), 'dispatch'), then: reload);
          }
        }),
      'ready' => OutlinedButton(onPressed: () => openTracking(ctx, id, reload), child: const Text('Ready for dispatch…')),
      'final_delivery' => OutlinedButton(
          onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const DispatchScreen())).then((_) => reload()),
          child: const Text('Prepare final delivery')),
      _ => OutlinedButton(onPressed: () => openTracking(ctx, id, reload), child: const Text('Details')),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PagedList(
      key: _list,
      title: 'Shipment Board',
      initialTab: 'incoming',
      empty: 'No shipments here.',
      fetch: (page, tab) => LogisticsApi.tracking(tab: tab ?? 'incoming', q: _q, status: _status, page: page),
      header: (ctx, body, reload) {
        final statuses = asMap(body['statuses']);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionCard(
            title: 'Scan a waybill',
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _scan,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _find(),
                  decoration: const InputDecoration(hintText: 'Scan or type a waybill / tracking number', isDense: true, border: OutlineInputBorder()),
                ),
              ),
              IconButton(
                tooltip: 'Camera',
                onPressed: _busy
                    ? null
                    : () async {
                        final code = await scanWaybill(context);
                        if (code != null) _find(code);
                      },
                icon: const Icon(Icons.qr_code_scanner, color: kOrange),
              ),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: _busy ? null : _find, child: const Text('Find')),
            ]),
          ),
          Row(children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(hintText: 'Tracking, #order, seller, municipality', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
                onSubmitted: (v) {
                  _q = v.trim().isEmpty ? null : v.trim();
                  reload();
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String?>(
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Any status')),
                  for (final e in statuses.entries) DropdownMenuItem<String?>(value: e.key, child: Text('${e.value}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  _status = v;
                  reload();
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
        ]);
      },
      itemBuilder: (ctx, p, reload) {
        final t = p['transfer'] == null ? null : asMap(p['transfer']);
        final last = p['last_event'] == null ? null : asMap(p['last_event']);
        return ParcelCard(
          p,
          onTap: () => openTracking(ctx, asInt(p['id']), reload),
          extra: [
            if (p['next'] != null) 'Next: ${p['next']}',
            if (t != null) '${t['reference']} ${t['from']} → ${t['to']} (${t['status_label']}${t['delayed'] == true ? ', delayed' : ''})',
            if (t != null && t['status'] == 'in_transit' && t['expected_by'] != null) 'Due ${formatDateTime(t['expected_by'])}',
            if (p['rider'] != null) 'Rider ${p['rider']}',
            if (last != null) '${last['label']} · ${formatDateTime(last['at'])}',
          ],
          actions: [_rowAction(ctx, p, reload)],
        );
      },
    );
  }
}

// ── One shipment ───────────────────────────────────────────────

/// The website's shipment page: confirm receipt (condition and notes), sort to a barangay or transfer to another
/// sorting center (with a transporter), dispatch or cancel the transfer, the tracking history and exceptions.
class TrackingDetailScreen extends StatefulWidget {
  final int parcelId;
  const TrackingDetailScreen({super.key, required this.parcelId});
  @override
  State<TrackingDetailScreen> createState() => _TrackingDetailScreenState();
}

class _TrackingDetailScreenState extends State<TrackingDetailScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  // Confirm Package Received
  String _condition = 'good';
  final _notes = TextEditingController();
  bool _checked = false;
  // Sort / transfer
  int? _area;
  int? _hub;
  int? _transporter;
  final _reason = TextEditingController();
  // Exception
  String? _exType;
  final _exDetails = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    _reason.dispose();
    _exDetails.dispose();
    super.dispose();
  }

  void _show(Map<String, dynamic> body) {
    _d = body;
    final p = asMap(body['parcel']);
    _area = body['suggested_area_id'] == null ? null : asInt(body['suggested_area_id']);
    final next = p['next'] == null ? null : asMap(p['next']);
    _hub = next?['center_id'] == null ? null : asInt(next!['center_id']);
  }

  Future<void> _load() async {
    final r = await LogisticsApi.trackingParcel(widget.parcelId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (r.ok) _show(r.body);
    });
  }

  Future<void> _do(Future<ApiResponse> Function() call, {bool reload = false}) async {
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok && r.body['parcel'] != null) _show(r.body);
    });
    showResult(context, r);
    if ((r.ok && reload) || r.broken) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final d = _d;
    final p = asMap(d?['parcel']);
    final actions = asMap(p['actions']);
    final t = p['transfer'] == null ? null : asMap(p['transfer']);
    Widget row(String l, dynamic v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(l, style: TextStyle(color: c.muted))),
            Expanded(child: Text('${v ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar(d == null ? 'Shipment' : '${p['waybill'] ?? p['tracking']}', actions: [
        if (actions['waybill'] == true)
          IconButton(tooltip: 'Print waybill', onPressed: () => openWaybills(context, [widget.parcelId]), icon: const Icon(Icons.print_outlined)),
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
                child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 40), children: [
                  SectionCard(
                    title: 'Package',
                    child: Column(children: [
                      Row(children: [const Spacer(), Pill('${p['status_label']}', color: parcelColor('${p['status']}'))]),
                      row('Tracking', p['tracking']),
                      row('Order', p['order_number']),
                      row('Seller', p['seller']),
                      row('Receiver', '${p['receiver'] ?? '—'} · ${p['dropoff_address'] ?? p['destination'] ?? ''}'),
                      row('Weight', p['weight_kg'] != null ? '${p['weight_kg']} kg' : null),
                      row('Payment', p['cod'] != null ? 'COD ${peso(p['cod'])}' : p['payment']),
                      row('At', p['held_by']),
                      row('Next destination', p['next_label']),
                      if (p['received_at'] != null) row('Received', '${formatDateTime(p['received_at'])} by ${p['received_by'] ?? '—'}'),
                    ]),
                  ),
                  if (actions['receive'] == true) _receiveCard(p, t),
                  if (actions['start_sorting'] == true || actions['sort'] == true || actions['transfer'] == true) _sortCard(p, actions),
                  if (t != null) _transferCard(t),
                  SectionCard(
                    title: 'Tracking history',
                    child: asList(p['events']).isEmpty
                        ? Text('No events yet.', style: TextStyle(color: c.muted))
                        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            for (final e in asList(p['events']))
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text.rich(TextSpan(children: [
                                    TextSpan(text: '${e['label']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                    if ((e['note'] ?? '').toString().isNotEmpty) TextSpan(text: ' — ${e['note']}', style: TextStyle(color: c.muted)),
                                  ])),
                                  if (e['corrects'] != null) Text('Corrects: ${e['corrects']}', style: TextStyle(fontSize: 11.5, color: c.muted)),
                                  Text(
                                    [
                                      formatDateTime(e['at']),
                                      e['by'] != null ? 'By ${e['by']}' : 'System',
                                      if (e['from_status'] != null) '${e['from_status']} → ${e['to_status']}',
                                    ].join(' · '),
                                    style: TextStyle(fontSize: 11.5, color: c.muted),
                                  ),
                                ]),
                              ),
                          ]),
                  ),
                  _exceptionsCard(p),
                  _historyCard(p),
                ]),
              ),
      ),
    );
  }

  Widget _receiveCard(Map<String, dynamic> p, Map<String, dynamic>? t) {
    final c = context.bc;
    return SectionCard(
      title: 'Confirm Package Received',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (t != null && t['stray'] == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('This parcel is in transit to ${t['to']}. Receive it here only if it physically arrived at your hub.',
                style: const TextStyle(color: Color(0xFFB45309))),
          ),
        Text.rich(TextSpan(style: TextStyle(fontSize: 13, color: c.text), children: [
          const TextSpan(text: 'Check the label matches '),
          TextSpan(text: '${p['waybill'] ?? p['tracking']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const TextSpan(text: ' and the receiver '),
          TextSpan(text: '${p['receiver'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
          const TextSpan(text: ', then record its condition.'),
        ])),
        RadioGroup<String>(
          groupValue: _condition,
          onChanged: (v) => setState(() => _condition = v ?? 'good'),
          child: const Row(children: [
            Expanded(child: RadioListTile<String>(value: 'good', title: Text('Good condition'), dense: true, contentPadding: EdgeInsets.zero)),
            Expanded(child: RadioListTile<String>(value: 'damaged', title: Text('Damaged'), dense: true, contentPadding: EdgeInsets.zero)),
          ]),
        ),
        TextField(controller: _notes, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (required if damaged)', border: OutlineInputBorder())),
        CheckboxListTile(
          value: _checked,
          activeColor: kOrange,
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('The parcel is physically here and I checked it.'),
          onChanged: (v) => setState(() => _checked = v == true),
        ),
        BusyButton('Confirm Package Received', busy: _busy, color: const Color(0xFF2563EB), onPressed: () {
          if (!_checked) return showError(context, 'Tick the box to confirm the parcel is physically here and you checked it.');
          _do(() => LogisticsApi.confirmReceived(widget.parcelId, _condition, _notes.text.trim()));
        }),
      ]),
    );
  }

  Widget _sortCard(Map<String, dynamic> p, Map<String, dynamic> actions) {
    final c = context.bc;
    final d = _d!;
    final local = asMap(p['next'])['type'] == 'local';
    final areas = asList(d['areas']);
    final hubs = asList(d['hubs']);
    final transporters = asList(d['transporters']);
    final transfer = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<int>(
        initialValue: _hub,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Transfer to sorting center', border: OutlineInputBorder(), isDense: true),
        items: [
          for (final h in hubs)
            DropdownMenuItem(value: asInt(h['id']), child: Text('${h['name']}${h['municipality'] != null ? ' — ${h['municipality']}' : ''}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => _hub = v),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<int?>(
        initialValue: _transporter,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Transporter (optional)', border: OutlineInputBorder(), isDense: true),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('— None —')),
          for (final r in transporters) DropdownMenuItem<int?>(value: asInt(r['id']), child: Text('${r['name']}')),
        ],
        onChanged: (v) => setState(() => _transporter = v),
      ),
      if (transporters.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text("No riders are allowed to transport transfers yet (set it on the rider's page).", style: TextStyle(fontSize: 11.5, color: c.muted)),
        ),
      const SizedBox(height: 8),
      TextField(controller: _reason, maxLength: 500, decoration: const InputDecoration(labelText: 'Reason (required if not the suggested center)', border: OutlineInputBorder(), isDense: true)),
      OutlinedButton(
        onPressed: _busy
            ? null
            : () async {
                if (await confirmAction(context, 'Create this transfer?', 'The parcel stays here until you dispatch it.') && mounted) {
                  _do(() => LogisticsApi.initiateTransfer(widget.parcelId, _hub ?? 0, _reason.text.trim(), transporterId: _transporter), reload: true);
                }
              },
        child: const Text('Create transfer'),
      ),
    ]);
    return SectionCard(
      title: local ? 'Sort to barangay' : 'Sort or transfer',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (actions['start_sorting'] == true)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (await confirmAction(context, 'Start sorting?', 'Start sorting ${p['tracking']}?') && mounted) {
                        _do(() => LogisticsApi.startSorting(widget.parcelId));
                      }
                    },
              child: const Text('Start sorting'),
            ),
          ),
        if (actions['sort'] == true) ...[
          DropdownButtonFormField<int>(
            initialValue: _area,
            isExpanded: true,
            decoration: const InputDecoration(labelText: "Buyer's barangay", border: OutlineInputBorder(), isDense: true),
            items: [
              for (final a in areas)
                DropdownMenuItem(
                  value: asInt(a['id']),
                  child: Text('${a['name']}${asInt(a['id']) == asInt(d['suggested_area_id']) ? ' (from the address)' : ''}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _area = v),
          ),
          const SizedBox(height: 8),
          BusyButton('Sort', busy: _busy, onPressed: () => _do(() => LogisticsApi.sort(widget.parcelId, _area ?? 0), reload: true)),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Sorting gives the delivery to a rider of that barangay; Rider Dispatch shows who has the job.', style: TextStyle(fontSize: 12, color: c.muted)),
          ),
        ],
        if (actions['transfer'] == true) ...[
          const SizedBox(height: 8),
          local
              ? ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Send to another sorting center instead', style: TextStyle(fontSize: 13, color: c.muted)),
                  children: [transfer],
                )
              : transfer,
        ],
      ]),
    );
  }

  Widget _transferCard(Map<String, dynamic> t) {
    final c = context.bc;
    final bad = t['delayed'] == true || t['status'] == 'exception';
    return SectionCard(
      title: 'Transfer ${t['reference']}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Pill('${t['status_label']}${t['delayed'] == true ? ' · Delayed' : ''}', color: bad ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
        const SizedBox(height: 6),
        Text('${t['from']} → ${t['to']}', style: const TextStyle(fontWeight: FontWeight.w700)),
        if (t['transporter'] != null) Text('Transporter: ${t['transporter']}', style: TextStyle(color: c.muted)),
        if (t['dispatched_at'] != null) Text('Dispatched ${formatDateTime(t['dispatched_at'])} · due ${formatDateTime(t['expected_by'])}', style: TextStyle(color: c.muted)),
        if (t['exception_reason'] != null) Text('${t['exception_reason']}', style: const TextStyle(color: Color(0xFFB91C1C))),
        if (t['can_dispatch'] == true || t['can_cancel'] == true) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (t['can_dispatch'] == true)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                onPressed: _busy
                    ? null
                    : () async {
                        if (await confirmAction(context, 'Confirm dispatch?', 'Confirm the parcel is leaving now?') && mounted) {
                          _do(() => LogisticsApi.transferAction(asInt(t['id']), 'dispatch'), reload: true);
                        }
                      },
                child: const Text('Confirm dispatch'),
              ),
            if (t['can_cancel'] == true)
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                onPressed: _busy
                    ? null
                    : () async {
                        if (await confirmAction(context, 'Cancel this transfer?', 'The parcel stays here.', danger: true) && mounted) {
                          _do(() => LogisticsApi.transferAction(asInt(t['id']), 'cancel'), reload: true);
                        }
                      },
                child: const Text('Cancel transfer'),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _exceptionsCard(Map<String, dynamic> p) {
    final c = context.bc;
    final types = asMap(_d?['exception_types']);
    return SectionCard(
      title: 'Exceptions',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (asList(p['exceptions']).isEmpty) Text('None.', style: TextStyle(color: c.muted)),
        for (final x in asList(p['exceptions']))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${x['type_label']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Pill(x['status'] == 'open' ? 'Open' : 'Resolved', color: x['status'] == 'open' ? const Color(0xFFDC2626) : const Color(0xFF15803D)),
              ]),
              Text('${x['details']}'),
              Text('${formatDateTime(x['created_at'])}${x['reporter'] != null ? ' · ${x['reporter']}' : ''}', style: TextStyle(fontSize: 11.5, color: c.muted)),
              if (x['resolution'] != null) Text('Resolution: ${x['resolution']}'),
            ]),
          ),
        const Divider(),
        DropdownButtonFormField<String>(
          initialValue: _exType,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Flag shipment exception', border: OutlineInputBorder(), isDense: true),
          items: [for (final e in types.entries) DropdownMenuItem(value: e.key, child: Text('${e.value}'))],
          onChanged: (v) => setState(() => _exType = v),
        ),
        const SizedBox(height: 8),
        TextField(controller: _exDetails, maxLength: 500, maxLines: 2, decoration: const InputDecoration(hintText: 'What is wrong?', border: OutlineInputBorder())),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () {
                  _do(() => LogisticsApi.flagException(widget.parcelId, _exType ?? '', _exDetails.text.trim())).then((_) {
                    if (mounted && asList(_d?['parcel']?['exceptions']).isNotEmpty) _exDetails.clear();
                  });
                },
          child: const Text('Record exception'),
        ),
      ]),
    );
  }

  Widget _historyCard(Map<String, dynamic> p) {
    final c = context.bc;
    final h = asMap(p['history']);
    final transfers = asList(h['transfers']), pickups = asList(h['pickups']), deliveries = asList(h['deliveries']);
    Widget line(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(text, style: const TextStyle(fontSize: 13)));
    return SectionCard(
      title: 'Transfers & riders',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final t in transfers) line('${t['reference']} · ${t['from']} → ${t['to']} · ${t['status_label']}${t['transporter'] != null ? ' · ${t['transporter']}' : ''}'),
        for (final x in pickups) line('Pickup · ${x['rider'] ?? '—'} · ${x['status_label']}'),
        for (final x in deliveries) line('Delivery attempt ${x['attempt']} · ${x['rider'] ?? '—'} · ${x['status_label']}'),
        if (transfers.isEmpty && pickups.isEmpty && deliveries.isEmpty) Text('None yet.', style: TextStyle(color: c.muted)),
      ]),
    );
  }
}

// ── Commission & Earnings ──────────────────────────────────────

/// The website's Commission & Earnings: each parcel this hub handled, its share of the shipping fee, ALVY's
/// commission, the hub's rider pay and what is left, by period and status, with CSV / Excel export.
class LogisticsCommissionsScreen extends StatefulWidget {
  const LogisticsCommissionsScreen({super.key});
  @override
  State<LogisticsCommissionsScreen> createState() => _LogisticsCommissionsScreenState();
}

class _LogisticsCommissionsScreenState extends State<LogisticsCommissionsScreen> {
  String _period = 'month';
  DateTimeRange? _custom;
  String? _status;
  Map<String, dynamic>? _d;
  List<Map<String, dynamic>> _rows = [];
  int _page = 1, _last = 1;
  bool _loading = true, _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _from => _custom == null ? null : ymd(_custom!.start);
  String? get _to => _custom == null ? null : ymd(_custom!.end);

  Future<void> _load({bool more = false}) async {
    final r = await LogisticsApi.commissions(period: _period, from: _from, to: _to, status: _status, page: more ? _page + 1 : 1);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (!r.ok) return;
      _d = r.body;
      final rows = asList(r.body['data']);
      _rows = more ? [..._rows, ...rows] : rows;
      _page = asInt(asMap(r.body['meta'])['current_page']);
      _last = asInt(asMap(r.body['meta'])['last_page']);
    });
  }

  Future<void> _pickPeriod(String p) async {
    if (p == 'custom') {
      final now = DateTime.now();
      final r = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 2), lastDate: now, initialDateRange: _custom);
      if (r == null) return;
      _custom = r;
    } else {
      _custom = null;
    }
    setState(() {
      _period = p;
      _loading = true;
    });
    _load();
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    final f = await LogisticsApi.exportCommissions(format, period: _period, from: _from, to: _to, status: _status);
    if (!mounted) return;
    setState(() => _exporting = false);
    if (!f.ok) return showError(context, f.error!.message);
    await saveReportDownload(context, f);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final d = _d;
    final s = asMap(d?['summary']);
    final statuses = asMap(d?['statuses']);
    final parcels = asInt(s['parcels']);
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Commission & Earnings'),
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
                  Wrap(spacing: 6, children: [
                    for (final (key, label) in const [('today', 'Today'), ('week', 'This week'), ('month', 'This month'), ('custom', 'Custom')])
                      ChoiceChip(label: Text(label), selected: _period == key, selectedColor: kOrange.withValues(alpha: .15), onSelected: (_) => _pickPeriod(key)),
                  ]),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${d['range_label']}', style: TextStyle(color: c.muted, fontSize: 12))),
                  StatGrid([
                    StatTile(label: 'Shipping fees earned', value: peso(s['fees']), icon: Icons.local_shipping_outlined, color: const Color(0xFF2563EB),
                        hint: '$parcels parcel${parcels == 1 ? '' : 's'}, your share'),
                    StatTile(label: 'ALVY commission (${asNum(d['rate'])}%)', value: '−${peso(s['commission'])}', icon: Icons.percent, color: const Color(0xFF9333EA), hint: 'Kept by ALVY'),
                    StatTile(label: 'Rider pay', value: '−${peso(s['rider_pay'])}', icon: Icons.two_wheeler, color: const Color(0xFFB45309), hint: 'Per pickup and per delivery'),
                    StatTile(label: 'Net earnings', value: peso(s['net']), icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF15803D),
                        hint: '${peso(s['earned_net'])} earned · ${peso(s['pending_net'])} pending'),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All statuses')),
                          for (final e in statuses.entries) DropdownMenuItem<String?>(value: e.key, child: Text('${e.value}')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _status = v;
                            _loading = true;
                          });
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _exporting ? null : () => _export('csv'), child: const Text('CSV')),
                    const SizedBox(width: 6),
                    OutlinedButton(onPressed: _exporting ? null : () => _export('xlsx'), child: const Text('Excel')),
                  ]),
                  const SizedBox(height: 10),
                  if (_rows.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('No parcels in this period.', textAlign: TextAlign.center, style: TextStyle(color: c.muted))),
                  for (final r in _rows)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => openTracking(context, asInt(r['parcel_id'])),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${r['waybill'] ?? r['tracking']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                              Pill('${r['status_label']}', color: Pill.forState(r['status'] == 'earned' ? 'completed' : '${r['status']}')),
                            ]),
                            Text('${r['order_number'] ?? '—'} · ${formatDate(r['created_at'])} · ${r['role']}', style: TextStyle(fontSize: 12, color: c.muted)),
                            const SizedBox(height: 4),
                            Text(
                              'Fee ${peso(r['fee'])}${asInt(r['hubs']) > 1 ? ' ÷ ${r['hubs']} hubs' : ''} = share ${peso(r['share'])} · commission ${peso(r['commission'])} · rider pay ${peso(r['rider_pay'])}',
                              style: TextStyle(fontSize: 12, color: c.textSecondary),
                            ),
                            Text('Net ${peso(r['net'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ]),
                        ),
                      ),
                    ),
                  if (_page < _last) TextButton(onPressed: () => _load(more: true), child: const Text('Load more')),
                ]),
              ),
      ),
    );
  }
}

// ── Transfers between hubs ─────────────────────────────────────

/// The website's Sorting Center Transfers: create a transfer (parcel, destination, optional transporter, reason),
/// confirm dispatch or cancel outgoing ones, receive incoming ones on their shipment page, and the history.
class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});
  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  int? _parcel, _to, _transporter;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.transfers();
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

  Future<void> _do(Future<ApiResponse> Function() call, {bool created = false}) async {
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok && r.body['parcels'] != null) _d = r.body;
      if (r.ok && created) {
        _parcel = _to = _transporter = null;
        _reason.clear();
      }
    });
    showResult(context, r);
    if (r.broken) _load();
  }

  void _pickParcel(int? id) {
    final p = asList(_d?['parcels']).where((x) => asInt(x['id']) == id).firstOrNull;
    final next = p?['next'] == null ? null : asMap(p!['next']);
    setState(() {
      _parcel = id;
      // The website preselects the center serving the address.
      if (next?['center_id'] != null) _to = asInt(next!['center_id']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    final outgoing = asList(d?['outgoing']), incoming = asList(d?['incoming']);
    final delayed = [...outgoing, ...incoming].where((t) => t['delayed'] == true).length;
    Widget title(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, color: c.text)));
    Color badge(Map<String, dynamic> t) =>
        t['delayed'] == true || t['status'] == 'exception' ? const Color(0xFFDC2626) : (t['status'] == 'pending' ? const Color(0xFFB45309) : const Color(0xFF2563EB));
    Widget row(Map<String, dynamic> t, String other, String status, List<String> notes, List<Widget> actions) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: t['parcel_id'] == null ? null : () => openTracking(context, asInt(t['parcel_id']), _load),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${t['reference']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  Pill(status, color: badge(t)),
                ]),
                Text('${t['waybill'] ?? t['tracking']} · $other', style: TextStyle(fontSize: 12, color: c.muted)),
                for (final n in notes) Text(n, style: TextStyle(fontSize: 11.5, color: c.muted)),
                if (actions.isNotEmpty) ...[const SizedBox(height: 6), Wrap(spacing: 8, children: actions)],
              ]),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Sorting Center Transfers', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 40), children: [
                  StatGrid([
                    StatTile(label: 'Awaiting dispatch', value: '${outgoing.where((t) => t['status'] == 'pending').length}', icon: Icons.upload_outlined),
                    StatTile(label: 'Sent, in transit', value: '${outgoing.where((t) => t['status'] == 'in_transit').length}', icon: Icons.swap_horiz, color: const Color(0xFF2563EB)),
                    StatTile(label: 'Coming to you', value: '${incoming.where((t) => t['status'] == 'in_transit').length}', icon: Icons.move_to_inbox_outlined, color: const Color(0xFF15803D)),
                    StatTile(label: 'Delayed', value: '$delayed', icon: Icons.schedule, color: delayed > 0 ? const Color(0xFFDC2626) : const Color(0xFF6B7280)),
                  ]),
                  title('Create a Transfer'),
                  SectionCard(
                    child: asList(d['parcels']).isEmpty
                        ? Text('No parcels available for transfer.\nOnly parcels received at your hub (with no active transfer or rider) can be transferred.',
                            textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 13))
                        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            DropdownButtonFormField<int>(
                              initialValue: _parcel,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Parcel', border: OutlineInputBorder(), isDense: true),
                              items: [
                                for (final p in asList(d['parcels']))
                                  DropdownMenuItem(
                                    value: asInt(p['id']),
                                    child: Text('${p['tracking']} — ${p['destination']} · ${asMap(p['next'])['label'] ?? ''}', overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                              onChanged: _pickParcel,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              key: ValueKey('to-$_to'),
                              initialValue: _to,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Destination sorting center', border: OutlineInputBorder(), isDense: true),
                              items: [
                                for (final s in asList(d['centers']))
                                  DropdownMenuItem(value: asInt(s['id']), child: Text('${s['name']} — ${s['municipality'] ?? ''}', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) => setState(() => _to = v),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int?>(
                              initialValue: _transporter,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Transporter (optional)', border: OutlineInputBorder(), isDense: true),
                              items: [
                                const DropdownMenuItem<int?>(value: null, child: Text('— None —')),
                                for (final r in asList(d['transporters'])) DropdownMenuItem<int?>(value: asInt(r['id']), child: Text('${r['name']}')),
                              ],
                              onChanged: (v) => setState(() => _transporter = v),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _reason,
                              maxLength: 500,
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'Reason (needed when it is not the center serving the address)', border: OutlineInputBorder()),
                            ),
                            BusyButton('Create transfer', busy: _busy, icon: Icons.upload_outlined, onPressed: () async {
                              if (_parcel == null) return showError(context, 'Choose a parcel.');
                              if (!await confirmAction(context, 'Create this transfer?', 'The parcel stays here until you confirm dispatch.') || !mounted) return;
                              _do(() => LogisticsApi.initiateTransfer(_parcel!, _to ?? 0, _reason.text.trim(), transporterId: _transporter), created: true);
                            }),
                          ]),
                  ),
                  title('Outgoing Transfers'),
                  if (outgoing.isEmpty) Text('No outgoing transfers.', style: TextStyle(color: c.muted)),
                  for (final t in outgoing)
                    row(t, 'To ${t['to']}', '${t['status_label']}', [
                      if (t['dispatched_at'] != null) 'Sent ${formatDateTime(t['dispatched_at'])}',
                      if (t['transporter'] != null) 'Transporter: ${t['transporter']}',
                    ], [
                      if (t['status'] == 'pending') ...[
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (await confirmAction(context, 'Confirm dispatch?', 'Confirm ${t['tracking']} is leaving now?') && mounted) {
                                    _do(() => LogisticsApi.transferAction(asInt(t['id']), 'dispatch'));
                                  }
                                },
                          child: const Text('Confirm dispatch'),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (await confirmAction(context, 'Cancel this transfer?', 'The parcel stays here.', danger: true) && mounted) {
                                    _do(() => LogisticsApi.transferAction(asInt(t['id']), 'cancel'));
                                  }
                                },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ]),
                  title('Incoming Transfers'),
                  if (incoming.isEmpty) Text('No incoming transfers right now.', style: TextStyle(color: c.muted)),
                  for (final t in incoming)
                    row(t, 'From ${t['from']}', t['status'] == 'pending' ? 'Not dispatched yet' : '${t['status_label']}', [
                      if (t['status'] == 'in_transit' && t['expected_by'] != null) 'Due ${formatDateTime(t['expected_by'])}',
                    ], [
                      if (t['status'] == 'in_transit')
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: kOrange),
                          onPressed: () => openTracking(context, asInt(t['parcel_id']), _load),
                          child: const Text('Check & receive'),
                        ),
                      if (t['status'] == 'pending')
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (await confirmAction(context, 'Decline this transfer?', 'The parcel stays with the sender.', danger: true) && mounted) {
                                    _do(() => LogisticsApi.transferAction(asInt(t['id']), 'reject'));
                                  }
                                },
                          child: const Text('Decline'),
                        ),
                    ]),
                  title('Transfer History (last 30)'),
                  if (asList(d['history']).isEmpty) Text('No transfers yet.', style: TextStyle(color: c.muted)),
                  for (final t in asList(d['history']))
                    row(t, t['direction'] == 'out' ? 'Sent to ${t['to']}' : 'Received from ${t['from']}', '${t['status_label']}',
                        [formatDateTime(t['received_at'] ?? t['created_at'])], const []),
                ]),
              ),
      ),
    );
  }
}
