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
        decoration: BoxDecoration(color: Alvy.dangerSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFCA5A5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 6),
            Expanded(child: Text('${v['action']} from ALVY · ${v['type']}', style: TextStyle(fontWeight: FontWeight.w800, color: Alvy.dangerText))),
          ]),
          const SizedBox(height: 4),
          Text('${v['product'] != null ? '"${v['product']}": ' : ''}${v['note']}', style: TextStyle(color: Alvy.dangerText)),
          const SizedBox(height: 2),
          Text('${formatDateTime(v['at'])} · Repeated violations can lead to suspension.', style: TextStyle(fontSize: 11.5, color: Alvy.dangerText)),
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
          decoration: BoxDecoration(color: Alvy.dangerSoft, shape: BoxShape.circle),
          child: Icon(Icons.warning_amber_rounded, color: Alvy.dangerText, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Low stock warning', style: TextStyle(fontWeight: FontWeight.w700, color: Alvy.dangerText, fontSize: 13)),
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
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _metric(
            'Sales',
            Icons.payments_outlined,
            [
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(peso(money['gross']), style: Alvy.display(size: 22, color: c.text, weight: FontWeight.w800))),
              const SizedBox(height: 8),
              SizedBox(height: 34, child: CustomPaint(size: Size.infinite, painter: _Spark([for (final p in chart) asNum(p['value']).toDouble()]))),
              const SizedBox(height: 8),
              _chip(asNum(money['refunds']) > 0 ? '${peso(money['refunds'])} refunded' : 'What buyers paid', Alvy.slateSoft, Alvy.slate),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metric(
            'Orders',
            Icons.inventory_2_outlined,
            [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${asInt(counts['total'])}', style: Alvy.display(size: 22, color: c.text, weight: FontWeight.w800)),
                const SizedBox(width: 4),
                Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('orders', style: TextStyle(color: c.textSecondary))),
              ]),
              const SizedBox(height: 8),
              _subRow('In progress', '${asInt(counts['in_progress'])}', kOrange, Alvy.orangeSoft),
              const SizedBox(height: 6),
              _subRow('Completed', '${asInt(counts['completed'])}', Alvy.slate, c.subtle),
            ],
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _metric(
            'Net earnings',
            Icons.account_balance_wallet_outlined,
            [
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(peso(money['net']), style: Alvy.display(size: 22, color: c.text, weight: FontWeight.w800))),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ALVY COMMISSION', style: TextStyle(fontSize: 10.5, letterSpacing: 0.4, fontWeight: FontWeight.w700, color: c.textSecondary)),
                  FittedBox(child: Text(peso(money['commission']), style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w800))),
                  Text('$rateText% per sale', style: const TextStyle(fontSize: 11.5, color: kOrange, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metric(
            'Products',
            Icons.storefront_outlined,
            [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${asInt(products['active'])}', style: Alvy.display(size: 22, color: c.text, weight: FontWeight.w800)),
                const SizedBox(width: 4),
                Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('active', style: TextStyle(color: c.textSecondary))),
              ]),
              const SizedBox(height: 14),
              Builder(builder: (_) {
                final total = asInt(products['active']) + asInt(products['inactive']);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : asInt(products['active']) / total,
                    minHeight: 7,
                    color: Alvy.slate,
                    backgroundColor: c.subtle,
                  ),
                );
              }),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.inventory_outlined, size: 14, color: Alvy.slate),
                const SizedBox(width: 4),
                Expanded(child: Text('${asInt(products['inactive'])} inactive / draft', style: TextStyle(fontSize: 11.5, color: Alvy.slate))),
              ]),
            ],
          ),
        ),
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
      if (recent.isNotEmpty) ...[
        SectionTitle('Orders to Fulfill',
            action: 'View all', onAction: () => SellerMainScreen.of(context)?.goTo(SellerMainScreenState.tabOrders),
            padding: const EdgeInsets.fromLTRB(0, 22, 0, 12)),
        for (final o in recent) _orderCard(Map.from(o)),
      ],
      const SizedBox(height: 8),
      SectionCard(title: 'Net earnings by month', child: _Chart(chart)),
      SectionCard(
        title: 'Orders',
        child: Column(children: [
          for (final (key, label, color) in [
            ('in_progress', 'In progress', const Color(0xFFFA4E1C)),
            ('completed', 'Completed', Alvy.slate),
            ('cancelled', 'Cancelled', Alvy.textMuted),
            ('refunded', 'Refunded', const Color(0xFFEF4444)),
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
    ]);
  }

  /// A metric card (the design's "Today's Sales"): small label with an icon, then the content.
  Widget _metric(String label, IconData icon, List<Widget> children) {
    final c = context.bc;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardBox(context, radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontWeight: FontWeight.w600))),
          Icon(icon, size: 18, color: kOrange),
        ]),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  Widget _subRow(String label, String value, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: context.bc.text))),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fg)),
        ]),
      );

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );

  /// The design's "Orders to Fulfill": each recent order as a card.
  Widget _orderCard(Map o) {
    final c = context.bc;
    Future<void> open() async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SellerOrderDetailsScreen(orderId: asInt(o['order_id']))));
      _load();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: cardBox(context, radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${o['number'] ?? ''}', style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w800))),
          Pill('${o['status'] ?? ''}', color: Pill.forState(o['status'])),
        ]),
        const SizedBox(height: 2),
        Text('Customer: ${o['buyer'] ?? ''} · ${formatDate(o['created_at'])}', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o['product'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                Text('Qty: ${o['quantity']}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ]),
            ),
            Text(peso(o['earning']), style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: open,
            style: FilledButton.styleFrom(backgroundColor: c.subtle, foregroundColor: c.text, minimumSize: const Size(0, 38)),
            child: const Text('Details'),
          ),
        ),
      ]),
    );
  }
}

/// The design's sales sparkline: a smooth orange line with a soft fill under it.
class _Spark extends CustomPainter {
  final List<double> values;
  _Spark(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final max = values.reduce((a, b) => a > b ? a : b);
    final pts = [
      for (var i = 0; i < values.length; i++)
        Offset(size.width * i / (values.length - 1), size.height - (max == 0 ? 0 : values[i] / max) * (size.height - 4) - 2),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final mid = Offset((pts[i - 1].dx + pts[i].dx) / 2, (pts[i - 1].dy + pts[i].dy) / 2);
      line.quadraticBezierTo(pts[i - 1].dx, pts[i - 1].dy, mid.dx, mid.dy);
    }
    line.lineTo(pts.last.dx, pts.last.dy);
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = const Color(0x1FFA4E1C));
    canvas.drawPath(line, Paint()
      ..color = const Color(0xFFD93D0E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_Spark old) => old.values != values;
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
