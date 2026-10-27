import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/api_client.dart';
import '../../../services/buyer_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/buyer_kit.dart';
import '../../../widgets/net_image.dart';
import '../../../widgets/shipment_tracking.dart';
import '../../logistics/rider_admin_screens.dart' show showDocument;
import '../chat_screen.dart';
import '../product_detail_screen.dart';

/// The website's order page (profile/order-show): items with ratings, the delivery OTP or proof of
/// delivery, the timeline, return / refund, payment, address, and the buttons the web shows.
class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? o;
  bool loading = true;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.order(widget.orderId);
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : (r.status == 404 ? 'Order not found.' : r.message);
      if (r.ok) o = Map<String, dynamic>.from(r.body['order']);
    });
  }

  /// Runs an order action and shows the web's answer; the page then shows the order as it is now.
  Future<bool> _act(Future<ApiResponse> Function() call) async {
    setState(() => busy = true);
    final r = await call();
    if (!mounted) return false;
    setState(() {
      busy = false;
      if (r.ok && r.body['order'] != null) o = Map<String, dynamic>.from(r.body['order']);
    });
    showResult(context, r);
    if (r.ok && r.body['order'] == null) _load();
    return r.ok;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(
        title: Text(o != null ? 'Order ${o!['number']}' : 'Order'),
      ),
      body: LoadState(
        loading: loading,
        error: error,
        onRetry: _load,
        child: o == null ? const SizedBox() : RefreshIndicator(color: kOrange, onRefresh: _load, child: _body()),
      ),
    );
  }

  /// The website's "Out for delivery" card: who is bringing it, the delivery code with its rules, and the cash to prepare.
  Widget _outForDelivery(Map<String, dynamic> d) {
    final c = context.bc;
    final cod = asNum(d['cod_amount']);
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(backgroundColor: kOrange, child: Icon(Icons.local_shipping_outlined, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Out for delivery', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
              Text.rich(TextSpan(style: TextStyle(fontSize: 13, color: c.textSecondary), children: [
                TextSpan(text: '${d['rider'] ?? 'Your rider'}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                const TextSpan(text: ' is bringing your parcel'),
                if (d['vehicle'] != null) TextSpan(text: ' · ${d['vehicle']}', style: TextStyle(color: c.muted)),
              ])),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(20)),
            child: const Text('On the way', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFC2410C))),
          ),
        ]),
        const SizedBox(height: 12),
        Text('Your delivery code', style: TextStyle(fontSize: 12, color: c.muted)),
        const SizedBox(height: 4),
        Row(children: [
          for (final digit in '${d['otp'] ?? ''}'.split(''))
            Container(
              width: 40,
              height: 50,
              margin: const EdgeInsets.only(right: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFFFF7F3), border: Border.all(color: const Color(0xFFFBD5C5), width: 2), borderRadius: BorderRadius.circular(10)),
              child: Text(digit, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kOrange)),
            ),
        ]),
        const SizedBox(height: 10),
        for (final tip in const [
          'Give it to the rider only when the parcel is in your hands.',
          'The rider enters it to confirm the delivery.',
          'ALVY and riders never ask for it by call, text or chat.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check, size: 16, color: Color(0xFF059669)),
              const SizedBox(width: 6),
              Expanded(child: Text(tip, style: TextStyle(fontSize: 13, color: c.textSecondary))),
            ]),
          ),
        if (cod > 0)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFFBEB), border: Border.all(color: const Color(0xFFFDE68A)), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Expanded(child: Text('Cash on delivery · please prepare the exact amount', style: TextStyle(fontSize: 13, color: Color(0xFF92400E)))),
              Text(peso(cod), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
            ]),
          ),
      ]),
    );
  }

  /// The website's "Delivered" card: when, by whom (and their hub), the cash paid, the proof photo and the next step.
  Widget _delivered(Map<String, dynamic> d, Map<String, dynamic> a) {
    final c = context.bc;
    final at = DateTime.tryParse('${d['delivered_at'] ?? ''}')?.toLocal();
    Widget fact(String label, String value, [String? sub]) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: c.muted)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
            if (sub != null) Text(sub, style: TextStyle(fontSize: 12, color: c.muted)),
          ]),
        );
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(backgroundColor: Color(0xFF059669), child: Icon(Icons.check, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delivered', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
              Text('Your parcel was handed over ${formatDateTime(d['delivered_at'])}.', style: TextStyle(fontSize: 12.5, color: c.muted)),
            ]),
          ),
          if (o!['status'] == 'Completed')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(20)),
              child: const Text('Order completed', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
            ),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: fact('Delivered on', at != null ? formatDate(d['delivered_at']) : '—', at != null ? TimeOfDay.fromDateTime(at).format(context) : null)),
          const SizedBox(width: 8),
          Expanded(child: fact('Delivered by', '${d['rider'] ?? 'ALVY rider'}', '${d['rider_hub'] ?? 'ALVY logistics'}')),
        ]),
        if (asNum(d['cod_collected']) > 0) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: fact('Cash paid to the rider', peso(d['cod_collected']))),
        ],
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => showDocument(context, BuyerApi.proofOfDelivery(widget.orderId), 'Proof of delivery'),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: NetImage(d['proof_url'], height: 160, width: double.infinity, fit: BoxFit.cover)),
        ),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Proof of delivery · taken by the rider', style: TextStyle(fontSize: 11.5, color: c.muted))),
        if (a['confirm_received'] == true)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF7F3), border: Border.all(color: const Color(0xFFFBD5C5)), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Got everything in good condition?', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
              const SizedBox(height: 2),
              Text.rich(TextSpan(style: TextStyle(fontSize: 12, color: c.textSecondary), children: [
                const TextSpan(text: 'Tap '),
                const TextSpan(text: 'Order Received', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(
                    text: ' to complete the order.${a['completes_on'] != null ? ' Something wrong? You can request a return until ${formatDate(a['completes_on'])}.' : ''}'),
              ])),
            ]),
          )
        else if (a['rate_prompt'] == true)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text.rich(TextSpan(style: TextStyle(fontSize: 12, color: c.muted), children: const [
              TextSpan(text: 'Enjoying it? '),
              TextSpan(text: 'Rate your items', style: TextStyle(fontWeight: FontWeight.w700, color: kOrange)),
              TextSpan(text: ' to help other buyers.'),
            ])),
          ),
      ]),
    );
  }

  Widget _body() {
    final a = Map<String, dynamic>.from(o!['actions']);
    final pay = Map<String, dynamic>.from(o!['payment']);
    final delivery = o!['delivery'];
    final ret = o!['return'];

    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Expanded(child: Text('${o!['store']} · placed ${formatDateTime(o!['created_at'])}', style: TextStyle(color: context.bc.muted, fontSize: 12.5))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFFFF1EE), borderRadius: BorderRadius.circular(20)),
          child: Text(o!['status_label'], style: const TextStyle(color: kOrange, fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 10),

      if (o!['status'] == 'Awaiting Payment') _toPay(a, pay),

      SectionCard(
        title: 'Items',
        child: Column(children: [for (final i in o!['order_items']) _item(Map<String, dynamic>.from(i))]),
      ),

      if (delivery != null && delivery['status'] == 'out_for_delivery')
        _outForDelivery(Map<String, dynamic>.from(delivery))
      else if (delivery != null && delivery['proof_url'] != null)
        _delivered(Map<String, dynamic>.from(delivery), a),

      if (o!['tracking'] != null) ShipmentTrackingCard(Map<String, dynamic>.from(o!['tracking'])),

      SectionCard(
        title: 'Order timeline',
        child: Column(children: [
          for (var i = 0; i < (o!['timeline'] as List).length; i++)
            Builder(builder: (_) {
              final e = o!['timeline'][i];
              final lastOne = i == (o!['timeline'] as List).length - 1;
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 10),
                  child: Icon(Icons.circle, size: 10, color: lastOne ? kOrange : const Color(0xFFE6EDF2)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e['label'], style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${formatDateTime(e['at'])}${e['note'] != null ? ' — ${e['note']}' : ''}', style: TextStyle(fontSize: 12, color: context.bc.muted)),
                    ]),
                  ),
                ),
              ]);
            }),
        ]),
      ),

      if (ret != null)
        SectionCard(
          title: 'Return / refund',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${ret['status_label']} · ${ret['reason']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (ret['seller_note'] != null) Text('Seller: ${ret['seller_note']}'),
            if ((ret['photos'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 6, children: [
                  for (final ph in ret['photos']) ClipRRect(borderRadius: BorderRadius.circular(6), child: NetImage(ph, width: 72, height: 72, fit: BoxFit.cover)),
                ]),
              ),
            if (a['escalate'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  onPressed: busy ? null : _escalate,
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB91C1C)),
                  child: const Text('Escalate to ALVY'),
                ),
              ),
          ]),
        ),

      if (a['return'] == true)
        SectionCard(
          title: 'Return / refund',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Until ${formatDateTime(a['return_deadline'])}', style: TextStyle(color: context.bc.muted, fontSize: 12)),
            const SizedBox(height: 6),
            OutlinedButton(onPressed: busy ? null : _requestReturn, child: const Text('Request a return / refund')),
          ]),
        ),

      SectionCard(
        title: 'Payment',
        child: Column(children: [
          _row('Merchandise', peso(pay['merchandise'])),
          _row('Shipping${pay['shipping_weight_kg'] != null ? ' (${pay['shipping_weight_kg']} kg)' : ''}', peso(pay['shipping'])),
          if (asNum(pay['promo_discount']) > 0) _row('Bundle deals & promos', '−${peso(pay['promo_discount'])}', green: true),
          if (asNum(pay['store_voucher']) > 0) _row('Store voucher', '−${peso(pay['store_voucher'])}', green: true),
          if (asNum(pay['alvy_voucher']) > 0) _row('ALVY voucher ${pay['alvy_voucher_code'] ?? ''}', '−${peso(pay['alvy_voucher'])}', green: true),
          if (asNum(pay['shipping_voucher']) > 0) _row('Shipping voucher ${pay['shipping_voucher_code'] ?? ''}', '−${peso(pay['shipping_voucher'])}', green: true),
          const Divider(),
          _row('Total', peso(pay['total']), bold: true),
          _row('Method', '${pay['method']} · ${pay['status']}'),
          // GCash paid by receipt: the screenshot sent at checkout (and its reference number).
          if (o!['payment_proof'] != null) ...[
            if (o!['payment_proof']['reference'] != null) _row('GCash ref. no.', '${o!['payment_proof']['reference']}'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showDocument(context, BuyerApi.paymentProof(widget.orderId), 'GCash receipt'),
                icon: const Icon(Icons.receipt_long, color: kOrange),
                label: const Text('View the GCash receipt you sent', style: TextStyle(color: kOrange)),
              ),
            ),
          ],
          if (asNum(pay['refunded']) > 0) _row('Refunded', peso(pay['refunded']), green: true),
        ]),
      ),

      SectionCard(
        title: 'Deliver to',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o!['deliver_to']['name']} · ${o!['deliver_to']['phone']}'),
          Text(o!['deliver_to']['address'] ?? '', style: TextStyle(color: context.bc.muted)),
          if (o!['deliver_to']['note'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Your note: ${o!['deliver_to']['note']}', style: const TextStyle(fontSize: 12))),
        ]),
      ),

      if (a['confirm_received'] == true) ...[
        ElevatedButton(
          onPressed: busy ? null : _received,
          style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46)),
          child: const Text('Order Received'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Text('Completes by itself on ${formatDate(a['completes_on'])}.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.bc.muted)),
        ),
      ],
      if (a['cancel'] == true)
        OutlinedButton(
          onPressed: busy ? null : () => _cancel(List<String>.from(a['cancel_reasons'])),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB91C1C), side: const BorderSide(color: Color(0xFFFCA5A5)), minimumSize: const Size.fromHeight(44)),
          child: const Text('Cancel order'),
        )
      else if (a['cancel_blocked_note'] != null)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(8)),
          child: Text(a['cancel_blocked_note'], style: const TextStyle(fontSize: 12)),
        ),
      if (a['message_seller'] == true)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(onPressed: _messageSeller, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)), child: const Text('Message the seller')),
        ),
    ]);
  }

  Widget _toPay(Map a, Map pay) {
    final failed = pay['status'] == 'Failed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: failed ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: failed ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(failed ? 'Payment failed' : 'Waiting for your payment (${pay['method']})', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              failed
                  ? 'Nothing was charged. You can pay again${pay['pay_by'] != null ? ' until ${formatDateTime(pay['pay_by'])}' : ''}.'
                  : 'Pay ${pay['pay_by'] != null ? 'by ${formatDateTime(pay['pay_by'])}' : 'soon'}, or the order is cancelled automatically.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ]),
        ),
        if (a['pay'] == true)
          ElevatedButton(
            onPressed: busy ? null : _pay,
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white),
            child: Text(a['pay_label']),
          ),
      ]),
    );
  }

  Widget _item(Map<String, dynamic> i) {
    final review = i['review'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: i['slug'] == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: i['slug']))),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(width: 56, height: 56, child: i['image_url'] != null ? NetImage(i['image_url'], fit: BoxFit.cover) : const Icon(Icons.image)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i['title'], maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('${i['variation'] != null ? '${i['variation']} · ' : ''}${peso(i['price'])} × ${i['quantity']}', style: TextStyle(fontSize: 12, color: context.bc.muted)),
                if (i['refunded'] != null) Text('Refunded ${peso(i['refunded'])}', style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
              ]),
            ),
            Text(peso(i['total']), style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        if (review != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Stars(asNum(review['rating'])),
                Text('  · your review${review['edited'] == true ? ' (edited)' : ''}', style: TextStyle(fontSize: 12, color: context.bc.muted)),
              ]),
              if ((review['comment'] ?? '').toString().isNotEmpty) Text(review['comment']),
              if ((review['photos'] as List).isNotEmpty)
                Wrap(spacing: 6, children: [for (final ph in review['photos']) NetImage(ph, width: 56, height: 56, fit: BoxFit.cover)]),
              if (review['can_edit'] == true)
                TextButton(onPressed: () => _reviewForm(i, review: Map<String, dynamic>.from(review)), child: const Text('Edit review (one time only)')),
            ]),
          )
        else if (i['can_review'] == true)
          TextButton.icon(onPressed: () => _reviewForm(i), icon: const Icon(Icons.star_border, color: kOrange), label: const Text('Rate this item')),
      ]),
    );
  }

  Widget _row(String label, String value, {bool green = false, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: green ? const Color(0xFF059669) : context.bc.textSecondary))),
          Text(value, style: TextStyle(color: bold ? kOrange : (green ? const Color(0xFF059669) : null), fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        ]),
      );

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _pay() async {
    setState(() => busy = true);
    final r = await BuyerApi.pay(widget.orderId);
    if (!mounted) return;
    setState(() => busy = false);
    if (r.ok && r.body['payment_url'] != null) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment page'),
          content: SelectableText(r.body['payment_url']),
          actions: [
            TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: r.body['payment_url'])), child: const Text('Copy link')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      _load();
    } else {
      showResult(context, r);
    }
  }

  Future<void> _cancel(List<String> reasons) async {
    String? reason;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Cancel order'),
          content: DropdownButtonFormField<String>(
            initialValue: reason,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Choose a reason'),
            items: [for (final r in reasons) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => set(() => reason = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel order', style: TextStyle(color: Color(0xFFB91C1C)))),
          ],
        ),
      ),
    );
    if (ok == true) await _act(() => BuyerApi.cancel(widget.orderId, reason ?? ''));
  }

  Future<void> _received() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('Confirm you received this order? It will be marked completed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Order Received')),
        ],
      ),
    );
    if (ok == true) await _act(() => BuyerApi.received(widget.orderId));
  }

  Future<void> _escalate() async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escalate to ALVY'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Don't agree with the seller? Ask ALVY to review it."),
          TextField(controller: note, maxLength: 500, decoration: const InputDecoration(hintText: 'Why you disagree (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Escalate', style: TextStyle(color: Color(0xFFB91C1C)))),
        ],
      ),
    );
    if (ok == true) await _act(() => BuyerApi.escalate(widget.orderId, note.text.trim()));
  }

  Future<void> _requestReturn() async {
    final a = o!['actions'];
    final items = List<Map>.from(o!['order_items']);
    final picked = <int>{...items.map((i) => i['id'] as int)};
    final details = TextEditingController();
    String? reason;
    List<XFile> photos = [];

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              const Text('Return / refund', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              DropdownButtonFormField<String>(
                initialValue: reason,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: [for (final r in a['return_reasons']) DropdownMenuItem(value: '$r', child: Text('$r'))],
                onChanged: (v) => set(() => reason = v),
              ),
              const SizedBox(height: 8),
              const Text('Items to return', style: TextStyle(fontWeight: FontWeight.w600)),
              for (final i in items)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: picked.contains(i['id']),
                  onChanged: (v) => set(() => v == true ? picked.add(i['id']) : picked.remove(i['id'])),
                  title: Text('${i['title']}${i['variation'] != null ? ' (${i['variation']})' : ''} × ${i['quantity']}'),
                ),
              const Text("Untick items you are keeping. Each item's refund is its price minus its share of the vouchers.", style: TextStyle(fontSize: 12)),
              TextField(
                controller: details,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Describe the problem — 10 to 500 characters'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final files = await ImagePicker().pickMultiImage(limit: 5);
                  set(() => photos = files.take(5).toList());
                },
                icon: const Icon(Icons.add_a_photo),
                label: Text(photos.isEmpty ? 'Add 1 to 5 photos (JPG or PNG, up to 5 MB each)' : '${photos.length} photo(s) chosen'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46)),
                child: const Text('Submit request'),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final fields = <String, String>{
      'reason': reason ?? '',
      'details': details.text.trim(),
      for (final (n, id) in picked.indexed) 'items[$n]': '$id',
    };
    await _act(() => BuyerApi.requestReturn(widget.orderId, fields, photos.map((p) => p.path).toList()));
  }

  Future<void> _reviewForm(Map<String, dynamic> item, {Map<String, dynamic>? review}) async {
    int rating = review != null ? asNum(review['rating']).toInt() : 0;
    final comment = TextEditingController(text: review?['comment'] ?? '');
    List<XFile> photos = [];

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(review == null ? 'Rate this item' : 'Edit your review (one time only)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(item['title'], style: const TextStyle(fontSize: 12)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var s = 1; s <= 5; s++)
                IconButton(
                  onPressed: () => set(() => rating = s),
                  icon: Icon(s <= rating ? Icons.star : Icons.star_border, color: const Color(0xFFF59E0B), size: 34),
                ),
            ]),
            TextField(controller: comment, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'Your review (optional)')),
            OutlinedButton.icon(
              onPressed: () async {
                final files = await ImagePicker().pickMultiImage(limit: 5);
                set(() => photos = files.take(5).toList());
              },
              icon: const Icon(Icons.add_a_photo),
              label: Text(photos.isEmpty ? 'Add up to 5 photos (optional)' : '${photos.length} photo(s) chosen'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(46)),
              child: Text(review == null ? 'Submit review' : 'Save changes'),
            ),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    final fields = {'rating': rating == 0 ? '' : '$rating', 'comment': comment.text.trim()};
    final paths = photos.map((p) => p.path).toList();
    await _act(() => review == null ? BuyerApi.review(item['id'], fields, paths) : BuyerApi.editReview(review['id'], fields, paths));
  }

  Future<void> _messageSeller() async {
    final r = await BuyerApi.startChat(o!['seller_id']);
    if (!mounted) return;
    if (!r.ok) return showResult(context, r);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(type: r.body['type'], id: r.body['id'], title: o!['store'])));
  }
}
