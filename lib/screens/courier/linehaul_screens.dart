import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../../services/linehaul_api.dart';
import '../../services/location.dart';
import '../../theme/app_theme.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/reason_dialog.dart';
import '../../widgets/waybill_scanner.dart';
import '../logistics/rider_admin_screens.dart' show showDocument;
import '../logistics/staff_screens.dart' show DocField, dateField, staffField;
import '../seller/seller_kit.dart';
import '../../widgets/design_kit.dart';

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
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                  // The design's captain card: avatar, name, duty tag, and the truck in a beige box.
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: cardBox(context, radius: 20),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Alvy.orangeSoft,
                          child: Text(riderInitials('${me['name']}'), style: Alvy.display(size: 17, color: Alvy.orange, weight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${me['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w800)),
                            Text('${me['company']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Alvy.slate, fontSize: 13)),
                          ]),
                        ),
                        riderTag('${me['duty_label']}'.toUpperCase(), live: me['on_duty_now'] == true),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          const Icon(Icons.local_shipping_outlined, color: Alvy.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${me['vehicle_type']}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                              Text('Plate ${me['plate_number']} · ${me['load_capacity_kg']} kg', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(Icons.warehouse_outlined, size: 16, color: c.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Home hub ${me['home_hub_label'] ?? me['home_hub']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        ),
                        Text('Today ', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        Text(peso(d['today_earnings']), style: Alvy.display(size: 15, color: Alvy.orange, weight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 12),
                      if (suspended)
                        const Text('Your account is suspended by your logistics company. You cannot go On Duty.', style: TextStyle(color: _red))
                      else if (me['on_duty'] == true)
                        BusyButton('Go Off Duty', busy: _busy, color: Alvy.navyFill, icon: Icons.power_settings_new, onPressed: _goOffDuty)
                      else
                        BusyButton('Go On Duty', busy: _busy, icon: Icons.play_arrow, onPressed: _goOnDuty),
                    ]),
                  ),
                  for (final n in asList(d['needs_note']))
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: const Icon(Icons.edit_note, color: Alvy.orangeDark),
                        title: Text('${n['code']} had a discrepancy'),
                        subtitle: const Text('Add your note about what happened.'),
                        onTap: () => _open(asInt(n['id'])),
                      ),
                    ),
                  Padding(padding: const EdgeInsets.only(top: 4, bottom: 10), child: Text('Current Trip', style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700))),
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
    final c = context.bc;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardBox(context, radius: 20),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(6)),
                  child: const Text('TRIP ASSIGNMENT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Alvy.orangeDark, letterSpacing: 0.4)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('${t['code']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600))),
                Pill('${t['status_label']}', color: Pill.forState('${t['status']}')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.route_outlined, color: Alvy.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${t['route']}', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _box(context, Icons.inventory_2_outlined, 'Parcels', '${t['parcels']}'),
                const SizedBox(width: 8),
                _box(context, Icons.scale_outlined, 'Weight', '${t['weight_kg']} kg'),
                const SizedBox(width: 8),
                _box(context, Icons.payments_outlined, 'Pay', peso(t['pay']), accent: true),
              ]),
              if (t['delayed'] == true)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('Delayed', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A small beige figure box (the design's "Distance 96.5 km").
Widget _box(BuildContext context, IconData icon, String label, String value, {bool accent = false}) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: Alvy.slate),
            const SizedBox(width: 4),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Alvy.slate, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Alvy.display(size: 16, color: accent ? Alvy.orange : context.bc.text, weight: FontWeight.w800)),
        ]),
      ),
    );

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
            SizedBox(width: 110, child: Text(l, style: TextStyle(color: c.textSecondary))),
            Expanded(child: Text('${v ?? '—'}', style: TextStyle(fontWeight: FontWeight.w600, color: c.text))),
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
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                  // The design's route card: from → to on a dotted line, then the figures.
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: cardBox(context, radius: 20),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Pill('${t['status_label']}', color: Pill.forState(status)),
                        if (t['delayed'] == true) ...[const SizedBox(width: 6), const Pill('Delayed', color: Color(0xFFB45309))],
                        const Spacer(),
                        Text('${t['code']}', style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 14),
                      _stop(Alvy.orange, origin),
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(width: 2, height: 18, color: c.border),
                      ),
                      _stop(Alvy.slate, dest),
                      const SizedBox(height: 14),
                      Row(children: [
                        _box(context, Icons.inventory_2_outlined, 'Parcels', '${t['parcels']}'),
                        const SizedBox(width: 8),
                        _box(context, Icons.scale_outlined, 'Weight', '${t['weight_kg']} kg'),
                        const SizedBox(width: 8),
                        _box(context, Icons.payments_outlined, 'Pay', peso(t['pay']), accent: true),
                      ]),
                    ]),
                  ),
                  SectionCard(
                    child: Column(children: [
                      row('Departure', t['scheduled_departure_at'] != null ? formatDateTime(t['scheduled_departure_at']) : 'As soon as loaded'),
                      if (t['seal_number'] != null) row('Seal', t['seal_number']),
                      if (t['eta_at'] != null) row('ETA', '${formatDateTime(t['eta_at'])}${t['delay_reason'] != null ? ' (${t['delay_reason']})' : ''}'),
                      if (t['courier_note'] != null) row('Your note', t['courier_note']),
                    ]),
                  ),
                  if (t['needs_rescan'] == true)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(14)),
                      child: const Text('This trip was given to you on the road: scan every parcel before continuing.',
                          style: TextStyle(color: Alvy.orangeDark, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 8),
                  ..._actions(status, origin, dest),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Parcels',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(99)),
                      child: Text('${t['loaded']} of ${t['parcels']} loaded', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textSecondary)),
                    ),
                    child: Column(children: [
                      Builder(builder: (_) {
                        final total = asInt(t['parcels']);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : (asInt(t['loaded']) / total).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: c.subtle,
                            color: Alvy.orange,
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      for (final p in asList(t['items']))
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Icon(p['status'] == 'loaded' || p['status'] == 'received' ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: p['status'] == 'loaded' || p['status'] == 'received' ? Alvy.slate : c.muted, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text('${p['tracking']}', style: TextStyle(fontWeight: FontWeight.w600, color: c.text))),
                            Text('${p['weight_kg']} kg · ${p['status']}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                          ]),
                        ),
                    ]),
                  ),
                ]),
              ),
      ),
    );
  }

  Widget _stop(Color color, Map<String, dynamic> hub) {
    final c = context.bc;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.18), border: Border.all(color: color, width: 3)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${hub['label']}', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700)),
          if ((hub['address'] ?? '').toString().isNotEmpty) Text('${hub['address']}', style: TextStyle(fontSize: 12.5, color: Alvy.slate)),
        ]),
      ),
    ]);
  }

  List<Widget> _actions(String status, Map<String, dynamic> origin, Map<String, dynamic> dest) {
    final t = _t!;
    Widget gap() => const SizedBox(height: 8);
    switch (status) {
      case 'assigned':
        return [
          BusyButton('Accept', busy: _busy, icon: Icons.check_circle_outline, onPressed: () => _do(() => LinehaulApi.accept(widget.tripId))),
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
          BusyButton('Seal and Depart', busy: _busy, color: all ? kOrange : Alvy.slate, icon: Icons.local_shipping, onPressed: _depart),
        ];
      case 'in_transit':
        return [
          if (t['needs_rescan'] == true) ...[
            BusyButton('Scan parcel (${t['loaded']}/${t['parcels']})', busy: _busy, icon: Icons.qr_code_scanner, onPressed: _scan),
            gap(),
          ],
          BusyButton('Arrived at ${dest['code']}', busy: _busy, icon: Icons.flag, onPressed: _arrived),
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
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            if (_range != null)
              InputChip(label: Text('${formatDate(ymd(_range!.start))} – ${formatDate(ymd(_range!.end))}'), onDeleted: () {
                setState(() => _range = null);
                _load();
              }),
            if (_rows.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('No trips yet.', textAlign: TextAlign.center, style: TextStyle(color: c.muted))),
            for (final h in _rows)
              _tripRow(context, '${h['code']}', '${h['route']}', '${formatDateTime(h['date'])} · ${h['parcels']} parcel(s)${h['reason'] != null ? '\n${h['reason']}' : ''}',
                  h['pay'], '${h['result']}'),
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
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                  riderHero('Linehaul pay · this week', peso(d['week']), [('Today', peso(d['today'])), ('Per trip', peso(d['pay_per_trip']))],
                      icon: Icons.local_shipping_outlined),
                  Text('${d['vehicle_type']}: ${peso(d['pay_per_trip'])} per completed trip. Declined and reassigned trips pay ₱0.00.',
                      style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  if (_range != null)
                    Row(children: [
                      riderFigure(context, '${formatDate(ymd(_range!.start))} – ${formatDate(ymd(_range!.end))}', peso(d['range_total']), Icons.date_range_outlined),
                    ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
                    child: Text('Trip Breakdown', style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700)),
                  ),
                  if (asList(d['trips']).isEmpty) Text('No trips yet.', style: TextStyle(color: c.muted)),
                  for (final t in asList(d['trips']))
                    _tripRow(context, '${t['code']}', '${t['route']}', formatDateTime(t['completed_at']), t['pay'], '${t['result']}'),
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
            SizedBox(width: 120, child: Text(l, style: TextStyle(color: c.textSecondary))),
            Expanded(child: Text('${v ?? '—'}', style: TextStyle(fontWeight: FontWeight.w600, color: c.text))),
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
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: cardBox(context, radius: 20),
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Alvy.orange, width: 2)),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Alvy.orangeSoft,
                        child: Text(riderInitials('${p['name']}'), style: Alvy.display(size: 18, color: Alvy.orange, weight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${p['name']}', style: Alvy.display(size: 19, color: c.text, weight: FontWeight.w800)),
                        Text('${p['company']}', style: TextStyle(color: Alvy.slate, fontSize: 13)),
                        const SizedBox(height: 6),
                        Pill('${p['status']}', color: p['status'] == 'Active' ? _green : _red),
                      ]),
                    ),
                  ]),
                ),
                SectionCard(
                  child: Column(children: [
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
                SectionCard(
                  title: 'Documents',
                  child: Column(children: [
                    for (final (key, label) in const [('license', 'Driver\'s license'), ('or-cr', 'OR/CR'), ('nbi', 'NBI clearance')])
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                        decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Icon(docs[key] == true ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: docs[key] == true ? _green : c.muted),
                          const SizedBox(width: 10),
                          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.text))),
                          if (docs[key] == true)
                            TextButton(
                              onPressed: () => showDocument(context, LinehaulApi.document(key), label),
                              child: Text('View', style: TextStyle(color: Alvy.slate, fontWeight: FontWeight.w700)),
                            )
                          else
                            Padding(padding: const EdgeInsets.all(10), child: Text('Not uploaded', style: TextStyle(fontSize: 12, color: c.muted))),
                        ]),
                      ),
                  ]),
                ),
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

/// A finished trip as the design's trip-breakdown card.
Widget _tripRow(BuildContext context, String code, String route, String sub, dynamic pay, String result) {
  final c = context.bc;
  final paid = asNum(pay) > 0;
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: cardBox(context, radius: 16),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(radius: 18, backgroundColor: c.subtle, child: Icon(Icons.local_shipping_outlined, size: 18, color: c.textSecondary)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(code, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
          Text(route, style: TextStyle(fontSize: 12.5, color: c.text)),
          Text(sub, style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ]),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${paid ? '+' : ''}${peso(pay)}', style: Alvy.display(size: 15, color: paid ? Alvy.orange : c.muted, weight: FontWeight.w800)),
        Text(result, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
      ]),
    ]),
  );
}
