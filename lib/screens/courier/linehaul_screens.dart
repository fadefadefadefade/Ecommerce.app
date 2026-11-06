import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../../services/linehaul_api.dart';
import '../../services/location.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/reason_dialog.dart';
import '../../widgets/waybill_scanner.dart';
import '../logistics/rider_admin_screens.dart' show showDocument;
import '../logistics/staff_screens.dart' show DocField, dateField, staffField;
import '../seller/seller_kit.dart';

// A courier of a logistics company drives hub-to-hub trips: On Duty after the pre-trip checklist, then
// Accept → Start Loading (scan every parcel) → seal and Depart → Arrived; the destination hub scans the parcels in.

const _green = Color(0xFF15803D);
const _red = Color(0xFFDC2626);

/// Shows why the phone has no location, with a button to the phone's Settings when that fixes it.
Future<void> _locationProblem(BuildContext context, PhoneLocation loc) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Location needed'),
      content: Text(loc.problem ?? ''),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        if (loc.settings)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kOrange),
            onPressed: () {
              Navigator.pop(ctx);
              PhoneLocation.openSettings();
            },
            child: const Text('Open Settings'),
          ),
      ],
    ),
  );
}

/// The phone's location, or null after explaining why there is none.
Future<PhoneLocation?> _where(BuildContext context) async {
  final loc = await PhoneLocation.current();
  if (!context.mounted) return null;
  if (!loc.ok) {
    await _locationProblem(context, loc);
    return null;
  }
  return loc;
}

// ── Home: duty and the current trip ───────────────────────────

class LinehaulHomeScreen extends StatefulWidget {
  const LinehaulHomeScreen({super.key});
  @override
  State<LinehaulHomeScreen> createState() => _LinehaulHomeScreenState();
}

class _LinehaulHomeScreenState extends State<LinehaulHomeScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // While On Duty the app sends where it is every minute (Logistics sees it; a closed app goes Offline after 5 minutes).
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (!mounted || asMap(_d?['courier'])['on_duty'] != true) return;
    final loc = await PhoneLocation.current();
    if (loc.ok) await LinehaulApi.ping(loc.body);
    if (mounted && ModalRoute.of(context)?.isCurrent == true) _load();
  }

  Future<void> _load() async {
    final r = await LinehaulApi.home();
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

  Future<void> _goOnDuty() async {
    final loc = await _where(context);
    if (loc == null || !mounted) return;
    final result = await showModalBottomSheet<(Map<String, String>, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChecklistSheet(items: (_d?['checklist_items'] as List? ?? const []).map((e) => '$e').toList()),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    final r = await LinehaulApi.duty(true, items: result.$1, note: result.$2, location: loc.body);
    if (!mounted) return;
    setState(() => _busy = false);
    showResult(context, r);
    if (r.ok) setState(() => _d = r.body);
  }

  Future<void> _goOffDuty() async {
    setState(() => _busy = true);
    final r = await LinehaulApi.duty(false);
    if (!mounted) return;
    setState(() => _busy = false);
    showResult(context, r);
    if (r.ok) setState(() => _d = r.body);
  }

  Future<void> _open(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LinehaulTripScreen(tripId: id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    final me = asMap(d?['courier']);
    final trip = d?['trip'] == null ? null : asMap(d!['trip']);
    final suspended = me['status'] == 'suspended';
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Courier', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
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
                  SectionCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${me['name']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
                      Text('${me['company']}', style: TextStyle(color: c.muted)),
                      const SizedBox(height: 6),
                      Text('Home hub ${me['home_hub_label'] ?? me['home_hub']}', style: TextStyle(color: c.text)),
                      Text('${me['vehicle_type']} · ${me['plate_number']} · ${me['load_capacity_kg']} kg', style: TextStyle(color: c.text)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Pill('${me['duty_label']}', color: me['on_duty_now'] == true ? _green : (suspended ? _red : const Color(0xFF6B7280))),
                        const Spacer(),
                        Text('Today ${peso(d['today_earnings'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      if (suspended)
                        const Text('Your account is suspended by your logistics company. You cannot go On Duty.', style: TextStyle(color: _red))
                      else if (me['on_duty'] == true)
                        BusyButton('Go Off Duty', busy: _busy, color: const Color(0xFF6B7280), icon: Icons.power_settings_new, onPressed: _goOffDuty)
                      else
                        BusyButton('Go On Duty', busy: _busy, color: _green, icon: Icons.play_arrow, onPressed: _goOnDuty),
                    ]),
                  ),
                  for (final n in asList(d['needs_note']))
                    Card(
                      color: const Color(0xFFFFF7ED),
                      child: ListTile(
                        leading: const Icon(Icons.edit_note, color: Color(0xFF9A3412)),
                        title: Text('${n['code']} had a discrepancy'),
                        subtitle: const Text('Add your note about what happened.'),
                        onTap: () => _open(asInt(n['id'])),
                      ),
                    ),
                  Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: Text('Current trip', style: TextStyle(fontWeight: FontWeight.w800, color: c.text))),
                  if (trip == null)
                    Text(me['on_duty'] == true ? 'No trip yet. Trips assigned to you will show here.' : 'Go On Duty to get trips.', style: TextStyle(color: c.muted))
                  else
                    _TripCard(trip, onTap: () => _open(asInt(trip['id']))),
                ]),
              ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> t;
  final VoidCallback onTap;
  const _TripCard(this.t, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.local_shipping_outlined, color: kOrange),
        title: Text('${t['code']} · ${t['route']}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${t['parcels']} parcel(s) · ${t['weight_kg']} kg · ${peso(t['pay'])}${t['delayed'] == true ? ' · Delayed' : ''}'),
        trailing: Pill('${t['status_label']}', color: Pill.forState('${t['status']}')),
      ),
    );
  }
}

/// The pre-trip checklist: every item OK or Not OK; a Not OK item needs a note (10–300 characters).
class _ChecklistSheet extends StatefulWidget {
  final List<String> items;
  const _ChecklistSheet({required this.items});
  @override
  State<_ChecklistSheet> createState() => _ChecklistSheetState();
}

class _ChecklistSheetState extends State<_ChecklistSheet> {
  static const _default = ['Tires', 'Lights', 'Brakes', 'Fuel', 'Cargo door lock'];
  final Map<String, String> _answers = {};
  final _note = TextEditingController();
  String? _error;

  List<String> get _items => widget.items.isEmpty ? _default : widget.items;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final bad = _answers.entries.where((e) => e.value == 'not_ok').map((e) => e.key).toList();
    setState(() {
      _error = _answers.length < _items.length
          ? 'Answer every item (OK or Not OK).'
          : bad.isNotEmpty && (_note.text.trim().length < 10 || _note.text.trim().length > 300)
              ? 'Add a note about ${bad.join(', ')} (10 to 300 characters).'
              : null;
    });
    if (_error == null) Navigator.pop(context, (Map<String, String>.from(_answers), _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final anyBad = _answers.values.contains('not_ok');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Pre-trip checklist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final item in _items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(item, style: const TextStyle(fontWeight: FontWeight.w600))),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    emptySelectionAllowed: true,
                    segments: const [ButtonSegment(value: 'ok', label: Text('OK')), ButtonSegment(value: 'not_ok', label: Text('Not OK'))],
                    selected: {if (_answers[item] != null) _answers[item]!},
                    onSelectionChanged: (s) => setState(() => s.isEmpty ? _answers.remove(item) : _answers[item] = s.first),
                  ),
                ]),
              ),
            if (anyBad) ...[
              const SizedBox(height: 8),
              staffField(_note, 'What is wrong? *', helper: 'Your logistics company is told. You stay Off Duty.', caps: TextCapitalization.sentences),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: _red))),
            BusyButton('Submit checklist', busy: false, onPressed: _submit),
          ]),
        ),
      ),
    );
  }
}

// ── The trip ───────────────────────────────────────────────────

class LinehaulTripScreen extends StatefulWidget {
  final int tripId;
  const LinehaulTripScreen({super.key, required this.tripId});
  @override
  State<LinehaulTripScreen> createState() => _LinehaulTripScreenState();
}

class _LinehaulTripScreenState extends State<LinehaulTripScreen> {
  // The server's lists (Linehaul::DECLINE_REASONS / DELAY_REASONS).
  static const _declineReasons = ['Vehicle problem', 'Not feeling well', 'Too far', 'Other'];
  static const _delayReasons = ['Heavy traffic', 'Vehicle breakdown', 'Weather', 'Road closure', 'Other'];

  Map<String, dynamic>? _t;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_t?['status'] != 'in_transit') return;
      final loc = await PhoneLocation.current();
      if (loc.ok) await LinehaulApi.ping(loc.body);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await LinehaulApi.trip(widget.tripId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _t = asMap(r.body['trip']);
        _error = null;
      } else {
        _error = r.message;
      }
    });
  }

  Future<ApiResponse?> _do(Future<ApiResponse> Function() call) async {
    if (_busy) return null; // one tap, one request
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return r;
    setState(() => _busy = false);
    showResult(context, r);
    if (r.ok && r.body['trip'] != null) setState(() => _t = asMap(r.body['trip']));
    if (r.broken) _load();
    return r;
  }

  Future<String?> _pick(String title, List<String> options) => showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(title: Text(title), children: [
          for (final o in options) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, o), child: Text(o)),
        ]),
      );

  Future<void> _decline() async {
    final reason = await _pick('Why are you declining?', _declineReasons);
    if (reason == null) return;
    final r = await _do(() => LinehaulApi.decline(widget.tripId, reason));
    if (r?.ok == true && mounted) Navigator.pop(context);
  }

  Future<void> _scan() async {
    final tracking = await scanWaybill(context, title: 'Scan parcel (${_t?['loaded']}/${_t?['parcels']})');
    if (tracking != null) await _do(() => LinehaulApi.scan(widget.tripId, tracking));
  }

  Future<void> _depart() async {
    final seal = TextEditingController(text: 'BH-');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seal and depart'),
        content: TextField(
          controller: seal,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')), LengthLimitingTextInputFormatter(10)],
          decoration: const InputDecoration(labelText: 'Seal number', helperText: 'BH- followed by 7 digits, e.g. BH-0004521'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => Navigator.pop(ctx, true), child: const Text('Depart')),
        ],
      ),
    );
    final value = seal.text.trim();
    seal.dispose();
    if (ok != true || !mounted) return;
    final loc = await _where(context);
    if (loc != null) await _do(() => LinehaulApi.depart(widget.tripId, value, loc.body));
  }

  Future<void> _delay() async {
    final reason = await _pick('Report a delay', _delayReasons);
    if (reason == null || !mounted) return;
    final now = DateTime.now();
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))), helpText: 'New ETA');
    if (t == null || !mounted) return;
    var eta = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (eta.isBefore(now.subtract(const Duration(hours: 1)))) eta = eta.add(const Duration(days: 1)); // past midnight
    String? photo;
    if (reason == 'Vehicle breakdown') {
      try {
        photo = (await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80))?.path;
      } on PlatformException {
        if (mounted) showError(context, 'The camera is off for ALVY. The breakdown is reported without a photo.');
      }
    }
    await _do(() => LinehaulApi.delay(widget.tripId, reason, eta.toIso8601String(), photo: photo));
  }

  Future<void> _arrived() async {
    final loc = await _where(context);
    if (loc != null) await _do(() => LinehaulApi.arrived(widget.tripId, loc.body));
  }

  Future<void> _note() async {
    final note = await showReasonDialog(context, title: 'Your note', message: 'What happened? (10 to 300 characters)', confirmLabel: 'Save', maxLength: 300);
    if (note != null) await _do(() => LinehaulApi.note(widget.tripId, note));
  }

  void _navigate(Map<String, dynamic> hub) {
    PhoneLocation.navigate(lat: hub['latitude'] == null ? null : asNum(hub['latitude']), lng: hub['longitude'] == null ? null : asNum(hub['longitude']), address: '${hub['address'] ?? hub['name']}');
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final c = context.bc;
    Widget row(String l, dynamic v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(l, style: TextStyle(color: c.muted))),
            Expanded(child: Text('${v ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
    final status = '${t?['status']}';
    final origin = asMap(t?['origin']);
    final dest = asMap(t?['destination']);
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar(t == null ? 'Trip' : '${t['code']}', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: t == null
            ? const SizedBox()
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  Row(children: [
                    Pill('${t['status_label']}', color: Pill.forState(status)),
                    if (t['delayed'] == true) ...[const SizedBox(width: 6), const Pill('Delayed', color: Color(0xFFB45309))],
                  ]),
                  const SizedBox(height: 10),
                  SectionCard(
                    child: Column(children: [
                      row('From', '${origin['label']}\n${origin['address'] ?? ''}'.trim()),
                      row('To', '${dest['label']}\n${dest['address'] ?? ''}'.trim()),
                      row('Parcels', '${t['parcels']} · ${t['weight_kg']} kg'),
                      row('Departure', t['scheduled_departure_at'] != null ? formatDateTime(t['scheduled_departure_at']) : 'As soon as loaded'),
                      row('Pay', peso(t['pay'])),
                      if (t['seal_number'] != null) row('Seal', t['seal_number']),
                      if (t['eta_at'] != null) row('ETA', '${formatDateTime(t['eta_at'])}${t['delay_reason'] != null ? ' (${t['delay_reason']})' : ''}'),
                      if (t['courier_note'] != null) row('Your note', t['courier_note']),
                    ]),
                  ),
                  if (t['needs_rescan'] == true)
                    const Card(
                      color: Color(0xFFFFF7ED),
                      child: ListTile(title: Text('This trip was given to you on the road: scan every parcel before continuing.', style: TextStyle(color: Color(0xFF9A3412)))),
                    ),
                  const SizedBox(height: 8),
                  ..._actions(status, origin, dest),
                  const SizedBox(height: 12),
                  Text('Parcels (${t['loaded']}/${t['parcels']} loaded)', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                  for (final p in asList(t['items']))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(p['status'] == 'loaded' || p['status'] == 'received' ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: p['status'] == 'loaded' || p['status'] == 'received' ? _green : c.muted),
                      title: Text('${p['tracking']}'),
                      subtitle: Text('${p['weight_kg']} kg · ${p['status']}'),
                    ),
                ]),
              ),
      ),
    );
  }

  List<Widget> _actions(String status, Map<String, dynamic> origin, Map<String, dynamic> dest) {
    final t = _t!;
    Widget gap() => const SizedBox(height: 8);
    switch (status) {
      case 'assigned':
        return [
          BusyButton('Accept', busy: _busy, color: _green, onPressed: () => _do(() => LinehaulApi.accept(widget.tripId))),
          gap(),
          OutlinedButton(onPressed: _busy ? null : _decline, child: const Text('Decline')),
        ];
      case 'accepted':
        return [
          BusyButton('Start Loading', busy: _busy, icon: Icons.inventory, onPressed: () => _do(() => LinehaulApi.startLoading(widget.tripId))),
          gap(),
          OutlinedButton.icon(onPressed: () => _navigate(origin), icon: const Icon(Icons.navigation_outlined), label: Text('Navigate to ${origin['code']}')),
          gap(),
          OutlinedButton(onPressed: _busy ? null : _decline, child: const Text('Decline')),
        ];
      case 'loading':
        final all = asInt(t['loaded']) == asInt(t['parcels']);
        return [
          BusyButton('Scan parcel (${t['loaded']}/${t['parcels']})', busy: _busy, icon: Icons.qr_code_scanner, onPressed: _scan),
          gap(),
          BusyButton('Seal and Depart', busy: _busy, color: all ? _green : const Color(0xFF6B7280), icon: Icons.local_shipping, onPressed: _depart),
        ];
      case 'in_transit':
        return [
          if (t['needs_rescan'] == true) ...[
            BusyButton('Scan parcel (${t['loaded']}/${t['parcels']})', busy: _busy, icon: Icons.qr_code_scanner, onPressed: _scan),
            gap(),
          ],
          BusyButton('Arrived at ${dest['code']}', busy: _busy, color: _green, icon: Icons.flag, onPressed: _arrived),
          gap(),
          OutlinedButton.icon(onPressed: () => _navigate(dest), icon: const Icon(Icons.navigation_outlined), label: Text('Navigate to ${dest['code']}')),
          gap(),
          OutlinedButton.icon(onPressed: _busy ? null : _delay, icon: const Icon(Icons.schedule), label: const Text('Report delay or breakdown')),
        ];
      case 'arrived':
        return [Text('At ${dest['code']}: hub staff check the seal and scan the parcels in. You are paid when they close receiving.', style: TextStyle(color: context.bc.muted))];
      default:
        return [
          if (t['needs_courier_note'] == true) BusyButton('Add your note', busy: _busy, icon: Icons.edit_note, onPressed: _note),
        ];
    }
  }
}

// ── History and earnings ───────────────────────────────────────

/// From–to filter (both days included).
Future<DateTimeRange?> _pickRange(BuildContext context, DateTimeRange? current) => showDateRangePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: current,
    );

class LinehaulHistoryScreen extends StatefulWidget {
  const LinehaulHistoryScreen({super.key});
  @override
  State<LinehaulHistoryScreen> createState() => _LinehaulHistoryScreenState();
}

class _LinehaulHistoryScreenState extends State<LinehaulHistoryScreen> {
  DateTimeRange? _range;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LinehaulApi.history(from: _range == null ? null : ymd(_range!.start), to: _range == null ? null : ymd(_range!.end));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (r.ok) _rows = asList(r.body['data']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Trip History', actions: [
        IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () async {
            final r = await _pickRange(context, _range);
            if (r != null) {
              setState(() => _range = r);
              _load();
            }
          },
        ),
      ]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: RefreshIndicator(
          color: kOrange,
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            if (_range != null)
              InputChip(label: Text('${formatDate(ymd(_range!.start))} – ${formatDate(ymd(_range!.end))}'), onDeleted: () {
                setState(() => _range = null);
                _load();
              }),
            if (_rows.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('No trips yet.', textAlign: TextAlign.center, style: TextStyle(color: c.muted))),
            for (final h in _rows)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${h['code']} · ${h['route']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${formatDateTime(h['date'])} · ${h['parcels']} parcel(s)${h['reason'] != null ? '\n${h['reason']}' : ''}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(peso(h['pay']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${h['result']}', style: TextStyle(fontSize: 12, color: c.muted)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class LinehaulEarningsScreen extends StatefulWidget {
  const LinehaulEarningsScreen({super.key});
  @override
  State<LinehaulEarningsScreen> createState() => _LinehaulEarningsScreenState();
}

class _LinehaulEarningsScreenState extends State<LinehaulEarningsScreen> {
  Map<String, dynamic>? _d;
  DateTimeRange? _range;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LinehaulApi.earnings(from: _range == null ? null : ymd(_range!.start), to: _range == null ? null : ymd(_range!.end));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (r.ok) _d = r.body;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    Widget tile(String label, dynamic v) => Expanded(
          child: SectionCard(
            child: Column(children: [
              Text(label, style: TextStyle(color: c.muted)),
              Text(peso(v), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
          ),
        );
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Earnings', actions: [
        IconButton(
          icon: const Icon(Icons.date_range),
          onPressed: () async {
            final r = await _pickRange(context, _range);
            if (r != null) {
              setState(() => _range = r);
              _load();
            }
          },
        ),
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
                  Row(children: [tile('Today', d['today']), const SizedBox(width: 8), tile('This week', d['week'])]),
                  Text('${d['vehicle_type']}: ${peso(d['pay_per_trip'])} per completed trip. Declined and reassigned trips pay ₱0.00.',
                      style: TextStyle(color: c.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (_range != null) Text('${formatDate(ymd(_range!.start))} – ${formatDate(ymd(_range!.end))}: ${peso(d['range_total'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (final t in asList(d['trips']))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${t['code']} · ${t['route']}'),
                      subtitle: Text('${formatDateTime(t['completed_at'])} · ${t['result']}'),
                      trailing: Text(peso(t['pay']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ]),
              ),
      ),
    );
  }
}

// ── Profile ────────────────────────────────────────────────────

class LinehaulProfileScreen extends StatefulWidget {
  const LinehaulProfileScreen({super.key});
  @override
  State<LinehaulProfileScreen> createState() => _LinehaulProfileScreenState();
}

class _LinehaulProfileScreenState extends State<LinehaulProfileScreen> {
  Map<String, dynamic>? _p;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LinehaulApi.profile();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (r.ok) _p = asMap(r.body['profile']);
    });
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => _EditVehicleScreen(profile: _p!)));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final c = context.bc;
    Widget row(String l, dynamic v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(l, style: TextStyle(color: c.muted))),
            Expanded(child: Text('${v ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
    final docs = asMap(p?['documents']);
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('My Profile', actions: [if (p != null) IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined))]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: p == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.all(12), children: [
                Align(alignment: Alignment.centerLeft, child: Pill('${p['status']}', color: p['status'] == 'Active' ? _green : _red)),
                const SizedBox(height: 8),
                SectionCard(
                  child: Column(children: [
                    row('Name', p['name']),
                    row('Company', p['company']),
                    row('Home hub', p['home_hub']),
                    row('License', '${p['license_number']} (${p['license_type']})'),
                    row('DL codes', p['dl_codes']),
                    row('Expires', p['license_expiry'] != null ? formatDate(p['license_expiry'], 'MM/dd/yyyy') : null),
                    row('Vehicle', '${p['vehicle_type']} · ${p['plate_number']}'),
                    row('Capacity', '${p['load_capacity_kg']} kg'),
                  ]),
                ),
                if (p['needs_reverification'] == true)
                  Text('Your changes are waiting for your logistics company to check them.', style: TextStyle(color: c.muted)),
                Wrap(spacing: 8, children: [
                  for (final (key, label) in const [('license', 'Driver\'s license'), ('or-cr', 'OR/CR'), ('nbi', 'NBI clearance')])
                    if (docs[key] == true)
                      OutlinedButton.icon(
                        onPressed: () => showDocument(context, LinehaulApi.document(key), label),
                        icon: const Icon(Icons.description_outlined),
                        label: Text(label),
                      ),
                ]),
              ]),
      ),
    );
  }
}

/// Load capacity, plate, license expiry and documents; the company checks the changes again.
class _EditVehicleScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const _EditVehicleScreen({required this.profile});
  @override
  State<_EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<_EditVehicleScreen> {
  late final _capacity = TextEditingController(text: '${widget.profile['load_capacity_kg'] ?? ''}');
  late final _plate = TextEditingController(text: '${widget.profile['plate_number'] ?? ''}');
  DateTime? _expiry;
  final _docs = <String, String>{};
  Map<String, String> _errors = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _expiry = DateTime.tryParse('${widget.profile['license_expiry']}');
  }

  @override
  void dispose() {
    _capacity.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final fields = <String, String>{};
    if (_capacity.text.trim() != '${widget.profile['load_capacity_kg']}') fields['load_capacity_kg'] = _capacity.text.trim();
    if (_plate.text.trim().toUpperCase() != '${widget.profile['plate_number']}') fields['plate_number'] = _plate.text.trim();
    if (_expiry != null && ymd(_expiry!) != '${widget.profile['license_expiry']}') fields['license_expiry'] = ymd(_expiry!);
    final r = await LinehaulApi.updateProfile(fields, _docs);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _errors = r.ok ? {} : r.fieldErrors;
    });
    showResult(context, r);
    if (r.ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final range = asMap(widget.profile['capacity_range']);
    final today = DateTime.now();
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Vehicle & documents'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        staffField(_capacity, 'Load capacity (kg)', error: _errors['load_capacity_kg'], keyboard: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
            helper: range.isEmpty ? null : '${asInt(range['min'])} to ${asInt(range['max'])} kg for a ${widget.profile['vehicle_type']}.'),
        staffField(_plate, 'Plate number', error: _errors['plate_number'], caps: TextCapitalization.characters, keyboard: TextInputType.visiblePassword),
        dateField(context, 'License expiry date', _expiry, (d) => setState(() => _expiry = d),
            first: DateTime(today.year - 1), last: DateTime(today.year + 15), initial: _expiry ?? today, error: _errors['license_expiry']),
        for (final (field, label) in const [('license_file', 'Professional driver\'s license'), ('or_cr_file', 'Vehicle OR/CR'), ('nbi_file', 'NBI clearance')])
          DocField(label: 'New $label', path: _docs[field], error: _errors[field], onPicked: (p) => setState(() => _docs[field] = p)),
        if (_errors['trip'] != null) Text(_errors['trip']!, style: const TextStyle(color: _red)),
        BusyButton('Save', busy: _busy, onPressed: _save),
      ]),
    );
  }
}
