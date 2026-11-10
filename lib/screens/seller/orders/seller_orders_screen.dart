import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

import '../../../services/seller_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/product_thumb.dart';
import '../seller_kit.dart';
import 'seller_order_details_screen.dart';

/// The web's Order Management list: tabs with counts (New, To Ship, Shipping, …), order-number search, pages.
class SellerOrdersScreen extends StatefulWidget {
  final String initialTab;
  const SellerOrdersScreen({super.key, this.initialTab = 'new'});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  late String _tab = widget.initialTab;
  final _q = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _tabs = [];
  final List<Map<String, dynamic>> _orders = [];
  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) _more();
    });
    _refresh();
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _orders.clear();
      _page = 0;
      _lastPage = 1;
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _lastPage) return;
    setState(() => _loading = true);
    final r = await SellerApi.orders(tab: _tab, page: _page + 1, q: _q.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!r.ok) {
        _error = r.message;
        return;
      }
      _orders.addAll(asList(r.body['data']));
      _tabs = asList(r.body['tabs']);
      final meta = asMap(r.body['meta']);
      _page = asInt(meta['current_page']);
      _lastPage = asInt(meta['last_page']);
    });
  }

  /// Tablet: the order opened in the right pane (the design's packing station); phones open it as a page.
  int? _selected;
  bool _split = false;

  Future<void> _open(int id) async {
    if (_split) {
      setState(() => _selected = id);
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SellerOrderDetailsScreen(orderId: id)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Orders', actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: LayoutBuilder(builder: (context, box) {
        // Wide enough for two panes: the queue on the left, the open order on the right.
        _split = box.maxWidth >= 840;
        final list = _list(context);
        if (!_split) return list;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 400, child: list),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: DecoratedBox(
                  decoration: cardBox(context, radius: 20),
                  child: _selected == null
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(18)),
                              child: const Icon(Icons.inventory_2_outlined, color: Alvy.orange, size: 30),
                            ),
                            const SizedBox(height: 12),
                            Text('Select an order', style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Its items, earnings and actions open here.', style: TextStyle(color: c.textSecondary)),
                          ]),
                        )
                      : SellerOrderDetailsScreen(key: ValueKey('order-$_selected'), orderId: _selected!),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  Widget _list(BuildContext context) {
    return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          // The status tabs as pills with their counts (the design's "New 2 · To Pack 3 · To Hand Over 5").
          child: SizedBox(
            height: 42,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final t in _tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterPill('${t['label']}  ${t['count']}', selected: _tab == t['key'], onTap: () {
                    _tab = '${t['key']}';
                    _refresh();
                  }),
                ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _refresh(),
            decoration: const InputDecoration(hintText: 'Search order number', prefixIcon: Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: LoadState(
            loading: _loading && _orders.isEmpty,
            error: _error,
            onRetry: _refresh,
            child: RefreshIndicator(
              color: kOrange,
              onRefresh: _refresh,
              child: _orders.isEmpty
                  ? ListView(children: const [EmptyNote(Icons.receipt_long_outlined, 'No orders here.')])
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: _orders.length + (_page < _lastPage ? 1 : 0),
                      itemBuilder: (_, i) => i == _orders.length
                          ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: kOrange)))
                          : _card(_orders[i]),
                    ),
            ),
          ),
        ),
      ]);
  }

  Widget _card(Map<String, dynamic> o) {
    final c = context.bc;
    final items = asList(o['items']);
    // The design's order card: number and status, the buyer, the items in a beige box, then the total and the button.
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      // Tablet: the order open in the right pane is outlined in orange.
      decoration: _split && _selected == asInt(o['id'])
          ? cardBox(context, radius: 20).copyWith(border: Border.all(color: Alvy.orange, width: 2))
          : cardBox(context, radius: 20),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(asInt(o['id'])),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${o['number']}', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${o['buyer'] ?? ''} · ${formatDateTime(o['created_at'])}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                  ]),
                ),
                const SizedBox(width: 8),
                Pill(stepLabel(o['seller_step'], o['status']), color: Pill.forState(o['status'])),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  for (var i = 0; i < items.length && i < 2; i++) ...[
                    if (i > 0) Divider(height: 16, color: c.border),
                    Row(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: ProductThumb(url: items[i]['image_url'], size: 48)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${items[i]['title']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                          Text('${items[i]['variation'] != null ? '${items[i]['variation']} · ' : ''}Qty: ${items[i]['quantity']}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                        ]),
                      ),
                    ]),
                  ],
                  if (items.length > 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('+${items.length - 2} more item${items.length - 2 == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: c.muted)),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total${o['payment'] != null ? ' (${o['payment']})' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    Text(peso(o['total']), style: Alvy.display(size: 20, color: c.text, weight: FontWeight.w700)),
                  ]),
                ),
                FilledButton(
                  onPressed: () => _open(asInt(o['id'])),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 18)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Open order'), SizedBox(width: 4), Icon(Icons.chevron_right, size: 18)]),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The web's seller step names (Order::sellerStep) as shown on the order list.
String stepLabel(dynamic step, dynamic status) {
  final s = '${status ?? ''}';
  if (s != 'Pending' && s != 'Processing') return s;
  return switch ('${step ?? ''}') {
    'new' => 'New',
    'accepted' => 'Accepted',
    'packed' => 'Packed',
    'ready' => 'Ready for Pickup',
    _ => s,
  };
}
