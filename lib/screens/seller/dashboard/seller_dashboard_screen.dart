import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/seller_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/product_thumb.dart';
import '../../buyer/account/notifications_screen.dart';
import '../orders/seller_order_details_screen.dart';
import '../products/add_edit_product_screen.dart';
import '../products/seller_products_screen.dart';
import '../reports/seller_commissions_screen.dart';
import '../seller_kit.dart';
import '../seller_main_screen.dart';

/// The web's seller dashboard: a period (today, this week, this month or custom), sales, commission and net earnings,
/// orders by state, best sellers, products and stock, net earnings by month and recent orders.
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;
  String _period = 'month';
  DateTimeRange? _custom;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _d == null;
      _error = null;
    });
    final r = await SellerApi.dashboard(period: _period, from: _custom == null ? null : ymd(_custom!.start), to: _custom == null ? null : ymd(_custom!.end));
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = r.body;
      } else {
        _error = r.message;
      }
    });
  }

  /// Opens a page, then reloads (stock or notifications may have changed there).
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  /// Warnings from ALVY (an admin set a violation): shown until the seller taps "I understand".
  Widget _violation(Map v) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCA5A5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 6),
            Expanded(child: Text('${v['action']} from ALVY · ${v['type']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF991B1B)))),
          ]),
          const SizedBox(height: 4),
          Text('${v['product'] != null ? '"${v['product']}": ' : ''}${v['note']}', style: const TextStyle(color: Color(0xFF7F1D1D))),
          const SizedBox(height: 2),
          Text('${formatDateTime(v['at'])} · Repeated violations can lead to suspension.', style: const TextStyle(fontSize: 11.5, color: Color(0xFFB91C1C))),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () async {
                final r = await SellerApi.acknowledgeViolation(asInt(v['id']));
                if (!mounted) return;
                if (!r.ok) showError(context, r.message);
                _load();
              },
              child: const Text('I understand'),
            ),
          ),
        ]),
      );

  /// The warning at the top when products are at the low-stock line (10 or fewer) or sold out.
  Widget _stockWarning(Map<String, dynamic> d) {
    final low = asInt(d['low_stock_count']);
    final out = asInt(d['sold_out_count']);
    if (low == 0 && out == 0) return const SizedBox.shrink();
    final limit = asInt(d['low_stock_threshold']) == 0 ? 10 : asInt(d['low_stock_threshold']);
    final parts = [
      if (low > 0) '$low product${low == 1 ? '' : 's'} with $limit or fewer left',
      if (out > 0) '$out sold out',
    ];
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: Color(0xFFFFDAD6), shape: BoxShape.circle),
          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFBA1A1A), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Low stock warning', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFBA1A1A), fontSize: 13)),
            Text('${parts.join(' · ')}. Restock so buyers can keep ordering.', style: TextStyle(color: context.bc.text, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.bc.surface,
            foregroundColor: context.bc.text,
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: () => _open(SellerProductsScreen(initialStatus: low > 0 ? 'low_stock' : 'out_of_stock')),
          child: const Text('Manage'),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Dashboard', actions: [
        // Notifications (low-stock alerts, new orders…) with the unread count.
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => _open(const NotificationsScreen()),
          icon: Badge(
            isLabelVisible: asInt(_d?['unread_notifications']) > 0,
            label: Text('${asInt(_d?['unread_notifications'])}'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: RefreshIndicator(
          onRefresh: _load,
          color: kOrange,
          child: _d == null ? const SizedBox() : _body(user?.name ?? ''),
        ),
      ),
    );
  }

  Future<void> _pickPeriod(String p) async {
    if (p == 'custom') {
      final now = DateTime.now();
      final r = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 2), lastDate: now, initialDateRange: _custom);
      if (r == null) return;
      _custom = r;
    } else {
      _custom = null;
    }
    setState(() => _period = p);
    _load();
  }

  Widget _body(String name) {
    final d = _d!;
    final c = context.bc;
    final money = asMap(d['money']);
    final counts = asMap(d['order_counts']);
    final products = asMap(d['product_counts']);
    final chart = asList(d['chart']);
    final lowStock = asList(d['low_stock']);
    final recent = asList(d['recent_orders']);
    final best = asList(d['best_sellers']);
    final rate = asNum(d['commission_rate']);
    final rateText = rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1);

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      for (final v in List<Map>.from(d['violations'] ?? const [])) _violation(v),
      // The store name, big, like the design's dashboard header.
      Text('Welcome back,', style: TextStyle(fontSize: 14, color: c.textSecondary)),
      Text(name, style: Alvy.display(size: 26, color: c.text, weight: FontWeight.w700)),
      const SizedBox(height: 14),
      // The period the numbers cover (Today / This week / This month / Custom).
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (key, label) in const [('today', 'Today'), ('week', 'This week'), ('month', 'This month'), ('custom', 'Custom')])
            Padding(padding: const EdgeInsets.only(right: 8), child: FilterPill(label, selected: _period == key, onTap: () => _pickPeriod(key))),
        ]),
      ),
      Padding(padding: const EdgeInsets.only(top: 8), child: Text('${d['range_label'] ?? ''}', style: TextStyle(color: c.muted, fontSize: 12))),
      // Orders waiting to ship: the design's urgent orange card.
      if (asInt(d['to_ship']) > 0)
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: Alvy.gradient, borderRadius: BorderRadius.circular(20), boxShadow: Alvy.buttonShadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text('TO SHIP', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)),
              ]),
            ),
            const SizedBox(height: 10),
            Text('${d['to_ship']} order${asInt(d['to_ship']) == 1 ? '' : 's'} to ship', style: Alvy.display(size: 22, color: Colors.white, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Accept, pack and book the pickup.', style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 13.5)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kOrange),
                onPressed: () => SellerMainScreen.of(context)?.goTo(SellerMainScreenState.tabOrders),
                icon: const Icon(Icons.inventory_2_outlined, size: 19),
                label: const Text('Go to orders'),
              ),
            ),
          ]),
        ),
      _stockWarning(d),
      const SectionTitle('Overview Metrics', padding: EdgeInsets.fromLTRB(0, 22, 0, 12)),
      StatGrid([
        StatTile(label: 'Sales', value: peso(money['gross']), icon: Icons.payments_outlined, color: const Color(0xFF2563EB),
            hint: asNum(money['refunds']) > 0 ? '${peso(money['refunds'])} refunded' : 'What buyers paid for your items'),
        StatTile(label: 'Commission', value: peso(money['commission']), icon: Icons.percent, color: const Color(0xFF9333EA), hint: 'ALVY fee ($rateText% per sale)'),
        StatTile(label: 'Net earnings', value: peso(money['net']), icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF15803D), hint: 'Sales minus commission'),
        StatTile(label: 'Orders', value: '${asInt(counts['total'])}', icon: Icons.receipt_long_outlined,
            hint: asInt(d['to_ship']) > 0 ? '${d['to_ship']} waiting to ship' : 'Nothing to ship'),
      ]),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _open(SellerCommissionsScreen(period: _period, custom: _custom)),
          icon: const Icon(Icons.percent, size: 18),
          label: const Text('Commission details'),
        ),
      ),
      // Quick actions (the design's round tiles).
      const SectionTitle('Quick Actions', padding: EdgeInsets.fromLTRB(0, 8, 0, 12)),
      Row(children: [
        for (final (icon, label, onTap) in <(IconData, String, VoidCallback)>[
          (Icons.add_box_outlined, 'New Item', () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditProductScreen()));
            _load();
          }),
          (Icons.inventory_2_outlined, 'Products', () => SellerMainScreen.of(context)?.goTo(SellerMainScreenState.tabProducts)),
          (Icons.receipt_long_outlined, 'Orders', () => SellerMainScreen.of(context)?.goTo(SellerMainScreenState.tabOrders)),
          (Icons.percent, 'Commission', () => _open(SellerCommissionsScreen(period: _period, custom: _custom))),
        ]) ...[
          Expanded(
            child: Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: c.subtle, shape: BoxShape.circle),
                      child: Icon(icon, color: kOrange, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.text)),
                  ]),
                ),
              ),
            ),
          ),
          if (label != 'Commission') const SizedBox(width: 10),
        ],
      ]),
      const SizedBox(height: 20),
      SectionCard(title: 'Net earnings by month', child: _Chart(chart)),
      SectionCard(
        title: 'Orders',
        child: Column(children: [
          for (final (key, label, color) in const [
            ('in_progress', 'In progress', Color(0xFFF59E0B)),
            ('completed', 'Completed', Color(0xFF059669)),
            ('cancelled', 'Cancelled', Color(0xFF8A716A)),
            ('refunded', 'Refunded', Color(0xFFEF4444)),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Icon(Icons.circle, size: 9, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(label)),
                Text('${asInt(counts[key])}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
      SectionCard(
        title: 'Best sellers · ${d['range_label'] ?? ''}',
        child: best.isEmpty
            ? Text('No sales in this period yet.', style: TextStyle(color: c.muted))
            : Column(children: [
                for (final b in best)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${b['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${b['units']} unit(s)'),
                    trailing: Text(peso(b['sales']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ]),
      ),
      SectionCard(
        title: 'Products',
        child: Column(children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => _open(const SellerProductsScreen(initialStatus: 'active')),
                child: Column(children: [Text('${asInt(products['active'])}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), Text('Active', style: TextStyle(color: c.muted, fontSize: 12))]),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _open(const SellerProductsScreen(initialStatus: 'archived')),
                child: Column(children: [Text('${asInt(products['inactive'])}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), Text('Inactive / draft', style: TextStyle(color: c.muted, fontSize: 12))]),
              ),
            ),
          ]),
          const Divider(),
          if (lowStock.isEmpty) Text('Nothing is running low.', style: TextStyle(color: c.muted)),
          for (final p in lowStock)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ProductThumb(url: p['image_url'], size: 44),
              title: Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(asInt(p['stock']) == 0 ? 'Out of stock' : '${p['stock']} left',
                  style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditProductScreen(productId: asInt(p['id']))));
                _load();
              },
            ),
        ]),
      ),
      SectionCard(
        title: 'Recent orders',
        child: recent.isEmpty
            ? Text('No orders in this period yet.', style: TextStyle(color: c.muted))
            : Column(children: [
                for (final o in recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${o['number'] ?? ''} · ${o['product'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${o['buyer'] ?? ''} · ×${o['quantity']} · ${formatDate(o['created_at'])}'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(peso(o['earning']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${o['status'] ?? ''}', style: TextStyle(fontSize: 11, color: Pill.forState(o['status']))),
                    ]),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => SellerOrderDetailsScreen(orderId: asInt(o['order_id']))));
                      _load();
                    },
                  ),
              ]),
      ),
    ]);
  }
}

class _Chart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  const _Chart(this.points);

  @override
  Widget build(BuildContext context) {
    final max = points.fold<double>(0, (m, p) => asNum(p['value']) > m ? asNum(p['value']) : m);
    return SizedBox(
      height: 150,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final p in points)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                FittedBox(child: Text(pesoWhole(p['value']), style: TextStyle(fontSize: 9, color: context.bc.muted))),
                const SizedBox(height: 2),
                Container(
                  height: max == 0 ? 2 : 2 + 100 * asNum(p['value']) / max,
                  decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 4),
                Text('${p['label']}', style: TextStyle(fontSize: 10, color: context.bc.muted)),
              ]),
            ),
          ),
      ]),
    );
  }
}
