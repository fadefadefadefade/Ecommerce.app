import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../services/api_client.dart';
import '../../../services/seller_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/product_thumb.dart';
import '../../../widgets/reason_dialog.dart';
import '../../../widgets/shipment_tracking.dart';
import '../../logistics/rider_admin_screens.dart' show showDocument;
import '../../buyer/chat_screen.dart';
import '../seller_kit.dart';
import 'seller_orders_screen.dart';
import 'waybill_pdf.dart';

/// The web's seller order page (seller.orders.show): earnings breakdown, ship-to, and the step actions
/// (Accept → Pack → Book pickup → Handed over), cancel with a reason, return decisions, waybill.
class SellerOrderDetailsScreen extends StatefulWidget {
  final int orderId;
  const SellerOrderDetailsScreen({super.key, required this.orderId});

  @override
  State<SellerOrderDetailsScreen> createState() => _SellerOrderDetailsScreenState();
}

class _SellerOrderDetailsScreenState extends State<SellerOrderDetailsScreen> {
  Map<String, dynamic>? _o;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  int get _id => widget.orderId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _o == null;
      _error = null;
    });
    final r = await SellerApi.order(_id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _o = asMap(r.body['order']);
      } else {
        _error = r.message;
      }
    });
  }

  /// Runs an order action; the answer has the order as it is now.
  Future<bool> _do(Future<ApiResponse> Function() call) async {
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return false;
    setState(() {
      _busy = false;
      if (r.ok && r.body['order'] != null) _o = asMap(r.body['order']);
    });
    showResult(context, r);
    if ((r.ok && r.body['order'] == null) || r.broken) _load();
    return r.ok;
  }

  Future<void> _cancel(List<String> reasons) async {
    String? reason;
    final details = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('The buyer is told why, and any payment is refunded.'),
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (v) => set(() => reason = v),
                child: Column(children: [
                  for (final r in reasons) RadioListTile<String>(value: r, title: Text(r), dense: true, contentPadding: EdgeInsets.zero),
                ]),
              ),
              TextField(controller: details, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Message to the buyer (optional)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel order'),
            ),
          ],
        ),
      ),
    );
    final text = details.text.trim();
    details.dispose();
    if (ok == true) await _do(() => SellerApi.cancel(_id, reason ?? '', text));
  }

  Future<void> _bookPickup(List<Map<String, dynamic>> centers) async {
    final body = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickupSheet(centers: centers),
    );
    if (body != null) await _do(() => SellerApi.handover(_id, body));
  }

  Future<void> _decideReturn() async {
    final approve = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return request'),
        content: const Text('Approve the return and refund the buyer, or reject it with a reason.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626)))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (approve == null || !mounted) return;
    if (approve) {
      await _do(() => SellerApi.decideReturn(_id, 'approve', ''));
      return;
    }
    final note = await showReasonDialog(context,
        title: 'Reject the return', message: 'Tell the buyer why (10 to 300 characters).', hint: 'Reason', confirmLabel: 'Reject', maxLength: 300);
    if (note != null) await _do(() => SellerApi.decideReturn(_id, 'reject', note));
  }

  Future<void> _waybill() async {
    final r = await SellerApi.waybill(_id);
    if (!mounted) return;
    if (!r.ok) return showResult(context, r);
    final w = asMap(r.body['waybill']);
    Navigator.push(context, MaterialPageRoute(builder: (_) => WaybillScreen(waybill: w)));
  }

  Widget _gcashCard(Map<String, dynamic> g) {
    final checking = g['checking'] == true;
    return Card(
      elevation: 0,
      color: const Color(0xFFF5F9FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFDBEAFE))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('GCash payment', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
            const Spacer(),
            Pill(checking ? 'For verification' : '${asMap(_o?['payment'])['status'] ?? ''}', color: checking ? const Color(0xFFB45309) : const Color(0xFF047857)),
          ]),
          const SizedBox(height: 6),
          Text('Amount to receive: ${peso(g['amount'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('Ref No.: ${g['reference'] ?? 'not given'}', style: const TextStyle(fontFamily: 'monospace')),
          if (g['has_receipt'] == true)
            TextButton.icon(
              onPressed: () => showDocument(context, SellerApi.paymentProof(_id), 'GCash receipt'),
              icon: const Icon(Icons.receipt_long, color: Color(0xFF007DFE)),
              label: const Text('Open the receipt', style: TextStyle(color: Color(0xFF007DFE))),
            )
          else
            const Text('No receipt was uploaded.', style: TextStyle(fontSize: 12)),
          if (checking)
            Text('Open your GCash app and check that ${peso(g['amount'])} arrived before you accept the order.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar(_o == null ? 'Order' : '${_o!['number']}', actions: [
        if (_o != null)
          IconButton(
            tooltip: 'Message buyer',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(type: 'order', id: '$_id'))),
          ),
      ]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: _o == null ? const SizedBox() : RefreshIndicator(color: kOrange, onRefresh: _load, child: _body(_o!)),
      ),
    );
  }

  Widget _body(Map<String, dynamic> o) {
    final c = context.bc;
    final f = asMap(o['figures']);
    final a = asMap(o['actions']);
    final ship = asMap(o['ship_to']);
    final ret = o['return'] == null ? null : asMap(o['return']);
    final parcel = o['parcel'] == null ? null : asMap(o['parcel']);
    final delivery = o['delivery'] == null ? null : asMap(o['delivery']);
    final centers = asList(o['sorting_centers']);
    final reasons = [for (final r in (a['cancel_reasons'] as List? ?? [])) '$r'];

    Widget money(String label, dynamic v, {bool minus = false, bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: c.textSecondary, fontWeight: bold ? FontWeight.w700 : null))),
            Text('${minus ? '− ' : ''}${peso(v)}', style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? c.text)),
          ]),
        );

    return ListView(padding: const EdgeInsets.all(12), children: [
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Placed ${formatDateTime(o['created_at'])}', style: TextStyle(color: c.muted, fontSize: 12))),
            Pill(stepLabel(o['seller_step'], o['status']), color: Pill.forState(o['status'])),
          ]),
          const SizedBox(height: 6),
          Text('${o['payment'] ?? ''}', style: TextStyle(color: c.textSecondary)),
          if (f['collect_cod'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Rider collects ${peso(f['collect_cod'])} (COD)', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
            ),
          if ((o['cancellation_reason'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${o['cancellation_reason']}', style: const TextStyle(color: Color(0xFFDC2626))),
            ),
        ]),
      ),
      _actions(a, centers, reasons),
      // GCash paid outside ALVY: the receipt the buyer sent. Accepting the order confirms the money arrived.
      if (o['gcash'] != null) _gcashCard(asMap(o['gcash'])),
      if (o['tracking'] != null && parcel != null) ShipmentTrackingCard(asMap(o['tracking'])),
      if (parcel != null || delivery != null)
        SectionCard(
          title: 'Shipment',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (parcel != null) ...[
              Text('${parcel['tracking_number'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (o['waybill_number'] != null) Text('Waybill ${o['waybill_number']}', style: TextStyle(fontSize: 12, color: context.bc.muted)),
              Text('${parcel['status_label'] ?? parcel['status']}${parcel['sorting_center'] != null ? ' · ${parcel['sorting_center']}' : ''}'),
              if (parcel['failure_reason'] != null) Text('${parcel['failure_reason']}', style: const TextStyle(color: Color(0xFFDC2626))),
            ] else if (delivery != null) ...[
              Text('${delivery['tracking_number'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('Courier: ${delivery['status']}'),
              if (delivery['pickup_scheduled_at'] != null) Text('Pickup ${formatDateTime(delivery['pickup_scheduled_at'])}'),
            ],
          ]),
        ),
      if (ret != null) _returnCard(ret),
      SectionCard(
        title: 'Items',
        child: Column(children: [
          for (final it in asList(o['order_items']))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                ProductThumb(url: it['image_url'], size: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${it['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text)),
                    if (it['variation'] != null) Text('${it['variation']}', style: TextStyle(fontSize: 12, color: c.muted)),
                    if (it['refunded'] != null) Text('Refunded ${peso(it['refunded'])}', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                  ]),
                ),
                Text('${peso(it['price'])} ×${it['quantity']}', style: TextStyle(color: c.textSecondary)),
              ]),
            ),
        ]),
      ),
      SectionCard(
        title: 'Your earnings',
        child: Column(children: [
          money('Items', f['gross']),
          if (asNum(f['promo']) > 0) money('Promotions', f['promo'], minus: true),
          if (asNum(f['store_voucher']) > 0) money('Store voucher${f['store_voucher_code'] != null ? ' (${f['store_voucher_code']})' : ''}', f['store_voucher'], minus: true),
          money('ALVY commission', f['commission'], minus: true),
          const Divider(),
          money('You earn', f['earnings'], bold: true, color: const Color(0xFF15803D)),
          if (asNum(f['alvy_voucher']) > 0 || asNum(f['shipping_fee']) > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Buyer paid ${peso(o['total'])} · shipping ${peso(f['shipping_fee'])}'
              '${asNum(f['alvy_voucher']) > 0 ? ' · ALVY voucher −${peso(f['alvy_voucher'])} (ALVY pays this)' : ''}',
              style: TextStyle(fontSize: 11, color: c.muted),
            ),
          ],
        ]),
      ),
      SectionCard(
        title: 'Ship to',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${ship['name']} · ${ship['phone'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${ship['address'] ?? ''}'),
          if ((ship['note'] ?? '').toString().isNotEmpty) Text('Note: ${ship['note']}', style: TextStyle(color: c.muted)),
        ]),
      ),
      if (asList(o['timeline']).isNotEmpty)
        SectionCard(
          title: 'Timeline',
          child: Column(children: [
            for (final e in asList(o['timeline']))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle, size: 10, color: kOrange),
                title: Text('${e['status']}'),
                subtitle: Text('${e['note'] ?? ''}${(e['note'] ?? '').toString().isNotEmpty ? '\n' : ''}${formatDateTime(e['at'])}'),
              ),
          ]),
        ),
    ]);
  }

  Widget _actions(Map<String, dynamic> a, List<Map<String, dynamic>> centers, List<String> reasons) {
    final buttons = <Widget>[
      if (a['accept'] == true)
        BusyButton('${a['accept_label'] ?? 'Accept order'}', busy: _busy, icon: Icons.check_circle_outline, onPressed: () => _do(() => SellerApi.accept(_id))),
      if (a['pack'] == true)
        BusyButton('Mark as packed', busy: _busy, icon: Icons.inventory_2_outlined, onPressed: () => _do(() => SellerApi.pack(_id))),
      if (a['book_pickup'] == true)
        BusyButton('Book pickup', busy: _busy, icon: Icons.local_shipping_outlined, onPressed: () => _bookPickup(centers)),
      if (a['handed_over'] == true)
        BusyButton('Handed to the courier', busy: _busy, icon: Icons.handshake_outlined, onPressed: () async {
          if (await confirmAction(context, 'Handed over?', 'Confirm the courier picked up the parcel.')) _do(() => SellerApi.handedOver(_id));
        }),
      if (a['decide_return'] == true)
        BusyButton('Decide on the return', busy: _busy, icon: Icons.assignment_return_outlined, color: const Color(0xFF2563EB), onPressed: _decideReturn),
      if (a['returned_received'] == true)
        BusyButton(a['returned_label'] != null ? 'Received the returned parcel (${a['returned_label']})' : 'Received the returned parcel',
            busy: _busy, icon: Icons.move_to_inbox_outlined, onPressed: () async {
          if (await confirmAction(context, 'Parcel received?', 'Confirm the returned parcel is back with you.')) _do(() => SellerApi.returnedReceived(_id));
        }),
      if (a['waybill'] == true)
        OutlinedButton.icon(onPressed: _waybill, icon: const Icon(Icons.print_outlined), label: const Text('Print waybill')),
      if (a['cancel'] == true)
        TextButton.icon(
          onPressed: _busy ? null : () => _cancel(reasons),
          icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
          label: const Text('Cancel order', style: TextStyle(color: Color(0xFFDC2626))),
        ),
    ];
    if (buttons.isEmpty) return const SizedBox();
    return SectionCard(
      title: 'Next step',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 8), child: b),
      ]),
    );
  }

  Widget _returnCard(Map<String, dynamic> r) {
    final c = context.bc;
    return SectionCard(
      title: 'Return / refund',
      trailing: Pill('${r['status']}', color: Pill.forState(r['status'])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${r['reason'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
        if ((r['details'] ?? '').toString().isNotEmpty) Text('${r['details']}'),
        Text('Refund ${peso(r['refund_amount'])}', style: TextStyle(color: c.textSecondary)),
        if (r['answer_by'] != null)
          Text('Answer by ${formatDateTime(r['answer_by'])}, or it is approved automatically.',
              style: const TextStyle(color: Color(0xFFB45309), fontSize: 12)),
        if ((r['seller_note'] ?? '').toString().isNotEmpty) Text('Your note: ${r['seller_note']}', style: TextStyle(color: c.muted)),
        if (r['escalated_at'] != null) Text('Escalated to ALVY: ${r['dispute_note'] ?? ''}', style: const TextStyle(color: Color(0xFFDC2626))),
        if (asList(r['photos']).isNotEmpty || (r['photos'] is List && (r['photos'] as List).isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in (r['photos'] as List)) ProductThumb(url: '$p', size: 64),
            ]),
          ),
      ]),
    );
  }
}

/// Book the pickup: the logistics company, the date and time, and a note for the rider (web: "Ready for Pickup").
class _PickupSheet extends StatefulWidget {
  final List<Map<String, dynamic>> centers;
  const _PickupSheet({required this.centers});

  @override
  State<_PickupSheet> createState() => _PickupSheetState();
}

class _PickupSheetState extends State<_PickupSheet> {
  int? _center;
  String? _when;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final covering = widget.centers.where((s) => s['covers_seller'] == true).toList();
    if (covering.length == 1) _center = asInt(covering.first['id']);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Book pickup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
            const SizedBox(height: 4),
            Text('Choose the logistics company whose rider will pick up the parcel.', style: TextStyle(color: c.muted)),
            const SizedBox(height: 8),
            if (widget.centers.isEmpty) Text('No logistics company is available right now.', style: TextStyle(color: c.muted)),
            RadioGroup<int>(
              groupValue: _center,
              onChanged: (v) => setState(() => _center = v),
              child: Column(children: [
                for (final s in widget.centers)
                  RadioListTile<int>(
                    value: asInt(s['id']),
                    contentPadding: EdgeInsets.zero,
                    title: Text('${s['name']}'),
                    subtitle: Text('${s['municipality'] ?? ''} · ${s['rider_count']} rider(s)${s['covers_seller'] == true ? ' · covers your area' : ''}'),
                  ),
              ]),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_when ?? 'Choose the pickup date and time'),
              onTap: () async {
                final v = await pickDateTime(context, initial: _when);
                if (v != null) setState(() => _when = v);
              },
            ),
            FormInput(_notes, 'Note for the rider (optional)', maxLength: 500, maxLines: 2),
            BusyButton('Book pickup', busy: false, icon: Icons.local_shipping_outlined, onPressed: () {
              Navigator.pop(context, {
                if (_center != null) 'sorting_center_id': _center,
                if (_when != null) 'pickup_scheduled_at': _when,
                'notes': _notes.text.trim(),
              });
            }),
          ]),
        ),
      ),
    );
  }
}

/// The printable waybill (the web's seller.orders.waybill): print it with the phone's print service
/// (a printer, or "Save as PDF"), or share / save the PDF.
class WaybillScreen extends StatefulWidget {
  final Map<String, dynamic> waybill;
  const WaybillScreen({super.key, required this.waybill});

  @override
  State<WaybillScreen> createState() => _WaybillScreenState();
}

class _WaybillScreenState extends State<WaybillScreen> {
  late final Future<Uint8List> _pdf = WaybillPdf.build(widget.waybill);
  bool _busy = false;

  String get _name => 'waybill-${widget.waybill['tracking'] ?? widget.waybill['order_number']}';

  Future<void> _run(Future<void> Function(Uint8List pdf) action) async {
    setState(() => _busy = true);
    try {
      await action(await _pdf);
    } catch (e) {
      if (mounted) showError(context, 'Could not open the printer: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sellerBar('Waybill ${widget.waybill['tracking'] ?? ''}'),
      body: PdfPreview(
        build: (_) => _pdf,
        useActions: false,
        pdfFileName: '$_name.pdf',
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _run((pdf) => Printing.sharePdf(bytes: pdf, filename: '$_name.pdf')),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share / Save PDF'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BusyButton('Print', busy: _busy, icon: Icons.print_outlined,
                  onPressed: () => _run((pdf) => Printing.layoutPdf(onLayout: (_) async => pdf, name: _name).then((_) {}))),
            ),
          ]),
        ),
      ),
    );
  }
}
