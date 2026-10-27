import 'package:flutter/material.dart';

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
  return Card(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 8),
    color: c.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        if (leading != null) ...[leading, const SizedBox(width: 10)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: c.muted)),
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
        return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
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

  Widget _date(String label, String? value, ValueChanged<String?> set, String field, {bool enabled = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: !enabled
              ? null
              : () async {
                  final v = await pickDateTime(context, initial: value, future: false);
                  if (v != null) setState(() => set(v));
                },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              enabled: enabled,
              errorText: _errors[field],
              errorMaxLines: 3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              suffixIcon: value == null || !enabled ? const Icon(Icons.event, size: 18) : InkWell(onTap: () => setState(() => set(null)), child: const Icon(Icons.close, size: 18)),
            ),
            child: Text(value ?? 'No limit', style: const TextStyle(fontSize: 13)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final lockedHint = _locked ? 'Buyers claimed this voucher: only the end date and usage limit can change.' : null;
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar(widget.voucherId == null ? 'New store voucher' : 'Edit voucher'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (lockedHint != null)
            Card(color: const Color(0xFFFFF7ED), child: Padding(padding: const EdgeInsets.all(12), child: Text(lockedHint, style: const TextStyle(color: Color(0xFF9A3412))))),
          SectionCard(
            child: Column(children: [
              FormInput(_code, 'Voucher code *', readOnly: _locked, helper: '4 to 12 letters and numbers, e.g. SALE1111.', error: _errors['code']),
              FormInput(_name, 'Name *', readOnly: _locked, maxLength: 120, error: _errors['name']),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<String>(
                  segments: const [ButtonSegment(value: 'fixed', label: Text('₱ off')), ButtonSegment(value: 'percent', label: Text('% off'))],
                  selected: {_type},
                  onSelectionChanged: _locked ? null : (s) => setState(() => _type = s.first),
                ),
              ),
              FormInput(_value, _type == 'percent' ? 'Discount (%) *' : 'Discount (₱) *', readOnly: _locked, keyboard: TextInputType.number, error: _errors['discount_value']),
              if (_type == 'percent') FormInput(_max, 'Maximum discount (₱)', readOnly: _locked, keyboard: TextInputType.number, error: _errors['max_discount']),
              FormInput(_min, 'Minimum spend (₱)', readOnly: _locked, keyboard: TextInputType.number, error: _errors['min_spend']),
              Row(children: [
                Expanded(child: FormInput(_usage, 'Usage limit', keyboard: TextInputType.number, helper: 'Blank = no limit', error: _errors['usage_limit'])),
                const SizedBox(width: 8),
                Expanded(child: FormInput(_perUser, 'Per buyer *', readOnly: _locked, keyboard: TextInputType.number, error: _errors['per_user_limit'])),
              ]),
              _date('Starts', _starts, (v) => _starts = v, 'starts_at', enabled: !_locked),
              _date('Ends', _ends, (v) => _ends = v, 'ends_at'),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, activeThumbColor: kOrange, title: const Text('Active'), onChanged: (v) => setState(() => _active = v)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _claimable,
                activeThumbColor: kOrange,
                title: const Text('Buyers can claim it'),
                subtitle: const Text('Shown on your store page to collect.'),
                onChanged: _locked ? null : (v) => setState(() => _claimable = v),
              ),
            ]),
          ),
          if (_products.isNotEmpty)
            SectionCard(
              title: 'Only for these products (optional)',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('None selected = the whole store.', style: TextStyle(fontSize: 12, color: context.bc.muted)),
                for (final p in _products)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _productIds.contains(asInt(p['id'])),
                    activeColor: kOrange,
                    title: Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onChanged: _locked ? null : (v) => setState(() => v == true ? _productIds.add(asInt(p['id'])) : _productIds.remove(asInt(p['id']))),
                  ),
              ]),
            ),
          BusyButton('Save voucher', busy: _saving, onPressed: _save),
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
        final list = asList(d['sales']);
        if (list.isEmpty) return ListView(children: const [EmptyNote(Icons.flash_on_outlined, 'No flash sales yet.')]);
        return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
          for (final s in list)
            _tile(
              context,
              leading: const Icon(Icons.flash_on, color: kOrange),
              title: '${s['product']} · ${peso(s['flash_price'])}',
              subtitle: '${formatDateTime(s['starts_at'])} – ${formatDateTime(s['ends_at'])}\n'
                  '${s['sold']}/${s['quantity']} sold · ${s['reminders']} reminder(s)',
              trailing: [
                Pill('${s['state']}', color: Pill.forState(s['state'])),
                if (s['state'] == 'Upcoming')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                    onPressed: () async {
                      if (await confirmAction(context, 'Delete this flash sale?', 'It won\'t run.', confirm: 'Delete', danger: true)) {
                        await act(() => SellerApi.deleteFlashSale(asInt(s['id'])));
                      }
                    },
                  ),
              ],
            ),
        ]);
      }, fab: _fab('New flash sale', _add));
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
            const Text('New flash sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _product,
              decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder(), isDense: true),
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
            BusyButton('Schedule', busy: false, onPressed: () {
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
        final list = asList(d['promotions']);
        if (list.isEmpty) return ListView(children: const [EmptyNote(Icons.redeem_outlined, 'No promotions yet.')]);
        return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
          for (final p in list)
            _tile(
              context,
              leading: const Icon(Icons.redeem, color: kOrange),
              title: '${p['name']}',
              subtitle: '${p['label']}${p['ends_at'] != null ? '\nUntil ${formatDateTime(p['ends_at'])}' : ''}',
              trailing: [
                Switch(
                  value: p['is_active'] == true,
                  activeThumbColor: kOrange,
                  onChanged: (_) => act(() => SellerApi.togglePromotion(asInt(p['id']))),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                  onPressed: () async {
                    if (await confirmAction(context, 'Delete "${p['name']}"?', 'Buyers no longer get this deal.', confirm: 'Delete', danger: true)) {
                      await act(() => SellerApi.deletePromotion(asInt(p['id'])));
                    }
                  },
                ),
              ],
            ),
        ]);
      }, fab: _fab('New promotion', _add));
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
            const Text('New promotion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'bundle', label: Text('Bundle deal')), ButtonSegment(value: 'bxgy', label: Text('Buy X get Y'))],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _minQty.text = _type == 'bundle' ? '2' : '1';
              }),
            ),
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
                decoration: const InputDecoration(labelText: 'Free product', border: OutlineInputBorder(), isDense: true),
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
            BusyButton('Create', busy: false, onPressed: () {
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
      contentPadding: EdgeInsets.only(left: child ? 28 : 4),
      dense: child,
      title: Text('${cat['name']}', style: TextStyle(color: hidden ? context.bc.muted : context.bc.text, fontWeight: child ? null : FontWeight.w700)),
      subtitle: Text('${cat['products']} product(s)${hidden ? ' · hidden' : ''}${cat['from_alvy'] == true ? '' : ' · your own name'}'),
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
        final list = asList(d['categories']);
        if (list.isEmpty) {
          return ListView(children: const [
            EmptyNote(Icons.category_outlined, 'Add the ALVY categories you sell in (e.g. Automotive & Motorcycle, Health & Beauty). They show as tabs on your store page.')
          ]);
        }
        return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
          for (var i = 0; i < list.length; i++)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: context.bc.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: context.bc.border)),
              child: Column(children: [
                _row(list[i], list, i),
                for (var j = 0; j < asList(list[i]['children']).length; j++)
                  _row(asList(list[i]['children'])[j], asList(list[i]['children']), j, child: true),
              ]),
            ),
        ]);
      }, fab: _fab('Add category', _add));
}
