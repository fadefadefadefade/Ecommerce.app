import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

import '../../../services/api_client.dart';
import '../../../services/seller_api.dart';
import '../../../theme/buyer_colors.dart';
import '../seller_kit.dart';

/// A list screen that loads one seller page and refreshes after each action.
abstract class _ListPageState<T extends StatefulWidget> extends State<T> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  Future<ApiResponse> fetch();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = data == null;
      error = null;
    });
    final r = await fetch();
    if (!mounted) return;
    setState(() {
      loading = false;
      if (r.ok) {
        data = r.body;
      } else {
        error = r.message;
      }
    });
  }

  Future<ApiResponse> act(Future<ApiResponse> Function() call) async {
    final r = await runAction(context, call);
    if (r.ok) load();
    return r;
  }

  Widget page(String title, Widget Function(Map<String, dynamic> d) body, {Widget? fab}) => Scaffold(
        backgroundColor: context.bc.background,
        appBar: sellerBar(title),
        floatingActionButton: fab,
        body: LoadState(
          loading: loading,
          error: error,
          onRetry: load,
          child: data == null ? const SizedBox() : RefreshIndicator(color: kOrange, onRefresh: load, child: body(data!)),
        ),
      );
}

Widget _fab(String label, VoidCallback onPressed) => FloatingActionButton.extended(
      backgroundColor: kOrange,
      foregroundColor: Colors.white,
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
    );

Widget _tile(BuildContext context, {required String title, required String subtitle, required List<Widget> trailing, Widget? leading}) {
  final c = context.bc;
  // The design's list card: the icon in a soft orange square, a Jakarta title, muted details.
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: cardBox(context, radius: 16),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        if (leading != null) ...[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(12)),
            child: Center(child: leading),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15, color: c.text)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.35)),
          ]),
        ),
        ...trailing,
      ]),
    ),
  );
}

// ── Store vouchers ─────────────────────────────────────────────

class SellerVouchersScreen extends StatefulWidget {
  const SellerVouchersScreen({super.key});
  @override
  State<SellerVouchersScreen> createState() => _SellerVouchersScreenState();
}

class _SellerVouchersScreenState extends _ListPageState<SellerVouchersScreen> {
  @override
  Future<ApiResponse> fetch() => SellerApi.vouchers();

  Future<void> _open([int? id]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => VoucherFormScreen(voucherId: id)));
    if (saved == true) load();
  }

  @override
  Widget build(BuildContext context) => page('Store vouchers', (d) {
        final list = asList(d['vouchers']);
        if (list.isEmpty) return ListView(children: const [EmptyNote(Icons.confirmation_number_outlined, 'No store vouchers yet.')]);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
          for (final v in list)
            InkWell(
              onTap: () => _open(asInt(v['id'])),
              child: _tile(
                context,
                leading: const Icon(Icons.confirmation_number_outlined, color: kOrange),
                title: '${v['code']} · ${v['label']}',
                subtitle: '${v['name']}\nMin. spend ${peso(v['min_spend'])} · used ${v['used_count']}${v['usage_limit'] != null ? '/${v['usage_limit']}' : ''} · ${v['claims']} claimed'
                    '${v['ends_at'] != null ? '\nUntil ${formatDateTime(v['ends_at'])}' : ''}',
                trailing: [
                  Pill('${v['state']}', color: Pill.forState(v['state'])),
                  PopupMenuButton<String>(
                    onSelected: (a) async {
                      if (a == 'edit') return _open(asInt(v['id']));
                      if (a == 'toggle') {
                        await act(() => SellerApi.toggleVoucher(asInt(v['id'])));
                        return;
                      }
                      if (a == 'delete' &&await confirmAction(context, 'Delete ${v['code']}?', 'Buyers can no longer use it.', confirm: 'Delete', danger: true)) {
                        await act(() => SellerApi.deleteVoucher(asInt(v['id'])));
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'toggle', child: Text(v['is_active'] == true ? 'Turn off' : 'Turn on')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Color(0xFFDC2626)))),
                    ],
                  ),
                ],
              ),
            ),
        ]);
      }, fab: _fab('New voucher', () => _open()));
}

/// The web's store voucher form. Once buyers claimed it, only the end date and usage limit can change (A27).
class VoucherFormScreen extends StatefulWidget {
  final int? voucherId;
  const VoucherFormScreen({super.key, this.voucherId});
  @override
  State<VoucherFormScreen> createState() => _VoucherFormScreenState();
}

class _VoucherFormScreenState extends State<VoucherFormScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _max = TextEditingController();
  final _min = TextEditingController();
  final _usage = TextEditingController();
  final _perUser = TextEditingController(text: '1');
  String _type = 'fixed';
  String? _starts;
  String? _ends;
  bool _active = true;
  bool _claimable = true;
  bool _locked = false;
  final Set<int> _productIds = {};
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    // The live preview follows what is typed.
    for (final c in [_code, _name, _value, _min]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _value, _max, _min, _usage, _perUser]) {
      c.dispose();
    }
    super.dispose();
  }

  String _s(dynamic v) => v == null ? '' : (v is num && v % 1 == 0 ? '${v.toInt()}' : '$v');

  Future<void> _load() async {
    final r = await SellerApi.voucherForm(widget.voucherId);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _loading = false;
        _error = r.message;
      });
      return;
    }
    _products = asList(r.body['products']);
    _locked = r.body['locked'] == true;
    final v = r.body['voucher'] == null ? null : asMap(r.body['voucher']);
    if (v != null) {
      _code.text = _s(v['code']);
      _name.text = _s(v['name']);
      _type = _s(v['discount_type']);
      _value.text = _s(v['discount_value']);
      _max.text = _s(v['max_discount']);
      _min.text = _s(v['min_spend']);
      _usage.text = _s(v['usage_limit']);
      _perUser.text = _s(v['per_user_limit']);
      _starts = (v['starts_at'] as String?)?.replaceFirst('T', ' ');
      _ends = (v['ends_at'] as String?)?.replaceFirst('T', ' ');
      _active = v['is_active'] == true;
      _claimable = v['is_claimable'] == true;
      _productIds.addAll([for (final id in (v['product_ids'] as List? ?? [])) asInt(id)]);
      _someProducts = _productIds.isNotEmpty;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors = {};
    });
    final r = await SellerApi.saveVoucher(widget.voucherId, {
      'code': _code.text.trim(),
      'name': _name.text.trim(),
      'discount_type': _type,
      'discount_value': _value.text.trim(),
      'max_discount': _max.text.trim(),
      'min_spend': _min.text.trim(),
      'usage_limit': _usage.text.trim(),
      'per_user_limit': _perUser.text.trim(),
      'starts_at': _starts ?? '',
      'ends_at': _ends ?? '',
      'is_active': _active,
      'is_claimable': _claimable,
      'product_ids': _productIds.toList(),
    });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = r.fieldErrors;
    });
    showResult(context, r);
    if (r.ok) Navigator.pop(context, true);
  }

  /// "Selected products" chosen on the Eligible Products card (none ticked = the whole store, like before).
  bool _someProducts = false;

  /// The design's section card: an icon square and a Jakarta title, then the fields.
  Widget _sec(String title, IconData icon, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        decoration: cardBox(context, radius: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: kOrange),
            ),
            const SizedBox(width: 10),
            Text(title, style: Alvy.display(size: 18, color: context.bc.text, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...children,
        ]),
      );

  /// The design's date tile: caps label, the date, the time under it.
  Widget _dateTile(String label, String? value, ValueChanged<String?> set, String field, {bool enabled = true}) {
    final c = context.bc;
    final parts = (value ?? '').split(' ');
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: !enabled
            ? null
            : () async {
                final v = await pickDateTime(context, initial: value, future: false);
                if (v != null) setState(() => set(v));
              },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 11, letterSpacing: 0.5, fontWeight: FontWeight.w700, color: c.textSecondary))),
              if (value != null && enabled)
                InkWell(onTap: () => setState(() => set(null)), child: Icon(Icons.close, size: 16, color: c.muted)),
            ]),
            const SizedBox(height: 4),
            Text(value == null ? 'No limit' : formatDate(parts.first), style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
            Text(value == null ? 'Tap to set' : (parts.length > 1 ? parts[1] : ''), style: TextStyle(fontSize: 12, color: c.textSecondary)),
            if (_errors[field] != null) Text(_errors[field]!, style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626))),
          ]),
        ),
      ),
    );
  }

  /// A toggle row like the design's "ALVY Discovery Deals".
  Widget _toggle(IconData icon, String title, String sub, bool value, ValueChanged<bool>? onChanged) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(color: context.bc.subtle, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          CircleAvatar(radius: 17, backgroundColor: Alvy.orangeSoft, child: Icon(icon, size: 18, color: kOrange)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: context.bc.text)),
              Text(sub, style: TextStyle(fontSize: 12, color: context.bc.textSecondary)),
            ]),
          ),
          Switch(value: value, onChanged: onChanged),
        ]),
      );

  /// One of the two Eligible Products choices.
  Widget _scope(String title, String sub, IconData icon, bool on, VoidCallback? onTap) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: on ? context.bc.surface : context.bc.subtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? kOrange : Colors.transparent, width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 20, color: on ? kOrange : context.bc.textSecondary),
                const Spacer(),
                Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20, color: on ? kOrange : context.bc.muted),
              ]),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: on ? kOrange : context.bc.text)),
              Text(sub, style: TextStyle(fontSize: 12, color: context.bc.textSecondary)),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final lockedHint = _locked ? 'Buyers claimed this voucher: only the end date and usage limit can change.' : null;
    final value = _value.text.trim().isEmpty ? '0' : _value.text.trim();
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar(widget.voucherId == null ? 'New store voucher' : 'Edit voucher'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          // The design's live preview: the ticket buyers will see.
          Row(children: [
            const Icon(Icons.circle, size: 8, color: kOrange),
            const SizedBox(width: 6),
            Text('LIVE CUSTOMER PREVIEW', style: TextStyle(fontSize: 11.5, letterSpacing: 0.5, fontWeight: FontWeight.w800, color: c.textSecondary)),
          ]),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: cardBox(context, radius: 18),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 96,
                  color: kOrange,
                  padding: const EdgeInsets.all(8),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FittedBox(
                      child: Text(_type == 'percent' ? '$value%' : '₱$value',
                          style: Alvy.display(size: 26, color: Colors.white, weight: FontWeight.w800)),
                    ),
                    const Text('OFF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8)),
                  ]),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(99)),
                        child: Text(_code.text.trim().isEmpty ? 'CODE' : _code.text.trim().toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Alvy.orangeDark)),
                      ),
                      const SizedBox(height: 6),
                      Text(_name.text.trim().isEmpty ? 'Voucher name' : _name.text.trim(), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700)),
                      Text(_min.text.trim().isEmpty ? 'No min. spend' : 'Min. spend ₱${_min.text.trim()}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.schedule, size: 13, color: c.muted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(_ends == null ? 'No end date' : 'Ends ${formatDate(_ends!.split(' ').first)}', style: TextStyle(fontSize: 11.5, color: c.muted))),
                        if (_claimable) const Text('Claim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kOrange)),
                      ]),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          if (lockedHint != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Alvy.warnSoft, borderRadius: BorderRadius.circular(14)),
              child: Text(lockedHint, style: TextStyle(color: Alvy.warnText)),
            ),
          _sec('Voucher Basics', Icons.edit_note, [
            FormInput(_name, 'Voucher display name *', readOnly: _locked, maxLength: 120, error: _errors['name']),
            FormInput(_code, 'Claim code *', readOnly: _locked, helper: '4 to 12 letters and numbers, e.g. SALE1111.', error: _errors['code']),
            Text('Discount value', style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
            const SizedBox(height: 8),
            // The design's two-way switch: a beige track, the chosen side on white.
            Container(
              padding: const EdgeInsets.all(4),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                for (final (key, label, icon) in const [('fixed', 'Fixed (₱)', Icons.payments_outlined), ('percent', 'Percentage (%)', Icons.percent)])
                  Expanded(
                    child: GestureDetector(
                      onTap: _locked ? null : () => setState(() => _type = key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: _type == key ? c.surface : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(icon, size: 16, color: _type == key ? kOrange : c.textSecondary),
                          const SizedBox(width: 6),
                          Text(label, style: TextStyle(fontWeight: _type == key ? FontWeight.w700 : FontWeight.w500, color: _type == key ? kOrange : c.textSecondary)),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
            FormInput(_value, _type == 'percent' ? 'Discount (%) *' : 'Discount (₱) *', readOnly: _locked, keyboard: TextInputType.number,
                error: _errors['discount_value']),
            if (_type == 'percent') FormInput(_max, 'Maximum discount (₱)', readOnly: _locked, keyboard: TextInputType.number, error: _errors['max_discount']),
          ]),
          _sec('Spend & Usage Rules', Icons.tune, [
            FormInput(_min, 'Minimum order basket (₱)', readOnly: _locked, keyboard: TextInputType.number,
                helper: 'Orders must reach this amount to use the voucher.', error: _errors['min_spend']),
            FormInput(_usage, 'Total usage pool', keyboard: TextInputType.number, helper: 'Blank = no limit', error: _errors['usage_limit']),
            FormInput(_perUser, 'Usage limit per buyer *', readOnly: _locked, keyboard: TextInputType.number, error: _errors['per_user_limit']),
          ]),
          _sec('Validity Schedule', Icons.calendar_month_outlined, [
            Row(children: [
              _dateTile('STARTS', _starts, (v) => _starts = v, 'starts_at', enabled: !_locked),
              const SizedBox(width: 10),
              _dateTile('ENDS', _ends, (v) => _ends = v, 'ends_at'),
            ]),
            const SizedBox(height: 12),
            _toggle(Icons.flash_on_outlined, 'Active', 'Buyers can use it at checkout', _active, (v) => setState(() => _active = v)),
            _toggle(Icons.storefront_outlined, 'Buyers can claim it', 'Shown on your store page to collect', _claimable,
                _locked ? null : (v) => setState(() => _claimable = v)),
          ]),
          if (_products.isNotEmpty)
            _sec('Eligible Products', Icons.category_outlined, [
              Row(children: [
                _scope('All Store Items', 'Entire catalog', Icons.storefront_outlined, !_someProducts,
                    _locked ? null : () => setState(() {
                          _someProducts = false;
                          _productIds.clear();
                        })),
                const SizedBox(width: 10),
                _scope('Selected Items', 'Pick products', Icons.checklist, _someProducts, _locked ? null : () => setState(() => _someProducts = true)),
              ]),
              if (_someProducts) ...[
                const SizedBox(height: 8),
                for (final p in _products)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _productIds.contains(asInt(p['id'])),
                    activeColor: kOrange,
                    title: Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onChanged: _locked ? null : (v) => setState(() => v == true ? _productIds.add(asInt(p['id'])) : _productIds.remove(asInt(p['id']))),
                  ),
              ],
              const SizedBox(height: 10),
            ]),
          BusyButton(widget.voucherId == null ? 'Publish voucher' : 'Save voucher', busy: _saving, icon: Icons.rocket_launch_outlined, onPressed: _save),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ── Flash sales ────────────────────────────────────────────────

class SellerFlashSalesScreen extends StatefulWidget {
  const SellerFlashSalesScreen({super.key});
  @override
  State<SellerFlashSalesScreen> createState() => _SellerFlashSalesScreenState();
}

class _SellerFlashSalesScreenState extends _ListPageState<SellerFlashSalesScreen> {
  @override
  Future<ApiResponse> fetch() => SellerApi.flashSales();

  Future<void> _add() async {
    final products = asList(data?['products']);
    if (products.isEmpty) {
      return showError(context, 'Flash sales are for live, in-stock products without options.');
    }
    final body = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FlashSaleSheet(products: products),
    );
    if (body != null) await act(() => SellerApi.addFlashSale(body));
  }

  @override
  Widget build(BuildContext context) => page('Flash sales', (d) {
        final c = context.bc;
        final list = asList(d['sales']);
        final live = list.where((x) => x['state'] == 'Ongoing' || x['state'] == 'Live').length;
        final upcoming = list.where((x) => x['state'] == 'Upcoming').length;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          // The design's campaign header: a beige card with the counts and what a flash sale does.
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(99)),
                  child: const Text('FLASH DEALS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Alvy.orangeDark, letterSpacing: 0.4)),
                ),
                const Spacer(),
                const Icon(Icons.alarm, size: 18, color: kOrange),
                const SizedBox(width: 4),
                Text('$live live · $upcoming upcoming', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kOrange)),
              ]),
              const SizedBox(height: 12),
              Text('Your Flash Sales', style: Alvy.display(size: 21, color: c.text, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('A lower price for a set time and quantity. Buyers can get a reminder before it starts.',
                  style: TextStyle(color: c.textSecondary, height: 1.4)),
            ]),
          ),
          Row(children: [
            Expanded(child: Text('Scheduled Products', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700))),
            if (list.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(99)),
                child: Text('${list.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: Alvy.orangeDark)),
              ),
          ]),
          const SizedBox(height: 12),
          if (list.isEmpty) const EmptyNote(Icons.flash_on_outlined, 'No flash sales yet.'),
          for (final s in list) _saleCard(s),
          // The design's "+ Add Another Product to Slot" button.
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _add,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_circle_outline, color: Alvy.slate),
                const SizedBox(width: 8),
                Text('Add Another Product', style: TextStyle(fontWeight: FontWeight.w700, color: Alvy.slate, fontSize: 15)),
              ]),
            ),
          ),
        ]);
      });

  /// One scheduled flash sale as the design's "allocated product" card.
  Widget _saleCard(Map s) {
    final c = context.bc;
    Widget box(String label, IconData icon, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(icon, size: 16, color: Alvy.slate),
                const SizedBox(width: 6),
                Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: c.text))),
              ]),
            ]),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: cardBox(context, radius: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.flash_on, color: kOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['product']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(peso(s['flash_price']), style: Alvy.display(size: 24, color: kOrange, weight: FontWeight.w800)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Pill('${s['state']}', color: Pill.forState(s['state'])),
            if (s['state'] == 'Upcoming')
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                onPressed: () async {
                  if (await confirmAction(context, 'Delete this flash sale?', 'It won\'t run.', confirm: 'Delete', danger: true)) {
                    await act(() => SellerApi.deleteFlashSale(asInt(s['id'])));
                  }
                },
              ),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.schedule, size: 16, color: kOrange),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${formatDateTime(s['starts_at'])} – ${formatDateTime(s['ends_at'])}',
                style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          box('Stock for sale', Icons.lock_outline, '${s['quantity']} units'),
          const SizedBox(width: 10),
          box('Sold', Icons.shopping_bag_outlined, '${s['sold']} of ${s['quantity']}'),
        ]),
        if (asNum(s['reminders']) > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Alvy.slateSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.notifications_active_outlined, size: 18, color: Alvy.slate),
              const SizedBox(width: 8),
              Expanded(child: Text('${s['reminders']} buyer(s) asked for a reminder', style: TextStyle(color: Alvy.slate, fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _FlashSaleSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  const _FlashSaleSheet({required this.products});
  @override
  State<_FlashSaleSheet> createState() => _FlashSaleSheetState();
}

class _FlashSaleSheetState extends State<_FlashSaleSheet> {
  int? _product;
  final _price = TextEditingController();
  final _qty = TextEditingController();
  String? _starts;
  String? _ends;

  @override
  void dispose() {
    _price.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.products.where((x) => asInt(x['id']) == _product).firstOrNull;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New flash sale', style: Alvy.display(size: 20, color: context.bc.text, weight: FontWeight.w800)),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _product,
              decoration: const InputDecoration(labelText: 'Product', isDense: true),
              items: [for (final x in widget.products) DropdownMenuItem(value: asInt(x['id']), child: Text('${x['title']}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => _product = v),
            ),
            if (p != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Price ${peso(p['price'])} · stock ${p['stock']}', style: const TextStyle(fontSize: 12))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FormInput(_price, 'Flash price (₱)', keyboard: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: FormInput(_qty, 'Quantity', keyboard: TextInputType.number)),
            ]),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow_outlined),
              title: Text(_starts ?? 'Starts'),
              onTap: () async {
                final v = await pickDateTime(context, initial: _starts);
                if (v != null) setState(() => _starts = v);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stop_outlined),
              title: Text(_ends ?? 'Ends'),
              onTap: () async {
                final v = await pickDateTime(context, initial: _ends ?? _starts);
                if (v != null) setState(() => _ends = v);
              },
            ),
            const SizedBox(height: 8),
            BusyButton('Schedule flash sale', busy: false, icon: Icons.flash_on, onPressed: () {
              Navigator.pop(context, {
                'product_id': _product,
                'flash_price': _price.text.trim(),
                'quantity': _qty.text.trim(),
                'starts_at': _starts,
                'ends_at': _ends,
              });
            }),
          ]),
        ),
      ),
    );
  }
}

// ── Bundles & promos ───────────────────────────────────────────

class SellerPromotionsScreen extends StatefulWidget {
  const SellerPromotionsScreen({super.key});
  @override
  State<SellerPromotionsScreen> createState() => _SellerPromotionsScreenState();
}

class _SellerPromotionsScreenState extends _ListPageState<SellerPromotionsScreen> {
  @override
  Future<ApiResponse> fetch() => SellerApi.promotions();

  Future<void> _add() async {
    final body = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PromotionSheet(products: asList(data?['products'])),
    );
    if (body != null) await act(() => SellerApi.addPromotion(body));
  }

  @override
  Widget build(BuildContext context) => page('Bundles & promos', (d) {
        final c = context.bc;
        final list = asList(d['promotions']);
        final active = list.where((x) => x['is_active'] == true).length;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          // The design's header: the engine chip, "PROMOTION TYPE" and the big title.
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.auto_awesome, size: 14, color: Alvy.orangeDark),
                const SizedBox(width: 5),
                Text('$active active', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Alvy.orangeDark)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Text('PROMOTION TYPE', style: TextStyle(fontSize: 11.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: Alvy.slate)),
          Text('Shop More & Save', style: Alvy.display(size: 22, color: c.text, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Bundle discounts and buy-X-get-Y deals on your products.', style: TextStyle(color: c.textSecondary)),
          const SizedBox(height: 16),
          if (list.isEmpty) const EmptyNote(Icons.redeem_outlined, 'No promotions yet.'),
          for (final p in list) _promoCard(p),
          const SizedBox(height: 4),
          BusyButton('Create Promotion', busy: false, icon: Icons.rocket_launch_outlined, onPressed: _add),
        ]);
      });

  /// One promotion as the design's tier card.
  Widget _promoCard(Map p) {
    final c = context.bc;
    final on = p['is_active'] == true;
    final bundle = p['type'] != 'bxgy';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: cardBox(context, radius: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: bundle ? Alvy.orangeSoft : Alvy.slateSoft, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(bundle ? Icons.check_circle_outline : Icons.redeem, size: 14, color: bundle ? Alvy.orangeDark : Alvy.slate),
              const SizedBox(width: 5),
              Text(bundle ? 'Bundle Discount' : 'Buy X Get Y', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: bundle ? Alvy.orangeDark : Alvy.slate)),
            ]),
          ),
          const Spacer(),
          Switch(value: on, onChanged: (_) => act(() => SellerApi.togglePromotion(asInt(p['id'])))),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text('${p['name']}', style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: on ? Alvy.orangeSoft : c.subtle, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: on ? kOrange : Alvy.slateSoft,
                child: Icon(bundle ? Icons.shopping_basket_outlined : Icons.card_giftcard, size: 17, color: on ? Colors.white : Alvy.slate),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('${p['label']}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text))),
            ]),
          ),
        ),
        Row(children: [
          Icon(Icons.schedule, size: 15, color: c.muted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(p['ends_at'] != null ? 'Until ${formatDateTime(p['ends_at'])}' : 'No end date',
                style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            onPressed: () async {
              if (await confirmAction(context, 'Delete "${p['name']}"?', 'Buyers no longer get this deal.', confirm: 'Delete', danger: true)) {
                await act(() => SellerApi.deletePromotion(asInt(p['id'])));
              }
            },
          ),
        ]),
      ]),
    );
  }
}

class _PromotionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  const _PromotionSheet({required this.products});
  @override
  State<_PromotionSheet> createState() => _PromotionSheetState();
}

class _PromotionSheetState extends State<_PromotionSheet> {
  String _type = 'bundle';
  final _name = TextEditingController();
  final _minQty = TextEditingController(text: '2');
  final _percent = TextEditingController();
  final _freeQty = TextEditingController(text: '1');
  final Set<int> _ids = {};
  int? _free;
  String? _ends;

  @override
  void dispose() {
    for (final c in [_name, _minQty, _percent, _freeQty]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New promotion', style: Alvy.display(size: 20, color: context.bc.text, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Promotion logic', style: TextStyle(fontWeight: FontWeight.w600, color: context.bc.textSecondary)),
            const SizedBox(height: 8),
            // The design's logic pills.
            Wrap(spacing: 8, children: [
              for (final (key, label) in const [('bundle', 'Bundle Discount'), ('bxgy', 'Buy X Get Y')])
                FilterPill(label, selected: _type == key, onTap: () => setState(() {
                  _type = key;
                  _minQty.text = _type == 'bundle' ? '2' : '1';
                })),
            ]),
            const SizedBox(height: 12),
            FormInput(_name, 'Name', maxLength: 120),
            Text('Products', style: TextStyle(fontWeight: FontWeight.w700, color: context.bc.text)),
            for (final p in widget.products)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: kOrange,
                value: _ids.contains(asInt(p['id'])),
                title: Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                onChanged: (v) => setState(() => v == true ? _ids.add(asInt(p['id'])) : _ids.remove(asInt(p['id']))),
              ),
            const SizedBox(height: 8),
            FormInput(_minQty, _type == 'bundle' ? 'Items in the bundle (min. 2)' : 'Buy how many', keyboard: TextInputType.number),
            if (_type == 'bundle')
              FormInput(_percent, 'Bundle discount (%)', keyboard: TextInputType.number)
            else ...[
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _free,
                decoration: const InputDecoration(labelText: 'Free product', isDense: true),
                items: [for (final p in widget.products) DropdownMenuItem(value: asInt(p['id']), child: Text('${p['title']}', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _free = v),
              ),
              const SizedBox(height: 12),
              FormInput(_freeQty, 'Free quantity', keyboard: TextInputType.number),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_ends ?? 'Ends (optional)'),
              onTap: () async {
                final v = await pickDateTime(context, initial: _ends);
                if (v != null) setState(() => _ends = v);
              },
            ),
            BusyButton('Create Promotion', busy: false, icon: Icons.rocket_launch_outlined, onPressed: () {
              Navigator.pop(context, {
                'name': _name.text.trim(),
                'type': _type,
                'product_ids': _ids.toList(),
                'min_qty': _minQty.text.trim(),
                if (_type == 'bundle') 'discount_percent': _percent.text.trim(),
                if (_type == 'bxgy') ...{'free_product_id': _free, 'free_qty': _freeQty.text.trim()},
                if (_ends != null) 'ends_at': _ends,
              });
            }),
          ]),
        ),
      ),
    );
  }
}

// ── Store categories ───────────────────────────────────────────

class SellerStoreCategoriesScreen extends StatefulWidget {
  const SellerStoreCategoriesScreen({super.key});
  @override
  State<SellerStoreCategoriesScreen> createState() => _SellerStoreCategoriesScreenState();
}

/// The categories on the store page, picked from the ALVY categories (motor parts and makeup → "Automotive &
/// Motorcycle" and "Health & Beauty"). A product is listed under the one for its ALVY category.
class _SellerStoreCategoriesScreenState extends _ListPageState<SellerStoreCategoriesScreen> {
  @override
  Future<ApiResponse> fetch() => SellerApi.storeCategories();

  /// Pick an ALVY category the store doesn't have yet.
  Future<void> _add() async {
    final available = asList(data?['available']);
    if (available.isEmpty) return showError(context, 'You have added every ALVY category.');
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Add a category from ALVY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final c in available)
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline, color: kOrange),
                    title: Text('${c['name']}'),
                    onTap: () => Navigator.pop(ctx, asInt(c['id'])),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (picked != null) await act(() => SellerApi.addStoreCategory(picked));
  }

  int get _maxName => asInt(data?['max_name']) == 0 ? 40 : asInt(data?['max_name']);

  Future<String?> _ask(String title, [String initial = '']) async {
    final ctrl = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, maxLength: _maxName, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    return v;
  }

  Future<void> _delete(Map<String, dynamic> cat) async {
    final r = await runAction(context, () => SellerApi.deleteStoreCategory(asInt(cat['id'])));
    if (!r.ok || !mounted) return;
    // A category with products or subcategories: the web asks to confirm first.
    if (r.body['warning'] == true) {
      if (await confirmAction(context, 'Delete "${cat['name']}"?', r.message, confirm: 'Delete', danger: true)) {
        if (mounted) await act(() => SellerApi.deleteStoreCategory(asInt(cat['id']), confirm: true));
      }
      return;
    }
    load();
  }

  Future<void> _move(List<Map<String, dynamic>> list, int i, int dir) async {
    final ids = list.map((c) => asInt(c['id'])).toList();
    final j = i + dir;
    if (j < 0 || j >= ids.length) return;
    final t = ids[i];
    ids[i] = ids[j];
    ids[j] = t;
    await act(() => SellerApi.reorderStoreCategories(ids));
  }

  Widget _row(Map<String, dynamic> cat, List<Map<String, dynamic>> siblings, int index, {bool child = false}) {
    final hidden = cat['is_hidden'] == true;
    return ListTile(
      contentPadding: EdgeInsets.only(left: child ? 40 : 12, right: 4),
      dense: child,
      leading: child
          ? Icon(Icons.subdirectory_arrow_right, size: 18, color: context.bc.muted)
          : Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: hidden ? context.bc.subtle : Alvy.orangeSoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.category_outlined, size: 19, color: hidden ? context.bc.muted : kOrange),
            ),
      title: Text('${cat['name']}', style: TextStyle(color: hidden ? context.bc.muted : context.bc.text, fontWeight: child ? FontWeight.w600 : FontWeight.w700)),
      subtitle: Text('${cat['products']} product(s)${hidden ? ' · hidden' : ''}${cat['from_alvy'] == true ? '' : ' · your own name'}',
          style: TextStyle(fontSize: 12, color: context.bc.textSecondary)),
      trailing: PopupMenuButton<String>(
        onSelected: (a) async {
          final id = asInt(cat['id']);
          switch (a) {
            case 'rename':
              final name = await _ask('Rename', '${cat['name']}');
              if (name != null && name.isNotEmpty) await act(() => SellerApi.renameStoreCategory(id, name));
            case 'toggle':
              await act(() => SellerApi.toggleStoreCategory(id));
            case 'up':
              await _move(siblings, index, -1);
            case 'down':
              await _move(siblings, index, 1);
            case 'delete':
              await _delete(cat);
          }
        },
        itemBuilder: (_) => [
          // ALVY categories keep ALVY's name; only older categories with a typed name can be renamed.
          if (cat['from_alvy'] != true) const PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'toggle', child: Text(hidden ? 'Show' : 'Hide')),
          if (index > 0) const PopupMenuItem(value: 'up', child: Text('Move up')),
          if (index < siblings.length - 1) const PopupMenuItem(value: 'down', child: Text('Move down')),
          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => page('Store categories', (d) {
        final c = context.bc;
        final list = asList(d['categories']);
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          // The design's "Storefront Sections" header.
          Text('Storefront Sections', style: Alvy.display(size: 21, color: c.text, weight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('Shown as tabs on your store page. Use the ⋮ menu to hide, reorder or delete.', style: TextStyle(color: c.textSecondary)),
          const SizedBox(height: 14),
          if (list.isEmpty)
            const EmptyNote(Icons.category_outlined, 'Add the ALVY categories you sell in (e.g. Automotive & Motorcycle, Health & Beauty). They show as tabs on your store page.'),
          for (var i = 0; i < list.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: cardBox(context, radius: 18),
              child: Column(children: [
                _row(list[i], list, i),
                for (var j = 0; j < asList(list[i]['children']).length; j++)
                  _row(asList(list[i]['children'])[j], asList(list[i]['children']), j, child: true),
              ]),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _add,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_circle_outline, color: Alvy.slate),
                const SizedBox(width: 8),
                Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700, color: Alvy.slate, fontSize: 15)),
              ]),
            ),
          ),
        ]);
      });
}
