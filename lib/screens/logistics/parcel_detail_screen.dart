import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/net_image.dart';
import 'logistics_kit.dart';

/// Opens a parcel's page, then runs [onBack] (e.g. reload the list).
Future<void> openParcel(BuildContext context, int id, [VoidCallback? onBack]) async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => ParcelDetailScreen(parcelId: id)));
  onBack?.call();
}

/// A parcel's details: route, order, delivery attempts, pickups, and marking it Lost or Damaged (L5).
class ParcelDetailScreen extends StatefulWidget {
  final int parcelId;
  const ParcelDetailScreen({super.key, required this.parcelId});
  @override
  State<ParcelDetailScreen> createState() => _ParcelDetailScreenState();
}

class _ParcelDetailScreenState extends State<ParcelDetailScreen> {
  Map<String, dynamic>? _p;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.parcel(widget.parcelId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _p = asMap(r.body['parcel']);
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _exception() async {
    final body = await showModalBottomSheet<Map<String, String>>(context: context, isScrollControlled: true, builder: (_) => const _ExceptionSheet());
    if (body == null || !mounted) return;
    final r = await LogisticsApi.markException(widget.parcelId, body['type']!, body['reason']!, photo: body['photo']);
    if (!mounted) return;
    showResult(context, r);
    if (r.ok && r.body['parcel'] != null) setState(() => _p = asMap(r.body['parcel']));
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final c = context.bc;
    Widget row(String l, dynamic v) => v == null || '$v'.isEmpty
        ? const SizedBox()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(l, style: TextStyle(color: c.muted))),
              Expanded(child: Text('$v', style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          );

    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar(p == null ? 'Parcel' : '${p['tracking']}'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: p == null
            ? const SizedBox()
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  Pill('${p['status_label']}', color: parcelColor('${p['status']}')),
                  const SizedBox(height: 10),
                  SectionCard(
                    child: Column(children: [
                      row('Order', p['order_number']),
                      row('Payment', p['payment']),
                      row('COD', p['cod'] != null ? peso(p['cod']) : null),
                      row('Seller', p['seller']),
                      row('Pick up', p['pickup_address']),
                      row('Receiver', '${p['receiver'] ?? ''} · ${p['receiver_phone'] ?? ''}'),
                      row('Deliver to', p['dropoff_address']),
                      row('Barangay', asMap(p['area'])['name']),
                      row('Weight', p['weight_kg'] != null ? '${p['weight_kg']} kg' : null),
                      row('Received', p['received_at'] != null ? formatDateTime(p['received_at']) : null),
                      row('Sorted', p['sorted_at'] != null ? formatDateTime(p['sorted_at']) : null),
                      row('Return rider', p['rts_rider']),
                      row('Reason', p['failure_reason']),
                    ]),
                  ),
                  if (p['exception_photo_url'] != null)
                    SectionCard(
                      title: 'Photo',
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: NetImage('${p['exception_photo_url']}', height: 200, fit: BoxFit.cover)),
                    ),
                  if (asList(p['pickups']).isNotEmpty)
                    SectionCard(
                      title: 'Pickups',
                      child: Column(children: [
                        for (final x in asList(p['pickups']))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${x['rider'] ?? '—'}'),
                            subtitle: Text(x['picked_up_at'] != null ? 'Picked up ${formatDateTime(x['picked_up_at'])}' : ''),
                            trailing: Pill('${x['status_label']}'),
                          ),
                      ]),
                    ),
                  if (asList(p['deliveries']).isNotEmpty)
                    SectionCard(
                      title: 'Delivery attempts',
                      child: Column(children: [
                        for (final x in asList(p['deliveries']))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Attempt ${x['attempt']} · ${x['rider'] ?? '—'}'),
                            subtitle: Text([
                              if (x['delivered_at'] != null) 'Delivered ${formatDateTime(x['delivered_at'])}',
                              if (x['failure_reason'] != null) '${x['failure_reason']}',
                              if (asNum(x['cod_collected']) > 0) 'COD ${peso(x['cod_collected'])}',
                            ].join(' · ')),
                            trailing: Pill('${x['status_label']}'),
                          ),
                      ]),
                    ),
                  if (p['can_mark_exception'] == true)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                      onPressed: _exception,
                      icon: const Icon(Icons.report_outlined),
                      label: const Text('Mark Lost or Damaged'),
                    ),
                ]),
              ),
      ),
    );
  }
}

class _ExceptionSheet extends StatefulWidget {
  const _ExceptionSheet();
  @override
  State<_ExceptionSheet> createState() => _ExceptionSheetState();
}

class _ExceptionSheetState extends State<_ExceptionSheet> {
  String _type = 'lost';
  String? _photo;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Lost or damaged parcel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('The order is refunded and the buyer and seller are told. This can\'t be undone.'),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'lost', label: Text('Lost')), ButtonSegment(value: 'damaged', label: Text('Damaged'))],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            FormInput(_reason, 'Reason (10 to 300 characters)', maxLines: 3, maxLength: 300),
            OutlinedButton.icon(
              onPressed: () async {
                final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
                if (x != null) setState(() => _photo = x.path);
              },
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(_photo == null ? (_type == 'damaged' ? 'Photo of the damage (required)' : 'Photo (optional)') : 'Retake photo'),
            ),
            const SizedBox(height: 12),
            BusyButton('Mark ${_type == 'lost' ? 'Lost' : 'Damaged'}', busy: false, color: const Color(0xFFDC2626), onPressed: () {
              Navigator.pop(context, {'type': _type, 'reason': _reason.text.trim(), if (_photo != null) 'photo': _photo!});
            }),
          ]),
        ),
      ),
    );
  }
}
