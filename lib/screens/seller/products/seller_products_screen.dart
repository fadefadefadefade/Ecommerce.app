import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/seller_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/product_thumb.dart';
import '../seller_kit.dart';
import 'add_edit_product_screen.dart';

/// The web's Inventory page (seller.books.index): status tabs with counts, search, row actions and bulk actions.
class SellerProductsScreen extends StatefulWidget {
  /// The tab it opens on (the dashboard's low-stock warning opens 'low_stock').
  final String initialStatus;
  const SellerProductsScreen({super.key, this.initialStatus = 'active'});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  static const _tabs = [
    ('active', 'Active'),
    ('draft', 'Drafts'),
    ('review', 'In review'),
    ('low_stock', 'Low stock'),
    ('out_of_stock', 'Out of stock'),
    ('archived', 'Archived'),
  ];

  String _status = 'active';
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _counts = {};
  bool _loading = true;
  String? _error;
  final Set<int> _selected = {};
  // The website's inventory filters, sort and pages.
  String _sort = 'newest';
  Map<String, dynamic> _sorts = {};
  List<Map<String, dynamic>> _categories = [];
  int? _categoryId;
  final _minPrice = TextEditingController();
  final _maxPrice = TextEditingController();
  int _page = 1;
  int _last = 1;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    final r = await SellerApi.products(
      status: _status,
      search: _search.text.trim(),
      categoryId: _categoryId,
      minPrice: _minPrice.text.trim().isEmpty ? null : _minPrice.text.trim(),
      maxPrice: _maxPrice.text.trim().isEmpty ? null : _maxPrice.text.trim(),
      sort: _sort,
      page: more ? _page + 1 : 1,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        final rows = asList(r.body['data']);
        _items = more ? [..._items, ...rows] : rows;
        _counts = asMap(r.body['counts']);
        _sorts = asMap(r.body['sorts']);
        _categories = asList(r.body['categories']);
        _page = asInt(asMap(r.body['meta'])['current_page']);
        _last = asInt(asMap(r.body['meta'])['last_page']);
        _selected.removeWhere((id) => !_items.any((p) => asInt(p['id']) == id));
      } else {
        _error = r.message;
      }
    });
  }

  /// Category and price range (the website's inventory filter).
  Future<void> _filters() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Filter products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All categories')),
                for (final c in _categories) DropdownMenuItem<int?>(value: asInt(c['id']), child: Text('${c['name']}')),
              ],
              onChanged: (v) => set(() => _categoryId = v),
            ),
            Row(children: [
              Expanded(child: TextField(controller: _minPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Min ₱'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _maxPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Max ₱'))),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => set(() {
                    _categoryId = null;
                    _minPrice.clear();
                    _maxPrice.clear();
                  }),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => Navigator.pop(ctx), child: const Text('Apply')),
              ),
            ]),
          ]),
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _open({int? id}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditProductScreen(productId: id)));
    _load();
  }

  Future<void> _act(Future<dynamic> Function() call) async {
    await call();
    _load();
  }

  Future<void> _stock(Map<String, dynamic> p) async {
    final ctrl = TextEditingController(text: '${p['stock']}');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update stock'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Stock (0 to 99,999)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (value == null || !mounted) return;
    await _act(() => runAction(context, () => SellerApi.stock(asInt(p['id']), int.tryParse(value) ?? -1)));
  }

  Future<void> _menu(Map<String, dynamic> p, String action) async {
    final id = asInt(p['id']);
    switch (action) {
      case 'edit':
        return _open(id: id);
      case 'stock':
        return _stock(p);
      case 'duplicate':
        final r = await runAction(context, () => SellerApi.duplicate(id));
        if (r.ok && mounted && r.body['product'] != null) return _open(id: asInt(r.body['product']['id']));
        return _load();
      case 'end_sale':
        if (await confirmAction(context, 'End the sale?', 'The product goes back to its regular price.', confirm: 'End sale')) {
          if (mounted) await _act(() => runAction(context, () => SellerApi.endSale(id)));
        }
      case 'archive':
        if (await confirmAction(context, 'Archive this product?', 'Buyers won\'t see it. You can unarchive it later.', confirm: 'Archive')) {
          if (mounted) await _act(() => runAction(context, () => SellerApi.archive(id)));
        }
      case 'unarchive':
        await _act(() => runAction(context, () => SellerApi.unarchive(id)));
      case 'delete':
        if (await confirmAction(context, 'Delete "${p['title']}"?', 'This can\'t be undone.', confirm: 'Delete', danger: true)) {
          if (mounted) await _act(() => runAction(context, () => SellerApi.deleteProduct(id)));
        }
    }
  }

  Future<void> _bulk(String action) async {
    if (action == 'delete' &&
        !await confirmAction(context, 'Delete ${_selected.length} product(s)?', 'This can\'t be undone.', confirm: 'Delete', danger: true)) {
      return;
    }
    if (!mounted) return;
    final r = await runAction(context, () => SellerApi.bulk(action, _selected.toList()));
    if (r.ok) _selected.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final selecting = _selected.isNotEmpty;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar(selecting ? '${_selected.length} selected' : 'My Products', actions: [
        if (selecting) ...[
          IconButton(tooltip: 'Activate', onPressed: () => _bulk('activate'), icon: const Icon(Icons.visibility_outlined)),
          IconButton(tooltip: 'Deactivate', onPressed: () => _bulk('deactivate'), icon: const Icon(Icons.visibility_off_outlined)),
          IconButton(tooltip: 'Delete', onPressed: () => _bulk('delete'), icon: const Icon(Icons.delete_outline)),
          IconButton(tooltip: 'Clear', onPressed: () => setState(_selected.clear), icon: const Icon(Icons.close)),
        ] else ...[
          IconButton(
            tooltip: 'Filter',
            onPressed: _filters,
            icon: Badge(isLabelVisible: _categoryId != null || _minPrice.text.isNotEmpty || _maxPrice.text.isNotEmpty, child: const Icon(Icons.tune)),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search name, SKU or product code',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: c.border)),
            ),
          ),
        ),
        if (_sorts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Text('Sort', style: TextStyle(color: c.muted, fontSize: 12)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sorts.containsKey(_sort) ? _sort : null,
                underline: const SizedBox(),
                items: [for (final e in _sorts.entries) DropdownMenuItem(value: e.key, child: Text('${e.value}', style: const TextStyle(fontSize: 13)))],
                onChanged: (v) {
                  setState(() => _sort = v ?? 'newest');
                  _load();
                },
              ),
            ]),
          ),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final t in _tabs)
              Padding(
                padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
                child: ChoiceChip(
                  label: Text('${t.$2} (${_counts[t.$1] ?? 0})'),
                  selected: _status == t.$1,
                  selectedColor: kOrange.withValues(alpha: 0.15),
                  onSelected: (_) {
                    setState(() {
                      _status = t.$1;
                      _items = [];
                      _selected.clear();
                    });
                    _load();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: LoadState(
            loading: _loading,
            error: _error,
            onRetry: _load,
            child: RefreshIndicator(
              color: kOrange,
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(children: const [EmptyNote(Icons.inventory_2_outlined, 'No products here.')])
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                      itemCount: _items.length + (_page < _last ? 1 : 0),
                      itemBuilder: (_, i) => i == _items.length
                          ? TextButton(onPressed: () => _load(more: true), child: const Text('Load more'))
                          : _row(_items[i]),
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> p) {
    final c = context.bc;
    final id = asInt(p['id']);
    final archived = p['is_archived'] == true;
    final approval = '${p['approval_status'] ?? ''}';
    final status = '${p['status'] ?? ''}';
    final selected = _selected.contains(id);
    final price = asNum(p['effective_price']);
    final regular = asNum(p['price']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? kOrange.withValues(alpha: 0.08) : c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? kOrange : c.border)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selected.isNotEmpty ? setState(() => selected ? _selected.remove(id) : _selected.add(id)) : _open(id: id),
        onLongPress: () => setState(() => selected ? _selected.remove(id) : _selected.add(id)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ProductThumb(url: p['image_url'], size: 64),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 2),
                Text('${p['product_code'] ?? ''}${p['sku'] != null ? ' · SKU ${p['sku']}' : ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.muted)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(peso(price), style: const TextStyle(fontWeight: FontWeight.w800, color: kOrange)),
                  if (price < regular) ...[
                    const SizedBox(width: 6),
                    Text(peso(regular), style: TextStyle(fontSize: 11, color: c.muted, decoration: TextDecoration.lineThrough)),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Stock ${p['stock']}${p['sold'] != null ? ' · Sold ${p['sold']}' : ''}',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p['low_stock'] == true ? const Color(0xFFDC2626) : c.textSecondary)),
                  ),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (archived) const Pill('Archived', color: Color(0xFF6B7280)) else Pill(_statusLabel(status), color: Pill.forState(status)),
                  // Stock warnings, as on the dashboard: 10 or fewer left, or none.
                  if (!archived && asInt(p['stock']) == 0) const Pill('Sold out', color: Color(0xFFDC2626)),
                  if (!archived && p['low_stock'] == true) Pill('Low stock (alert at ${p['low_stock_at'] ?? 10})', color: const Color(0xFFB45309)),
                  if (status != 'draft' && approval != 'approved')
                    Pill(approval == 'rejected' ? 'Rejected' : 'Waiting for approval', color: Pill.forState(approval)),
                  if (p['sale_state'] != null) Pill('Sale: ${p['sale_state']}', color: Pill.forState(p['sale_state'])),
                  if (asInt(p['variations_count']) > 0) Pill('${p['variations_count']} options', color: const Color(0xFF2563EB)),
                ]),
                if (approval == 'rejected' && (p['approval_note'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Admin note: ${p['approval_note']}', style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                ],
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (a) => _menu(p, a),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (!archived) const PopupMenuItem(value: 'stock', child: Text('Update stock')),
                const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                if (p['sale_state'] == 'Ongoing' || p['sale_state'] == 'Upcoming') const PopupMenuItem(value: 'end_sale', child: Text('End sale')),
                archived
                    ? const PopupMenuItem(value: 'unarchive', child: Text('Unarchive'))
                    : const PopupMenuItem(value: 'archive', child: Text('Archive')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Color(0xFFDC2626)))),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'active' => 'Active',
        'draft' => 'Draft',
        'inactive' => 'Inactive',
        'out_of_stock' => 'Out of stock',
        _ => s,
      };
}
