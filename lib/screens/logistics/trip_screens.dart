import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../../services/location.dart';
import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/waybill_scanner.dart';
import 'logistics_kit.dart';

// Linehaul Trips, like the website: hub-to-hub deliveries on the company's courier trucks to the sorting center
// nearest the buyers. The receiving sorting center accepts the delivery before it loads; both track it and message
// each other on it; on arrival the receiver checks the seal and receives the parcels, which then wait in its Parcel Sorting.

const _green = Color(0xFF15803D);

/// What each line of a trip's history means.
const _eventLabels = {
  'created': 'Delivery created', 'assigned': 'Courier assigned', 'reassigned': 'Courier reassigned', 'accepted': 'Courier accepted',
  'declined': 'Courier declined', 'unassigned': 'Courier removed', 'reassigned_away': 'Reassigned to another courier',
  'handover_accepted': 'Receiving sorting center accepted', 'handover_rejected': 'Receiving sorting center rejected',
  'parcels_added': 'Parcels added', 'parcel_removed': 'Parcel taken off', 'loading': 'Loading started', 'departed': 'Departed (sealed)',
  'delay': 'Delay reported', 'breakdown': 'Vehicle breakdown', 'arrived': 'Arrived', 'seal_ok': 'Seal checked: matches',
  'seal_discrepancy': 'Seal does not match', 'damaged': 'Parcel damaged', 'missing': 'Parcel missing', 'rescanned': 'Parcels rescanned',
  'courier_note': 'Courier note', 'completed': 'Received and completed', 'completed_discrepancy': 'Completed with discrepancy', 'cancelled': 'Cancelled',
};

/// The other sorting center's side of a delivery, as one short line.
String _otherSide(Map<String, dynamic> t) =>
    t['direction'] == 'incoming' ? 'From ${t['origin_company'] ?? 'another sorting center'}' : 'To ${t['destination_company'] ?? 'another sorting center'}';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final _list = GlobalKey<PagedListState>();
  bool _busy = false;

  /// Auto-assign all: every waiting parcel goes into a delivery to the hub nearest its buyer (new deliveries when needed).
  Future<void> _autoAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    final f = await LogisticsApi.tripForm();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!f.ok) return showResult(context, f);
    final outbound = asList(f.body['outbound']);
    if (outbound.isEmpty) return showError(context, 'No waiting parcel needs to go to another sorting center.');
    final total = outbound.fold<int>(0, (n, o) => n + asInt(o['count']));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-assign parcels?'),
        content: Text('$total parcel(s) go into deliveries to the hub nearest each buyer:\n\n'
            '${outbound.map((o) => '• ${o['hub']}: ${o['count']}').join('\n')}\n\n'
            'An open delivery to that hub is filled first; otherwise a new one is made, which they accept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => Navigator.pop(ctx, true), child: const Text('Auto-assign')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final r = await LogisticsApi.autoAssignTrips(asInt(f.body['origin_hub_id']));
    if (!mounted) return;
    setState(() => _busy = false);
    showResult(context, r);
    _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PagedList(
      key: _list,
      title: 'Linehaul Trips',
      initialTab: 'active',
      empty: 'No deliveries here.',
      actions: [
        IconButton(tooltip: 'Auto-assign parcels', icon: const Icon(Icons.bolt), onPressed: _busy ? null : _autoAll),
        IconButton(
          tooltip: 'Scan parcels in',
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
        label: const Text('New delivery'),
      ),
      fetch: (page, tab) => LogisticsApi.trips(status: tab ?? 'active', page: page),
      // The design's manifest card: code and state, the route, the other sorting center, parcels and weight, the courier.
      itemBuilder: (ctx, t, reload) {
        final c = ctx.bc;
        Widget box(IconData icon, String label, String value) => Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(icon, size: 18, color: Alvy.slate),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                    ]),
                  ),
                ]),
              ),
            );
        final courier = asMap(t['courier'])['name'];
        final incoming = t['direction'] == 'incoming';
        final pending = t['handover_status'] == 'pending';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: cardBox(ctx, radius: 18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              await Navigator.push(ctx, MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: asInt(t['id']))));
              reload();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: incoming ? Alvy.successSoft : Alvy.orangeSoft, borderRadius: BorderRadius.circular(10)),
                    child: Icon(incoming ? Icons.move_to_inbox_outlined : Icons.local_shipping_outlined, size: 20, color: incoming ? _green : kOrange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(incoming ? 'INCOMING DELIVERY' : 'OUTGOING DELIVERY',
                          style: TextStyle(fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w800, color: incoming ? _green : kOrange)),
                      Text('${t['code']}', style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w800)),
                    ]),
                  ),
                  Pill('${t['status_label']}', color: Pill.forState('${t['status']}')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.circle, size: 10, color: kOrange),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${t['route']}', style: Alvy.display(size: 15, color: c.text, weight: FontWeight.w700))),
                  if (t['delayed'] == true) Text('Delayed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Alvy.dangerText)),
                ]),
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 2),
                  child: Text(_otherSide(t), style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                ),
                if (pending || t['handover_status'] == 'rejected')
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: pending ? Alvy.warnSoft : Alvy.dangerSoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      pending ? (incoming ? 'Needs your acceptance' : 'Waiting for them to accept') : 'Rejected by the receiving sorting center',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: pending ? Alvy.warnText : Alvy.dangerText),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(children: [
                  box(Icons.inventory_2_outlined, 'Parcels', '${t['parcels']}'),
                  const SizedBox(width: 8),
                  box(Icons.scale_outlined, 'Weight', '${t['weight_kg']} kg'),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  CircleAvatar(radius: 14, backgroundColor: c.subtle, child: Icon(Icons.person_outline, size: 16, color: c.textSecondary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(courier == null ? 'No courier yet' : '$courier', style: TextStyle(fontWeight: FontWeight.w600, color: courier == null ? c.muted : c.text)),
                  ),
                  Icon(Icons.chevron_right, color: c.muted),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// A new delivery: from the company's hub to another sorting center's hub, filled automatically (Auto-assign)
/// and/or with parcels picked by hand. More can be added on the delivery until it departs.
class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});
  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  List<Map<String, dynamic>> _hubs = [];
  List<Map<String, dynamic>> _destinations = [];
  List<Map<String, dynamic>> _parcels = [];
  int? _origin;
  int? _dest;
  bool _auto = true;
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
        _destinations = asList(r.body['destinations']);
        _origin = asInt(r.body['origin_hub_id']);
        _parcels = asList(r.body['parcels']);
        _picked.removeWhere((id) => !_parcels.any((p) => asInt(p['id']) == id));
      }
    });
  }

  /// The parcels Auto-assign would add for the chosen destination (nearest hub to the buyer).
  int get _autoCount => _dest == null ? 0 : _parcels.where((p) => asInt(p['best_hub_id']) == _dest).length;

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await LogisticsApi.createTrip({
      'origin_hub_id': _origin,
      'destination_hub_id': _dest,
      'parcel_ids': _picked.toList(),
      'auto': _auto,
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
      appBar: sellerBar('New delivery'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Hub to hub, to the sorting center nearest the buyers. The delivery loads only after they accept it.',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _origin,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'From (your hub)', errorText: _errors['origin_hub_id'], isDense: true),
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
            decoration: InputDecoration(labelText: 'To (sorting center)', errorText: _errors['destination_hub_id'], isDense: true),
            items: [
              for (final h in _destinations)
                DropdownMenuItem(
                  value: asInt(h['id']),
                  child: Text('${h['company']} — ${h['code']}${h['municipality'] != null ? ' · ${h['municipality']}' : ''}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _dest = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _auto,
            activeThumbColor: kOrange,
            onChanged: (v) => setState(() => _auto = v),
            title: Text('Auto-assign parcels${_dest == null ? '' : ' ($_autoCount)'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Every parcel here whose nearest hub to the buyer is this sorting center'),
          ),
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
          Text('Or pick parcels yourself (${_picked.length} picked)', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
          if (_errors['parcel_ids'] != null) Text(_errors['parcel_ids']!, style: TextStyle(color: Alvy.dangerText)),
          if (_parcels.isEmpty) Text('No parcels are waiting at this hub. You can still create the delivery and add parcels later.', style: TextStyle(color: c.muted)),
          for (final p in _parcels)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: kOrange,
              value: _picked.contains(asInt(p['id'])),
              onChanged: (v) => setState(() => v == true ? _picked.add(asInt(p['id'])) : _picked.remove(asInt(p['id']))),
              title: Text('${p['tracking']}'),
              subtitle: Text('${p['receiver']} · ${p['destination']} · ${p['weight_kg']} kg\n'
                  '${p['best_hub'] != null ? 'Nearest hub: ${p['best_hub']}' : 'You deliver it'}'),
              isThreeLine: true,
            ),
          const SizedBox(height: 12),
          BusyButton('Create delivery', busy: _busy, icon: Icons.add_road, onPressed: _create),
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
  List<Map<String, dynamic>> _addable = [];
  String _role = 'sender';
  final _msg = TextEditingController();
  String? _error;
  bool _loading = true;
  bool _busy = false;

  bool get _sender => _role == 'sender';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  void _take(ApiResponse r) {
    _t = asMap(r.body['trip']);
    _assignable = asList(r.body['assignable']);
    _addable = asList(r.body['addable']);
    _role = '${r.body['role'] ?? 'sender'}';
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

  Future<ApiResponse?> _do(Future<ApiResponse> Function() call, {bool quiet = false}) async {
    if (_busy) return null;
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return r;
    setState(() {
      _busy = false;
      if (r.ok && r.body['trip'] != null) _take(r);
    });
    if (!quiet || !r.ok) showResult(context, r);
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

  /// Pick more parcels for the delivery (no limit): the ones nearest this destination are listed first.
  Future<void> _addParcels() async {
    if (_addable.isEmpty) return showError(context, 'No other parcel is waiting at ${asMap(_t!['origin'])['code']}.');
    final picked = <int>{};
    final dest = asInt(asMap(_t!['destination'])['id']);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.75,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(children: [
                  Expanded(child: Text('Add parcels', style: Alvy.display(size: 18, color: ctx.bc.text, weight: FontWeight.w800))),
                  Text('${picked.length} picked', style: TextStyle(color: ctx.bc.textSecondary)),
                ]),
              ),
              Expanded(
                child: ListView(children: [
                  for (final p in _addable)
                    CheckboxListTile(
                      activeColor: kOrange,
                      value: picked.contains(asInt(p['id'])),
                      onChanged: (v) => set(() => v == true ? picked.add(asInt(p['id'])) : picked.remove(asInt(p['id']))),
                      title: Text('${p['tracking']}'),
                      subtitle: Text('${p['receiver']} · ${p['destination']}\n'
                          '${p['best_hub'] != null ? 'Nearest hub: ${p['best_hub']}${asInt(p['best_hub_id']) == dest ? ' ✓' : ''}' : 'You deliver it'}'),
                      isThreeLine: true,
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: BusyButton('Add ${picked.length} parcel(s)', busy: false, onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, true)),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok == true && picked.isNotEmpty) await _do(() => LogisticsApi.addTripParcels(widget.tripId, picked.toList()));
  }

  Future<void> _reject() async {
    final note = await showReasonDialog(context,
        title: 'Reject ${_t!['code']}?', message: 'The delivery is cancelled and the parcels stay with them. Why?', confirmLabel: 'Reject', maxLength: 300);
    if (note != null) await _do(() => LogisticsApi.respondTrip(widget.tripId, false, note: note));
  }

  Future<void> _send() async {
    final body = _msg.text.trim();
    if (body.isEmpty) return;
    final r = await _do(() => LogisticsApi.tripMessage(widget.tripId, body), quiet: true);
    if (r != null && r.ok) _msg.clear();
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

  /// Receive the whole delivery: untick any parcel not on the truck (it becomes Missing in Transit).
  Future<void> _receiveAll() async {
    final items = asList(_t!['items']).where((p) => p['status'] == 'loaded' || p['status'] == 'pending').toList();
    final found = {for (final p in items) asInt(p['parcel_id'])};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.75,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('Receive the parcels', style: Alvy.display(size: 18, color: ctx.bc.text, weight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Untick a parcel that is not on the truck. Received parcels go to your Parcel Sorting.',
                    style: TextStyle(fontSize: 12.5, color: ctx.bc.textSecondary)),
              ),
              Expanded(
                child: ListView(children: [
                  for (final p in items)
                    CheckboxListTile(
                      activeColor: _green,
                      value: found.contains(asInt(p['parcel_id'])),
                      onChanged: (v) => set(() => v == true ? found.add(asInt(p['parcel_id'])) : found.remove(asInt(p['parcel_id']))),
                      title: Text('${p['tracking']}'),
                      subtitle: Text('${p['receiver'] ?? ''} · ${p['destination'] ?? ''}'),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: BusyButton('Receive ${found.length} of ${items.length}', busy: false, color: _green, onPressed: () => Navigator.pop(ctx, true)),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok == true) await _do(() => LogisticsApi.receiveTrip(widget.tripId, found.toList()));
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

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final c = context.bc;
    Widget row(String l, dynamic v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(l, style: TextStyle(color: c.muted))),
            Expanded(child: Text('${v ?? '—'}', style: TextStyle(fontWeight: FontWeight.w600, color: c.text))),
          ]),
        );
    final status = '${t?['status']}';
    final beforeDeparture = ['scheduled', 'assigned', 'accepted', 'loading'].contains(status);
    final pending = t?['handover_status'] == 'pending';
    final loc = t?['last_location'] == null ? null : asMap(t!['last_location']);
    final dest = asInt(asMap(t?['destination'])['id']);
    final forHere = _addable.where((p) => asInt(p['best_hub_id']) == dest).length;
    final other = _sender ? '${t?['destination_company'] ?? 'the receiver'}' : '${t?['origin_company'] ?? 'the sender'}';
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar(t == null ? 'Delivery' : '${t['code']}', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
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
                  Text('DELIVERY CODE', style: TextStyle(fontSize: 11, letterSpacing: 0.5, fontWeight: FontWeight.w800, color: c.textSecondary)),
                  Text('${t['code']}', style: Alvy.display(size: 24, color: c.text, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    Pill('${t['status_label']}', color: Pill.forState(status)),
                    Pill(_sender ? 'Outgoing' : 'Incoming', color: _sender ? kOrange : _green),
                    if (t['delayed'] == true) const Pill('Delayed', color: Color(0xFFB45309)),
                    if (t['seal_discrepancy'] == true) const Pill('Seal Discrepancy', color: Color(0xFFDC2626)),
                  ]),
                  const SizedBox(height: 10),

                  // The receiving sorting center's acceptance.
                  if (pending && !_sender)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Alvy.warnSoft, borderRadius: BorderRadius.circular(16)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('${t['origin_company']} wants to send ${t['parcels']} parcel(s) to your hub ${asMap(t['destination'])['code']}.',
                            style: TextStyle(fontWeight: FontWeight.w800, color: Alvy.warnText)),
                        const SizedBox(height: 4),
                        Text('The parcels are listed below. The truck can load and depart only after you accept.', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: OutlinedButton(onPressed: _busy ? null : _reject, child: Text('Reject', style: TextStyle(color: Alvy.dangerText)))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: _green),
                              onPressed: _busy ? null : () => _do(() => LogisticsApi.respondTrip(widget.tripId, true)),
                              child: const Text('Accept'),
                            ),
                          ),
                        ]),
                      ]),
                    )
                  else if (pending)
                    _note('Waiting for ${t['destination_company']} to accept this delivery. The courier can load once they accept.', Alvy.warnSoft, Alvy.warnText)
                  else if (t['handover_status'] == 'rejected')
                    _note('Rejected by ${t['destination_company']}${t['handover_note'] != null ? ': ${t['handover_note']}' : ''}', Alvy.dangerSoft, Alvy.dangerText),

                  SectionCard(
                    child: Column(children: [
                      row('Route', '${asMap(t['origin'])['label']} → ${asMap(t['destination'])['label']}'),
                      row(_sender ? 'To' : 'From', other),
                      row('Parcels', '${t['parcels']} · ${t['weight_kg']} kg · loaded ${t['loaded']} · received ${t['received']}'),
                      row('Courier', t['courier'] == null ? 'Not assigned' : '${asMap(t['courier'])['name']} (${asMap(t['courier'])['plate_number']})'),
                      if (t['accepted_at'] != null) row('Accepted', formatDateTime(t['accepted_at'])),
                      if (t['departed_at'] != null) row('Departed', formatDateTime(t['departed_at'])),
                      if (t['eta_at'] != null) row('ETA', '${formatDateTime(t['eta_at'])}${t['delay_reason'] != null ? ' (${t['delay_reason']})' : ''}'),
                      if (t['seal_number'] != null) row('Seal', '${t['seal_number']}${t['received_seal'] != null ? ' · found ${t['received_seal']}' : ''}'),
                      if (_sender) row('Pay', peso(t['pay'])),
                      if (t['courier_note'] != null) row('Courier note', t['courier_note']),
                    ]),
                  ),
                  if (loc != null)
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: kOrange),
                        title: const Text('Truck\'s last location'),
                        subtitle: Text('${formatDateTime(loc['at'])} · ${asList(t['route_points']).length} point(s) on the route'),
                        trailing: TextButton(
                          onPressed: () => PhoneLocation.navigate(lat: asNum(loc['lat']), lng: asNum(loc['lng'])),
                          child: const Text('Map'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // The sending sorting center: courier, parcels (Auto-assign / add), cancel.
                  if (_sender && (beforeDeparture || (status == 'in_transit' && asList(t['events']).any((e) => e['type'] == 'breakdown'))))
                    BusyButton(t['courier'] == null ? 'Assign courier' : 'Reassign courier', busy: _busy, icon: Icons.person_search, onPressed: _assign),
                  if (_sender && beforeDeparture) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: BusyButton('Auto-assign ($forHere)', busy: _busy, icon: Icons.bolt,
                            onPressed: forHere == 0 ? null : () => _do(() => LogisticsApi.autoAddTripParcels(widget.tripId))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: BusyButton('Add parcels', busy: _busy, color: Alvy.navyFill, icon: Icons.playlist_add, onPressed: _addParcels)),
                    ]),
                  ],

                  // The receiving sorting center, after arrival: seal, then receive.
                  if (!_sender && status == 'arrived') ...[
                    if (t['received_seal'] == null)
                      BusyButton('Check the seal', busy: _busy, icon: Icons.verified_outlined, onPressed: _seal)
                    else ...[
                      BusyButton('Receive the parcels', busy: _busy, color: _green, icon: Icons.done_all, onPressed: _receiveAll),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(onPressed: _busy ? null : _scanIn, icon: const Icon(Icons.qr_code_scanner), label: Text('Scan one by one (${t['received']}/${t['parcels']})')),
                    ],
                  ],
                  if (_sender && beforeDeparture) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                      onPressed: () async {
                        final reason = await showReasonDialog(context, title: 'Cancel ${t['code']}', message: 'Why? (10 to 300 characters)', confirmLabel: 'Cancel delivery', maxLength: 300);
                        if (reason != null) _do(() => LogisticsApi.cancelTrip(widget.tripId, reason));
                      },
                      child: const Text('Cancel delivery'),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Text('Parcels on this delivery', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                  if (asList(t['items']).isEmpty) Text('No parcels yet.', style: TextStyle(color: c.muted)),
                  for (final p in asList(t['items']))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${p['tracking']}'),
                      subtitle: Text('${p['receiver'] ?? ''} · ${p['destination'] ?? ''} · ${p['weight_kg']} kg · ${'${p['status']}'.replaceAll('_', ' ')}'),
                      trailing: _sender && beforeDeparture && p['status'] != 'removed'
                          ? IconButton(
                              tooltip: 'Take off this delivery',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _do(() => LogisticsApi.removeTripParcel(widget.tripId, asInt(p['parcel_id']))),
                            )
                          : !_sender && status == 'arrived' && (p['status'] == 'loaded' || p['status'] == 'pending')
                              ? TextButton(onPressed: () => _damaged(p), child: const Text('Damaged'))
                              : null,
                    ),

                  // Messages between the two sorting centers (delays, problems, handover details).
                  if (t['cross_company'] == true) ...[
                    const SizedBox(height: 12),
                    Text('Messages with $other', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(height: 6),
                    if (asList(t['messages']).isEmpty) Text('No messages yet. Use this for delays or problems.', style: TextStyle(color: c.muted)),
                    for (final m in asList(t['messages']))
                      Align(
                        alignment: m['mine'] == true ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(color: m['mine'] == true ? Alvy.orangeSoft : c.subtle, borderRadius: BorderRadius.circular(14)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${m['body']}', style: TextStyle(color: c.text)),
                            const SizedBox(height: 2),
                            Text('${m['from'] ?? ''} · ${formatDateTime(m['at'])}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                          ]),
                        ),
                      ),
                    if (status != 'cancelled')
                      Row(children: [
                        Expanded(child: TextField(controller: _msg, maxLength: 1000, decoration: InputDecoration(hintText: 'Message $other…', counterText: ''))),
                        IconButton(onPressed: _busy ? null : _send, icon: const Icon(Icons.send, color: kOrange)),
                      ]),
                  ],

                  const SizedBox(height: 12),
                  Text('History', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                  for (final e in asList(t['events']).reversed)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_eventLabels['${e['type']}'] ?? '${e['type']}'.replaceAll('_', ' ')),
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

  Widget _note(String text, Color bg, Color fg) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
      );
}

/// Scan parcels in at a hub one by one (the delivery must have arrived at this hub, with the seal checked).
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
          decoration: const InputDecoration(labelText: 'Receiving at', isDense: true),
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
