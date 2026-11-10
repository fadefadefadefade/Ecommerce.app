
import 'package:flutter/material.dart';

import '../../../services/seller_api.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/design_kit.dart';
import '../seller_kit.dart';
import '../../../widgets/report_download.dart';

/// The web's seller Reports page: totals for a date range, sales by product and earnings by day.
class SellerReportsScreen extends StatefulWidget {
  const SellerReportsScreen({super.key});

  @override
  State<SellerReportsScreen> createState() => _SellerReportsScreenState();
}

class _SellerReportsScreenState extends State<SellerReportsScreen> {
  String? _from;
  String? _to;
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _error;
  bool _exporting = false;

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
    final r = await SellerApi.reports(from: _from, to: _to);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = r.body;
        _from = '${r.body['from']}';
        _to = '${r.body['to']}';
      } else if (_d == null) {
        _error = r.message;
      }
    });
    if (!r.ok && _d != null && mounted) showResult(context, r);
  }

  Future<void> _range() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: DateTime.parse(_from!), end: DateTime.parse(_to!))
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked == null) return;
    _from = ymd(picked.start);
    _to = ymd(picked.end);
    _load();
  }

  /// The website's download (PDF / XLSX / CSV): saved in the phone's Downloads, then View or Share.
  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    final f = await SellerApi.exportReport(format, from: _from, to: _to);
    if (!mounted) return;
    setState(() => _exporting = false);
    await saveReportDownload(context, f);
  }

  void _preset(int days) {
    final now = DateTime.now();
    _from = ymd(now.subtract(Duration(days: days - 1)));
    _to = ymd(now);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Reports', actions: [
        IconButton(onPressed: _range, icon: const Icon(Icons.date_range)),
        _exporting
            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kOrange)))
            : PopupMenuButton<String>(
                tooltip: 'Export',
                icon: const Icon(Icons.download_outlined),
                onSelected: _export,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'pdf', child: Text('Download PDF')),   // PDF only, like the website
                ],
              ),
      ]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: _d == null ? const SizedBox() : RefreshIndicator(color: kOrange, onRefresh: _load, child: _body(_d!)),
      ),
    );
  }

  /// The preset the range matches (7 / 30 / 90 days ending today), for the pills.
  int? get _presetDays {
    if (_from == null || _to == null) return null;
    final to = DateTime.tryParse(_to!);
    final from = DateTime.tryParse(_from!);
    if (to == null || from == null || ymd(to) != ymd(DateTime.now())) return null;
    final n = to.difference(from).inDays + 1;
    return const [7, 30, 90].contains(n) ? n : null;
  }

  Widget _body(Map<String, dynamic> d) {
    final c = context.bc;
    final byProduct = asList(d['by_product']);
    final byDate = asList(d['by_date']);
    final maxDay = byDate.fold<double>(0, (m, e) => asNum(e['earnings']) > m ? asNum(e['earnings']) : m);
    final totalRevenue = asNum(d['total_revenue']);
    final orders = asInt(d['total_orders']);

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      // The design's header: "FINANCES & SETTLEMENTS / Revenue Hub" and the range chip.
      Text('FINANCES & SETTLEMENTS', style: TextStyle(fontSize: 11.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: c.textSecondary)),
      Text('Revenue Hub', style: Alvy.display(size: 26, color: c.text, weight: FontWeight.w800)),
      const SizedBox(height: 8),
      Row(children: [
        InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: _range,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.date_range, size: 15, color: kOrange),
              const SizedBox(width: 5),
              Text('${formatDate(_from)} – ${formatDate(_to)}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: c.text)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final (n, label) in const [(7, 'Last 7 days'), (30, 'Last 30 days'), (90, 'Last 90 days')])
            Padding(padding: const EdgeInsets.only(right: 8), child: FilterPill(label, selected: _presetDays == n, onTap: () => _preset(n))),
          Padding(padding: const EdgeInsets.only(right: 8), child: FilterPill('Custom', selected: _presetDays == null, onTap: _range)),
        ]),
      ),
      const SizedBox(height: 14),
      riderHero('Your earnings', peso(d['total_earnings']), [
        ('Commission (${asNum(d['commission_rate'])}%)', peso(d['total_commission'])),
        ('Orders', '$orders'),
      ], icon: Icons.account_balance_wallet_outlined),
      // Total revenue, then the two small figures.
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: cardBox(context, radius: 20),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.trending_up, color: kOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total Revenue', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600)),
              FittedBox(child: Text(peso(totalRevenue), style: Alvy.display(size: 24, color: c.text, weight: FontWeight.w800))),
              Text('What buyers paid for your items', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ]),
          ),
        ]),
      ),
      Row(children: [
        riderFigure(context, 'Avg. order value', peso(orders == 0 ? 0 : totalRevenue / orders), Icons.receipt_long_outlined),
        const SizedBox(width: 10),
        riderFigure(context, 'Discounts you funded', peso(d['total_seller_funded']), Icons.local_offer_outlined),
      ]),
      const SizedBox(height: 14),
      // The design's "Sales Velocity" bars: one per day, the best day in orange.
      SectionCard(
        title: 'Sales Velocity',
        child: byDate.isEmpty
            ? Text('No earnings in this period.', style: TextStyle(color: c.muted))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Your earnings by day', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: LayoutBuilder(builder: (_, box) {
                    final shown = byDate.length > 31 ? byDate.sublist(byDate.length - 31) : byDate;
                    final w = (box.maxWidth / shown.length).clamp(4.0, 40.0);
                    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final e in shown)
                        SizedBox(
                          width: w,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: w > 10 ? 2 : 1),
                            child: Tooltip(
                              message: '${e['day']} · ${peso(e['earnings'])}',
                              child: Container(
                                height: maxDay == 0 ? 3 : (3 + 140 * asNum(e['earnings']) / maxDay),
                                decoration: BoxDecoration(
                                  color: asNum(e['earnings']) == maxDay && maxDay > 0 ? kOrange : Alvy.slateSoft,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ]);
                  }),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Text('${byDate.first['day']}', style: TextStyle(fontSize: 11, color: c.muted)),
                  const Spacer(),
                  Text('${byDate.last['day']}', style: TextStyle(fontSize: 11, color: c.muted)),
                ]),
                if (maxDay > 0) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.local_fire_department_outlined, size: 16, color: kOrange),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Best day: ${byDate.firstWhere((e) => asNum(e['earnings']) == maxDay)['day']} · ${peso(maxDay)}',
                          style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ),
                  ]),
                ],
              ]),
      ),
      // The design's "Top Revenue Drivers": units, a share bar and the share of revenue.
      SectionCard(
        title: 'Top Revenue Drivers',
        child: byProduct.isEmpty
            ? Text('No sales in this period.', style: TextStyle(color: c.muted))
            : Column(children: [
                for (final (i, p) in byProduct.indexed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: i == 0 ? kOrange : Alvy.slateSoft,
                        child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: i == 0 ? Colors.white : Alvy.slate)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontWeight: FontWeight.w700)),
                          Text('${p['qty']} unit${asInt(p['qty']) == 1 ? '' : 's'} sold', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: totalRevenue == 0 ? 0 : (asNum(p['revenue']) / totalRevenue).clamp(0.0, 1.0),
                              minHeight: 6,
                              color: i == 0 ? kOrange : Alvy.slate,
                              backgroundColor: c.surface,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(peso(p['earnings']), style: Alvy.display(size: 15, color: kOrange, weight: FontWeight.w800)),
                        Text(totalRevenue == 0 ? '—' : '${(100 * asNum(p['revenue']) / totalRevenue).toStringAsFixed(1)}% share',
                            style: TextStyle(fontSize: 11.5, color: Alvy.slate, fontWeight: FontWeight.w600)),
                      ]),
                    ]),
                  ),
              ]),
      ),
      ReportDownloadButtons(busy: _exporting, onDownload: _export),
      const SizedBox(height: 16),
    ]);
  }
}
