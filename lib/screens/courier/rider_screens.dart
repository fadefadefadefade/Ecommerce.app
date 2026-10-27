import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../../services/api_client.dart';
import '../../services/rider_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/net_image.dart';
import '../seller/seller_kit.dart';

/// The web's Hub Jobs (courier.rider): Online / Offline, job offers with a countdown, and the active
/// pickups, deliveries and returns. It refreshes every 15 seconds like the website.
class RiderJobsScreen extends StatefulWidget {
  const RiderJobsScreen({super.key});

  @override
  State<RiderJobsScreen> createState() => _RiderJobsScreenState();
}

class _RiderJobsScreenState extends State<RiderJobsScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _refresh;
  Timer? _tick;
  DateTime _loadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false && TickerMode.of(context)) _load();
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  int _left(Map<String, dynamic> o) => asInt(o['seconds_left']) - DateTime.now().difference(_loadedAt).inSeconds;

  void _onTick() {
    if (!mounted || _d == null || !TickerMode.of(context)) return;
    final offers = asList(_d!['offers']);
    if (offers.isEmpty) return;
    // At 0 the offer went to the next rider: reload, like the website.
    if (offers.any((o) => _left(o) <= 0)) {
      _load();
    } else {
      setState(() {});
    }
  }

  Future<void> _load() async {
    if (_d == null) setState(() => _loading = true);
    final r = await RiderApi.jobs();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = r.body;
        _error = null;
        _loadedAt = DateTime.now();
      } else if (_d == null) {
        _error = r.message;
      }
    });
  }

  Future<void> _act(Future<ApiResponse> Function() call) async {
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.ok && r.body['rider'] != null) {
        _d = r.body;
        _loadedAt = DateTime.now();
      }
    });
    showResult(context, r);
    if (!r.ok) _load();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Hub Jobs', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: _d == null ? const SizedBox() : RefreshIndicator(color: kOrange, onRefresh: _load, child: _body(_d!)),
      ),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final c = context.bc;
    final rider = asMap(d['rider']);
    final offers = asList(d['offers']);
    final pickups = asList(d['pickups']);
    final deliveries = asList(d['deliveries']);
    final returns = asList(d['returns']);
    final transfers = asList(d['transfers']);
    final recent = asList(d['recent']);
    final online = rider['online'] == true;
    final suspended = rider['suspended'] == true;

    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('${rider['company']} · ${rider['full_name']}', style: TextStyle(color: c.muted)),
      const SizedBox(height: 8),
      SectionCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              suspended
                  ? const Pill('Suspended', color: Color(0xFFDC2626))
                  : Pill(online ? 'Online' : 'Offline', color: online ? const Color(0xFF15803D) : const Color(0xFF6B7280)),
              const SizedBox(height: 6),
              Text(
                suspended
                    ? 'Your account is suspended by ${rider['company']}. You can\'t go Online or receive jobs.'
                    : 'Online riders get job offers. Active jobs: ${rider['active_jobs']} of ${rider['max_active']}.',
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          online
              ? OutlinedButton(onPressed: _busy || suspended ? null : () => _act(() => RiderApi.setOnline(false)), child: const Text('Go Offline'))
              : FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
                  onPressed: _busy || suspended ? null : () => _act(() => RiderApi.setOnline(true)),
                  child: const Text('Go Online'),
                ),
        ]),
      ),
      Text('Offers', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
      const SizedBox(height: 6),
      if (offers.isEmpty)
        SectionCard(
          child: Column(children: [
            const Text('No offers right now', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(online ? 'Stay Online; new jobs appear here.' : 'Go Online to receive job offers.', style: TextStyle(color: c.muted)),
          ]),
        ),
      for (final o in offers) _offer(o),
      const SizedBox(height: 8),
      Text('Active jobs', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
      const SizedBox(height: 6),
      if (pickups.isEmpty && deliveries.isEmpty && returns.isEmpty)
        SectionCard(child: Text('No active jobs.', style: TextStyle(color: c.muted))),
      for (final p in pickups)
        _job(
          title: 'Pickup · ${p['waybill'] ?? p['tracking']}',
          subtitle: '${p['seller']} — ${p['pickup_address'] ?? ''}${p['on_the_way'] == true ? ' · On my way' : ''}',
          status: '${p['status_label']}',
          amber: p['status'] == 'assigned',
          onTap: () => _open(RiderPickupScreen(pickupId: asInt(p['id']))),
          actions: p['status'] == 'assigned' ? _assignedActions('pickup', p, d) : const [],
        ),
      for (final x in deliveries)
        _job(
          title: 'Delivery · ${x['waybill'] ?? x['tracking']}',
          subtitle: '${x['receiver']} — ${x['address'] ?? ''} · attempt ${x['attempt']} of ${x['max_attempts']}',
          status: '${x['status_label']}',
          amber: x['status'] == 'assigned',
          onTap: () => _open(RiderDeliveryScreen(deliveryId: asInt(x['id']))),
          actions: x['status'] == 'assigned' ? _assignedActions('delivery', x, d) : const [],
        ),
      for (final r in returns)
        _job(
          title: 'Return to seller · ${r['tracking']}',
          subtitle: '${r['seller']} — ${r['pickup_address'] ?? ''}',
          status: 'Handed back to seller',
          amber: false,
          onTap: () async {
            if (await confirmAction(context, 'Handed back to the seller?', 'Confirm you gave ${r['tracking']} back to the seller.')) {
              _act(() => RiderApi.returnedToSeller(asInt(r['id'])));
            }
          },
        ),
      // Hub-to-hub parcels this rider carries (riders the hub allowed to transport).
      if (transfers.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Hub transfers to carry', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
        const SizedBox(height: 6),
        for (final t in transfers)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.swap_horiz, color: kOrange),
              title: Text('${t['reference']} · ${t['waybill'] ?? t['tracking']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${t['from']} → ${t['to']}${t['expected_by'] != null ? ' · by ${formatDateTime(t['expected_by'])}' : ''}'),
              trailing: Pill(t['status'] == 'in_transit' ? 'In transit' : 'Waiting', color: const Color(0xFF2563EB)),
            ),
          ),
      ],
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('Recent deliveries', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
        const SizedBox(height: 6),
        for (final x in recent)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${x['waybill'] ?? x['tracking']} · ${x['receiver'] ?? ''}'),
            subtitle: Text(formatDateTime(x['updated_at'])),
            trailing: Pill('${x['status_label']}', color: x['status'] == 'delivered' ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
          ),
      ],
    ]);
  }

  /// A job the hub assigned and not started: Acknowledge ("I saw it"), On my way (pickups), or Decline with a reason.
  List<Widget> _assignedActions(String kind, Map<String, dynamic> job, Map<String, dynamic> d) {
    final id = asInt(job['id']);
    return [
      if (job['acknowledged'] != true)
        TextButton(onPressed: _busy ? null : () => _act(() => RiderApi.acknowledgeJob(kind, id)), child: const Text('Acknowledge')),
      if (kind == 'pickup' && job['on_the_way'] != true)
        TextButton(onPressed: _busy ? null : () => _act(() => RiderApi.onMyWay(id)), child: const Text('On my way')),
      TextButton(
        onPressed: _busy
            ? null
            : () async {
                final reasons = (d['decline_reasons'] as List? ?? const []).map((e) => '$e').toList();
                final reason = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(title: const Text('Why can\'t you do it?'), children: [
                    for (final r in reasons) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, r), child: Text(r)),
                  ]),
                );
                if (reason != null) _act(() => RiderApi.declineJob(kind, id, reason));
              },
        child: const Text('Decline', style: TextStyle(color: Color(0xFFDC2626))),
      ),
    ];
  }

  Widget _offer(Map<String, dynamic> o) {
    final c = context.bc;
    final left = _left(o).clamp(0, 9999);
    final kind = '${o['kind']}';
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${kind[0].toUpperCase()}${kind.substring(1)} · ${o['tracking']}', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
          ),
          Pill('${left}s', color: const Color(0xFFB45309)),
        ]),
        const SizedBox(height: 4),
        Text('Pickup: ${o['pickup_name']} — ${o['pickup_address'] ?? ''}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        Text('Drop-off: ${o['dropoff']}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        Text('COD: ${o['cod'] != null ? peso(o['cod']) : 'None (paid)'} · Pay: ${peso(o['pay'])} $kind', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _busy || left <= 0 ? null : () => _act(() => RiderApi.declineOffer(asInt(o['id']))), child: const Text('Decline'))),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kOrange),
              onPressed: _busy || left <= 0 ? null : () => _act(() => RiderApi.acceptOffer(asInt(o['id']))),
              child: const Text('Accept'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _job({required String title, required String subtitle, required String status, required bool amber, required VoidCallback onTap, List<Widget> actions = const []}) {
    final c = context.bc;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
      child: Column(children: [
        ListTile(
          onTap: onTap,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Pill(status, color: amber ? const Color(0xFFB45309) : const Color(0xFF2563EB)),
        ),
        if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 8, bottom: 4), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions)),
      ]),
    );
  }
}

// ── Pickup ─────────────────────────────────────────────────────

/// The web's pickup page: the seller's details, then scan or type the waybill's tracking number to confirm.
class RiderPickupScreen extends StatefulWidget {
  final int pickupId;
  const RiderPickupScreen({super.key, required this.pickupId});

  @override
  State<RiderPickupScreen> createState() => _RiderPickupScreenState();
}

class _RiderPickupScreenState extends State<RiderPickupScreen> {
  Map<String, dynamic>? _p;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _fieldError;
  final _tracking = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tracking.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await RiderApi.pickup(widget.pickupId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _p = asMap(r.body['pickup']);
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _confirm() async {
    if (_busy) return;   // one submit: a second scan of the same waybill doesn't send it twice
    setState(() {
      _busy = true;
      _fieldError = null;
    });
    final r = await RiderApi.confirmPickup(widget.pickupId, _tracking.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _fieldError = r.fieldErrors['tracking_number'];
      if (r.ok && r.body['pickup'] != null) _p = asMap(r.body['pickup']);
    });
    showResult(context, r);
    if (r.broken) return _load();
    if (r.ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar(p == null ? 'Pickup' : 'Pickup · ${p['tracking']}'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: p == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.all(12), children: [
                Row(children: [
                  Pill('${p['status_label']}', color: p['status'] == 'assigned' ? const Color(0xFFB45309) : const Color(0xFF2563EB)),
                  if (p['picked_up_at'] != null) Text('  · picked up ${formatDateTime(p['picked_up_at'])}'),
                ]),
                const SizedBox(height: 10),
                SectionCard(
                  child: Column(children: [
                    _row('Seller', '${p['seller']}'),
                    _row('Pickup address', '${p['pickup_address'] ?? '—'}'),
                    _row('Contact number', '${p['contact'] ?? '—'}'),
                    _row('Tracking number', '${p['tracking']}'),
                    _row('Parcels', '1 parcel${p['items'] != null ? ' · ${p['items']} item(s)' : ''}'),
                    _row('Bring to', '${p['bring_to']}'),
                  ]),
                ),
                if (p['can_confirm'] == true)
                  SectionCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextField(
                        controller: _tracking,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _confirm(),   // a barcode scanner types the number and presses Enter
                        decoration: InputDecoration(
                          labelText: 'Scan the waybill barcode or type the tracking number',
                          hintText: 'e.g. ${'${p['tracking']}'.substring(0, 4)}…',
                          errorText: _fieldError,
                          errorMaxLines: 3,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      BusyButton('Confirm pickup', busy: _busy, icon: Icons.inventory_2_outlined, onPressed: _confirm),
                    ]),
                  ),
              ]),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: context.bc.muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

// ── Delivery ───────────────────────────────────────────────────

/// The web's delivery page: Mark Out for Delivery, then photo + the buyer's OTP + the exact COD; or a failed attempt.
class RiderDeliveryScreen extends StatefulWidget {
  final int deliveryId;
  const RiderDeliveryScreen({super.key, required this.deliveryId});

  @override
  State<RiderDeliveryScreen> createState() => _RiderDeliveryScreenState();
}

class _RiderDeliveryScreenState extends State<RiderDeliveryScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, String> _errors = {};
  final _otp = TextEditingController();
  final _cod = TextEditingController();
  String? _photo;
  String? _reason;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _otp.dispose();
    _cod.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await RiderApi.delivery(widget.deliveryId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = asMap(r.body['delivery']);
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _do(Future<ApiResponse> Function() call, {bool back = false}) async {
    setState(() {
      _busy = true;
      _errors = {};
    });
    final r = await call();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _errors = r.fieldErrors;
      if (r.body['delivery'] != null) _d = asMap(r.body['delivery']);
    });
    showResult(context, r);
    if (r.broken) return _load();
    if (r.ok && back) Navigator.pop(context);
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
    if (x != null) setState(() => _photo = x.path);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar(d == null ? 'Delivery' : 'Delivery · ${d['tracking']}'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null ? const SizedBox() : _body(d),
      ),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final c = context.bc;
    final a = asMap(d['actions']);
    final cod = d['cod_amount'];
    final reasons = [for (final r in (d['failure_reasons'] as List? ?? [])) '$r'];

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(label, style: TextStyle(color: c.muted))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );

    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Pill('${d['status_label']}', color: const Color(0xFF2563EB)),
        Text('  · attempt ${d['attempt']} of ${d['max_attempts']}'),
      ]),
      const SizedBox(height: 10),
      SectionCard(
        child: Column(children: [
          row('Buyer', '${d['receiver']} · ${d['phone'] ?? ''}'),
          row('Address', '${d['address'] ?? ''}'),
          row('Payment', cod != null ? 'COD — collect ${peso(cod)}' : '₱0.00 · Paid (no cash to collect)'),
          row('Assigned', formatDateTime(d['assigned_at'])),
          if (d['out_at'] != null) row('Out for delivery', formatDateTime(d['out_at'])),
          if (d['delivered_at'] != null) row('Delivered', formatDateTime(d['delivered_at'])),
          if (d['failure_reason'] != null) row('Failed', '${d['failure_reason']}'),
        ]),
      ),
      if (asList(d['items']).isNotEmpty)
        SectionCard(
          title: 'Items',
          child: Column(children: [
            for (final i in asList(d['items']))
              Row(children: [
                Expanded(child: Text('${i['title']}${i['variation'] != null ? ' (${i['variation']})' : ''}')),
                Text('× ${i['quantity']}'),
              ]),
          ]),
        ),
      if (a['start'] == true)
        BusyButton('Mark Out for Delivery', busy: _busy, color: const Color(0xFF2563EB), icon: Icons.local_shipping_outlined,
            onPressed: () => _do(() => RiderApi.startDelivery(widget.deliveryId))),
      if (a['deliver'] == true)
        SectionCard(
          title: 'Deliver',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OutlinedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_photo == null ? 'Take proof-of-delivery photo' : 'Retake photo'),
            ),
            if (_photo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_photo!), height: 160, fit: BoxFit.cover)),
              ),
            if (_errors['pod_photo'] != null) Text(_errors['pod_photo']!, style: const TextStyle(color: Color(0xFFDC2626))),
            const SizedBox(height: 12),
            TextField(
              controller: _otp,
              enabled: d['otp_locked_until'] == null,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'OTP from the buyer',
                helperText: 'The buyer sees the 6-digit OTP on their order page.',
                helperMaxLines: 2,
                counterText: '',
                errorText: _errors['otp'] ??
                    (d['otp_locked_until'] != null ? 'OTP entry is locked until ${formatDate(d['otp_locked_until'], 'h:mm a')}.' : null),
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            if (cod != null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _cod,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'COD collected (₱)',
                  helperText: 'Collect exactly ${peso(cod)}.',
                  errorText: _errors['cod_collected'],
                  errorMaxLines: 3,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            BusyButton('Delivered', busy: _busy, color: const Color(0xFF15803D), icon: Icons.check_circle_outline,
                onPressed: () => _do(() => RiderApi.deliver(widget.deliveryId,
                    otp: _otp.text.trim(), cod: cod != null ? _cod.text.trim() : null, photo: _photo), back: true)),
          ]),
        ),
      if (a['fail'] == true)
        SectionCard(
          title: 'Failed delivery',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: InputDecoration(labelText: 'Reason', errorText: _errors['reason'], border: const OutlineInputBorder()),
              items: [for (final r in reasons) DropdownMenuItem(value: r, child: Text(r))],
              onChanged: (v) => setState(() => _reason = v),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626), side: const BorderSide(color: Color(0xFFDC2626))),
              onPressed: _busy
                  ? null
                  : () async {
                      if (await confirmAction(context, 'Mark as failed?', 'After the 3rd attempt, or when Refused, the parcel goes back to the seller.',
                          confirm: 'Mark failed', danger: true)) {
                        _do(() => RiderApi.failDelivery(widget.deliveryId, _reason ?? ''), back: true);
                      }
                    },
              child: const Text('Mark failed'),
            ),
          ]),
        ),
      if (d['pod_url'] != null)
        SectionCard(
          title: 'Proof of delivery',
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: NetImage('${d['pod_url']}', height: 220, fit: BoxFit.cover)),
        ),
    ]);
  }
}

// ── History, pay, COD ──────────────────────────────────────────

Widget _walletRow(BuildContext context, Map<String, dynamic> r, {bool time = false}) {
  final c = context.bc;
  return ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text('${r['type']} · ${r['tracking'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text('${r['result']} · ${time ? formatDate(r['at'], 'h:mm a') : formatDateTime(r['at'])}'
        '${asNum(r['cod']) > 0 ? ' · COD ${peso(r['cod'])}' : ''}'),
    trailing: Text(peso(r['pay']), style: TextStyle(fontWeight: FontWeight.w800, color: asNum(r['pay']) > 0 ? const Color(0xFF15803D) : c.muted)),
  );
}

class RiderHistoryScreen extends StatefulWidget {
  const RiderHistoryScreen({super.key});
  @override
  State<RiderHistoryScreen> createState() => _RiderHistoryScreenState();
}

class _RiderHistoryScreenState extends State<RiderHistoryScreen> {
  List<Map<String, dynamic>>? _rows;
  String? _from, _to, _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _rows == null);
    final r = await RiderApi.history(from: _from, to: _to);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _rows = asList(r.body['rows']);
        _error = null;
      } else if (_rows == null) {
        _error = r.message;
      }
    });
    if (!r.ok && _rows != null && mounted) showResult(context, r);
  }

  Future<void> _range() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked == null) return;
    _from = ymd(picked.start);
    _to = ymd(picked.end);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Job History', actions: [
        IconButton(onPressed: _range, icon: const Icon(Icons.date_range)),
        if (_from != null)
          IconButton(
            onPressed: () {
              _from = _to = null;
              _load();
            },
            icon: const Icon(Icons.clear),
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
            if (_from != null) Text('${formatDate(_from)} – ${formatDate(_to)}', style: TextStyle(color: c.muted)),
            if ((_rows ?? []).isEmpty) const EmptyNote(Icons.history, 'No jobs in this period.'),
            for (final r in _rows ?? []) _walletRow(context, r),
          ]),
        ),
      ),
    );
  }
}

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});
  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;
  String _period = 'week';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await RiderApi.earnings(period: _period);
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
    final cards = asMap(d?['cards']);
    final b = asMap(d?['breakdown']);
    final periods = asMap(d?['periods']);
    final days = asList(d?['days']);
    final peak = days.fold<double>(1, (m, x) => asNum(x['pay']) > m ? asNum(x['pay']) : m);
    Widget card(String key, String label, IconData icon, Color color) => StatTile(
        label: label, value: peso(asMap(cards[key])['pay']), icon: icon, color: color, hint: '${asInt(asMap(cards[key])['jobs'])} job(s)');
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Rider Pay'),
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
                  StatGrid([
                    card('today', 'Today', Icons.today, const Color(0xFF15803D)),
                    card('week', 'This week', Icons.date_range, const Color(0xFF2563EB)),
                    card('month', 'This month', Icons.calendar_month, const Color(0xFF9333EA)),
                    StatTile(label: 'To earn', value: peso(d['pending']), icon: Icons.hourglass_bottom, hint: 'Jobs you have now'),
                  ]),
                  const SizedBox(height: 8),
                  Text('Pay per job: ${peso(asMap(d['pay'])['pickup'])} pickup · ${peso(asMap(d['pay'])['delivery'])} delivery · ₱0.00 failed.',
                      style: TextStyle(color: c.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [
                    for (final e in periods.entries)
                      ChoiceChip(
                        label: Text('${e.value}'),
                        selected: _period == e.key,
                        selectedColor: kOrange.withValues(alpha: .15),
                        onSelected: (_) {
                          setState(() => _period = e.key);
                          _load();
                        },
                      ),
                  ]),
                  SectionCard(
                    title: '${periods[_period] ?? ''} · ${formatDate(d['from'])} – ${formatDate(d['to'])}',
                    child: Column(children: [
                      _line('Pickups (${asInt(asMap(b['pickups'])['count'])})', peso(asMap(b['pickups'])['pay'])),
                      _line('Deliveries (${asInt(asMap(b['deliveries'])['count'])})', peso(asMap(b['deliveries'])['pay'])),
                      _line('Failed attempts', '${asInt(b['failed'])} · ₱0.00'),
                      _line('COD collected', peso(b['cod'])),
                      const Divider(),
                      _line('Total pay', peso(b['total']), bold: true),
                    ]),
                  ),
                  if (days.isNotEmpty)
                    SectionCard(
                      title: 'Day by day',
                      child: Column(children: [
                        for (final x in days)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(children: [
                              SizedBox(width: 92, child: Text('${x['label']}', style: TextStyle(fontSize: 12, fontWeight: x['today'] == true ? FontWeight.w800 : FontWeight.normal))),
                              Expanded(
                                child: Container(
                                  height: 8,
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: (asNum(x['pay']) / peak).clamp(0.0, 1.0),
                                    child: Container(decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(4))),
                                  ),
                                ),
                              ),
                              SizedBox(width: 80, child: Text(peso(x['pay']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                            ]),
                          ),
                      ]),
                    ),
                  SectionCard(
                    title: 'Jobs',
                    child: asList(d['jobs']).isEmpty
                        ? Text('No jobs in this period.', style: TextStyle(color: c.muted))
                        : Column(children: [for (final r in asList(d['jobs'])) _walletRow(context, r, time: true)]),
                  ),
                ]),
              ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.normal))),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}

/// The website's remittance receipt: what the rider sent, to whom, the deliveries it covers and whether it was confirmed.
class RemittanceReceiptScreen extends StatefulWidget {
  final int remittanceId;
  const RemittanceReceiptScreen({super.key, required this.remittanceId});
  @override
  State<RemittanceReceiptScreen> createState() => _RemittanceReceiptScreenState();
}

class _RemittanceReceiptScreenState extends State<RemittanceReceiptScreen> {
  Map<String, dynamic>? _r;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await RiderApi.remittanceReceipt(widget.remittanceId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (r.ok) _r = asMap(r.body['receipt']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final c = context.bc;
    Widget row(String l, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 130, child: Text(l, style: TextStyle(color: c.muted))),
            Expanded(child: Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
          ]),
        );
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Remittance receipt'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: r == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.all(12), children: [
                SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${r['reference']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                      Pill(r['status'] == 'confirmed' ? 'Confirmed' : 'Pending', color: r['status'] == 'confirmed' ? const Color(0xFF15803D) : const Color(0xFFB45309)),
                    ]),
                    const SizedBox(height: 8),
                    row('Rider', '${r['rider']}'),
                    row('Sent to', '${r['company']}'),
                    row('Sent', formatDateTime(r['sent_at'])),
                    row('Amount', peso(r['amount']), bold: true),
                    row('Expected', peso(r['expected'])),
                    if (asNum(r['shortfall']) > 0) row('Short', peso(r['shortfall'])),
                    if (asNum(r['carried_over']) > 0) row('Carried over', peso(r['carried_over'])),
                    if (r['confirmed_at'] != null) row('Confirmed', '${formatDateTime(r['confirmed_at'])}${r['confirmed_by'] != null ? ' by ${r['confirmed_by']}' : ''}'),
                  ]),
                ),
                SectionCard(
                  title: 'Deliveries covered',
                  child: asList(r['deliveries']).isEmpty
                      ? Text('None listed.', style: TextStyle(color: c.muted))
                      : Column(children: [
                          for (final x in asList(r['deliveries']))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text('${x['order_number'] ?? ''} · ${x['tracking'] ?? ''}'),
                              subtitle: Text(formatDateTime(x['delivered_at'])),
                              trailing: Text(peso(x['cod']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                        ]),
                ),
              ]),
      ),
    );
  }
}

/// The web's COD Remittance: the COD collected, a remittance waiting for the company, and the history.
class RiderCodScreen extends StatefulWidget {
  const RiderCodScreen({super.key});
  @override
  State<RiderCodScreen> createState() => _RiderCodScreenState();
}

class _RiderCodScreenState extends State<RiderCodScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  String? _amountError;
  bool _loading = true;
  bool _busy = false;
  final _amount = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _show(Map<String, dynamic> d) {
    _d = d;
    final balance = asNum(d['balance']);
    _amount.text = balance > 0 ? balance.toStringAsFixed(2) : '';
  }

  Future<void> _load() async {
    final r = await RiderApi.cod();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _show(r.body);
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _remit() async {
    setState(() {
      _busy = true;
      _amountError = null;
    });
    final r = await RiderApi.remit(_amount.text.trim(), '${_d!['request_token']}');
    if (!mounted) return;
    setState(() {
      _busy = false;
      _amountError = r.fieldErrors['amount'];
      if (r.ok && r.body['balance'] != null) _show(r.body);
    });
    showResult(context, r);
    // Like the website: the receipt opens after sending.
    if (r.ok && r.body['remittance_id'] != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RemittanceReceiptScreen(remittanceId: asInt(r.body['remittance_id']))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('COD Remittance'),
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
                  Text('Hand the COD you collected to ${d['company']} by the end of the day. Only they can confirm it.', style: TextStyle(color: c.muted)),
                  const SizedBox(height: 10),
                  StatGrid([
                    StatTile(label: 'COD balance (not yet confirmed)', value: peso(d['balance']), icon: Icons.payments_outlined, color: kOrange),
                    StatTile(label: 'Remittance pending confirmation', value: peso(d['pending']), icon: Icons.hourglass_bottom, color: const Color(0xFFB45309)),
                  ]),
                  const SizedBox(height: 12),
                  SectionCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Amount (₱)', errorText: _amountError, errorMaxLines: 3, border: const OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      BusyButton('Remit', busy: _busy, icon: Icons.send_outlined,
                          onPressed: asNum(d['balance']) <= 0 || asNum(d['pending']) > 0 ? null : _remit),
                    ]),
                  ),
                  SectionCard(
                    title: 'COD collected',
                    child: asList(d['orders']).isEmpty
                        ? Text('No COD collected yet.', style: TextStyle(color: c.muted))
                        : Column(children: [
                            for (final o in asList(d['orders']))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('${o['tracking']} · ${o['order_number'] ?? ''}'),
                                subtitle: Text(formatDateTime(o['delivered_at'])),
                                trailing: Text(peso(o['cod']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                          ]),
                  ),
                  SectionCard(
                    title: 'Remittances',
                    child: asList(d['remittances']).isEmpty
                        ? Text('No remittances yet.', style: TextStyle(color: c.muted))
                        : Column(children: [
                            for (final r in asList(d['remittances']))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                onTap: r['id'] == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => RemittanceReceiptScreen(remittanceId: asInt(r['id'])))),
                                title: Text(peso(r['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${formatDateTime(r['created_at'])}${asNum(r['shortfall']) > 0 ? ' · shortfall ${peso(r['shortfall'])}' : ''}'),
                                trailing: Pill('${r['status']}'[0].toUpperCase() + '${r['status']}'.substring(1), color: Pill.forState(r['status'])),
                              ),
                          ]),
                  ),
                ]),
              ),
      ),
    );
  }
}

// ── Rider profile ──────────────────────────────────────────────

/// The web's Rider Profile: company and status, vehicle, license and OR/CR. Changing the vehicle sends it for re-verification.
class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key});
  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  Map<String, dynamic>? _r;
  Map<String, dynamic> _stats = {};   // the Account page's header: earned, paid jobs, online
  List<String> _vehicles = [];
  String? _error;
  bool _loading = true;
  bool _saving = false;
  Map<String, String> _errors = {};
  String? _vehicle;
  String? _expiry;
  String? _licenseFile;
  String? _orCrFile;
  final _plate = TextEditingController();
  final _license = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _plate.dispose();
    _license.dispose();
    super.dispose();
  }

  void _fill(Map<String, dynamic> body) {
    _r = asMap(body['rider']);
    _vehicles = [for (final v in (body['vehicles'] as List? ?? [])) '$v'];
    _vehicle = _r!['vehicle_type'] as String?;
    _plate.text = '${_r!['plate_number'] ?? ''}';
    _license.text = '${_r!['license_number'] ?? ''}';
    _expiry = _r!['license_expiry'] as String?;
    _licenseFile = _orCrFile = null;
  }

  Future<void> _load() async {
    final r = await RiderApi.profile();
    final acc = await RiderApi.courierAccount();
    if (!mounted) return;
    if (acc.ok) _stats = asMap(acc.body['stats']);
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
    final r = await RiderApi.updateProfile({
      'vehicle_type': _vehicle ?? '',
      'plate_number': _plate.text.trim(),
      'license_number': _license.text.trim(),
      'license_expiry': _expiry ?? '',
    }, licenseFile: _licenseFile, orCrFile: _orCrFile);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = r.fieldErrors;
      if (r.ok && r.body['rider'] != null) _fill(r.body);
    });
    showResult(context, r);
  }

  Future<void> _openDocument(String which, String title) async {
    final f = await RiderApi.document(which);
    if (!mounted) return;
    if (!f.ok) return showResult(context, f.error!);
    final bytes = Uint8List.fromList(f.bytes);
    final pdf = bytes.length > 4 && String.fromCharCodes(bytes.take(4)) == '%PDF';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: sellerBar(title),
          body: pdf
              ? PdfPreview(build: (_) async => bytes, useActions: false)
              : InteractiveViewer(child: Center(child: Image.memory(bytes, errorBuilder: (_, __, ___) => const Text('This file can\'t be shown.')))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Rider Profile'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: r == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.all(12), children: [
                SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['full_name']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
                    Text('${r['company']}', style: TextStyle(color: c.muted)),
                    if (_stats.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Earned ${peso(_stats['earned'])} · ${asInt(_stats['jobs'])} paid job(s) · ${_stats['online'] == true ? 'Online' : 'Offline'}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(height: 6),
                    Pill('${r['status']}', color: Pill.forState(r['status'] == 'Active' ? 'active' : r['status'])),
                    if (r['needs_reverification'] == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Your new vehicle details are waiting for re-verification.', style: TextStyle(color: Color(0xFFB45309))),
                      ),
                    const SizedBox(height: 8),
                    if (r['license_state'] != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: r['license_state'] == 'expired' ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          r['license_state'] == 'expired'
                              ? 'Your driver\'s license has expired. Renew it and update the details below.'
                              : 'Your driver\'s license expires on ${formatDate(r['license_expiry'])}. Renew it soon and update the details below.',
                          style: TextStyle(color: r['license_state'] == 'expired' ? const Color(0xFFB91C1C) : const Color(0xFFB45309)),
                        ),
                      ),
                    Text('Rider since: ${r['rider_since'] != null ? formatDate(r['rider_since'], 'MMM y') : '—'} · Area: ${r['area'] ?? '—'}'),
                    Text('Vehicle: ${r['vehicle_type'] ?? '—'} · ${r['plate_number'] ?? '—'}'),
                    Text('License: ${r['license_number'] ?? '—'} · expires ${formatDate(r['license_expiry'], 'MM/dd/yyyy')}'),
                    const SizedBox(height: 8),
                    for (final (key, label, has) in [
                      ('license', 'Driver\'s license', r['has_license_file'] == true),
                      ('or-cr', 'OR/CR', r['has_or_cr_file'] == true),
                    ])
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(has ? Icons.check_circle : Icons.radio_button_unchecked, color: has ? const Color(0xFF15803D) : c.muted),
                        title: Text(label),
                        subtitle: Text(has ? 'Uploaded' : 'Not uploaded yet'),
                        trailing: has ? TextButton(onPressed: () => _openDocument(key, label), child: const Text('View')) : null,
                      ),
                  ]),
                ),
                SectionCard(
                  title: 'Vehicle and license',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    DropdownButtonFormField<String>(
                      initialValue: _vehicles.contains(_vehicle) ? _vehicle : null,
                      decoration: InputDecoration(labelText: 'Vehicle type', errorText: _errors['vehicle_type'], border: const OutlineInputBorder(), isDense: true),
                      items: [for (final v in _vehicles) DropdownMenuItem(value: v, child: Text(v))],
                      onChanged: (v) => setState(() => _vehicle = v),
                    ),
                    const SizedBox(height: 12),
                    FormInput(_plate, 'Plate number', hint: 'e.g. 123ABC or NBC1234', error: _errors['plate_number']),
                    FormInput(_license, 'Driver\'s license number', error: _errors['license_number']),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(_expiry ?? '') ?? now,
                            firstDate: now.subtract(const Duration(days: 3650)),
                            lastDate: now.add(const Duration(days: 3650)));
                        if (picked != null) setState(() => _expiry = ymd(picked));
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: 'License expiry', errorText: _errors['license_expiry'], errorMaxLines: 3,
                            border: const OutlineInputBorder(), isDense: true, suffixIcon: const Icon(Icons.event)),
                        child: Text(_expiry ?? ''),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png']);
                        if (f?.files.single.path != null) setState(() => _licenseFile = f!.files.single.path);
                      },
                      icon: const Icon(Icons.upload_file),
                      label: Text(_licenseFile == null ? 'New driver\'s license photo (JPG/PNG)' : _licenseFile!.split(RegExp(r'[\\/]')).last),
                    ),
                    if (_errors['license_file'] != null) Text(_errors['license_file']!, style: const TextStyle(color: Color(0xFFDC2626))),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
                        if (f?.files.single.path != null) setState(() => _orCrFile = f!.files.single.path);
                      },
                      icon: const Icon(Icons.upload_file),
                      label: Text(_orCrFile == null ? 'New OR/CR (PDF, JPG or PNG)' : _orCrFile!.split(RegExp(r'[\\/]')).last),
                    ),
                    if (_errors['or_cr_file'] != null) Text(_errors['or_cr_file']!, style: const TextStyle(color: Color(0xFFDC2626))),
                    const SizedBox(height: 6),
                    Text('Changing the plate or the OR/CR sends it to ${r['company']} for re-verification.', style: TextStyle(fontSize: 12, color: c.muted)),
                    const SizedBox(height: 12),
                    BusyButton('Save profile', busy: _saving, onPressed: _save),
                  ]),
                ),
              ]),
      ),
    );
  }
}
