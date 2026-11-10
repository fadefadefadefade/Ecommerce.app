import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
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
              SizedBox(width: 110, child: Text(l, style: TextStyle(color: c.textSecondary))),
              Expanded(child: Text('$v', style: TextStyle(fontWeight: FontWeight.w600, color: c.text))),
            ]),
          );

    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Parcel'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: p == null
            ? const SizedBox()
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
                  // The design's parcel card: state and tracking, the amount to collect, then the route.
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: cardBox(context, radius: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Pill('${p['status_label']}', color: parcelColor('${p['status']}')),
                        const Spacer(),
                        Text('${p['tracking']}', style: TextStyle(fontWeight: FontWeight.w700, color: Alvy.slate)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Text(p['cod'] != null ? 'Collect on delivery' : 'Payment', style: TextStyle(color: c.textSecondary))),
                        if (p['cod'] != null)
                          Text(peso(p['cod']), style: Alvy.display(size: 22, color: Alvy.orange, weight: FontWeight.w800))
                        else
                          Text('Nothing to collect', style: TextStyle(fontWeight: FontWeight.w700, color: Alvy.slate)),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                        child: Column(children: [
                          _stop(context, Alvy.orange, '${p['seller'] ?? 'Seller'}', '${p['pickup_address'] ?? ''}'),
                          _stop(context, Alvy.slate, '${p['receiver'] ?? 'Receiver'}${p['receiver_phone'] != null ? ' · ${p['receiver_phone']}' : ''}',
                              '${p['dropoff_address'] ?? ''}'),
                        ]),
                      ),
                    ]),
                  ),
                  SectionCard(
                    title: 'Details',
                    child: Column(children: [
                      row('Order', p['order_number']),
                      row('Payment', p['payment']),
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
                      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: NetImage('${p['exception_photo_url']}', height: 200, fit: BoxFit.cover)),
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
                            trailing: Pill('${x['status_label']}', color: parcelColor('${x['status']}')),
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
                            trailing: Pill('${x['status_label']}', color: parcelColor('${x['status']}')),
                          ),
                      ]),
                    ),
                  if (p['can_mark_exception'] == true)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        backgroundColor: c.subtle,
                        side: BorderSide.none,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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

Widget _stop(BuildContext context, Color dot, String title, String address) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 5, right: 10), decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: context.bc.text)),
            if (address.isNotEmpty) Text(address, style: TextStyle(fontSize: 12.5, color: context.bc.textSecondary)),
          ]),
        ),
      ]),
    );

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
            Text('Lost or damaged parcel', style: Alvy.display(size: 19, color: context.bc.text, weight: FontWeight.w800)),
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
