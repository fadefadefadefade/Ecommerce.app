import 'package:flutter/material.dart';

import '../../../services/seller_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/report_download.dart' show saveReportDownload;
import '../seller_kit.dart';

/// The website's Commission details: each order line with the rate stored at purchase, ALVY's commission and the
/// seller's net, by period and status (Pending, Finalized, Refunded, Reversed, Unpaid), with CSV / Excel export.
class SellerCommissionsScreen extends StatefulWidget {
  final String period;
  final DateTimeRange? custom;
  const SellerCommissionsScreen({super.key, this.period = 'month', this.custom});
  @override
  State<SellerCommissionsScreen> createState() => _SellerCommissionsScreenState();
}

class _SellerCommissionsScreenState extends State<SellerCommissionsScreen> {
  late String _period = widget.period;
  late DateTimeRange? _custom = widget.custom;
  String? _status;
  Map<String, dynamic>? _d;
  List<Map<String, dynamic>> _rows = [];
  int _page = 1;
  int _last = 1;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _from => _custom == null ? null : ymd(_custom!.start);
  String? get _to => _custom == null ? null : ymd(_custom!.end);

  Future<void> _load({bool more = false}) async {
    final r = await SellerApi.commissions(period: _period, from: _from, to: _to, status: _status, page: more ? _page + 1 : 1);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (!r.ok) return;
      _d = r.body;
      final rows = asList(r.body['data']);
      _rows = more ? [..._rows, ...rows] : rows;
      _page = asInt(asMap(r.body['meta'])['current_page']);
      _last = asInt(asMap(r.body['meta'])['last_page']);
    });
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
    setState(() {
      _period = p;
      _loading = true;
    });
    _load();
  }

  Future<void> _export(String format) async {
    setState(() => _exporting = true);
    final f = await SellerApi.exportCommissions(format, period: _period, from: _from, to: _to, status: _status);
    if (!mounted) return;
    setState(() => _exporting = false);
    if (!f.ok) return showError(context, f.error!.message);
    await saveReportDownload(context, f);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final d = _d;
    final s = asMap(d?['summary']);
    final statuses = asMap(d?['statuses']);
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Commission details'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: d == null
            ? const SizedBox()
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  Wrap(spacing: 6, children: [
                    for (final (key, label) in const [('today', 'Today'), ('week', 'This week'), ('month', 'This month'), ('custom', 'Custom')])
                      ChoiceChip(label: Text(label), selected: _period == key, selectedColor: kOrange.withValues(alpha: .15), onSelected: (_) => _pickPeriod(key)),
                  ]),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${d['range_label']}', style: TextStyle(color: c.muted, fontSize: 12))),
                  StatGrid([
                    StatTile(label: 'Sales', value: peso(s['gross']), icon: Icons.payments_outlined, color: const Color(0xFF2563EB),
                        hint: asNum(s['refunds']) > 0 ? '${peso(s['refunds'])} refunded' : null),
                    StatTile(label: 'Commission', value: peso(s['commission']), icon: Icons.percent, color: const Color(0xFF9333EA),
                        hint: 'Pending ${peso(s['pending_commission'])} · final ${peso(s['finalized_commission'])}'),
                    StatTile(label: 'Net earnings', value: peso(s['net']), icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF15803D)),
                    StatTile(label: 'Lines', value: '${asInt(s['lines'])}', icon: Icons.list_alt, hint: 'Current rate ${asNum(d['configured_rate'])}%'),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Status', isDense: true, border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All statuses')),
                          for (final e in statuses.entries) DropdownMenuItem<String?>(value: e.key, child: Text('${e.value}')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _status = v;
                            _loading = true;
                          });
                          _load();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _exporting ? null : () => _export('csv'), child: const Text('CSV')),
                    const SizedBox(width: 6),
                    OutlinedButton(onPressed: _exporting ? null : () => _export('xlsx'), child: const Text('Excel')),
                  ]),
                  const SizedBox(height: 10),
                  if (_rows.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('No order lines in this period.', textAlign: TextAlign.center, style: TextStyle(color: c.muted))),
                  for (final r in _rows)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text('${r['order_number']} · ${formatDate(r['placed_at'])}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            Pill('${r['status_label']}', color: Pill.forState('${r['status']}')),
                          ]),
                          Text('${r['product']}${r['option'] != null ? ' (${r['option']})' : ''} ×${r['quantity']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('Gross ${peso(r['gross'])} · ${asNum(r['rate'])}% = ${peso(r['commission'])} · You earn ${peso(r['net'])}',
                              style: TextStyle(fontSize: 12, color: c.muted)),
                        ]),
                      ),
                    ),
                  if (_page < _last) TextButton(onPressed: () => _load(more: true), child: const Text('Load more')),
                ]),
              ),
      ),
    );
  }
}
