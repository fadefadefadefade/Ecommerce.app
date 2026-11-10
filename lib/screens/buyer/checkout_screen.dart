import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../../widgets/voucher_ticket.dart';
import 'account/collections_screens.dart' show VoucherCenterScreen;

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/net_image.dart';
import '../../widgets/gcash_pay_box.dart';
import 'add_address_screen.dart';
import 'order_confirmation_screen.dart';

/// The website's checkout (checkout/index): delivery address, the items per store with a note to the
/// seller, store / ALVY / shipping vouchers (or a typed code), shipping per store, payment method, and
/// the totals the web works out live. Place Order uses the page's one-time token, like the website.
class CheckoutScreen extends StatefulWidget {
  final List<int>? items;
  final bool buyNow;

  const CheckoutScreen({super.key, this.items, this.buyNow = false});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Map<String, dynamic>? page; // what GET /checkout returned
  Map<String, dynamic>? totals; // the latest summary (page or preview)
  bool loading = true;
  String? error;
  bool placing = false;
  int? addressId;
  String payment = 'cod';
  // GCash paid by receipt (the website's "GCash — upload your receipt"): the screenshot and its Ref No.
  String? _receipt;
  final _gcashRef = TextEditingController();
  String? platform;
  String? shipping;
  Map<String, String> sellers = {};
  final _code = TextEditingController();
  final Map<String, TextEditingController> _notes = {};
  Map<String, String> fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _gcashRef.dispose();
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// [quiet]: after a quantity change, the page stays on screen while it reloads.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => loading = true);
    final r = await BuyerApi.checkout(items: widget.items, buyNow: widget.buyNow, addressId: addressId);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (!r.ok) {
        error = r.message;
        return;
      }
      error = null;
      page = r.body;
      totals = r.body;
      addressId = r.body['address_id'];
      final chosen = asMap(r.body['chosen']);
      platform = chosen['platform'];
      shipping = chosen['shipping'];
      sellers = asMap(chosen['sellers']).map((k, v) => MapEntry(k, '$v'));
      for (final s in r.body['stores']) {
        _notes.putIfAbsent('${s['seller_id'] ?? 0}', () => TextEditingController());
      }
    });
  }

  bool _qtyBusy = false;

  /// − / + on an item: the cart line (or the Buy now item) gets the new quantity, then the page and its
  /// totals are worked out again by the web, keeping the vouchers the buyer picked.
  Future<void> _setQty(Map l, int qty) async {
    setState(() => _qtyBusy = true);
    final r = widget.buyNow
        ? await BuyerApi.addToCart(l['product']['id'], quantity: qty, variationId: l['variation']?['id'], buyNow: true)
        : await BuyerApi.updateCart(l['id'], qty);
    if (!mounted) return;
    if (!r.ok) {
      setState(() => _qtyBusy = false);
      return showResult(context, r);
    }
    final picked = (platform, shipping, Map<String, String>.from(sellers));
    await _load(quiet: true);
    if (!mounted) return;
    setState(() => _qtyBusy = false);
    if (page == null) return;
    platform = picked.$1;
    shipping = picked.$2;
    sellers = picked.$3;
    await _preview();
  }

  /// Placing leaves out a typed code that already failed on Apply (it would only fail again).
  Map<String, dynamic> _voucherBody({bool typed = true}) => {
        'address_id': addressId,
        'platform_voucher': platform,
        'shipping_voucher': shipping,
        'seller_vouchers': sellers,
        if (typed && _code.text.trim().isNotEmpty) 'voucher_code': _code.text.trim(),
        if (widget.buyNow) 'buy_now': 1,
      };

  /// The web works out the totals again (address, vouchers).
  Future<void> _preview() async {
    final r = await BuyerApi.preview(_voucherBody());
    if (!mounted) return;
    if (!r.ok) return showResult(context, r);
    setState(() {
      totals = r.body;
      final applied = asMap(r.body['applied']);
      platform = applied['platform'];
      shipping = applied['shipping'];
      sellers = asMap(applied['sellers']).map((k, v) => MapEntry(k, '$v'));
      final errors = asMap(r.body['errors']);
      fieldErrors = errors.map((k, v) => MapEntry(k, '$v'));
      if (errors.isEmpty) _code.clear();
    });
    for (final n in List.from(r.body['notices'] ?? [])) {
      if (mounted) showError(context, '$n');
    }
  }

  Future<void> _place() async {
    if (payment == 'gcash_receipt') {
      final problem = GcashPayBox.problem(_receipt, _gcashRef.text);
      if (problem != null) return showError(context, problem);
    }
    setState(() => placing = true);
    final body = {
      ..._voucherBody(typed: fieldErrors['voucher_code'] == null),
      'payment_method': payment,
      'checkout_token': page!['checkout_token'],
      'prices': page!['prices'],
      'buyer_notes': {for (final e in _notes.entries) if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim()},
      if (payment == 'gcash_receipt') 'payment_reference': _gcashRef.text.trim(),
    };
    final r = payment == 'gcash_receipt' ? await BuyerApi.placeOrderWithReceipt(body, _receipt!) : await BuyerApi.placeOrder(body);
    if (!mounted) return;
    setState(() => placing = false);

    if (!r.ok) {
      showResult(context, r);
      // A price or stock change: the web asks to check the new total.
      if (r.message.startsWith('Prices changed') || r.message.contains('sold out') || r.message.contains('left')) _load();
      return;
    }
    final orders = List.from(r.body['orders'] ?? []);
    if (r.body['payment_url'] != null) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Complete your payment'),
          content: SelectableText('Your order is saved. Open this payment page to pay:\n\n${r.body['payment_url']}'),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: r.body['payment_url'])),
              child: const Text('Copy link'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderConfirmationScreen(orders: orders, message: r.body['message'])));
  }

  Widget _gcashBox(Map<String, dynamic> account) => GcashPayBox(
        account: account,
        // The live preview's amount after a quantity or voucher change; the page's own until then.
        amount: (totals?['gcash_total'] ?? account['amount']) as num?,
        ordersTotal: (totals?['gcash_orders'] ?? account['orders_total']) as num?,
        receipt: _receipt,
        onReceipt: (path) => setState(() => _receipt = path),
        reference: _gcashRef,
        referenceError: fieldErrors['payment_reference'],
        stores: List.from(page?['stores'] ?? const []).length,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar( title: const Text('Checkout')),
      body: LoadState(
        loading: loading && page == null,
        error: page == null ? error : null,
        onRetry: _load,
        child: page == null ? const SizedBox() : _body(),
      ),
      bottomNavigationBar: page == null ? null : _placeBar(),
    );
  }

  Widget _body() {
    final addresses = List<Map>.from(page!['addresses']);
    final address = addresses.where((a) => a['id'] == addressId).firstOrNull;
    final t = totals!;
    // The page lists stores; a voucher preview keys them by seller id ({"96": {...}}).
    final rawStores = t['stores'];
    final storesTotals = rawStores is Map
        ? rawStores.map((k, v) => MapEntry('$k', v))
        : {for (final s in rawStores ?? []) '${s['seller_id'] ?? 0}': s};
    final lines = List<Map>.from(page!['lines']);
    final vouchers = asMap(page!['vouchers']);

    final c = context.bc;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      _steps(),
      // The design's "Shipping Destination": the name with a Default tag, the address in a beige box.
      SectionCard(
        title: 'Shipping Destination',
        trailing: TextButton(onPressed: () => _pickAddress(addresses), child: Text(address == null ? 'Add' : 'Edit')),
        child: address == null
            ? Text('Please add a delivery address.', style: TextStyle(color: c.muted))
            : Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text('${address['full_name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Alvy.display(size: 16.5, color: c.text, weight: FontWeight.w700)),
                    ),
                    if (address['is_default'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Alvy.navyFill, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Default', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(address['full_address'] ?? '', style: TextStyle(color: c.textSecondary, height: 1.4)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.call_outlined, size: 15, color: c.textSecondary),
                    const SizedBox(width: 6),
                    Text('${address['phone']}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  ]),
                ]),
              ),
      ),
      if (t['unserviceable'] != null)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Alvy.dangerSoft, borderRadius: BorderRadius.circular(8)),
          child: Text(t['unserviceable'], style: TextStyle(color: Alvy.dangerText)),
        ),

      for (final s in page!['stores']) _store(Map.from(s), lines, Map.from(storesTotals['${s['seller_id'] ?? 0}'] ?? s), vouchers),

      SectionCard(
        title: 'Vouchers & Credits',
        child: Column(children: [
          _voucherPicker('platform', 'ALVY discount voucher', 'All stores', List.from(vouchers['platform'] ?? []), platform, (v) {
            platform = v;
            _preview();
          }),
          _voucherPicker('shipping', 'Free shipping voucher', 'Any order', List.from(vouchers['shipping'] ?? []), shipping, (v) {
            shipping = v;
            _preview();
          }),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter a voucher code',
                  isDense: true,
                  errorText: fieldErrors['voucher_code'],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _preview, child: const Text('Apply')),
          ]),
        ]),
      ),

      // Payment: one card per way to pay (the design's method cards); the chosen one has an orange edge.
      const SectionTitle('Payment Method', padding: EdgeInsets.fromLTRB(0, 8, 0, 12)),
      _payCard('cod', 'Cash on Delivery', 'Pay the rider when your order arrives.', Icons.payments_outlined),
      if (page!['gcash_account'] != null)
        _payCard('gcash_receipt', 'GCash',
            "Scan ALVY's GCash QR, send the amount shown, then upload the receipt and its Ref No. ALVY checks it, then the seller prepares your order.",
            Icons.qr_code_2_rounded),
      for (final m in page!['payment_methods'])
        if (m['key'] != 'gcash_receipt' && m['key'] != 'cod') _payCard('${m['key']}', '${m['label'] ?? m['key']}', null, Icons.account_balance_wallet_outlined),
      if (payment == 'gcash_receipt' && page!['gcash_account'] != null)
        Padding(padding: const EdgeInsets.only(bottom: 12), child: _gcashBox(asMap(page!['gcash_account']))),


      SectionCard(
        title: 'Order Summary',
        child: Column(children: [
          _row('Merchandise subtotal', peso(t['subtotal'])),
          if (asNum(t['promo_discount']) > 0) _row('Bundle deals & promos', '−${peso(t['promo_discount'])}', green: true),
          _row('Shipping', peso(t['shipping_total'])),
          if (asNum(t['seller_discount']) > 0) _row('Store vouchers', '−${peso(t['seller_discount'])}', green: true),
          if (asNum(t['platform_discount']) > 0) _row('ALVY voucher', '−${peso(t['platform_discount'])}', green: true),
          if (asNum(t['shipping_discount']) > 0) _row('Shipping voucher', '−${peso(t['shipping_discount'])}', green: true),
          Divider(height: 22, color: c.border),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total Amount', style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700)),
                Text('Shipping and vouchers included', style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
              ]),
            ),
            Text(peso(t['total']), style: Alvy.display(size: 24, color: kOrange, weight: FontWeight.w700)),
          ]),
        ]),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.verified_user_outlined, size: 17, color: Alvy.slate),
          const SizedBox(width: 8),
          Flexible(child: Text('ALVY Guarantee · Returns and refunds through ALVY', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.textSecondary))),
        ]),
      ),
    ]);
  }

  /// The design's step header: "✓ 1. Cart —— 2 Payment & Review" with a full bar.
  Widget _steps() {
    final c = context.bc;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: cardBox(context),
      child: Column(children: [
        Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text('1. Cart', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Alvy.slate)),
          Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 10), color: kOrange)),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle),
            child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 6),
          Text('Payment & Review', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: const LinearProgressIndicator(value: 1, minHeight: 5, color: kOrange)),
      ]),
    );
  }

  /// One way to pay: a card with a round check, the name, a line about it and an icon.
  Widget _payCard(String value, String title, String? sub, IconData icon) {
    final c = context.bc;
    final on = payment == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => payment = value),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? kOrange : c.border, width: on ? 1.5 : 1),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? kOrange : c.subtle,
                  border: on ? null : Border.all(color: c.border),
                ),
                child: on ? const Icon(Icons.circle, size: 9, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Alvy.display(size: 16.5, color: c.text, weight: FontWeight.w600)),
                  if (sub != null) ...[
                    const SizedBox(height: 3),
                    Text(sub, style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.35)),
                  ],
                ]),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: Alvy.slate, size: 22),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _store(Map s, List<Map> lines, Map st, Map<String, dynamic> vouchers) {
    final sid = '${s['seller_id'] ?? 0}';
    final storeOptions = asMap(vouchers['sellers'])[sid];
    return SectionCard(
      title: s['name'],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final l in lines.where((l) => '${l['seller_id']}' == sid))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: l['product']?['image_url'] != null ? NetImage(l['product']['image_url'], fit: BoxFit.cover) : const Icon(Icons.image),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l['product']?['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${l['variation'] != null ? '${l['variation']['name']} · ' : ''}${peso(l['unit_price'])}',
                      style: TextStyle(fontSize: 12, color: context.bc.muted)),
                  const SizedBox(height: 4),
                  Builder(builder: (_) {
                    final qty = asNum(l['quantity']).toInt();
                    final stock = asNum(l['stock']).toInt();
                    // − / + or type the amount (large orders).
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: QuantityStepper(
                        value: qty,
                        max: stock < 1 ? qty : stock,
                        height: 34,
                        onChanged: _qtyBusy || placing ? null : (n) => _setQty(l, n),
                      ),
                    );
                  }),
                ]),
              ),
              Text(peso(l['subtotal'])),
            ]),
          ),
        if ((st['promo_labels'] as List? ?? []).isNotEmpty)
          Text((st['promo_labels'] as List).join(' · '), style: const TextStyle(fontSize: 12, color: Color(0xFF059669))),
        if ((storeOptions != null && (storeOptions['vouchers'] as List).isNotEmpty) || sellers[sid] != null)
          _voucherPicker('seller', 'Store voucher', 'Only at ${s['name']}', List.from(storeOptions?['vouchers'] ?? []), sellers[sid], (v) {
            if (v == null) {
              sellers.remove(sid);
            } else {
              sellers[sid] = v;
            }
            _preview();
          }),
        _row('Shipping${st['chargeable'] != null ? ' (${st['chargeable']} kg${st['route'] != null ? ', ${st['route']}' : ''})' : ''}', st['shipping'] == null ? '—' : peso(st['shipping'])),
        if (asNum(st['discount']) > 0) _row('Store voucher', '−${peso(st['discount'])}', green: true),
        TextField(
          controller: _notes[sid],
          maxLength: 200,
          decoration: const InputDecoration(hintText: 'Note to the seller (optional)', isDense: true, counterText: ''),
        ),
      ]),
    );
  }

  /// The website's voucher picker: a bar (title, the applied voucher or "N available") that opens the ticket list —
  /// "Don't use a voucher", every voucher as a ticket (greyed with the reason when it can't be used, or what it saves),
  /// the Voucher Center and OK. Hidden when there are no vouchers of this kind.
  Widget _voucherPicker(String kind, String title, String where, List options, String? value, ValueChanged<String?> onChanged) {
    if (options.isEmpty && value == null) return const SizedBox.shrink();
    final c = context.bc;
    String chip(Map o) => kind == 'shipping' ? 'Free shipping${asNum(o['value']) > 0 ? ' up to ₱${asNum(o['value']).toStringAsFixed(0)}' : ''}' : '${o['label']}';
    final chosen = options.cast<Map>().where((o) => o['code'] == value).firstOrNull;
    final usable = options.where((o) => o['reason'] == null).length;
    final state = value == null ? (options.isEmpty ? 'None available' : '$usable available') : (chosen != null ? chip(chosen) : value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final picked = await _openVoucherList(kind, title, where, options, value);
          if (picked != null && picked.$1 != value) setState(() => onChanged(picked.$1));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(kind == 'shipping' ? Icons.local_shipping_outlined : Icons.confirmation_number_outlined,
                size: 20, color: kind == 'shipping' ? const Color(0xFF0F9F8A) : kOrange),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: c.text))),
            Flexible(
              child: Text(state,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: value != null ? kOrange : c.muted, fontWeight: value != null ? FontWeight.w700 : FontWeight.normal)),
            ),
            Icon(Icons.chevron_right, color: c.muted),
          ]),
        ),
      ),
    );
  }

  /// The ticket list. Returns (the chosen code or null for none) on OK; null when closed.
  Future<(String?,)?> _openVoucherList(String kind, String title, String where, List options, String? value) {
    String? pick = value;
    return showModalBottomSheet<(String?,)>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = ctx.bc;
          Widget dot(bool on, {bool enabled = true}) =>
              Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: !enabled ? c.border : (on ? kOrange : c.muted));
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                  child: Row(children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ]),
                ),
                Flexible(
                  child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 4, 12, 8), children: [
                    InkWell(
                      onTap: () => set(() => pick = null),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: Row(children: [dot(pick == null), const SizedBox(width: 8), const Text("Don't use a voucher")]),
                      ),
                    ),
                    for (final o in options.cast<Map>())
                      GestureDetector(
                        onTap: o['reason'] != null ? null : () => set(() => pick = o['code']),
                        child: VoucherTicket(
                          o,
                          kind: kind,
                          where: where,
                          saving: o['reason'] == null && asNum(o['discount']) > 0 ? asNum(o['discount']) : null,
                          trailing: dot(pick == o['code'], enabled: o['reason'] == null),
                        ),
                      ),
                    if (options.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('No ${title.toLowerCase()}s right now. Find more in the Voucher Center.', style: TextStyle(color: c.muted)),
                      ),
                  ]),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherCenterScreen()));
                      },
                      child: const Text('Voucher Center', style: TextStyle(color: kOrange)),
                    ),
                    const Spacer(),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => Navigator.pop(ctx, (pick,)), child: const Text('OK')),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool green = false, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: green ? const Color(0xFF059669) : context.bc.textSecondary))),
          Text(value,
              style: TextStyle(
                color: bold ? kOrange : (green ? const Color(0xFF059669) : context.bc.text),
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                fontSize: bold ? 17 : 14,
              )),
        ]),
      );

  Future<void> _pickAddress(List<Map> addresses) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final a in addresses)
            ListTile(
              leading: Icon(a['id'] == addressId ? Icons.radio_button_checked : Icons.radio_button_off, color: kOrange),
              title: Text('${a['label']} · ${a['full_name']}${a['is_default'] == true ? ' (default)' : ''}'),
              subtitle: Text(a['full_address'] ?? ''),
              onTap: () => Navigator.pop(ctx, a['id'] as int),
            ),
          ListTile(leading: const Icon(Icons.add, color: kOrange), title: const Text('Add a new address'), onTap: () => Navigator.pop(ctx, -1)),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == -1) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAddressScreen()));
      _load();
      return;
    }
    setState(() => addressId = picked);
    _preview();
  }

  /// The design's full-width "Confirm & Place Order (₱…)" button with the safety line under it.
  Widget _placeBar() {
    final blocked = totals?['unserviceable'] != null || addressId == null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        decoration: BoxDecoration(
          color: context.bc.surface,
          boxShadow: const [BoxShadow(color: Color(0x142A1A10), blurRadius: 16, offset: Offset(0, -3))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: placing || blocked ? null : _place,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: placing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.lock_outline_rounded, size: 19),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Confirm & Place Order (${peso(totals?['total'])})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shield_outlined, size: 13, color: Alvy.slate),
            const SizedBox(width: 4),
            Text('Your payment is checked by ALVY', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.bc.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}
