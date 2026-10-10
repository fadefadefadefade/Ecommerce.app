import 'package:flutter/material.dart';
import '../../../widgets/net_image.dart';
import '../../../services/api_service.dart';
import '../../../theme/buyer_colors.dart';
import 'account_ui.dart';
import 'order_detail_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  static final _tabs = ['All', ...orderStages.values, 'Cancelled'];

  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = ApiService.unwrap(await ApiService.get('/orders'));
      if (!mounted) return;
      setState(() {
        _orders = (data['orders'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filtered(String tab) {
    if (tab == 'All') return _orders;
    return _orders.where((o) => (o['stage_label'] ?? o['status'] ?? '').toString() == tab).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: context.bc.background,
        appBar: accountAppBar(
          'My Orders',
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: _tabs.map((t) {
              final count = _filtered(t).length;
              return Tab(text: t == 'All' || count == 0 ? t : '$t ($count)');
            }).toList(),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: BuyerPalette.primary))
            : _error != null
                ? AccountEmptyState(
                    icon: Icons.wifi_off,
                    title: 'Could not load orders',
                    message: _error!,
                    action: ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  )
                : TabBarView(children: _tabs.map(_buildList).toList()),
      ),
    );
  }

  Widget _buildList(String tab) {
    final orders = _filtered(tab);
    return RefreshIndicator(
      color: BuyerPalette.primary,
      onRefresh: _load,
      child: orders.isEmpty
          ? ListView(
              children: [
                SizedBox(
                  height: 400,
                  child: AccountEmptyState(
                    icon: Icons.receipt_long,
                    title: tab == 'All' ? 'No orders yet' : 'No ${tab.toLowerCase()} orders',
                    message: 'Orders you place will show up here.',
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _buildOrderCard(orders[i]),
            ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final c = context.bc;
    final itemsCount = toNum(order['items_count']).toInt();
    final title = order['first_item_title'] as String?;
    final image = order['first_item_image'] as String?;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order['id'])),
          );
          _load();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, size: 18, color: c.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Order #${order['order_number'] ?? order['id']}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
                    ),
                  ),
                  StageBadge('${order['stage'] ?? ''}', label: order['stage_label']),
                ],
              ),
              Divider(height: 20, color: c.border),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: c.subtle,
                      child: image != null
                          ? NetImage(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.inventory_2, color: c.muted),
                            )
                          : Icon(Icons.inventory_2, color: c.muted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? (itemsCount == 0 ? 'No items' : '$itemsCount item${itemsCount == 1 ? '' : 's'}'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.text),
                        ),
                        if (title != null && itemsCount > 1)
                          Text('+${itemsCount - 1} more item${itemsCount - 1 == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 12, color: c.muted)),
                        const SizedBox(height: 4),
                        Text(formatDate(order['created_at']), style: TextStyle(fontSize: 12, color: c.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('${order['payment_method'] ?? ''}', style: TextStyle(fontSize: 12, color: c.muted)),
                  const Spacer(),
                  Text('Total: ', style: TextStyle(color: c.textSecondary)),
                  Text(
                    peso(order['total_price']),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: BuyerPalette.primary, fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
