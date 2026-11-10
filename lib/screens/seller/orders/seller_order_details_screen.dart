import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../services/api_client.dart';
import '../../../services/seller_api.dart';
import '../../../theme/app_theme.dart';
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardBox(context, color: Alvy.slateSoft),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('GCash payment', style: TextStyle(fontWeight: FontWeight.w800, color: Alvy.slate)),
            const Spacer(),
            Pill(checking ? 'For verification' : '${asMap(_o?['payment'])['status'] ?? ''}', color: checking ? const Color(0xFFB45309) : Alvy.successText),
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
                style: TextStyle(fontSize: 12, color: Alvy.warnText)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Order Details'),
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

    final items = asList(o['order_items']);
    final note = (ship['note'] ?? '').toString();

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      // The design's orange header: the step, the order number, the buyer and when it was placed.
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Alvy.orange, Alvy.orangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: Alvy.buttonShadow,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.circle, size: 7, color: Colors.white),
                const SizedBox(width: 6),
                Text(stepLabel(o['seller_step'], o['status']).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
              ]),
            ),
            const Spacer(),
            Text(formatDateTime(o['created_at']), style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Text(_initials('${ship['name'] ?? o['buyer'] ?? ''}'),
                  style: Alvy.display(size: 15, color: Alvy.orange, weight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${ship['name'] ?? o['buyer'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Alvy.display(size: 18, color: Colors.white, weight: FontWeight.w700)),
                Text('${o['payment'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ]),
            ),
            IconButton(
              tooltip: 'Message buyer',
              style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2)),
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(type: 'order', id: '$_id'))),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Text('Order Reference', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${o['number']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            ]),
          ),
          if (f['collect_cod'] != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.payments_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Rider collects ${peso(f['collect_cod'])} (COD)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        ]),
      ),
      if ((o['cancellation_reason'] ?? '').toString().isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Alvy.dangerSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('${o['cancellation_reason']}', style: TextStyle(color: Alvy.dangerText))),
          ]),
        ),
      // GCash paid outside ALVY: the receipt the buyer sent. Accepting the order confirms the money arrived.
      if (o['gcash'] != null) _gcashCard(asMap(o['gcash'])),
      // Ship to: the design's destination card, with the buyer's note in a beige box.
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.local_shipping_outlined, color: Alvy.orange, size: 18),
            const SizedBox(width: 6),
            const Expanded(child: Text('Ship to', style: TextStyle(color: Alvy.orange, fontWeight: FontWeight.w700, fontSize: 13))),
            if (o['payment'] != null) _chip('${o['payment']}'),
          ]),
          const SizedBox(height: 10),
          Text('${ship['name'] ?? ''}', style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${ship['address'] ?? ''}', style: TextStyle(color: c.textSecondary, height: 1.4)),
          if ((ship['phone'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${ship['phone']}', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600)),
            ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.sticky_note_2_outlined, color: Alvy.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Customer Request Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.text)),
                    const SizedBox(height: 2),
                    Text('"$note"', style: TextStyle(fontStyle: FontStyle.italic, color: c.textSecondary)),
                  ]),
                ),
              ]),
            ),
          ],
        ]),
      ),
      SectionCard(
        title: 'Order Items (${items.length})',
        trailing: _chip('${items.fold<int>(0, (n, it) => n + asInt(it['quantity']))} pcs'),
        child: Column(children: [
          for (final it in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10), child: ProductThumb(url: it['image_url'], size: 56)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${it['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
                    Text('${it['variation'] != null ? '${it['variation']} · ' : ''}Qty: ${it['quantity']}',
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    if (it['refunded'] != null) Text('Refunded ${peso(it['refunded'])}', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                  ]),
                ),
                const SizedBox(width: 8),
                Text(peso(asNum(it['price']) * asInt(it['quantity'])), style: Alvy.display(size: 14.5, color: Alvy.orange, weight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
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
            // Like the website: the rider's proof-of-delivery photo once the parcel is delivered.
            if (parcel?['status'] == 'delivered' || delivery?['status'] == 'delivered') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showDocument(context, SellerApi.proofOfDelivery(_id), 'Proof of delivery'),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('View proof of delivery'),
              ),
            ],
          ]),
        ),
      if (ret != null) _returnCard(ret),
      // The design's "Escrow Summary": what the buyer paid, what comes off, and the big payout box.
      SectionCard(
        title: 'Earnings Summary',
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 14, color: Alvy.slate),
          const SizedBox(width: 4),
          Text('Protected', style: TextStyle(fontSize: 12, color: Alvy.slate, fontWeight: FontWeight.w700)),
        ]),
        child: Column(children: [
          money('Order subtotal (items)', f['gross']),
          if (asNum(f['promo']) > 0) money('Promotions', f['promo'], minus: true),
          if (asNum(f['store_voucher']) > 0) money('Store voucher${f['store_voucher_code'] != null ? ' (${f['store_voucher_code']})' : ''}', f['store_voucher'], minus: true),
          money('Buyer paid total', o['total'], bold: true),
          money('ALVY commission', f['commission'], minus: true),
          if (asNum(f['alvy_voucher']) > 0 || asNum(f['shipping_fee']) > 0)
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Shipping ${peso(f['shipping_fee'])}'
                '${asNum(f['alvy_voucher']) > 0 ? ' · ALVY voucher −${peso(f['alvy_voucher'])} (ALVY pays this)' : ''}',
                style: TextStyle(fontSize: 11, color: c.muted),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('You earn', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                  Text('Paid to you after delivery', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ]),
              ),
              Text(peso(f['earnings']), style: Alvy.display(size: 24, color: Alvy.orange, weight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
      if (asList(o['timeline']).isNotEmpty)
        SectionCard(
          title: 'Timeline',
          child: Column(children: [
            for (final (i, e) in asList(o['timeline']).indexed)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(i == 0 ? Icons.radio_button_checked : Icons.circle, size: i == 0 ? 14 : 10, color: i == 0 ? Alvy.orange : c.muted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${e['status']}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                      if ((e['note'] ?? '').toString().isNotEmpty) Text('${e['note']}', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                      Text(formatDateTime(e['at']), style: TextStyle(color: c.muted, fontSize: 11.5)),
                    ]),
                  ),
                ),
              ]),
          ]),
        ),
      _actions(a, centers, reasons),
    ]);
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Alvy.slateSoft, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(fontSize: 11.5, color: Alvy.slate, fontWeight: FontWeight.w700)),
      );

  /// The design's stacked buttons at the end: the next step in orange, the label in navy, then message / cancel side by side.
  Widget _actions(Map<String, dynamic> a, List<Map<String, dynamic>> centers, List<String> reasons) {
    final c = context.bc;
    final steps = <Widget>[
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
        BusyButton('Decide on the return', busy: _busy, icon: Icons.assignment_return_outlined, color: Alvy.navyFill, onPressed: _decideReturn),
      if (a['returned_received'] == true)
        BusyButton(a['returned_label'] != null ? 'Received the returned parcel (${a['returned_label']})' : 'Received the returned parcel',
            busy: _busy, icon: Icons.move_to_inbox_outlined, onPressed: () async {
          if (await confirmAction(context, 'Parcel received?', 'Confirm the returned parcel is back with you.')) _do(() => SellerApi.returnedReceived(_id));
        }),
      if (a['waybill'] == true)
        FilledButton.icon(
          onPressed: _waybill,
          style: FilledButton.styleFrom(backgroundColor: Alvy.navyFill, minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Print waybill', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
    ];
    final soft = OutlinedButton.styleFrom(
      backgroundColor: c.subtle,
      side: BorderSide.none,
      minimumSize: const Size.fromHeight(46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final b in steps) Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: soft,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(type: 'order', id: '$_id'))),
              icon: Icon(Icons.chat_outlined, size: 18, color: c.text),
              label: Text('Message', style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
            ),
          ),
          if (a['cancel'] == true) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: soft,
                onPressed: _busy ? null : () => _cancel(reasons),
                icon: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFDC2626)),
                label: const Text('Cancel order', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
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
