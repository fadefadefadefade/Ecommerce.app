import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../services/rider_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/net_image.dart';
import '../../widgets/responsive.dart';
import '../seller/seller_kit.dart';
import '../../widgets/design_kit.dart';
import '../../widgets/waybill_scanner.dart';

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

    final name = '${rider['full_name'] ?? ''}';
    Widget stat(String value, String label, {Color? color}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Alvy.display(size: 19, color: color ?? c.text, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
            ]),
          ),
        );
    // The design's rider card: who, the company, Online/Offline, and today's figures.
    final top = <Widget>[
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Stack(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Alvy.orangeSoft,
                child: Text(name.isEmpty ? 'R' : name[0].toUpperCase(), style: Alvy.display(size: 20, color: kOrange)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: suspended ? const Color(0xFFDC2626) : (online ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF)),
                    shape: BoxShape.circle,
                    border: Border.all(color: Alvy.surface, width: 2),
                  ),
                ),
              ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700)),
                Text('${rider['company'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
              ]),
            ),
            suspended
                ? const Pill('Suspended', color: Color(0xFFDC2626))
                : Pill(online ? 'Online' : 'Offline', color: online ? const Color(0xFF15803D) : const Color(0xFF6B7280)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            stat('${rider['active_jobs'] ?? 0}', 'Active jobs', color: kOrange),
            const SizedBox(width: 8),
            stat('${rider['area'] ?? '—'}', 'Barangay'),
            const SizedBox(width: 8),
            stat('${offers.length}', 'Offers'),
          ]),
          const SizedBox(height: 12),
          Text(
            suspended
                ? 'Your account is suspended by ${rider['company']}. You can\'t go Online or receive jobs.'
                : (online ? 'You are Online: your hub assigns you the pickups and deliveries of your barangay.' : 'Go Online so your hub can assign you jobs.'),
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          const SizedBox(height: 10),
          online
              ? OutlinedButton.icon(
                  onPressed: _busy || suspended ? null : () => _act(() => RiderApi.setOnline(false)),
                  icon: const Icon(Icons.pause_circle_outline, size: 19),
                  label: const Text('Go Offline'),
                )
              : FilledButton.icon(
                  onPressed: _busy || suspended ? null : () => _act(() => RiderApi.setOnline(true)),
                  icon: const Icon(Icons.power_settings_new, size: 19),
                  label: const Text('Go Online'),
                ),
        ]),
      ),
    ];
    final offersPart = <Widget>[
      if (offers.isNotEmpty) ...[
        const SectionTitle('Job Offers', padding: EdgeInsets.fromLTRB(0, 10, 0, 12)),
        for (final o in offers) _offer(o),
      ],
    ];
    final jobsPart = <Widget>[
      const SectionTitle('Active Jobs', padding: EdgeInsets.fromLTRB(0, 10, 0, 12)),
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
        const SectionTitle('Hub Transfers', padding: EdgeInsets.fromLTRB(0, 10, 0, 12)),
        for (final t in transfers)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.swap_horiz, color: kOrange),
              title: Text('${t['reference']} · ${t['waybill'] ?? t['tracking']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${t['from']} → ${t['to']}${t['expected_by'] != null ? ' · by ${formatDateTime(t['expected_by'])}' : ''}'),
              trailing: Pill(t['status'] == 'in_transit' ? 'In transit' : 'Waiting', color: Alvy.slate),
            ),
          ),
      ],
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 8),
        const SectionTitle('Recent Deliveries', padding: EdgeInsets.fromLTRB(0, 10, 0, 12)),
        SectionCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(children: [
            for (final x in recent)
              ListTile(
                dense: true,
                title: Text('${x['receiver'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('#${x['waybill'] ?? x['tracking']} · ${formatDateTime(x['updated_at'])}'),
                trailing: Pill('${x['status_label']}', color: x['status'] == 'delivered' ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
              ),
          ]),
        ),
      ],
    ];

    // Tablet: offers on the left, active jobs and recent deliveries on the right. Phones: one list.
    if (Responsive.isWide(context)) {
      Widget column(List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
      return ListView(padding: const EdgeInsets.all(16), children: [
        ...top,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: column(offersPart)),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: column(jobsPart)),
        ]),
      ]);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      ...top,
      ...offersPart,
      const SizedBox(height: 8),
      ...jobsPart,
    ]);
  }

  /// A job the hub assigned (the rider's barangay) and not started: Acknowledge ("I saw it") or On my way (pickups).
  List<Widget> _assignedActions(String kind, Map<String, dynamic> job, Map<String, dynamic> d) {
    final id = asInt(job['id']);
    return [
      if (job['acknowledged'] != true)
        TextButton(onPressed: _busy ? null : () => _act(() => RiderApi.acknowledgeJob(kind, id)), child: const Text('Acknowledge')),
      if (kind == 'pickup' && job['on_the_way'] != true)
        TextButton(onPressed: _busy ? null : () => _act(() => RiderApi.onMyWay(id)), child: const Text('On my way')),
    ];
  }

  Widget _offer(Map<String, dynamic> o) {
    final left = _left(o).clamp(0, 9999);
    final kind = '${o['kind']}';
    const white = Colors.white;
    final soft = Colors.white.withValues(alpha: .85);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: Alvy.gradient, borderRadius: BorderRadius.circular(20), boxShadow: Alvy.buttonShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.circle, size: 10, color: white),
          const SizedBox(width: 8),
          Expanded(
            child: Text('NEW ${kind.toUpperCase()} OFFER', style: const TextStyle(color: white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_outlined, size: 14, color: kOrange),
              const SizedBox(width: 4),
              Text('${left}s', style: const TextStyle(color: kOrange, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text('${o['pickup_name']}', style: Alvy.display(size: 21, color: white, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.location_on_outlined, size: 16, color: soft),
          const SizedBox(width: 4),
          Expanded(child: Text('${o['pickup_address'] ?? ''}', style: TextStyle(color: soft, fontSize: 13))),
        ]),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.flag_outlined, size: 16, color: soft),
          const SizedBox(width: 4),
          Expanded(child: Text('To: ${o['dropoff']}', style: TextStyle(color: soft, fontSize: 13))),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your pay', style: TextStyle(color: soft, fontSize: 12)),
              Text(peso(o['pay']), style: Alvy.display(size: 24, color: white, weight: FontWeight.w700)),
            ]),
          ),
          Text(o['cod'] != null ? 'COD ${peso(o['cod'])}' : 'Paid · no COD', style: TextStyle(color: soft, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
        Text('#${o['tracking']}', style: TextStyle(color: soft, fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .16), foregroundColor: white, side: const BorderSide(color: Colors.transparent)),
              onPressed: _busy || left <= 0 ? null : () => _act(() => RiderApi.declineOffer(asInt(o['id']))),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: white, foregroundColor: kOrange),
              onPressed: _busy || left <= 0 ? null : () => _act(() => RiderApi.acceptOffer(asInt(o['id']))),
              icon: const Icon(Icons.check_circle_outline, size: 19),
              label: const Text('Accept'),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _job({required String title, required String subtitle, required String status, required bool amber, required VoidCallback onTap, List<Widget> actions = const []}) {
    final c = context.bc;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardBox(context),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Pill(status, color: amber ? const Color(0xFFB45309) : Alvy.slate),
                const Spacer(),
                Icon(Icons.chevron_right, color: c.muted),
              ]),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: c.text)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 4, right: 8),
                  decoration: BoxDecoration(color: Alvy.slate, shape: BoxShape.circle),
                ),
                Expanded(child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textSecondary))),
              ]),
              if (actions.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ]),
          ),
        ),
      ),
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
  String? _photoError;
  String? _photo;
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

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await RiderApi.acknowledgeJob('pickup', widget.pickupId);
    if (!mounted) return;
    setState(() => _busy = false);
    showResult(context, r);
    _load();
  }

  Future<void> _takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
    if (x != null && mounted) {
      setState(() {
        _photo = x.path;
        _photoError = null;
      });
    }
  }

  Future<void> _scan() async {
    final code = await scanWaybill(context, title: 'Scan the waybill');
    if (code == null || !mounted) return;
    _tracking.text = code;
    _confirm();
  }

  Future<void> _confirm() async {
    if (_busy) return;   // one submit: a second scan of the same waybill doesn't send it twice
    if (_photo == null) {
      setState(() => _photoError = 'Take a photo of the parcel first (proof of pickup).');
      return;
    }
    if (_tracking.text.trim().isEmpty) {
      setState(() => _fieldError = 'Scan the waybill or type its number.');
      return;
    }
    setState(() {
      _busy = true;
      _fieldError = null;
      _photoError = null;
    });
    final r = await RiderApi.confirmPickup(widget.pickupId, _tracking.text.trim(), photo: _photo);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _fieldError = r.fieldErrors['tracking_number'];
      _photoError = r.fieldErrors['proof_photo'];
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
      appBar: sellerBar('Pickup'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: p == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                // The design's pickup card: the state, the seller, and where to bring the parcel.
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      riderTag('${p['status_label']}'.toUpperCase(), live: p['picked_up_at'] == null),
                      const Spacer(),
                      Text('${p['tracking']}', style: TextStyle(fontSize: 12, color: context.bc.textSecondary, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 12),
                    Text('${p['seller']}', style: Alvy.display(size: 21, color: context.bc.text, weight: FontWeight.w800)),
                    Text(p['picked_up_at'] != null ? 'Picked up ${formatDateTime(p['picked_up_at'])}' : 'Pickup at the merchant',
                        style: TextStyle(color: context.bc.textSecondary, fontSize: 13)),
                  ]),
                ),
                SectionCard(
                  child: Column(children: [
                    _row(Icons.place_outlined, 'Pickup address', '${p['pickup_address'] ?? '—'}'),
                    _row(Icons.call_outlined, 'Contact number', '${p['contact'] ?? '—'}'),
                    _row(Icons.qr_code_2, 'Tracking number', '${p['tracking']}'),
                    _row(Icons.inventory_2_outlined, 'Parcels', '1 parcel${p['items'] != null ? ' · ${p['items']} item(s)' : ''}'),
                    _row(Icons.warehouse_outlined, 'Bring to', '${p['bring_to']}'),
                  ]),
                ),
                if (p['can_confirm'] == true && p['acknowledged'] != true)
                  SectionCard(
                    title: 'New pickup job',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Accept this job, then go to the seller.', style: TextStyle(color: context.bc.textSecondary)),
                      const SizedBox(height: 12),
                      BusyButton('Accept job', busy: _busy, icon: Icons.check_circle_outline, onPressed: _accept),
                    ]),
                  ),
                if (p['can_confirm'] == true && p['acknowledged'] == true)
                  SectionCard(
                    title: '1. Photo of the parcel',
                    trailing: const Text('Proof of pickup', style: TextStyle(fontSize: 12, color: Alvy.orange, fontWeight: FontWeight.w700)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      InkWell(
                        onTap: _takePhoto,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 170,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(14)),
                          child: _photo == null
                              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Icon(Icons.photo_camera_outlined, size: 36, color: Alvy.orange),
                                  const SizedBox(height: 8),
                                  Text('Take a photo of the parcel', style: TextStyle(color: context.bc.textSecondary, fontWeight: FontWeight.w600)),
                                ])
                              : Image.file(File(_photo!), fit: BoxFit.cover),
                        ),
                      ),
                      if (_photoError != null)
                        Padding(padding: const EdgeInsets.only(top: 6), child: Text(_photoError!, style: const TextStyle(color: Color(0xFFDC2626)))),
                    ]),
                  ),
                if (p['can_confirm'] == true && p['acknowledged'] == true)
                  SectionCard(
                    title: '2. Scan the waybill',
                    trailing: Icon(Icons.qr_code_scanner, color: Alvy.slate),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan with camera'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tracking,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _confirm(),   // a barcode scanner types the number and presses Enter
                        decoration: InputDecoration(
                          labelText: 'Or type the waybill / tracking number',
                          hintText: 'e.g. PH2611…',
                          prefixIcon: const Icon(Icons.qr_code_2),
                          errorText: _fieldError,
                          errorMaxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      BusyButton('Confirm pickup', busy: _busy, icon: Icons.inventory_2_outlined, onPressed: _confirm),
                    ]),
                  ),
              ]),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: Alvy.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12, color: context.bc.textSecondary)),
              Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: context.bc.text)),
            ]),
          ),
        ]),
      );
}
// ── Delivery ───────────────────────────────────────────────────

/// The web's delivery page: Mark Out for Delivery, then the proof photo + the exact COD; or a failed attempt.
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
  final _cod = TextEditingController();
  String? _photo;
  String? _scanned;   // the waybill the rider scanned at the door
  String? _reason;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
      appBar: sellerBar('Delivery'),
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

    final done = d['delivered_at'] != null;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      // The design's route card: the state, the order, and the big maps button.
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            riderTag('${d['status_label']}'.toUpperCase(), live: !done),
            const Spacer(),
            Text('${d['tracking']}', style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          Text(done ? 'Delivered' : 'Attempt ${d['attempt']} of ${d['max_attempts']}',
              style: Alvy.display(size: 22, color: c.text, weight: FontWeight.w800)),
          Text(
            done
                ? formatDateTime(d['delivered_at'])
                : d['out_at'] != null
                    ? 'Out for delivery since ${formatDateTime(d['out_at'])}'
                    : 'Assigned ${formatDateTime(d['assigned_at'])}',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
          if (d['maps_url'] != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse('${d['maps_url']}'), mode: LaunchMode.externalApplication),
              style: FilledButton.styleFrom(backgroundColor: Alvy.navyFill, minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.explore_outlined, size: 20),
              label: Text(d['has_pin'] == true ? "Directions to the buyer's pin" : 'Find the address in Maps'),
            ),
            if (d['has_pin'] != true)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text("The buyer didn't pin this address on the map; call them if you can't find it.",
                    style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
              ),
          ],
        ]),
      ),
      // The buyer: initials, name and phone, then the address in a beige box.
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Alvy.orangeSoft,
              child: Text(riderInitials('${d['receiver'] ?? ''}'), style: Alvy.display(size: 15, color: Alvy.orange, weight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d['receiver'] ?? ''}', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700)),
                if ((d['phone'] ?? '').toString().isNotEmpty) Text('${d['phone']}', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.place_outlined, color: Alvy.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${d['address'] ?? ''}', style: TextStyle(color: c.text, height: 1.4))),
            ]),
          ),
          if (d['failure_reason'] != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Alvy.dangerSoft, borderRadius: BorderRadius.circular(12)),
              child: Text('Failed: ${d['failure_reason']}', style: TextStyle(color: Alvy.dangerText, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
      // Payment: the amount to collect, big, and a clear "collect" / "do not collect" box.
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.verified_user_outlined, color: Alvy.slate, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Payment', style: TextStyle(fontWeight: FontWeight.w700, color: c.text))),
            riderChip(cod != null ? 'Cash on delivery' : 'Paid', soft: cod == null),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('Amount to collect:', style: TextStyle(color: c.textSecondary))),
            Text(peso(cod ?? 0), style: Alvy.display(size: 24, color: cod != null ? Alvy.orange : Alvy.slate, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cod != null ? Alvy.orangeSoft : Alvy.dangerSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(cod != null ? Icons.payments_outlined : Icons.block, size: 20, color: cod != null ? Alvy.orangeDark : Alvy.dangerText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cod != null ? 'COLLECT EXACTLY ${peso(cod)}\nThe buyer pays in cash when they receive the parcel.' : 'DO NOT COLLECT CASH\nThis order is already paid.',
                  style: TextStyle(color: cod != null ? Alvy.orangeDark : Alvy.dangerText, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
            ]),
          ),
        ]),
      ),
      if (asList(d['items']).isNotEmpty)
        SectionCard(
          title: 'Items',
          child: Column(children: [
            for (final i in asList(d['items']))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${i['title']}${i['variation'] != null ? ' (${i['variation']})' : ''}', style: TextStyle(color: c.text))),
                  riderChip('× ${i['quantity']}', soft: true),
                ]),
              ),
          ]),
        ),
      if (a['start'] == true)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BusyButton('Mark Out for Delivery', busy: _busy, icon: Icons.local_shipping_outlined,
              onPressed: () => _do(() => RiderApi.startDelivery(widget.deliveryId))),
        ),
      if (a['deliver'] == true)
        SectionCard(
          title: 'Proof of Delivery',
          trailing: const Text('Photo needed', style: TextStyle(fontSize: 12, color: Alvy.orange, fontWeight: FontWeight.w700)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InkWell(
              onTap: _takePhoto,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 180,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                child: _photo == null
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.photo_camera_outlined, size: 36, color: Alvy.orange),
                        const SizedBox(height: 8),
                        Text('Take proof-of-delivery photo', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600)),
                      ])
                    : Stack(fit: StackFit.expand, children: [
                        Image.file(File(_photo!), fit: BoxFit.cover),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: CircleAvatar(radius: 18, backgroundColor: Colors.white, child: Icon(Icons.photo_camera_outlined, size: 18, color: Alvy.navy)),
                        ),
                      ]),
              ),
            ),
            if (_errors['pod_photo'] != null)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(_errors['pod_photo']!, style: const TextStyle(color: Color(0xFFDC2626)))),
            // Proof of delivery: the parcel photo + the rider's scan of the parcel's waybill.
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final code = await scanWaybill(context, title: 'Scan the waybill');
                      if (code != null && mounted) setState(() => _scanned = code);
                    },
              icon: Icon(_scanned == null ? Icons.qr_code_scanner : Icons.check_circle, color: _scanned == null ? null : Alvy.successText),
              label: Text(_scanned == null ? 'Scan the waybill' : 'Waybill scanned: $_scanned'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
            if (_errors['tracking_number'] != null)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(_errors['tracking_number']!, style: const TextStyle(color: Color(0xFFDC2626)))),
            if (cod != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _cod,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'COD collected (₱)',
                  helperText: 'Collect exactly ${peso(cod)}.',
                  errorText: _errors['cod_collected'],
                  errorMaxLines: 3,
                ),
              ),
            ],
            const SizedBox(height: 14),
            BusyButton('Complete Dropoff', busy: _busy, icon: Icons.check_circle_outline, onPressed: () {
              if (_photo == null || _scanned == null) {
                setState(() => _errors = {
                      if (_photo == null) 'pod_photo': 'Take a photo of the parcel.',
                      if (_scanned == null) 'tracking_number': 'Scan the waybill on the parcel.',
                    });
                return;
              }
              _do(() => RiderApi.deliver(widget.deliveryId, cod: cod != null ? _cod.text.trim() : null, photo: _photo, tracking: _scanned), back: true);
            }),
          ]),
        ),
      if (a['fail'] == true)
        SectionCard(
          title: 'Customer unreachable?',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: InputDecoration(labelText: 'Reason', errorText: _errors['reason']),
              items: [for (final r in reasons) DropdownMenuItem(value: r, child: Text(r))],
              onChanged: (v) => setState(() => _reason = v),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: c.subtle,
                side: BorderSide.none,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _busy
                  ? null
                  : () async {
                      if (await confirmAction(context, 'Mark as failed?', 'After the 3rd attempt, or when Refused, the parcel goes back to the seller.',
                          confirm: 'Mark failed', danger: true)) {
                        _do(() => RiderApi.failDelivery(widget.deliveryId, _reason ?? ''), back: true);
                      }
                    },
              icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
              label: const Text('Failed Delivery', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      if (d['pod_url'] != null)
        SectionCard(
          title: 'Proof of delivery',
          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: NetImage('${d['pod_url']}', height: 220, fit: BoxFit.cover)),
        ),
    ]);
  }
}

// ── History, pay, COD ──────────────────────────────────────────

Widget _walletRow(BuildContext context, Map<String, dynamic> r, {bool time = false}) {
  final c = context.bc;
  final pay = asNum(r['pay']);
  final cod = asNum(r['cod']);
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: cardBox(context, radius: 16),
    child: Column(children: [
      Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: cod > 0 ? Alvy.orangeSoft : c.subtle,
          child: Icon(cod > 0 ? Icons.payments_outlined : Icons.check_circle_outline, size: 18, color: cod > 0 ? Alvy.orange : c.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['tracking'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
            Text('${r['type']} · ${r['result']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${pay > 0 ? '+' : ''}${peso(pay)}', style: Alvy.display(size: 15, color: pay > 0 ? Alvy.orange : c.muted, weight: FontWeight.w800)),
          Text(time ? formatDate(r['at'], 'h:mm a') : formatDateTime(r['at']), style: TextStyle(fontSize: 11.5, color: c.muted)),
        ]),
      ]),
      if (cod > 0) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(8)),
          child: Text('COD collected: ${peso(cod)}', textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: Alvy.orangeDark, fontWeight: FontWeight.w700)),
        ),
      ],
    ]),
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
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            if (_from != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  const Icon(Icons.event_outlined, size: 18, color: Alvy.orange),
                  const SizedBox(width: 6),
                  Text('${formatDate(_from)} – ${formatDate(_to)}', style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
                ]),
              ),
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
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                  riderSegments(context, periods, _period, (k) {
                    setState(() => _period = k);
                    _load();
                  }),
                  const SizedBox(height: 12),
                  riderHero(
                    'Rider pay · ${periods[_period] ?? ''}',
                    peso(b['total']),
                    [
                      ('Pickups (${asInt(asMap(b['pickups'])['count'])})', peso(asMap(b['pickups'])['pay'])),
                      ('Deliveries (${asInt(asMap(b['deliveries'])['count'])})', peso(asMap(b['deliveries'])['pay'])),
                    ],
                  ),
                  Text('${formatDate(d['from'])} – ${formatDate(d['to'])} · ${peso(asMap(d['pay'])['pickup'])} per pickup · ${peso(asMap(d['pay'])['delivery'])} per delivery · ₱0.00 failed',
                      style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(children: [
                    riderFigure(context, 'Today', peso(asMap(cards['today'])['pay']), Icons.today_outlined, hint: '${asInt(asMap(cards['today'])['jobs'])} job(s)'),
                    const SizedBox(width: 10),
                    riderFigure(context, 'To earn', peso(d['pending']), Icons.hourglass_bottom, hint: 'Jobs you have now'),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    riderFigure(context, 'This week', peso(asMap(cards['week'])['pay']), Icons.date_range_outlined, hint: '${asInt(asMap(cards['week'])['jobs'])} job(s)'),
                    const SizedBox(width: 10),
                    riderFigure(context, 'This month', peso(asMap(cards['month'])['pay']), Icons.calendar_month_outlined, hint: '${asInt(asMap(cards['month'])['jobs'])} job(s)'),
                  ]),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Summary',
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
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              SizedBox(
                                width: 92,
                                child: Text('${x['label']}',
                                    style: TextStyle(fontSize: 12, color: c.text, fontWeight: x['today'] == true ? FontWeight.w800 : FontWeight.normal)),
                              ),
                              Expanded(
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(99)),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: (asNum(x['pay']) / peak).clamp(0.0, 1.0),
                                    child: Container(decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(99))),
                                  ),
                                ),
                              ),
                              SizedBox(width: 80, child: Text(peso(x['pay']), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: c.text))),
                            ]),
                          ),
                      ]),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
                    child: Text('Trip Breakdown', style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700)),
                  ),
                  if (asList(d['jobs']).isEmpty)
                    Text('No jobs in this period.', style: TextStyle(color: c.muted))
                  else
                    for (final r in asList(d['jobs'])) _walletRow(context, r, time: true),
                ]),
              ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: bold ? context.bc.text : context.bc.textSecondary, fontWeight: bold ? FontWeight.w800 : FontWeight.normal))),
          Text(value, style: TextStyle(color: bold ? Alvy.orange : context.bc.text, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 16 : null)),
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
            SizedBox(width: 130, child: Text(l, style: TextStyle(color: c.textSecondary))),
            Expanded(child: Text(v, style: TextStyle(color: c.text, fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
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
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                riderHero(r['status'] == 'confirmed' ? 'Remitted · confirmed' : 'Remitted · waiting for confirmation', peso(r['amount']),
                    [('COD covered', peso(r['expected'])), ('Sent to', '${r['company']}')], icon: Icons.receipt_long_outlined),
                SectionCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${r['reference']}', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w800))),
                      Pill(r['status'] == 'confirmed' ? 'Confirmed' : 'Pending', color: r['status'] == 'confirmed' ? const Color(0xFF15803D) : const Color(0xFFB45309)),
                    ]),
                    const SizedBox(height: 8),
                    row('Rider', '${r['rider']}'),
                    row('Sent to', '${r['company']}'),
                    row('Sent', formatDateTime(r['sent_at'])),
                    row('Amount', peso(r['amount']), bold: true),
                    row('COD covered', peso(r['expected'])),
                    if (asNum(r['pay_kept']) > 0) row('Your pay kept', peso(r['pay_kept'])),
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
    // What to hand over: the COD minus the rider's unpaid pay (worked out by the server, like the website).
    final next = asMap(d['next']);
    final remit = next.isEmpty ? asNum(d['balance']) : asNum(next['remit']);
    _amount.text = remit > 0 ? remit.toStringAsFixed(2) : '';
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
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                  riderHero('COD on hand (not yet confirmed)', peso(d['balance']), [('Pending confirmation', peso(d['pending'])), ('Hand to', '${d['company']}')],
                      icon: Icons.account_balance_outlined),
                  Builder(builder: (_) {
                    final next = asMap(d['next']);
                    final cod = next.isEmpty ? asNum(d['balance']) : asNum(next['cod']);
                    final pay = asNum(next['pay']);
                    final remit = next.isEmpty ? cod : asNum(next['remit']);
                    Widget line(String label, String value, {Color? color, bool bold = false}) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Expanded(child: Text(label, style: TextStyle(color: bold ? c.text : c.textSecondary, fontWeight: bold ? FontWeight.w800 : null))),
                            Text(value, style: bold
                                ? Alvy.display(size: 22, color: Alvy.orange, weight: FontWeight.w800)
                                : TextStyle(color: color ?? c.text, fontWeight: FontWeight.w600)),
                          ]),
                        );
                    return SectionCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          CircleAvatar(radius: 20, backgroundColor: Alvy.slateSoft, child: Icon(Icons.account_balance_outlined, color: Alvy.slate, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Next Remittance', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700)),
                              Text('Hand the COD to ${d['company']} by the end of the day. Only they can confirm it.',
                                  style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.35)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                          child: Column(children: [
                            line("COD you're holding", peso(cod)),
                            line('Less: your pay (keep it from the cash)', '− ${peso(pay)}', color: Alvy.slate),
                            Divider(color: c.border),
                            line('Hand over to ${d['company']}', peso(remit), bold: true),
                            if (asNum(next['owed']) > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('${peso(next['owed'])} more of your pay is kept from your next COD.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                              ),
                          ]),
                        ),
                        if (_amountError != null)
                          Padding(padding: const EdgeInsets.only(top: 8), child: Text(_amountError!, style: TextStyle(color: Alvy.dangerText))),
                        const SizedBox(height: 12),
                        BusyButton('Remit ${peso(remit)}', busy: _busy, icon: Icons.send_outlined,
                            onPressed: cod <= 0 || asNum(d['pending']) > 0 ? null : _remit),
                      ]),
                    );
                  }),
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
                                subtitle: Text('${formatDateTime(r['created_at'])}${asNum(r['pay_kept']) > 0 ? ' · pay kept ${peso(r['pay_kept'])}' : ''}${asNum(r['shortfall']) > 0 ? ' · shortfall ${peso(r['shortfall'])}' : ''}'),
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
            : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                // The design's profile header: avatar, name, company, status, and the rider's figures.
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: cardBox(context, radius: 20),
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Alvy.orange, width: 2)),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Alvy.orangeSoft,
                          child: Text(riderInitials('${r['full_name']}'), style: Alvy.display(size: 18, color: Alvy.orange, weight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${r['full_name']}', style: Alvy.display(size: 19, color: c.text, weight: FontWeight.w800)),
                          Text('${r['company']}', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Pill('${r['status']}', color: Pill.forState(r['status'] == 'Active' ? 'active' : r['status'])),
                            if (_stats.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              riderTag(_stats['online'] == true ? 'ONLINE' : 'OFFLINE', live: _stats['online'] == true),
                            ],
                          ]),
                        ]),
                      ),
                    ]),
                    if (_stats.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          _figure(peso(_stats['earned']), 'Earned'),
                          Container(width: 1, height: 30, color: c.border),
                          _figure('${asInt(_stats['jobs'])}', 'Paid jobs'),
                          Container(width: 1, height: 30, color: c.border),
                          _figure(r['rider_since'] != null ? formatDate(r['rider_since'], 'MMM y') : '—', 'Rider since'),
                        ]),
                      ),
                    ],
                    if (r['needs_reverification'] == true)
                      _notice('Your new vehicle details are waiting for re-verification.', const Color(0xFFB45309), Alvy.warnSoft),
                    if (r['license_state'] != null)
                      _notice(
                        r['license_state'] == 'expired'
                            ? 'Your driver\'s license has expired. Renew it and update the details below.'
                            : 'Your driver\'s license expires on ${formatDate(r['license_expiry'])}. Renew it soon and update the details below.',
                        r['license_state'] == 'expired' ? Alvy.dangerText : const Color(0xFFB45309),
                        r['license_state'] == 'expired' ? Alvy.dangerSoft : Alvy.warnSoft,
                      ),
                  ]),
                ),
                SectionCard(
                  title: 'Vehicle & Documents',
                  child: Column(children: [
                    _info(Icons.place_outlined, 'Area', '${r['area'] ?? '—'}'),
                    _info(Icons.two_wheeler_outlined, 'Vehicle', '${r['vehicle_type'] ?? '—'} · ${r['plate_number'] ?? '—'}'),
                    _info(Icons.badge_outlined, 'License', '${r['license_number'] ?? '—'} · expires ${formatDate(r['license_expiry'], 'MM/dd/yyyy')}'),
                    const SizedBox(height: 6),
                    for (final (key, label, has) in [
                      ('license', 'Driver\'s license', r['has_license_file'] == true),
                      ('or-cr', 'OR/CR', r['has_or_cr_file'] == true),
                    ])
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                        decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Icon(has ? Icons.check_circle : Icons.radio_button_unchecked, color: has ? const Color(0xFF15803D) : c.muted, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                              Text(has ? 'Uploaded' : 'Not uploaded yet', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            ]),
                          ),
                          if (has)
                            TextButton(onPressed: () => _openDocument(key, label), child: Text('View', style: TextStyle(color: Alvy.slate, fontWeight: FontWeight.w700))),
                        ]),
                      ),
                  ]),
                ),
                SectionCard(
                  title: 'Update vehicle and license',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    DropdownButtonFormField<String>(
                      initialValue: _vehicles.contains(_vehicle) ? _vehicle : null,
                      decoration: InputDecoration(labelText: 'Vehicle type', errorText: _errors['vehicle_type'], isDense: true),
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
                            isDense: true, suffixIcon: const Icon(Icons.event)),
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

  Widget _figure(String value, String label) => Expanded(
        child: Column(children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Alvy.display(size: 16, color: Alvy.orange, weight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 11.5, color: context.bc.textSecondary)),
        ]),
      );

  Widget _notice(String text, Color fg, Color bg) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, height: 1.35)),
      );

  Widget _info(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: Alvy.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12, color: context.bc.textSecondary)),
              Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: context.bc.text)),
            ]),
          ),
        ]),
      );
}
