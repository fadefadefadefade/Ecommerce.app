import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/voucher_ticket.dart';
import 'account/collections_screens.dart' show VoucherCenterScreen;

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/net_image.dart';
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

  Future<void> _load() async {
    setState(() => loading = true);
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
    if (payment == 'gcash_receipt' && _receipt == null) {
      return showError(context, 'Upload the screenshot of your GCash receipt.');
    }
    setState(() => placing = true);
    final body = {
      ..._voucherBody(typed: fieldErrors['voucher_code'] == null),
      'payment_method': payment,
      'checkout_token': page!['checkout_token'],
      'prices': page!['prices'],
      'buyer_notes': {for (final e in _notes.entries) if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim()},
      if (payment == 'gcash_receipt' && _gcashRef.text.trim().isNotEmpty) 'payment_reference': _gcashRef.text.trim(),
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

  Widget _gcashBox(Map<String, dynamic> account) {
    final total = totals?['total'];
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBFDBFE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Send ${total == null ? 'the total' : peso(total)} by GCash to', style: TextStyle(color: context.bc.textSecondary)),
        SelectableText('${account['number']} · ${account['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        Text('Then attach the screenshot of the GCash receipt. The seller checks it before shipping (For verification).',
            style: TextStyle(fontSize: 12, color: context.bc.muted)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
              if (x != null) setState(() => _receipt = x.path);
            } on PlatformException {
              if (mounted) showError(context, 'Photo access is off for ALVY. Allow it in Settings › Apps › ALVY › Permissions.');
            }
          },
          icon: Icon(_receipt == null ? Icons.upload_file : Icons.check_circle, color: _receipt == null ? kOrange : const Color(0xFF15803D)),
          label: Text(_receipt == null ? 'Attach GCash receipt' : 'Receipt attached — change'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _gcashRef,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')), LengthLimitingTextInputFormatter(20)],
          decoration: InputDecoration(labelText: 'GCash Ref No. (optional)', isDense: true, border: const OutlineInputBorder(),
              errorText: fieldErrors['payment_reference'], helperText: 'The 13-digit "Ref No." on your receipt'),
        ),
      ]),
    );
  }

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

    return ListView(padding: const EdgeInsets.all(12), children: [
      SectionCard(
        title: 'Delivery Address',
        trailing: TextButton(onPressed: () => _pickAddress(addresses), child: Text(address == null ? 'Add' : 'Change')),
        child: address == null
            ? Text('Please add a delivery address.', style: TextStyle(color: context.bc.muted))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${address['full_name']} · ${address['phone']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(address['full_address'] ?? '', style: TextStyle(color: context.bc.muted)),
              ]),
      ),
      if (t['unserviceable'] != null)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
          child: Text(t['unserviceable'], style: const TextStyle(color: Color(0xFFB91C1C))),
        ),

      for (final s in page!['stores']) _store(Map.from(s), lines, Map.from(storesTotals['${s['seller_id'] ?? 0}'] ?? s), vouchers),

      SectionCard(
        title: 'Vouchers',
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
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _preview, child: const Text('Apply')),
          ]),
        ]),
      ),

      SectionCard(
        title: 'Payment Method',
        child: RadioGroup<String>(
          groupValue: payment,
          onChanged: (v) => setState(() => payment = v ?? 'cod'),
          child: Column(children: [
            const RadioListTile<String>(value: 'cod', title: Text('Cash on Delivery'), dense: true, activeColor: kOrange),
            if (page!['gcash_account'] != null)
              const RadioListTile<String>(value: 'gcash_receipt', title: Text('GCash (send, then upload the receipt)'), dense: true, activeColor: kOrange),
            for (final m in page!['payment_methods'])
              if (m['key'] != 'gcash_receipt')
                RadioListTile<String>(value: m['key'], title: Text(m['label'] ?? m['key']), dense: true, activeColor: kOrange),
            if (payment == 'gcash_receipt' && page!['gcash_account'] != null) _gcashBox(asMap(page!['gcash_account'])),
          ]),
        ),
      ),

      SectionCard(
        title: 'Order Summary',
        child: Column(children: [
          _row('Merchandise subtotal', peso(t['subtotal'])),
          if (asNum(t['promo_discount']) > 0) _row('Bundle deals & promos', '−${peso(t['promo_discount'])}', green: true),
          _row('Shipping', peso(t['shipping_total'])),
          if (asNum(t['seller_discount']) > 0) _row('Store vouchers', '−${peso(t['seller_discount'])}', green: true),
          if (asNum(t['platform_discount']) > 0) _row('ALVY voucher', '−${peso(t['platform_discount'])}', green: true),
          if (asNum(t['shipping_discount']) > 0) _row('Shipping voucher', '−${peso(t['shipping_discount'])}', green: true),
          const Divider(),
          _row('Total', peso(t['total']), bold: true),
        ]),
      ),
    ]);
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
                  Text('${l['variation'] != null ? '${l['variation']['name']} · ' : ''}${peso(l['unit_price'])} × ${l['quantity']}',
                      style: TextStyle(fontSize: 12, color: context.bc.muted)),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(8)),
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

  Widget _placeBar() {
    final blocked = totals?['unserviceable'] != null || addressId == null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        decoration: BoxDecoration(color: context.bc.surface, border: Border(top: BorderSide(color: context.bc.border))),
        child: Row(children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total', style: TextStyle(fontSize: 12, color: context.bc.muted)),
              Text(peso(totals?['total']), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kOrange)),
            ]),
          ),
          ElevatedButton(
            onPressed: placing || blocked ? null : _place,
            style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white, minimumSize: const Size(150, 46)),
            child: placing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Place Order', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
