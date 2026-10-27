import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/seller_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/product_thumb.dart';
import '../seller_kit.dart';

/// The web's product form (seller.books.form): photos, details, price & sale, options, shipping, store categories.
/// A new product waits for an admin; a seller that isn't verified yet can only save drafts.
class AddEditProductScreen extends StatefulWidget {
  final int? productId;
  const AddEditProductScreen({super.key, this.productId});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _VarType {
  final TextEditingController name;
  final List<TextEditingController> options;
  _VarType(String n, List<String> opts)
      : name = TextEditingController(text: n),
        options = [for (final o in opts) TextEditingController(text: o)];
  void dispose() {
    name.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

class _VarRow {
  int? id;
  final String name;
  final TextEditingController price;
  final TextEditingController stock;
  final TextEditingController sku;
  _VarRow(this.name, {this.id, String price = '', String stock = '', String sku = ''})
      : price = TextEditingController(text: price),
        stock = TextEditingController(text: stock),
        sku = TextEditingController(text: sku);
  void dispose() {
    price.dispose();
    stock.dispose();
    sku.dispose();
  }
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  bool get _edit => widget.productId != null;

  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  Map<String, String> _errors = {};
  Map<String, dynamic>? _product;

  // Options from the web form.
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic> _subMap = {};
  List<Map<String, dynamic>> _addresses = [];
  List<int> _myCategoryIds = []; // the store's categories (ALVY category ids), listed first
  int _maxImages = 9;
  int _maxTypes = 2;
  int _maxOptions = 20;

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _brand = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  final _discount = TextEditingController();
  final _stock = TextEditingController();
  final _sku = TextEditingController();
  // The website's "Low-stock alert at" (empty = the store default).
  final _lowStockAt = TextEditingController();
  int _lowStockDefault = 10;
  final _weight = TextEditingController();
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  String _saleType = 'none'; // none / price / percent — the sale is one of them, or none
  String? _saleStarts;
  String? _saleEnds;
  int? _categoryId;
  String? _subcategory;
  int? _addressId;
  String _status = 'active';

  List<Map<String, dynamic>> _savedImages = [];
  final List<int> _removedImages = [];
  final List<String> _newImages = [];
  String? _video;       // a new video to upload
  String? _videoUrl;    // the saved one

  final List<_VarType> _types = [];
  final List<_VarRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _brand, _price, _salePrice, _discount, _stock, _sku, _lowStockAt, _weight, _length, _width, _height]) {
      c.dispose();
    }
    for (final t in _types) {
      t.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  String _s(dynamic v) {
    if (v == null) return '';
    if (v is num) return v % 1 == 0 ? v.toInt().toString() : v.toString();
    return '$v';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final r = _edit ? await SellerApi.product(widget.productId!) : await SellerApi.productForm();
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _loading = false;
        _loadError = r.message;
      });
      return;
    }
    final b = r.body;
    _categories = asList(b['categories']);
    _subMap = asMap(b['subcategories']);
    _addresses = asList(b['addresses']);
    _myCategoryIds = [for (final id in (b['my_category_ids'] as List? ?? [])) asInt(id)];
    _lowStockDefault = asInt(b['low_stock_default']) == 0 ? 10 : asInt(b['low_stock_default']);
    // A new product starts in the store's registered business category (the only one it may use).
    if (!_edit && b['business_category_id'] != null) _categoryId = asInt(b['business_category_id']);
    _maxImages = asInt(b['max_images']) == 0 ? 9 : asInt(b['max_images']);
    _maxTypes = asInt(b['max_variation_types']) == 0 ? 2 : asInt(b['max_variation_types']);
    _maxOptions = asInt(b['max_variation_options']) == 0 ? 20 : asInt(b['max_variation_options']);
    if (_edit) _fill(asMap(b['product']));
    if (!_edit) {
      final def = _addresses.where((a) => a['is_default'] == true).toList();
      _addressId = def.isNotEmpty ? asInt(def.first['id']) : null;
    }
    setState(() => _loading = false);
  }

  void _fill(Map<String, dynamic> p) {
    _product = p;
    _title.text = _s(p['title']);
    _description.text = _s(p['description']);
    _brand.text = _s(p['brand']);
    _price.text = _s(p['price']);
    _salePrice.text = _s(p['sale_price']);
    _discount.text = _s(p['discount_percent']);
    _stock.text = _s(p['stock']);
    _sku.text = _s(p['sku']);
    _lowStockAt.text = _s(p['low_stock_threshold']);
    _weight.text = _s(p['weight_kg']);
    _length.text = _s(p['length_cm']);
    _width.text = _s(p['width_cm']);
    _height.text = _s(p['height_cm']);
    // A saved sale price wins over a saved discount (the website does the same).
    _saleType = p['sale_price'] != null ? 'price' : (asNum(p['discount_percent']) > 0 ? 'percent' : 'none');
    _saleStarts = (p['sale_starts_at'] as String?)?.replaceFirst('T', ' ');
    _saleEnds = (p['sale_ends_at'] as String?)?.replaceFirst('T', ' ');
    _categoryId = p['category_id'] == null ? null : asInt(p['category_id']);
    _subcategory = p['subcategory'] as String?;
    _addressId = p['address_id'] == null ? null : asInt(p['address_id']);
    _status = _s(p['status']) == 'out_of_stock' ? 'active' : _s(p['status']);
    _savedImages = asList(p['images']);
    _videoUrl = p['video_url'] as String?;

    // Variation types rebuilt from the saved option names ("Red / S"), like the web form.
    final vars = asList(p['variations']);
    if (vars.isNotEmpty) {
      final groups = <List<String>>[];
      for (final v in vars) {
        final parts = '${v['name']}'.split('/').map((e) => e.trim()).toList();
        for (var i = 0; i < parts.length; i++) {
          if (groups.length <= i) groups.add([]);
          if (parts[i].isNotEmpty && !groups[i].contains(parts[i])) groups[i].add(parts[i]);
        }
      }
      final labels = '${p['variation_labels'] ?? ''}'.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      for (var i = 0; i < groups.length; i++) {
        _types.add(_VarType(i < labels.length ? labels[i] : (groups.length > 1 ? 'Option ${i + 1}' : 'Variation'), groups[i]));
      }
      for (final v in vars) {
        _rows.add(_VarRow('${v['name']}', id: asInt(v['id']), price: _s(v['price']), stock: _s(v['stock']), sku: _s(v['sku'])));
      }
    }
  }

  /// Every combination of the options ("Red / S", "Red / M", …), keeping what was typed for rows that stay.
  void _rebuildRows() {
    final lists = [
      for (final t in _types) [for (final o in t.options) o.text.trim()].where((e) => e.isNotEmpty).toList(),
    ].where((l) => l.isNotEmpty).toList();
    var combos = <String>[];
    if (lists.isNotEmpty) {
      combos = [''];
      for (final l in lists) {
        combos = [for (final c in combos) for (final o in l) c.isEmpty ? o : '$c / $o'];
      }
    }
    final old = {for (final r in _rows) r.name.toLowerCase(): r};
    final next = <_VarRow>[];
    for (final name in combos) {
      final keep = old.remove(name.toLowerCase());
      next.add(keep ?? _VarRow(name));
    }
    for (final r in old.values) {
      r.dispose();
    }
    setState(() {
      _rows
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _pickVideo() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['mp4', 'mov', 'webm']);
    final f = picked?.files.single;
    if (f?.path == null || !mounted) return;
    if (f!.size > 20 * 1024 * 1024) return showError(context, 'The video must be 20 MB or smaller.');
    setState(() => _video = f.path);
  }

  Future<void> _pickPhotos() async {
    final room = _maxImages - (_savedImages.length - _removedImages.length) - _newImages.length;
    if (room <= 0) return showError(context, 'A product can have up to $_maxImages photos.');
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png'], allowMultiple: true);
    if (picked == null) return;
    setState(() => _newImages.addAll(picked.files.map((f) => f.path).whereType<String>().take(room)));
  }

  Map<String, String> _fields(bool draft) {
    final f = <String, String>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'brand': _brand.text.trim(),
      'price': _price.text.trim(),
      'sale_type': _saleType,
      'sale_price': _saleType == 'price' ? _salePrice.text.trim() : '',
      'discount_percent': _saleType == 'percent' ? _discount.text.trim() : '',
      'sale_starts_at': _saleType == 'none' ? '' : (_saleStarts ?? ''),
      'sale_ends_at': _saleType == 'none' ? '' : (_saleEnds ?? ''),
      'stock': _stock.text.trim(),
      'sku': _sku.text.trim(),
      'low_stock_threshold': _lowStockAt.text.trim(),
      'weight_kg': _weight.text.trim(),
      'length_cm': _length.text.trim(),
      'width_cm': _width.text.trim(),
      'height_cm': _height.text.trim(),
      'status': draft ? 'draft' : (_status == 'draft' ? 'active' : _status),
      if (draft) 'action': 'draft',
      if (_categoryId != null) 'category_id': '$_categoryId',
      if (_subcategory != null) 'subcategory': _subcategory!,
      if (_addressId != null) 'address_id': '$_addressId',
    };
    for (var i = 0; i < _removedImages.length; i++) {
      f['removed_images[$i]'] = '${_removedImages[i]}';
    }
    final kept = _savedImages.where((img) => !_removedImages.contains(asInt(img['id']))).toList();
    for (var i = 0; i < kept.length; i++) {
      f['image_order[$i]'] = '${kept[i]['id']}';
    }
    final types = _types.where((t) => t.name.text.trim().isNotEmpty || t.options.any((o) => o.text.trim().isNotEmpty)).toList();
    for (var t = 0; t < types.length; t++) {
      f['variation_types[$t][name]'] = types[t].name.text.trim();
      final opts = types[t].options.map((o) => o.text.trim()).where((o) => o.isNotEmpty).toList();
      for (var o = 0; o < opts.length; o++) {
        f['variation_types[$t][options][$o]'] = opts[o];
      }
    }
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      if (r.id != null) f['variations[$i][id]'] = '${r.id}';
      f['variations[$i][name]'] = r.name;
      f['variations[$i][price]'] = r.price.text.trim();
      f['variations[$i][stock]'] = r.stock.text.trim();
      f['variations[$i][sku]'] = r.sku.text.trim();
    }
    return f;
  }

  Future<void> _save({required bool draft}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _errors = {};
    });
    final files = {
      for (var i = 0; i < _newImages.length; i++) 'images[$i]': _newImages[i],
      if (_video != null) 'video': _video!,
    };
    final r = _edit
        ? await SellerApi.updateProduct(widget.productId!, _fields(draft), files)
        : await SellerApi.createProduct(_fields(draft), files);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = r.fieldErrors;
    });
    showResult(context, r);
    if (r.ok) Navigator.pop(context, true);
  }

  String? _err(String field) {
    if (_errors[field] != null) return _errors[field];
    final hit = _errors.entries.where((e) => e.key.startsWith('$field.')).toList();
    return hit.isEmpty ? null : hit.first.value;
  }

  @override
  Widget build(BuildContext context) {
    final verified = context.watch<AuthProvider>().user?.isApprovedSeller == true;
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar(_edit ? 'Edit product' : 'Add product'),
      body: LoadState(
        loading: _loading,
        error: _loadError,
        onRetry: _load,
        child: _loading || _loadError != null ? const SizedBox() : _form(verified),
      ),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                color: context.bc.surface,
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _save(draft: true),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Save as draft'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: BusyButton(
                      verified ? (_edit ? 'Save changes' : 'Submit for approval') : 'Publish (verify store first)',
                      busy: _saving,
                      onPressed: verified ? () => _save(draft: false) : null,
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _form(bool verified) {
    final c = context.bc;
    final p = _product;
    final generalErrors = [
      for (final k in ['publish', 'images', 'variations', 'variation_types'])
        if (_err(k) != null) _err(k)!,
    ];
    final catName = _categories.where((x) => asInt(x['id']) == _categoryId).map((x) => '${x['name']}').firstOrNull;
    final subs = catName == null ? <String>[] : [for (final s in (_subMap[catName] as List? ?? [])) '$s'];

    return ListView(padding: const EdgeInsets.all(12), children: [
      if (!verified)
        const Card(
          color: Color(0xFFFFF7ED),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('Your store must be verified before you can publish products. You can save drafts for now.',
                style: TextStyle(color: Color(0xFF9A3412))),
          ),
        ),
      if (p != null && p['approval_status'] == 'rejected' && (p['approval_note'] ?? '').toString().isNotEmpty)
        Card(
          color: const Color(0xFFFEF2F2),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Not approved: ${p['approval_note']}', style: const TextStyle(color: Color(0xFFB91C1C))),
          ),
        ),
      for (final e in generalErrors)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(e, style: const TextStyle(color: Color(0xFFDC2626)))),

      SectionCard(
        title: 'Photos (${_savedImages.length - _removedImages.length + _newImages.length}/$_maxImages)',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final img in _savedImages.where((i) => !_removedImages.contains(asInt(i['id']))))
            _photo(ProductThumb(url: img['url'], size: 84), () => setState(() => _removedImages.add(asInt(img['id'])))),
          for (final path in _newImages)
            _photo(
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), width: 84, height: 84, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fileTile())),
              () => setState(() => _newImages.remove(path)),
            ),
          InkWell(
            onTap: _pickPhotos,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(border: Border.all(color: c.border, width: 1.5), borderRadius: BorderRadius.circular(8)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo_outlined, color: c.muted),
                Text('Add', style: TextStyle(fontSize: 11, color: c.muted)),
              ]),
            ),
          ),
        ]),
      ),

      SectionCard(
        title: 'Video',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Optional — MP4, MOV or WebM up to 20 MB.', style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.videocam_outlined, color: c.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _video != null
                    ? 'New video: ${_video!.split(RegExp(r'[\\/]')).last}'
                    : _videoUrl != null
                        ? 'Current video: ${_videoUrl!.split('/').last}'
                        : 'No video',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_video != null) IconButton(onPressed: () => setState(() => _video = null), icon: const Icon(Icons.close, size: 18)),
            TextButton(onPressed: _pickVideo, child: Text(_videoUrl != null || _video != null ? 'Replace' : 'Choose')),
          ]),
          if (_err('video') != null) Text(_err('video')!, style: const TextStyle(color: Color(0xFFDC2626))),
        ]),
      ),

      SectionCard(
        title: 'Basic information',
        child: Column(children: [
          FormInput(_title, 'Product name *', maxLength: 120, error: _err('title')),
          _categoryDropdown(),
          if (subs.isNotEmpty) _dropdown<String>('Subcategory', subs.contains(_subcategory) ? _subcategory : null, [for (final s in subs) (s, s)], (v) => setState(() => _subcategory = v)),
          FormInput(_description, 'Description *', maxLines: 6, maxLength: 3000, helper: '20 to 3,000 characters.', error: _err('description')),
          FormInput(_brand, 'Brand', error: _err('brand')),
        ]),
      ),

      SectionCard(
        title: 'Price & stock',
        child: Column(children: [
          FormInput(_price, 'Price *', prefix: '₱ ', keyboard: const TextInputType.numberWithOptions(decimal: true), error: _err('price')),
          Align(alignment: Alignment.centerLeft, child: Text('Sale (optional)', style: TextStyle(fontWeight: FontWeight.w600, color: c.text))),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'none', label: Text('No sale')),
                ButtonSegment(value: 'price', label: Text('Sale price')),
                ButtonSegment(value: 'percent', label: Text('Discount %')),
              ],
              selected: {_saleType},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _saleType = v.first),
            ),
          ),
          const SizedBox(height: 10),
          if (_saleType == 'price')
            FormInput(_salePrice, 'Sale price *', prefix: '₱ ', keyboard: const TextInputType.numberWithOptions(decimal: true),
                helper: 'Lower than the price.', error: _err('sale_price')),
          if (_saleType == 'percent')
            FormInput(_discount, 'Discount % *', keyboard: TextInputType.number, helper: '1 to 99. Applies to every option\'s price.',
                error: _err('discount_percent')),
          if (_saleType != 'none')
            Row(children: [
              Expanded(child: _dateField('Sale starts', _saleStarts, (v) => setState(() => _saleStarts = v), _err('sale_starts_at'))),
              const SizedBox(width: 8),
              Expanded(child: _dateField('Sale ends', _saleEnds, (v) => setState(() => _saleEnds = v), _err('sale_ends_at'))),
            ]),
          if (_rows.isEmpty)
            FormInput(_stock, 'Stock *', keyboard: TextInputType.number, error: _err('stock'))
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Stock is set per option below.', style: TextStyle(color: c.muted, fontSize: 12)),
            ),
          FormInput(_sku, 'SKU', error: _err('sku')),
          FormInput(_lowStockAt, 'Low-stock alert at (optional)', keyboard: TextInputType.number, error: _err('low_stock_threshold'),
              hint: '$_lowStockDefault', helper: 'We notify you when stock drops to this or fewer. Empty = $_lowStockDefault.'),
          if (_edit && _status != 'draft')
            _dropdown<String>('Status', _status, const [('active', 'Active'), ('inactive', 'Inactive (hidden)')], (v) => setState(() => _status = v ?? 'active')),
        ]),
      ),

      SectionCard(
        title: 'Options (variations)',
        trailing: _types.length < _maxTypes
            ? TextButton.icon(
                onPressed: () => setState(() => _types.add(_VarType(_types.isEmpty ? 'Color' : 'Size', ['']))),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add type'),
              )
            : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_types.isEmpty)
            Text('Add a type like Color or Size if buyers choose between options. Each option can have its own price and stock.',
                style: TextStyle(color: c.muted, fontSize: 12)),
          for (final t in _types) _typeEditor(t),
          if (_rows.isNotEmpty) ...[
            const Divider(),
            for (final r in _rows) _rowEditor(r),
          ],
        ]),
      ),

      SectionCard(
        title: 'Shipping',
        child: Column(children: [
          FormInput(_weight, 'Weight (kg) *', keyboard: const TextInputType.numberWithOptions(decimal: true), error: _err('weight_kg')),
          Row(children: [
            Expanded(child: FormInput(_length, 'L (cm)', keyboard: const TextInputType.numberWithOptions(decimal: true), error: _err('length_cm'))),
            const SizedBox(width: 6),
            Expanded(child: FormInput(_width, 'W (cm)', keyboard: const TextInputType.numberWithOptions(decimal: true), error: _err('width_cm'))),
            const SizedBox(width: 6),
            Expanded(child: FormInput(_height, 'H (cm)', keyboard: const TextInputType.numberWithOptions(decimal: true), error: _err('height_cm'))),
          ]),
          if (_addresses.isNotEmpty)
            _dropdown<int>('Ships from', _addressId, [
              for (final a in _addresses) (asInt(a['id']), '${a['label'] ?? a['full_name'] ?? ''} · ${a['city'] ?? a['municipality'] ?? ''}'),
            ], (v) => setState(() => _addressId = v), error: _err('address_id')),
        ]),
      ),

      const SizedBox(height: 20),
    ]);
  }

  Widget _fileTile() => Container(width: 84, height: 84, color: const Color(0xFFF4F7FA), child: const Icon(Icons.image_outlined, color: kOrange));

  Widget _photo(Widget image, VoidCallback onRemove) => Stack(children: [
        SizedBox(width: 84, height: 84, child: image),
        Positioned(
          right: 2,
          top: 2,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ]);

  Widget _typeEditor(_VarType t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: t.name,
              maxLength: 30,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Type (e.g. Color)', isDense: true, counterText: ''),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _types.remove(t));
              t.dispose();
              _rebuildRows();
            },
            icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
          ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final o in t.options)
            SizedBox(
              width: 110,
              child: TextField(
                controller: o,
                maxLength: 40,
                onChanged: (_) => _rebuildRows(),
                decoration: InputDecoration(
                  hintText: 'Option',
                  isDense: true,
                  counterText: '',
                  suffixIcon: InkWell(
                    onTap: () {
                      setState(() => t.options.remove(o));
                      o.dispose();
                      _rebuildRows();
                    },
                    child: const Icon(Icons.close, size: 16),
                  ),
                ),
              ),
            ),
          if (t.options.length < _maxOptions)
            ActionChip(label: const Text('+ Option'), onPressed: () => setState(() => t.options.add(TextEditingController()))),
        ]),
      ]),
    );
  }

  Widget _rowEditor(_VarRow r) {
    final i = _rows.indexOf(r);
    InputDecoration dec(String label, String field) =>
        InputDecoration(labelText: label, isDense: true, errorText: _errors['variations.$i.$field'], errorMaxLines: 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        Row(children: [
          Expanded(child: TextField(controller: r.price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: dec('Price (₱)', 'price'))),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: r.stock,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: dec('Stock', 'stock'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: TextField(controller: r.sku, decoration: dec('SKU', 'sku'))),
        ]),
      ]),
    );
  }

  Widget _dateField(String label, String? value, ValueChanged<String?> onChanged, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final v = await pickDateTime(context, initial: value, future: false);
          if (v != null) onChanged(v);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            errorText: error,
            errorMaxLines: 3,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: value == null
                ? const Icon(Icons.event, size: 18)
                : InkWell(onTap: () => onChanged(null), child: const Icon(Icons.close, size: 18)),
          ),
          child: Text(value ?? '', style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }

  /// Category: the store's categories first (Store categories, picked from ALVY), then the other ALVY
  /// categories — picking one of those adds it to the store when the product is saved.
  Widget _categoryDropdown() {
    String name(int id) => '${_categories.firstWhere((x) => asInt(x['id']) == id, orElse: () => {'name': ''})['name']}';
    final mine = [for (final id in _myCategoryIds) if (_categories.any((x) => asInt(x['id']) == id)) id];
    final others = [for (final x in _categories) if (!mine.contains(asInt(x['id']))) asInt(x['id'])];
    DropdownMenuItem<int> header(String text, int key) => DropdownMenuItem<int>(
          value: key,
          enabled: false,
          child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kOrange)),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        key: ValueKey('category:$_categoryId:${mine.length}'),
        initialValue: _categories.any((x) => asInt(x['id']) == _categoryId) ? _categoryId : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Category *',
          helperText: 'Your product shows under this category on your store page.',
          helperMaxLines: 2,
          isDense: true,
          errorText: _err('category_id'),
          errorMaxLines: 3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        selectedItemBuilder: (_) => [
          if (mine.isNotEmpty) const SizedBox.shrink(),
          for (final id in mine) Text(name(id), overflow: TextOverflow.ellipsis),
          const SizedBox.shrink(),
          for (final id in others) Text(name(id), overflow: TextOverflow.ellipsis),
        ],
        items: [
          if (mine.isNotEmpty) header('Your store categories', -1),
          for (final id in mine) DropdownMenuItem(value: id, child: Text(name(id), overflow: TextOverflow.ellipsis)),
          header(mine.isEmpty ? 'ALVY categories (adds it to your store)' : 'Other ALVY categories (adds it to your store)', -2),
          for (final id in others) DropdownMenuItem(value: id, child: Text(name(id), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          if (v == null || v < 0) return;
          setState(() {
            _categoryId = v;
            _subcategory = null;
          });
        },
      ),
    );
  }

  Widget _dropdown<T>(String label, T? value, List<(T, String)> items, ValueChanged<T?> onChanged, {String? error}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        key: ValueKey('$label:$value'),
        initialValue: items.any((e) => e.$1 == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          errorText: error,
          errorMaxLines: 3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: [for (final e in items) DropdownMenuItem(value: e.$1, child: Text(e.$2, overflow: TextOverflow.ellipsis))],
        onChanged: onChanged,
      ),
    );
  }
}
