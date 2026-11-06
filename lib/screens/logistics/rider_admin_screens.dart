import 'dart:async';

import 'package:flutter/material.dart';
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
  await Navigator.push(context, MaterialPageRoute(
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
                Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 2), child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: ctx.bc.muted))),
                for (final c in choices.where((c) => (c['available'] == true) == available))
                  ListTile(
                    enabled: available,
                    leading: Icon(Icons.two_wheeler, color: available ? const Color(0xFF15803D) : ctx.bc.muted),
                    title: Text(available ? '${c['name']} (${c['active_jobs']} ${asInt(c['active_jobs']) == 1 ? 'job' : 'jobs'})' : '${c['name']} · ${c['why']}'),
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
    final offer = p['offer'] == null ? null : asMap(p['offer']);
    final id = asInt(p['id']);
    return ParcelCard(
      p,
      onTap: () => openParcel(context, id, _load),
      extra: [
        '${p['job_kind'] == 'pickup' ? 'Pickup' : 'Delivery'} job',
        if (offer != null) 'Offered to ${offer['rider']} (${offer['seconds_left']}s)',
      ],
      actions: [
        Checkbox(value: _selected.contains(id), activeColor: kOrange, onChanged: (v) => setState(() => v == true ? _selected.add(id) : _selected.remove(id))),
        if (p['unassigned'] != true && offer == null)
          OutlinedButton(onPressed: () => _do(() => LogisticsApi.autoAssign(id)), child: const Text('Auto assign')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => _assign(p), child: const Text('Assign')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    Widget title(String t) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, color: c.text)));
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
                child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
                  Text('Offers last ${d['offer_seconds']} seconds. A rider can hold up to ${d['max_active']} jobs.', style: TextStyle(color: c.muted, fontSize: 12)),
                  title('Waiting for a rider (${asList(d['jobs']).length})'),
                  if (asList(d['jobs']).isEmpty) Text('No jobs waiting.', style: TextStyle(color: c.muted)),
                  for (final p in asList(d['jobs'])) _job(p),
                  title('Unassigned — 3 riders declined or let it expire (${asList(d['unassigned']).length})'),
                  if (asList(d['unassigned']).isEmpty) Text('None.', style: TextStyle(color: c.muted)),
                  for (final p in asList(d['unassigned'])) _job(p),
                  title('Given to a rider, not started yet'),
                  if (asList(d['not_started']).isEmpty) Text('None.', style: TextStyle(color: c.muted)),
                  for (final j in asList(d['not_started']))
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${j['tracking']} · ${j['kind']}'),
                        subtitle: Text('${j['rider']} · since ${formatDateTime(j['since'])}'),
                        trailing: TextButton(onPressed: () => _assign(j, reassign: true), child: const Text('Reassign')),
                      ),
                    ),
                  title('Riders'),
                  for (final r in _riders)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.circle, size: 12, color: r['online'] == true ? const Color(0xFF15803D) : c.muted),
                      title: Text('${r['full_name']}'),
                      subtitle: Text('${r['area'] ?? '—'} · ${r['status_label']}'),
                      trailing: Text('${r['active_jobs']}/${d['max_active']} jobs'),
                    ),
                ]),
              ),
      ),
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
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
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
      itemBuilder: (ctx, r, reload) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () async {
            await Navigator.push(ctx, MaterialPageRoute(builder: (_) => RiderDetailScreen(riderId: asInt(r['id']))));
            reload();
          },
          leading: Icon(Icons.two_wheeler, color: r['online'] == true ? const Color(0xFF15803D) : ctx.bc.muted),
          title: Text('${r['full_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text([r['area'] ?? '—', '${r['vehicle_type'] ?? ''} ${r['plate_number'] ?? ''}'.trim(), if (r['needs_reverification'] == true) 'Re-verify vehicle']
              .where((e) => '$e'.isNotEmpty)
              .join(' · ')),
          trailing: Pill('${r['status_label']}', color: Pill.forState('${r['status_label']}'.toLowerCase() == 'suspended' ? 'off' : '${r['status_label']}')),
        ),
      ),
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
            : ListView(padding: const EdgeInsets.all(12), children: [
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
                    row('License', '${r['license_number'] ?? '—'} · expires ${r['license_expiry'] != null ? formatDate(r['license_expiry'], 'MM/dd/yyyy') : '—'}'),
                    row('Active jobs', r['active_jobs']),
                    row('COD balance', peso(r['cod_balance'])),
                    row('COD to confirm', peso(r['cod_pending'])),
                    row('Hub transfers', r['can_transport_transfers'] == true
                        ? 'Allowed to carry parcels between sorting centers'
                        : 'Last-mile only (not allowed to carry hub transfers)'),
                    if (r['rejection_reason'] != null) row('Rejected', r['rejection_reason']),
                  ]),
                ),
                if (r['needs_reverification'] == true)
                  Card(
                    color: const Color(0xFFFFF7ED),
                    child: ListTile(
                      title: const Text('Vehicle changed: check the new OR/CR', style: TextStyle(color: Color(0xFF9A3412))),
                      trailing: FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => _do('verify'), child: const Text('Verified')),
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
                  BusyButton('Resend activation email', busy: false, icon: Icons.forward_to_inbox,
                      onPressed: () => act(context, () => LogisticsApi.resendRiderActivation(widget.riderId))),
                if (r['application_status'] == 'pending') ...[
                  BusyButton('Approve', busy: false, color: const Color(0xFF15803D), onPressed: () => _do('approve')),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final reason = await showReasonDialog(context, title: 'Reject rider', message: 'They are told the reason (10 to 300 characters).', confirmLabel: 'Reject', maxLength: 300);
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
                                title: 'Suspend rider', message: 'They go Offline and get no jobs. Give the reason (10 to 300 characters).', confirmLabel: 'Suspend', maxLength: 300);
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
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionCard(
            title: 'Riders\' COD',
            child: Column(children: [
              for (final r in asList(body['riders']))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${r['name']}'),
                  subtitle: Text('Collected ${peso(r['collected'])} · to confirm ${peso(r['pending'])}'),
                  trailing: Text(peso(r['balance']), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ]),
          ),
          SectionCard(
            title: 'Daily reconciliation · ${formatDate(body['date'])}',
            trailing: IconButton(
              icon: const Icon(Icons.event),
              onPressed: () async {
                final p = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: DateTime.now());
                if (p != null) {
                  _date = ymd(p);
                  reload();
                }
              },
            ),
            child: asList(body['daily']).isEmpty
                ? Text('No COD collected or remitted on this day.', style: TextStyle(color: c.muted))
                : Column(children: [
                    for (final d in asList(body['daily']))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${d['rider']}'),
                        subtitle: Text('Collected ${peso(d['collected'])} · remitted ${peso(d['remitted'])}'),
                        trailing: Text(peso(d['difference']),
                            style: TextStyle(fontWeight: FontWeight.w800, color: asNum(d['difference']) < 0 ? const Color(0xFFDC2626) : const Color(0xFF15803D))),
                      ),
                  ]),
          ),
          Text('Remittances', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 6),
        ]);
      },
      itemBuilder: (ctx, r, reload) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text('${r['rider']} · ${peso(r['amount'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Expected ${peso(r['expected'])}${asNum(r['shortfall']) > 0 ? ' · short ${peso(r['shortfall'])}' : ''}\n${formatDateTime(r['created_at'])}'),
          isThreeLine: true,
          trailing: r['status'] == 'pending'
              ? FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kOrange),
                  onPressed: () => act(ctx, () => LogisticsApi.confirmRemittance(asInt(r['id'])), then: reload),
                  child: const Text('Confirm'),
                )
              : const Pill('Confirmed', color: Color(0xFF15803D)),
        ),
      ),
    );
  }
}
