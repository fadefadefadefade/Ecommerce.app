
import 'package:flutter/material.dart';

import '../../../services/seller_api.dart';
import '../../../theme/buyer_colors.dart';
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
            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            : PopupMenuButton<String>(
                tooltip: 'Export',
                icon: const Icon(Icons.download_outlined),
                onSelected: _export,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'pdf', child: Text('Download PDF')),
                  PopupMenuItem(value: 'xlsx', child: Text('Download Excel (XLSX)')),
                  PopupMenuItem(value: 'csv', child: Text('Download CSV')),
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

  Widget _body(Map<String, dynamic> d) {
    final c = context.bc;
    final byProduct = asList(d['by_product']);
    final byDate = asList(d['by_date']);
    final maxDay = byDate.fold<double>(0, (m, e) => asNum(e['earnings']) > m ? asNum(e['earnings']) : m);

    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Expanded(
          child: InkWell(
            onTap: _range,
            child: Text('${formatDate(_from)} – ${formatDate(_to)}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
          ),
        ),
        for (final p in const [(7, '7d'), (30, '30d'), (90, '90d')])
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ActionChip(label: Text(p.$2), onPressed: () => _preset(p.$1), visualDensity: VisualDensity.compact),
          ),
      ]),
      const SizedBox(height: 10),
      StatGrid([
        StatTile(label: 'Revenue', value: peso(d['total_revenue']), icon: Icons.payments_outlined, color: const Color(0xFF2563EB)),
        StatTile(label: 'Your earnings', value: peso(d['total_earnings']), icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF15803D)),
        StatTile(label: 'Commission (${asNum(d['commission_rate'])}%)', value: peso(d['total_commission']), icon: Icons.percent, color: const Color(0xFF9333EA)),
        StatTile(label: 'Discounts you funded', value: peso(d['total_seller_funded']), icon: Icons.local_offer_outlined),
        StatTile(label: 'Orders', value: '${d['total_orders']}', icon: Icons.receipt_long_outlined),
      ]),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Sales by product',
        child: byProduct.isEmpty
            ? Text('No sales in this period.', style: TextStyle(color: c.muted))
            : Column(children: [
                for (final p in byProduct)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${p['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.text, fontWeight: FontWeight.w600)),
                          Text('${p['qty']} sold · revenue ${peso(p['revenue'])}', style: TextStyle(fontSize: 12, color: c.muted)),
                        ]),
                      ),
                      Text(peso(p['earnings']), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                    ]),
                  ),
              ]),
      ),
      SectionCard(
        title: 'Earnings by day',
        child: byDate.isEmpty
            ? Text('No earnings in this period.', style: TextStyle(color: c.muted))
            : Column(children: [
                for (final e in byDate)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      SizedBox(width: 84, child: Text('${e['day']}', style: TextStyle(fontSize: 12, color: c.muted))),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (_, box) => Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 10,
                              width: maxDay == 0 ? 2 : (box.maxWidth * asNum(e['earnings']) / maxDay).clamp(2, box.maxWidth),
                              decoration: BoxDecoration(color: kOrange, borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 90, child: Text(peso(e['earnings']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                    ]),
                  ),
              ]),
      ),
      ReportDownloadButtons(busy: _exporting, onDownload: _export),
      const SizedBox(height: 16),
    ]);
  }
}
