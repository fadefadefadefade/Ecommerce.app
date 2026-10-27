import 'package:flutter/material.dart';

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

  Future<void> _open(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SellerOrderDetailsScreen(orderId: id)));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Orders', actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _refresh(),
            decoration: InputDecoration(
              hintText: 'Search order number',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: c.border)),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final t in _tabs)
              Padding(
                padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
                child: ChoiceChip(
                  label: Text('${t['label']} (${t['count']})'),
                  selected: _tab == t['key'],
                  selectedColor: kOrange.withValues(alpha: 0.15),
                  onSelected: (_) {
                    _tab = '${t['key']}';
                    _refresh();
                  },
                ),
              ),
          ]),
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
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: _orders.length + (_page < _lastPage ? 1 : 0),
                      itemBuilder: (_, i) => i == _orders.length
                          ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: kOrange)))
                          : _card(_orders[i]),
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> o) {
    final c = context.bc;
    final items = asList(o['items']);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(asInt(o['id'])),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${o['number']}', style: TextStyle(fontWeight: FontWeight.w800, color: c.text))),
              Pill(stepLabel(o['seller_step'], o['status']), color: Pill.forState(o['status'])),
            ]),
            const SizedBox(height: 2),
            Text('${o['buyer'] ?? ''} · ${formatDateTime(o['created_at'])}', style: TextStyle(fontSize: 12, color: c.muted)),
            const SizedBox(height: 8),
            for (final it in items.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  ProductThumb(url: it['image_url'], size: 40),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${it['title']}${it['variation'] != null ? ' (${it['variation']})' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text)),
                  ),
                  Text('×${it['quantity']}', style: TextStyle(color: c.muted)),
                ]),
              ),
            if (items.length > 2) Text('+${items.length - 2} more item(s)', style: TextStyle(fontSize: 12, color: c.muted)),
            const Divider(height: 14),
            Row(children: [
              Expanded(child: Text('${o['payment'] ?? ''}', style: TextStyle(fontSize: 12, color: c.muted))),
              Text(peso(o['total']), style: const TextStyle(fontWeight: FontWeight.w800, color: kOrange)),
            ]),
          ]),
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
