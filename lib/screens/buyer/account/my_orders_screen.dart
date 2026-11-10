import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

import '../../../services/buyer_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/buyer_kit.dart';
import '../../../widgets/net_image.dart';
import '../chat_screen.dart';
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
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Row(children: [
          const Text('My Purchases'),
          if ((counts['to_pay'] ?? 0) + (counts['to_ship'] ?? 0) + (counts['to_receive'] ?? 0) > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(99)),
              child: Text('${(counts['to_pay'] ?? 0) + (counts['to_ship'] ?? 0) + (counts['to_receive'] ?? 0)} active',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Alvy.orangeDark)),
            ),
          ],
        ]),
        // The status filters: pills with their counts (the design's "All · To Pay 1 · To Ship 2 …").
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: SizedBox(
            height: 58,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), children: [
              // Return/Refund only when the server lists it (returns are on, or this buyer has old return orders).
              for (final t in _tabs.where((t) => t.$1 != 'return_refund' || counts.containsKey('return_refund')))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterPill(
                    (counts[t.$1] ?? 0) > 0 && t.$1 != 'all' ? '${t.$2}  ${counts[t.$1]}' : t.$2,
                    selected: tab == t.$1,
                    onTap: () {
                      setState(() => tab = t.$1);
                      _load();
                    },
                  ),
                ),
            ]),
          ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
                    child: Column(children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
                        child: const Icon(Icons.receipt_long_outlined, size: 40, color: kOrange),
                      ),
                      const SizedBox(height: 14),
                      Text('No orders here yet', style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Orders you place show up here.', style: TextStyle(color: c.textSecondary)),
                    ]),
                  ),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
                  for (final o in orders) _order(Map.from(o)),
                  if (page < last) TextButton(onPressed: () => _load(more: true), child: const Text('Load more')),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      CircleAvatar(radius: 22, backgroundColor: Alvy.orangeSoft, child: const Icon(Icons.verified_user_outlined, color: kOrange)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('ALVY Buyer Protection', style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('Your payment is checked by ALVY, and you can ask for a return if the item is not as described.',
                              style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
        ),
      ),
    );
  }

  /// Status colors: waiting (amber), moving (blue), done (green), stopped (red).
  Color _statusColor(String label) {
    final l = label.toLowerCase();
    if (l.contains('cancel') || l.contains('fail') || l.contains('reject') || l.contains('refund')) return const Color(0xFFDC2626);
    if (l.contains('deliver') || l.contains('complete') || l.contains('received')) return const Color(0xFF15803D);
    if (l.contains('pay') || l.contains('pending') || l.contains('verif') || l.contains('pack')) return const Color(0xFFB45309);
    return Alvy.slate;
  }

  Widget _order(Map o) {
    final c = context.bc;
    final items = List<Map>.from(o['items']);
    final store = '${o['store'] ?? ''}';
    final initials = store.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final count = items.fold<int>(0, (n, i) => n + asNum(i['quantity']).toInt());
    Future<void> open() async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o['id'])));
      _load();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: cardBox(context, radius: 20),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Shop, order number and status.
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Alvy.slateSoft,
                  child: Text(initials.isEmpty ? 'S' : initials, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Alvy.slate)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(store, maxLines: 1, overflow: TextOverflow.ellipsis, style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700)),
                    Text('${o['number']} · ${formatDate(o['created_at'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
                    const SizedBox(height: 6),
                    _statusPill('${o['status_label'] ?? ''}'),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              for (final i in items.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 62,
                        height: 62,
                        color: c.subtle,
                        child: i['image_url'] != null ? NetImage(i['image_url'], fit: BoxFit.cover) : Icon(Icons.image_outlined, color: c.muted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${i['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                        if (i['variation'] != null) Text('${i['variation']}', maxLines: 1, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                        const SizedBox(height: 2),
                        Text(peso(i['price']), style: Alvy.display(size: 14.5, color: c.text, weight: FontWeight.w700)),
                      ]),
                    ),
                    Text('Qty: ${i['quantity']}', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                  ]),
                ),
              if (items.length > 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('+${items.length - 2} more item${items.length - 2 == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: c.muted)),
                ),
              if (const ['to_pay', 'to_ship', 'to_receive', 'completed'].contains(o['tab'])) _timeline('${o['tab']}'),
              Divider(height: 18, color: c.border),
              Row(children: [
                Expanded(child: Text('Order Total ($count item${count == 1 ? '' : 's'})', style: TextStyle(fontSize: 13, color: c.textSecondary))),
                Text(peso(o['total']), style: Alvy.display(size: 20, color: kOrange, weight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(type: 'order', id: '${o['id']}', title: store))),
                    style: FilledButton.styleFrom(backgroundColor: c.subtle, foregroundColor: c.text, minimumSize: const Size(0, 42)),
                    icon: const Icon(Icons.chat_outlined, size: 17),
                    label: const FittedBox(child: Text('Contact Seller')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: open,
                    style: FilledButton.styleFrom(backgroundColor: Alvy.orangeSoft, foregroundColor: kOrange, minimumSize: const Size(0, 42)),
                    child: const FittedBox(child: Text('View Order Details')),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  /// Four steps with a line between: done steps navy with a check, the current one orange, the rest grey.
  Widget _timeline(String tab) {
    final c = context.bc;
    const steps = [('Placed', Icons.receipt_long_outlined), ('Packing', Icons.inventory_2_outlined), ('On the way', Icons.two_wheeler), ('Delivered', Icons.home_outlined)];
    final at = const {'to_pay': 0, 'to_ship': 1, 'to_receive': 2, 'completed': 3}[tab] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ORDER PROGRESS', style: TextStyle(fontSize: 11, letterSpacing: 0.5, fontWeight: FontWeight.w800, color: c.text)),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) Expanded(child: Container(height: 2, color: i <= at ? (i == at ? kOrange : Alvy.slate) : c.border)),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < at || (i == at && tab == 'completed') ? Alvy.slate : (i == at ? kOrange : c.surface),
              ),
              child: Icon(i < at || (i == at && tab == 'completed') ? Icons.check : steps[i].$2, size: 15,
                  color: i <= at ? Colors.white : c.muted),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Text(steps[i].$1,
                  textAlign: i == 0 ? TextAlign.left : (i == steps.length - 1 ? TextAlign.right : TextAlign.center),
                  style: TextStyle(fontSize: 11, fontWeight: i == at ? FontWeight.w700 : FontWeight.w500, color: i == at ? kOrange : (i < at ? Alvy.slate : c.muted))),
            ),
        ]),
      ]),
    );
  }

  Widget _statusPill(String label) {
    final color = _statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 7, color: color),
        const SizedBox(width: 5),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color))),
      ]),
    );
  }
}
