import '../../widgets/responsive.dart';
import 'package:flutter/material.dart';
import '../seller/seller_kit.dart' show Pill;
import '../../theme/app_theme.dart';

import '../../services/buyer_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/buyer_kit.dart';
import '../../widgets/net_image.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';

/// The website's cart (cart/index): lines grouped by store, tick what to check out, change the
/// quantity within stock, remove; lines that can't be bought say why.
class CartScreen extends StatefulWidget {
  final VoidCallback? onBrowse;
  /// The item count from each load, for the tab badge (so the badge needs no request of its own).
  final ValueChanged<int>? onCount;

  const CartScreen({super.key, this.onBrowse, this.onCount});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<dynamic> stores = [];
  final Set<int> selected = {};
  bool loading = true;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Iterable<Map> get _lines => stores.expand((s) => List<Map>.from(s['lines']));

  Future<void> _load() async {
    final r = await BuyerApi.cart();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (!r.ok) return;
      final first = stores.isEmpty;
      stores = r.body['stores'];
      final ids = _lines.map((l) => l['id'] as int).toSet();
      selected.retainAll(ids);
      // Like the website, buyable lines start ticked.
      if (first) selected.addAll(_lines.where((l) => l['unavailable'] == null).map((l) => l['id'] as int));
    });
    if (r.ok) widget.onCount?.call((r.body['count'] as num?)?.toInt() ?? 0);
  }

  Future<void> _setQty(Map line, int qty) async {
    setState(() => busy = true);
    final r = await BuyerApi.updateCart(line['id'], qty);
    if (!mounted) return;
    setState(() => busy = false);
    if (!r.ok) showResult(context, r);
    _load();
  }

  Future<void> _remove(Map line) async {
    final name = '${line['product']?['title'] ?? 'this item'}';
    if (!await confirmRemoval(context, title: 'Remove from cart?', message: '"$name" will be taken out of your cart.')) return;
    if (!mounted) return;
    setState(() => busy = true);
    final r = await BuyerApi.removeFromCart(line['id']);
    if (!mounted) return;
    setState(() => busy = false);
    showResult(context, r);
    _load();
  }

  double get _total => _lines.where((l) => selected.contains(l['id'])).fold(0.0, (s, l) => s + asNum(l['subtotal']));

  void _checkout() {
    final blocked = _lines.where((l) => selected.contains(l['id']) && l['unavailable'] != null).toList();
    if (blocked.isNotEmpty) {
      showError(context,
          'Some items can\'t be checked out: ${blocked.map((l) => '${l['product']?['title'] ?? 'Removed item'} (${l['unavailable']})').join(', ')}. Please untick or update them.');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(items: selected.toList()))).then((_) => _load());
  }

  /// Tablet: the website's Order Summary card next to the cart lines.
  Widget _summaryCard() {
    final c = context.bc;
    return SizedBox(
      width: 320,
      child: Card(
        margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('Order Summary', style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Selected items', style: TextStyle(color: c.muted))),
              Text('${selected.length} of ${_lines.length}', style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text('Subtotal', style: TextStyle(color: c.muted))),
              Text(peso(_total), style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
            ]),
            const SizedBox(height: 4),
            Text('Shipping and vouchers are added at checkout.', style: TextStyle(fontSize: 12, color: c.muted)),
            const Divider(height: 24),
            Row(children: [
              Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700, color: c.text))),
              Text(peso(_total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kOrange)),
            ]),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: selected.isEmpty || busy ? null : _checkout,
              style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
              child: Text('Check Out (${selected.length})'),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.isWide(context);
    return Scaffold(
      backgroundColor: context.bc.background,
      // Tablet: the web header is already on top, so the title sits in the page (no second bar).
      appBar: wide
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              title: Text('Shopping Cart (${_lines.length})'),
            ),
      body: LoadState(
        loading: loading,
        error: error,
        onRetry: _load,
        child: stores.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
                      child: const Icon(Icons.shopping_cart_outlined, size: 44, color: kOrange),
                    ),
                    const SizedBox(height: 16),
                    Text('Your cart is empty', style: Alvy.display(size: 20, color: context.bc.text, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Find something you like and add it here.', textAlign: TextAlign.center, style: TextStyle(color: context.bc.textSecondary)),
                    const SizedBox(height: 18),
                    if (widget.onBrowse != null)
                      FilledButton.icon(onPressed: widget.onBrowse, icon: const Icon(Icons.storefront_outlined, size: 19), label: const Text('Browse Items')),
                  ]),
                ),
              )
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: wide
                    ? WebWidth(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: ListView(padding: const EdgeInsets.all(12), children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                                child: Text('Shopping Cart (${_lines.length})',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.bc.text)),
                              ),
                              for (final s in stores) _store(Map.from(s)),
                            ]),
                          ),
                          _summaryCard(),
                        ]),
                      )
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                        _steps(),
                        SectionTitle('Items in Cart (${_lines.length})', padding: const EdgeInsets.fromLTRB(0, 12, 0, 14)),
                        for (final s in stores) _store(Map.from(s)),
                        _summary(),
                        // Shipping and vouchers come at checkout.
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            Icon(Icons.verified_user_outlined, size: 18, color: context.bc.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(child: Text('Shipping and vouchers are added at checkout.', style: TextStyle(fontSize: 12.5, color: context.bc.textSecondary))),
                          ]),
                        ),
                      ]),
              ),
      ),
      bottomNavigationBar: stores.isEmpty || wide
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: context.bc.surface,
                  boxShadow: const [BoxShadow(color: Color(0x142A1A10), blurRadius: 16, offset: Offset(0, -3))],
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('Total (${selected.length} item${selected.length == 1 ? '' : 's'})', style: TextStyle(fontSize: 12, color: context.bc.textSecondary)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(peso(_total), style: Alvy.display(size: 22, color: kOrange, weight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                  FilledButton(
                    onPressed: selected.isEmpty || busy ? null : _checkout,
                    style: FilledButton.styleFrom(minimumSize: const Size(150, 50)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Check Out (${selected.length})'),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward, size: 18),
                    ]),
                  ),
                ]),
              ),
            ),
    );
  }

  /// The design's step header: "1 Cart & Shipping · Step 1 of 2" with a progress bar (checkout is step 2).
  Widget _steps() {
    final c = context.bc;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle),
            child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('Cart & Shipping', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700))),
          Text('Step 1 of 2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Alvy.slate)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: .5, minHeight: 5, color: kOrange, backgroundColor: c.border),
        ),
        const SizedBox(height: 6),
        Row(children: [
          const Text('Your items', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kOrange)),
          const Spacer(),
          Text('Checkout & Payment', style: TextStyle(fontSize: 11.5, color: c.muted)),
        ]),
      ]),
    );
  }

  /// The design's "Payment Summary": what is ticked, the subtotal and the total so far.
  Widget _summary() {
    final c = context.bc;
    final count = _lines.where((l) => selected.contains(l['id'])).fold<int>(0, (n, l) => n + asNum(l['quantity']).toInt());
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: bold ? c.text : c.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
            Text(value, style: TextStyle(fontSize: 13.5, color: c.text, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ]),
        );
    return SectionCard(
      title: 'Payment Summary',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        row('Items Subtotal ($count item${count == 1 ? '' : 's'})', peso(_total)),
        row('Delivery Fee', 'At checkout'),
        row('Vouchers', 'At checkout'),
        Divider(height: 20, color: c.border),
        Row(children: [
          Expanded(child: Text('Total so far', style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700))),
          Text(peso(_total), style: Alvy.display(size: 22, color: kOrange, weight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _store(Map s) {
    final c = context.bc;
    final lines = List<Map>.from(s['lines']);
    final ids = lines.where((l) => l['unavailable'] == null).map((l) => l['id'] as int);
    final all = ids.isNotEmpty && ids.every(selected.contains);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardBox(context),
      child: Column(children: [
        // The shop: tick to choose all its items.
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 0),
          child: Row(children: [
            Checkbox(
              value: all,
              onChanged: ids.isEmpty ? null : (v) => setState(() => v == true ? selected.addAll(ids) : selected.removeAll(ids)),
            ),
            Icon(Icons.storefront_outlined, size: 18, color: Alvy.slate),
            const SizedBox(width: 6),
            Expanded(
              child: Text(s['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Alvy.slate)),
            ),
            if (s['on_vacation'] == true) const Pill('On vacation', color: Color(0xFFB45309)),
          ]),
        ),
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: c.border),
          _line(lines[i]),
        ],
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _line(Map l) {
    final c = context.bc;
    final product = l['product'];
    final reason = l['unavailable'];
    final qty = asNum(l['quantity']).toInt();
    final stock = asNum(l['stock']).toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 14, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Checkbox(
            value: selected.contains(l['id']),
            onChanged: (v) => setState(() => v == true ? selected.add(l['id']) : selected.remove(l['id'])),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: product == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: product['slug']))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 82,
              height: 82,
              color: c.subtle,
              child: product?['image_url'] != null ? NetImage(product['image_url'], fit: BoxFit.cover) : Icon(Icons.image_not_supported, color: c.muted),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product?['title'] ?? 'Removed item', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Alvy.display(size: 14.5, color: c.text, weight: FontWeight.w600)),
            if (l['variation'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(l['variation']['name'], style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
              ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Pill('$reason', color: const Color(0xFFDC2626)),
              )
            else if (stock > 0 && stock <= 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Pill('Only $stock left', color: const Color(0xFFB45309)),
              ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(peso(l['unit_price']), style: Alvy.display(size: 18, color: kOrange, weight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              // The quantity: type it (large orders) or tap − / +; saved when typing ends.
              QuantityStepper(value: qty, max: stock < 1 ? qty : stock, height: 36, onChanged: busy ? null : (n) => _setQty(l, n)),
              const Spacer(),
              IconButton(
                onPressed: busy ? null : () => _remove(l),
                tooltip: 'Remove item',
                style: IconButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                icon: const Icon(Icons.delete_outline, size: 21),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

}
