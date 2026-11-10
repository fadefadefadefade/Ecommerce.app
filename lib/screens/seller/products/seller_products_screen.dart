import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
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
      body: Column(children: [
        // The design's inventory header: the title and count, search with Filter, and the big Add New Product bar.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Product Inventory', style: Alvy.display(size: 22, color: c.text, weight: FontWeight.w700)),
            Text('Manage your ${_counts['all'] ?? _items.length} listings & stock', style: TextStyle(fontSize: 13, color: c.textSecondary)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(),
                  decoration: const InputDecoration(hintText: 'Search name, SKU or code', prefixIcon: Icon(Icons.search)),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: c.subtle,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _filters,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(children: [
                        Icon(Icons.tune, size: 19, color: c.text),
                        const SizedBox(width: 6),
                        Text('Filter', style: TextStyle(fontWeight: FontWeight.w600, color: c.text)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _open(),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.add_circle_outline, size: 21),
              label: const Text('Add New Product', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            ),
            if (_sorts.isNotEmpty)
              Row(children: [
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
          ]),
        ),
        SizedBox(
          height: 50,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 4, 16, 4), children: [
            for (final t in _tabs)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterPill(
                  '${t.$2}  ${_counts[t.$1] ?? 0}',
                  selected: _status == t.$1,
                  onTap: () {
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
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

    final stock = asInt(p['stock']);
    final low = !archived && p['low_stock'] == true;
    final out = !archived && stock == 0;
    // The design's inventory card: photo with a tag, the code line, name, price and sold; a beige stock strip under it.
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: selected ? Alvy.orangeSoft : c.surface,
        borderRadius: BorderRadius.circular(20),
        border: selected ? Border.all(color: kOrange, width: 1.5) : null,
        boxShadow: Alvy.cardShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _selected.isNotEmpty ? setState(() => selected ? _selected.remove(id) : _selected.add(id)) : _open(id: id),
          onLongPress: () => setState(() => selected ? _selected.remove(id) : _selected.add(id)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: ProductThumb(url: p['image_url'], size: 92)),
                  if (out || low)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: out ? Alvy.dangerText : Alvy.dangerSoft, borderRadius: BorderRadius.circular(6)),
                        child: Text(out ? 'Sold out' : 'Low Stock',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: out ? Colors.white : Alvy.dangerText)),
                      ),
                    ),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text('${p['product_code'] ?? ''}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .6, color: Alvy.slate)),
                      ),
                      SizedBox(
                        width: 28,
                        height: 24,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_vert, size: 20, color: c.textSecondary),
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
                      ),
                    ]),
                    Text('${p['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Alvy.display(size: 17, color: c.text, weight: FontWeight.w600)),
                    if (p['sku'] != null)
                      Text('SKU: ${p['sku']}', style: TextStyle(fontSize: 11.5, letterSpacing: .4, color: c.textSecondary)),
                    const SizedBox(height: 6),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(peso(price), style: Alvy.display(size: 20, color: kOrange, weight: FontWeight.w700)),
                        ),
                      ),
                      if (price < regular) ...[
                        const SizedBox(width: 6),
                        Text(peso(regular), style: TextStyle(fontSize: 11, color: c.muted, decoration: TextDecoration.lineThrough)),
                      ],
                      const Spacer(),
                      if (p['sold'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(20)),
                          child: Text('${p['sold']} sold', style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
                        ),
                    ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              // The stock strip: units left and the variations, the status on the right; Restock when low.
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.inventory_2_outlined, size: 18, color: out || low ? const Color(0xFFDC2626) : Alvy.slate),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(out ? 'Out of stock' : '$stock in stock',
                          style: TextStyle(fontWeight: FontWeight.w700, color: out || low ? const Color(0xFFDC2626) : c.text)),
                      Text(asInt(p['variations_count']) > 0 ? '${p['variations_count']} options' : 'Single variant',
                          style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
                    ]),
                  ),
                  if ((out || low) && !archived)
                    FilledButton.icon(
                      onPressed: () => _menu(p, 'stock'),
                      style: FilledButton.styleFrom(backgroundColor: Alvy.navyFill, minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                      icon: const Icon(Icons.add_box_outlined, size: 17),
                      label: const Text('Restock'),
                    )
                  else if (archived)
                    const Pill('Archived', color: Color(0xFF6B7280))
                  else
                    Pill(_statusLabel(status), color: Pill.forState(status)),
                ]),
              ),
              if ((status != 'draft' && approval != 'approved') || p['sale_state'] != null) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (status != 'draft' && approval != 'approved')
                    Pill(approval == 'rejected' ? 'Rejected' : 'Waiting for approval', color: Pill.forState(approval)),
                  if (p['sale_state'] != null) Pill('Sale: ${p['sale_state']}', color: Pill.forState(p['sale_state'])),
                ]),
              ],
              if (approval == 'rejected' && (p['approval_note'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Admin note: ${p['approval_note']}', style: const TextStyle(fontSize: 11.5, color: Color(0xFFDC2626))),
              ],
            ]),
          ),
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
