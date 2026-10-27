import 'package:flutter/material.dart';

import '../../../services/buyer_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/buyer_kit.dart';
import '../../../widgets/net_image.dart';
import 'order_detail_screen.dart';

/// The website's My Purchases (profile/orders): tabs with counts and the orders in each.
class MyOrdersScreen extends StatefulWidget {
  final String initialTab;
  const MyOrdersScreen({super.key, this.initialTab = 'all'});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  static const _tabs = [
    ('all', 'All'),
    ('to_pay', 'To Pay'),
    ('to_ship', 'To Ship'),
    ('to_receive', 'To Receive'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
    ('return_refund', 'Return/Refund'),
  ];

  late String tab = widget.initialTab;
  List<dynamic> orders = [];
  Map<String, int> counts = {};
  int page = 1;
  int last = 1;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) setState(() => loading = true);
    final r = await BuyerApi.orders(tab: tab, page: more ? page + 1 : 1);
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (!r.ok) return;
      orders = more ? [...orders, ...r.body['data']] : List.of(r.body['data']);
      page = r.body['meta']['current_page'];
      last = r.body['meta']['last_page'];
      counts = {for (final t in r.body['tabs']) t['key'] as String: asNum(t['count']).toInt()};
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: _tabs.indexWhere((t) => t.$1 == tab).clamp(0, _tabs.length - 1),
      child: Scaffold(
        backgroundColor: context.bc.background,
        appBar: AppBar(
          title: const Text('My Purchases'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: kOrange,
            indicatorColor: kOrange,
            onTap: (i) {
              setState(() => tab = _tabs[i].$1);
              _load();
            },
            tabs: [
              for (final t in _tabs) Tab(text: (counts[t.$1] ?? 0) > 0 ? '${t.$2} (${counts[t.$1]})' : t.$2),
            ],
          ),
        ),
        body: LoadState(
          loading: loading,
          error: error,
          onRetry: _load,
          child: RefreshIndicator(
            color: kOrange,
            onRefresh: _load,
            child: orders.isEmpty
                ? ListView(children: [
                    Padding(padding: const EdgeInsets.all(48), child: Center(child: Text('No orders here yet.', style: TextStyle(color: context.bc.muted)))),
                  ])
                : ListView(padding: const EdgeInsets.all(12), children: [
                    for (final o in orders) _order(Map.from(o)),
                    if (page < last) TextButton(onPressed: () => _load(more: true), child: const Text('Load more')),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _order(Map o) {
    final items = List<Map>.from(o['items']);
    return InkWell(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o['id'])));
        _load();
      },
      child: SectionCard(
        title: '${o['store']} · ${o['number']}',
        trailing: Text(o['status_label'] ?? '', style: const TextStyle(color: kOrange, fontWeight: FontWeight.w600, fontSize: 12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final i in items.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(width: 48, height: 48, child: i['image_url'] != null ? NetImage(i['image_url'], fit: BoxFit.cover) : const Icon(Icons.image)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${i['title']}${i['variation'] != null ? ' (${i['variation']})' : ''} × ${i['quantity']}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Text(peso(i['price'])),
              ]),
            ),
          if (items.length > 2) Text('+${items.length - 2} more item(s)', style: TextStyle(fontSize: 12, color: context.bc.muted)),
          const Divider(),
          Row(children: [
            Expanded(child: Text(formatDate(o['created_at']), style: TextStyle(fontSize: 12, color: context.bc.muted))),
            Text('Order Total: ', style: TextStyle(color: context.bc.textSecondary)),
            Text(peso(o['total']), style: const TextStyle(fontWeight: FontWeight.w800, color: kOrange)),
          ]),
        ]),
      ),
    );
  }
}
