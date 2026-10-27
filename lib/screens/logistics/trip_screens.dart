import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../../services/location.dart';
import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/waybill_scanner.dart';
import 'logistics_kit.dart';

// The company's hub-to-hub trips: create (origin, destination, parcels waiting at the origin), assign an On Duty courier,
// follow it on the road, and at the destination check the seal, scan the parcels in and close receiving.

const _green = Color(0xFF15803D);

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final _list = GlobalKey<PagedListState>();

  @override
  Widget build(BuildContext context) {
    return PagedList(
      key: _list,
      title: 'Hub-to-hub Trips',
      initialTab: 'active',
      empty: 'No trips here.',
      actions: [
        IconButton(
          tooltip: 'Receive at a hub',
          icon: const Icon(Icons.move_to_inbox_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HubReceivingScreen())).then((_) => _list.currentState?.reload()),
        ),
      ],
      fab: FloatingActionButton.extended(
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        onPressed: () async {
          final id = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => const CreateTripScreen()));
          _list.currentState?.reload();
          if (id != null && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: id)));
        },
        icon: const Icon(Icons.add_road),
        label: const Text('New trip'),
      ),
      fetch: (page, tab) => LogisticsApi.trips(status: tab ?? 'active', page: page),
      itemBuilder: (ctx, t, reload) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () async {
            await Navigator.push(ctx, MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: asInt(t['id']))));
            reload();
          },
          leading: const Icon(Icons.local_shipping_outlined),
          title: Text('${t['code']} · ${t['route']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text([
            '${t['parcels']} parcel(s) · ${t['weight_kg']} kg',
            asMap(t['courier'])['name'] ?? 'No courier yet',
            if (t['delayed'] == true) 'Delayed',
          ].join(' · ')),
          trailing: Pill('${t['status_label']}', color: Pill.forState('${t['status']}')),
        ),
      ),
    );
  }
}

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});
  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  List<Map<String, dynamic>> _hubs = [];
  List<Map<String, dynamic>> _parcels = [];
  int? _origin;
  int? _dest;
  final Set<int> _picked = {};
  DateTime? _departure;
  Map<String, String> _errors = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.tripForm(originHubId: _origin);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (r.ok) {
        _hubs = asList(r.body['hubs']);
        _origin = asInt(r.body['origin_hub_id']);
        _parcels = asList(r.body['parcels']);
        _picked.removeWhere((id) => !_parcels.any((p) => asInt(p['id']) == id));
      }
    });
  }

  double get _weight => _parcels.where((p) => _picked.contains(asInt(p['id']))).fold(0.0, (s, p) => s + asNum(p['weight_kg']));

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await LogisticsApi.createTrip({
      'origin_hub_id': _origin,
      'destination_hub_id': _dest,
      'parcel_ids': _picked.toList(),
      if (_departure != null) 'scheduled_departure_at': _departure!.toIso8601String(),
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _errors = r.ok ? {} : r.fieldErrors;
    });
    showResult(context, r);
    if (r.ok) Navigator.pop(context, asInt(asMap(r.body['trip'])['id']));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('New trip'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<int>(
            initialValue: _origin,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'From (origin hub)', errorText: _errors['origin_hub_id'], border: const OutlineInputBorder(), isDense: true),
            items: [for (final h in _hubs) DropdownMenuItem(value: asInt(h['id']), child: Text('${h['label']}', overflow: TextOverflow.ellipsis))],
            onChanged: (v) {
              setState(() => _origin = v);
              _load();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _dest,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'To (destination hub)', errorText: _errors['destination_hub_id'], border: const OutlineInputBorder(), isDense: true),
            items: [for (final h in _hubs.where((h) => asInt(h['id']) != _origin)) DropdownMenuItem(value: asInt(h['id']), child: Text('${h['label']}', overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _dest = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(_departure == null ? 'Departure: as soon as loaded' : 'Departure: ${formatDateTime(_departure!.toIso8601String())}'),
            trailing: TextButton(
              child: const Text('Set'),
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: now);
                if (d == null || !context.mounted) return;
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))));
                if (t != null) setState(() => _departure = DateTime(d.year, d.month, d.day, t.hour, t.minute));
              },
            ),
          ),
          Row(children: [
            Expanded(child: Text('Parcels waiting at the origin (${_picked.length} picked · ${_weight.toStringAsFixed(1)} kg)', style: TextStyle(fontWeight: FontWeight.w800, color: c.text))),
            TextButton(onPressed: () => setState(() => _picked.length == _parcels.length ? _picked.clear() : _picked.addAll(_parcels.map((p) => asInt(p['id'])))),
                child: Text(_picked.length == _parcels.length && _parcels.isNotEmpty ? 'None' : 'All')),
          ]),
          if (_errors['parcel_ids'] != null) Text(_errors['parcel_ids']!, style: const TextStyle(color: Color(0xFFDC2626))),
          if (_parcels.isEmpty) Text('No parcels are waiting at this hub.', style: TextStyle(color: c.muted)),
          for (final p in _parcels)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: kOrange,
              value: _picked.contains(asInt(p['id'])),
              onChanged: (v) => setState(() => v == true ? _picked.add(asInt(p['id'])) : _picked.remove(asInt(p['id']))),
              title: Text('${p['tracking']}'),
              subtitle: Text('${p['receiver']} · ${p['destination']} · ${p['weight_kg']} kg'),
            ),
          const SizedBox(height: 12),
          BusyButton('Create trip', busy: _busy, onPressed: _create),
        ]),
      ),
    );
  }
}

class TripDetailScreen extends StatefulWidget {
  final int tripId;
  const TripDetailScreen({super.key, required this.tripId});
  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Map<String, dynamic>? _t;
  List<Map<String, dynamic>> _assignable = [];
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _take(ApiResponse r) {
    _t = asMap(r.body['trip']);
    _assignable = asList(r.body['assignable']);
  }

  Future<void> _load() async {
    final r = await LogisticsApi.trip(widget.tripId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _take(r);
        _error = null;
      } else {
        _error = r.message;
      }
    });
  }

  Future<ApiResponse?> _do(Future<ApiResponse> Function() call) async {
    if (_busy) return null;
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return r;
    setState(() {
      _busy = false;
      if (r.ok && r.body['trip'] != null) _take(r);
    });
    showResult(context, r);
    if (r.broken) _load();
    return r;
  }

  Future<void> _assign() async {
    final t = _t!;
    final reassign = t['courier'] != null;
    if (_assignable.isEmpty) {
      return showError(context, 'No courier can take it now: they must be Active, On Duty, without a trip and with enough load capacity.');
    }
    final id = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(reassign ? 'Reassign to' : 'Assign to', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final c in _assignable)
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text('${c['name']}'),
              subtitle: Text('${c['vehicle_type']} · ${c['plate_number']} · ${c['load_capacity_kg']} kg · ${c['duty_label']}'),
              trailing: Text(peso(c['pay_per_trip'])),
              onTap: () => Navigator.pop(ctx, asInt(c['id'])),
            ),
        ]),
      ),
    );
    if (id == null || !mounted) return;
    String? reason;
    if (reassign) {
      reason = await showReasonDialog(context, title: 'Reassign ${t['code']}', message: 'Why? It is kept in the trip log.', confirmLabel: 'Reassign', maxLength: 300);
      if (reason == null) return;
    }
    await _do(() => LogisticsApi.assignTrip(widget.tripId, id, reason: reason));
  }

  Future<void> _seal() async {
    final seal = TextEditingController(text: 'BH-');
    final note = TextEditingController();
    var needNote = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Check the seal'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: seal,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')), LengthLimitingTextInputFormatter(10)],
              decoration: const InputDecoration(labelText: 'Seal number on the truck'),
            ),
            if (needNote) TextField(controller: note, maxLength: 300, decoration: const InputDecoration(labelText: 'Note (it does not match)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kOrange),
              onPressed: () async {
                final r = await LogisticsApi.tripSeal(widget.tripId, seal.text.trim(), note: needNote ? note.text.trim() : null);
                if (!ctx.mounted) return;
                if (r.ok) {
                  Navigator.pop(ctx);
                  if (mounted) setState(() => _take(r));
                  if (mounted) showResult(context, r);
                } else if (r.fieldErrors.containsKey('note') && !needNote) {
                  set(() => needNote = true);
                  showError(ctx, r.message);
                } else {
                  showResult(ctx, r);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    seal.dispose();
    note.dispose();
  }

  Future<void> _scanIn() async {
    final tracking = await scanWaybill(context, title: 'Scan in at ${asMap(_t!['destination'])['code']}');
    if (tracking != null) await _do(() => LogisticsApi.receiveParcel(asInt(asMap(_t!['destination'])['id']), tracking));
  }

  Future<void> _damaged(Map<String, dynamic> item) async {
    String? photo;
    try {
      photo = (await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80))?.path;
    } on PlatformException {
      if (mounted) showError(context, 'Camera access is off for ALVY. Allow it in Settings › Apps › ALVY › Permissions.');
      return;
    }
    await _do(() => LogisticsApi.damagedParcel(widget.tripId, asInt(item['parcel_id']), photo));
  }

  Future<void> _close() async {
    final r = await _do(() => LogisticsApi.closeReceiving(widget.tripId));
    if (r == null || r.ok || !r.fieldErrors.containsKey('missing') || !mounted) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close receiving?'),
        content: Text(r.fieldErrors['missing']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep scanning')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Close anyway', style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (sure == true) await _do(() => LogisticsApi.closeReceiving(widget.tripId, confirm: true));
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
    final beforeDeparture = ['scheduled', 'assigned', 'accepted', 'loading'].contains(status);
    final loc = t?['last_location'] == null ? null : asMap(t!['last_location']);
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
                    if (t['seal_discrepancy'] == true) ...[const SizedBox(width: 6), const Pill('Seal Discrepancy', color: Color(0xFFDC2626))],
                  ]),
                  const SizedBox(height: 10),
                  SectionCard(
                    child: Column(children: [
                      row('Route', '${asMap(t['origin'])['label']} → ${asMap(t['destination'])['label']}'),
                      row('Parcels', '${t['parcels']} · ${t['weight_kg']} kg · loaded ${t['loaded']} · received ${t['received']}'),
                      row('Courier', t['courier'] == null ? 'Not assigned' : '${asMap(t['courier'])['name']} (${asMap(t['courier'])['plate_number']})'),
                      if (t['accepted_at'] != null) row('Accepted', formatDateTime(t['accepted_at'])),
                      if (t['departed_at'] != null) row('Departed', formatDateTime(t['departed_at'])),
                      if (t['eta_at'] != null) row('ETA', '${formatDateTime(t['eta_at'])}${t['delay_reason'] != null ? ' (${t['delay_reason']})' : ''}'),
                      if (t['seal_number'] != null) row('Seal', '${t['seal_number']}${t['received_seal'] != null ? ' · found ${t['received_seal']}' : ''}'),
                      row('Pay', peso(t['pay'])),
                      if (t['courier_note'] != null) row('Courier note', t['courier_note']),
                    ]),
                  ),
                  if (loc != null)
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: kOrange),
                        title: const Text('Courier\'s last location'),
                        subtitle: Text('${formatDateTime(loc['at'])} · ${asList(t['route_points']).length} point(s) on the route'),
                        trailing: TextButton(
                          onPressed: () => PhoneLocation.navigate(lat: asNum(loc['lat']), lng: asNum(loc['lng'])),
                          child: const Text('Map'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (beforeDeparture || (status == 'in_transit' && asList(t['events']).any((e) => e['type'] == 'breakdown')))
                    BusyButton(t['courier'] == null ? 'Assign courier' : 'Reassign courier', busy: _busy, icon: Icons.person_search, onPressed: _assign),
                  if (status == 'arrived') ...[
                    if (t['received_seal'] == null)
                      BusyButton('Check the seal', busy: _busy, icon: Icons.verified_outlined, onPressed: _seal)
                    else ...[
                      BusyButton('Scan parcel in (${t['received']}/${t['parcels']})', busy: _busy, icon: Icons.qr_code_scanner, onPressed: _scanIn),
                      const SizedBox(height: 8),
                      BusyButton('Close receiving', busy: _busy, color: _green, icon: Icons.done_all, onPressed: _close),
                    ],
                  ],
                  if (beforeDeparture) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                      onPressed: () async {
                        final reason = await showReasonDialog(context, title: 'Cancel ${t['code']}', message: 'Why? (10 to 300 characters)', confirmLabel: 'Cancel trip', maxLength: 300);
                        if (reason != null) _do(() => LogisticsApi.cancelTrip(widget.tripId, reason));
                      },
                      child: const Text('Cancel trip'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Parcels', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                  for (final p in asList(t['items']))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${p['tracking']}'),
                      subtitle: Text('${p['receiver'] ?? ''} · ${p['weight_kg']} kg · ${p['status']}'),
                      trailing: beforeDeparture
                          ? IconButton(
                              tooltip: 'Take off this trip',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _do(() => LogisticsApi.removeTripParcel(widget.tripId, asInt(p['parcel_id']))),
                            )
                          : status == 'arrived' && (p['status'] == 'loaded' || p['status'] == 'pending')
                              ? TextButton(onPressed: () => _damaged(p), child: const Text('Damaged'))
                              : null,
                    ),
                  const SizedBox(height: 12),
                  Text('Trip log', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                  for (final e in asList(t['events']).reversed)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${e['type']}'.replaceAll('_', ' ')),
                      subtitle: Text([
                        formatDateTime(e['at']),
                        if (e['by'] != null) 'by ${e['by']}',
                        if (e['old_value'] != null || e['new_value'] != null) '${e['old_value'] ?? ''} → ${e['new_value'] ?? ''}',
                        if (e['reason'] != null) '${e['reason']}',
                      ].join(' · ')),
                    ),
                ]),
              ),
      ),
    );
  }
}

/// Scan parcels in at a hub (the trip must have arrived at this hub, with the seal checked).
class HubReceivingScreen extends StatefulWidget {
  const HubReceivingScreen({super.key});
  @override
  State<HubReceivingScreen> createState() => _HubReceivingScreenState();
}

class _HubReceivingScreenState extends State<HubReceivingScreen> {
  List<Map<String, dynamic>> _hubs = [];
  int? _hub;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    LogisticsApi.hubs().then((r) {
      if (mounted && r.ok) setState(() => _hubs = asList(r.body['hubs']));
    });
  }

  Future<void> _scan() async {
    if (_hub == null) return showError(context, 'Choose the hub you are receiving at.');
    final tracking = await scanWaybill(context, title: 'Scan parcel in');
    if (tracking == null || !mounted) return;
    final r = await LogisticsApi.receiveParcel(_hub!, tracking);
    if (!mounted) return;
    showResult(context, r);
    setState(() => _log.insert(0, r.message));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Receive at hub'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<int>(
          initialValue: _hub,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Receiving at', border: OutlineInputBorder(), isDense: true),
          items: [for (final h in _hubs) DropdownMenuItem(value: asInt(h['id']), child: Text('${h['label']}', overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => _hub = v),
        ),
        const SizedBox(height: 12),
        BusyButton('Scan parcel in', busy: false, icon: Icons.qr_code_scanner, onPressed: _scan),
        const SizedBox(height: 12),
        for (final l in _log) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.inventory_2_outlined), title: Text(l)),
      ]),
    );
  }
}
