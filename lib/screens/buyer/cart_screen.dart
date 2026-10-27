import 'package:flutter/material.dart';

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
  final VoidCallback? onChanged;

  const CartScreen({super.key, this.onBrowse, this.onChanged});

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
    widget.onChanged?.call();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Shopping Cart (${_lines.length})'),
      ),
      body: LoadState(
        loading: loading,
        error: error,
        onRetry: _load,
        child: stores.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: context.bc.muted),
                  const SizedBox(height: 12),
                  Text('Your cart is empty.', style: TextStyle(color: context.bc.muted)),
                  const SizedBox(height: 12),
                  if (widget.onBrowse != null)
                    ElevatedButton(
                      onPressed: widget.onBrowse,
                      style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white),
                      child: const Text('Browse Items'),
                    ),
                ]),
              )
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(12), children: [for (final s in stores) _store(Map.from(s))]),
              ),
      ),
      bottomNavigationBar: stores.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                decoration: BoxDecoration(color: context.bc.surface, border: Border(top: BorderSide(color: context.bc.border))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('Total (${selected.length} item${selected.length == 1 ? '' : 's'})', style: TextStyle(fontSize: 12, color: context.bc.muted)),
                      Text(peso(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kOrange)),
                    ]),
                  ),
                  ElevatedButton(
                    onPressed: selected.isEmpty || busy ? null : _checkout,
                    style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white, minimumSize: const Size(140, 46)),
                    child: Text('Check Out (${selected.length})'),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _store(Map s) {
    final lines = List<Map>.from(s['lines']);
    final ids = lines.where((l) => l['unavailable'] == null).map((l) => l['id'] as int);
    final all = ids.isNotEmpty && ids.every(selected.contains);
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 8),
      child: Column(children: [
        Row(children: [
          Checkbox(
            value: all,
            activeColor: kOrange,
            onChanged: ids.isEmpty ? null : (v) => setState(() => v == true ? selected.addAll(ids) : selected.removeAll(ids)),
          ),
          const Icon(Icons.storefront, size: 18, color: kOrange),
          const SizedBox(width: 6),
          Expanded(child: Text(s['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: context.bc.text))),
          if (s['on_vacation'] == true) const Text('On vacation', style: TextStyle(fontSize: 11, color: Color(0xFFB45309))),
        ]),
        for (final l in lines) _line(l),
      ]),
    );
  }

  Widget _line(Map l) {
    final product = l['product'];
    final reason = l['unavailable'];
    final qty = asNum(l['quantity']).toInt();
    final stock = asNum(l['stock']).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(
          value: selected.contains(l['id']),
          activeColor: kOrange,
          onChanged: (v) => setState(() => v == true ? selected.add(l['id']) : selected.remove(l['id'])),
        ),
        InkWell(
          onTap: product == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: product['slug']))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 64,
              height: 64,
              color: context.bc.subtle,
              child: product?['image_url'] != null ? NetImage(product['image_url'], fit: BoxFit.cover) : const Icon(Icons.image_not_supported),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product?['title'] ?? 'Removed item', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.bc.text)),
            if (l['variation'] != null) Text(l['variation']['name'], style: TextStyle(fontSize: 12, color: context.bc.muted)),
            Text(peso(l['unit_price']), style: const TextStyle(color: kOrange, fontWeight: FontWeight.w700)),
            if (reason != null) Text(reason, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            Row(children: [
              _qtyButton(Icons.remove, qty > 1 && !busy ? () => _setQty(l, qty - 1) : null),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700))),
              _qtyButton(Icons.add, qty < stock && !busy ? () => _setQty(l, qty + 1) : null),
              const Spacer(),
              IconButton(onPressed: busy ? null : () => _remove(l), icon: Icon(Icons.delete_outline, color: context.bc.muted), tooltip: 'Remove'),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 30,
        height: 30,
        child: OutlinedButton(onPressed: onTap, style: OutlinedButton.styleFrom(padding: EdgeInsets.zero), child: Icon(icon, size: 16)),
      );
}
