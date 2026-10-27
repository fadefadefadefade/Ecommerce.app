import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import 'hub_more_screens.dart';
import 'logistics_kit.dart';
import 'parcel_detail_screen.dart';
import '../../widgets/password_code_dialog.dart';
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
          icon: Icon(Icons.date_range, color: _from != null ? Colors.yellowAccent : null),
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
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
                  if (_from != null) Text('${formatDate(_from)} – ${formatDate(_to)}', style: TextStyle(color: c.muted)),
                  const SizedBox(height: 10),
                  SectionCard(
                    title: 'Shipments',
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final b in asList(d['shipment_counts']))
                        ActionChip(
                          label: Text('${b['label']}: ${b['count']}'),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShipmentsScreen(status: '${b['key']}'))),
                        ),
                    ]),
                  ),
                  StatGrid([
                    StatTile(label: 'Parcels received today', value: '${asMap(d['stats'])['total_parcels_today']}', icon: Icons.move_to_inbox_outlined),
                    StatTile(label: 'Out for delivery', value: '${asMap(d['stats'])['in_transit']}', icon: Icons.local_shipping_outlined, color: const Color(0xFF2563EB)),
                    StatTile(label: 'Delivered today', value: '${asMap(d['stats'])['delivered_today']}', icon: Icons.check_circle_outline, color: const Color(0xFF15803D)),
                    StatTile(label: 'Active riders', value: '${asMap(d['stats'])['active_riders']}', icon: Icons.two_wheeler, color: const Color(0xFF0891B2)),
                    StatTile(label: 'Pending pickup', value: '${asMap(d['stats'])['pending_pickup']}', icon: Icons.schedule, color: const Color(0xFFB45309)),
                    StatTile(label: 'Sorting queue', value: '${asMap(d['stats'])['sorting_queue']}', icon: Icons.sort, color: const Color(0xFF9333EA)),
                  ]),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Recent deliveries',
                    child: asList(d['recent']).isEmpty
                        ? Text('No deliveries yet.', style: TextStyle(color: c.muted))
                        : Column(children: [
                            for (final x in asList(d['recent']))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onTap: asMap(x['parcel'])['id'] == null ? null : () => openParcel(context, asInt(asMap(x['parcel'])['id']), _load),
                                title: Text('${asMap(x['parcel'])['tracking'] ?? '—'}'),
                                subtitle: Text('${x['rider'] ?? '—'} · ${x['area'] ?? '—'}'),
                                trailing: Pill('${x['status_label']}'),
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
                            SizedBox(width: 110, child: Text('${a['name']}', overflow: TextOverflow.ellipsis)),
                            Expanded(child: LinearProgressIndicator(value: asNum(a['rate']) / 100, color: kOrange, backgroundColor: c.subtle)),
                            SizedBox(width: 90, child: Text('${a['rate']}% (${a['delivered']}/${a['total']})', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                          ]),
                        ),
                    ]),
                  ),
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
            : ListView(padding: const EdgeInsets.all(12), children: [
                if (d['has_municipality'] != true)
                  const Card(
                    color: Color(0xFFFFF7ED),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Your account has not been assigned a municipality yet. Contact an administrator.', style: TextStyle(color: Color(0xFF9A3412))),
                    ),
                  )
                else
                  SectionCard(
                    title: 'Add a barangay of ${d['municipality']}',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('${asList(d['areas']).length} of ${d['barangay_total']} barangays covered.', style: TextStyle(color: c.muted)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _psgc,
                        decoration: const InputDecoration(labelText: 'Barangay', border: OutlineInputBorder(), isDense: true),
                        items: [for (final b in asList(d['barangays'])) DropdownMenuItem(value: '${b['psgc']}', child: Text('${b['name']}'))],
                        onChanged: (v) => setState(() => _psgc = v),
                      ),
                      const SizedBox(height: 8),
                      BusyButton('Add to coverage', busy: false, onPressed: () {
                        final b = asList(d['barangays']).where((x) => '${x['psgc']}' == _psgc).firstOrNull;
                        _do(() => LogisticsApi.addArea(_psgc ?? '', b?['code']?.toString()));
                      }),
                    ]),
                  ),
                for (final a in asList(d['areas']))
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${a['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${a['barangay_code'] ?? '—'} · ${a['riders']} rider(s)'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                        onPressed: () async {
                          if (await confirmAction(context, 'Remove ${a['name']}?', 'It is no longer in your coverage.', confirm: 'Remove', danger: true)) {
                            _do(() => LogisticsApi.removeArea(asInt(a['id'])));
                          }
                        },
                      ),
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
            : ListView(padding: const EdgeInsets.all(12), children: [
                Text('A change applies to checkouts started from now on.', style: TextStyle(color: c.muted)),
                const SizedBox(height: 8),
                SectionCard(
                  title: 'Rates by route',
                  child: Column(children: [
                    for (final r in asList(d['rates']))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${r['label']}'),
                        subtitle: Text('${peso(r['first_kg'])} first kg + ${peso(r['additional_kg'])} each additional kg'),
                        trailing: const Icon(Icons.edit_outlined, size: 18),
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
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${z['name']} (${z['province']})'),
                        subtitle: Text('${peso(z['first_kg'])} + ${peso(z['additional_kg'])}/kg'),
                      ),
                  ]),
                ),
                SectionCard(
                  title: 'Provinces nobody covers yet',
                  child: Column(children: [
                    if (asList(d['uncovered']).isEmpty) Text('Every province is covered.', style: TextStyle(color: c.muted)),
                    for (final u in asList(d['uncovered']))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${u['name']}'),
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
            : ListView(padding: const EdgeInsets.all(12), children: [
                Text('${formatDate(_from)} – ${formatDate(_to)}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  for (final t in tabs) ChoiceChip(label: Text(t.$2), selected: _tab == t.$1, onSelected: (_) => setState(() => _tab = t.$1)),
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
    Widget line(String title, String sub, [String? trailing]) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          trailing: trailing == null ? null : Text(trailing, style: const TextStyle(fontWeight: FontWeight.w800)),
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
      itemBuilder: (ctx, l, reload) => ListTile(
        dense: true,
        title: Text('${l['action'] ?? ''}${(l['description'] ?? '').toString().isNotEmpty ? ' · ${l['description']}' : ''}'),
        subtitle: Text([
          if (l['old_value'] != null || l['new_value'] != null) '${l['old_value'] ?? '—'} → ${l['new_value'] ?? '—'}',
          if (l['reason'] != null) 'Reason: ${l['reason']}',
          '${formatDateTime(l['created_at'])}${l['ip'] != null ? ' · ${l['ip']}' : ''}',
        ].join('\n')),
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
              decoration: const InputDecoration(hintText: 'Search contacts', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: ListView(children: [
              for (final c in list)
                ListTile(
                  leading: CircleAvatar(backgroundColor: kOrange, child: Text('${c['name']}'.isEmpty ? '?' : '${c['name']}'[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                  title: Text('${c['name']}'),
                  subtitle: Text('${c['role']}'.replaceAll('_', ' ')),
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
                  decoration: const InputDecoration(hintText: 'Message', isDense: true, counterText: '', border: OutlineInputBorder()),
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

/// The web's logistics Account: name and email, and the password (with the current one).
class LogisticsAccountScreen extends StatefulWidget {
  const LogisticsAccountScreen({super.key});
  @override
  State<LogisticsAccountScreen> createState() => _LogisticsAccountScreenState();
}

class _LogisticsAccountScreenState extends State<LogisticsAccountScreen> {
  Map<String, dynamic>? _d;
  String _via = 'email';   // where the password-change code goes
  String? _error;
  bool _loading = true, _saving = false;
  Map<String, String> _errors = {};
  final _name = TextEditingController(), _email = TextEditingController();
  final _current = TextEditingController(), _password = TextEditingController(), _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _current, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> body) {
    _d = body;
    _name.text = '${asMap(body['company'])['name'] ?? ''}';
    _email.text = '${asMap(body['company'])['email'] ?? ''}';
    _current.clear();
    _password.clear();
    _confirm.clear();
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
      if (_current.text.isNotEmpty) ...{'current_password': _current.text, 'password': _password.text, 'password_confirmation': _confirm.text, 'code_via': _via},
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = r.fieldErrors;
      if (r.ok && r.body['company'] != null) _fill(r.body);
    });
    if (r.ok && r.body['user'] != null) context.read<AuthProvider>().updateUser(asMap(r.body['user']));
    if (passwordCodeSent(r)) {
      // The new password waits for the code emailed to the account.
      for (final c in [_current, _password, _confirm]) {
        c.clear();
      }
      await confirmPasswordCode(context, message: r.message);
    } else {
      showResult(context, r);
    }
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
            : ListView(padding: const EdgeInsets.all(12), children: [
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
                    const Divider(),
                    const Align(alignment: Alignment.centerLeft, child: Text('Change password (optional)', style: TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 8),
                    FormInput(_current, 'Current password', obscure: true, error: _errors['current_password']),
                    FormInput(_password, 'New password (min. 8)', obscure: true, error: _errors['password']),
                    FormInput(_confirm, 'Confirm new password', obscure: true),
                    PasswordCodeChoice(onChanged: (v) => _via = v),
                    BusyButton('Save', busy: _saving, onPressed: _save),
                  ]),
                ),
              ]),
      ),
    );
  }
}
