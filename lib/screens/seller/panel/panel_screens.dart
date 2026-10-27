import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../services/psgc_service.dart';
import '../../../services/seller_api.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/product_thumb.dart';
import '../seller_kit.dart';

// ── Reviews ────────────────────────────────────────────────────

/// The web's seller Reviews page: filter by stars / replied, and reply once (then edit the reply).
class SellerReviewsScreen extends StatefulWidget {
  const SellerReviewsScreen({super.key});
  @override
  State<SellerReviewsScreen> createState() => _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends State<SellerReviewsScreen> {
  int? _stars;
  String? _replied;
  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _counts = {};
  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  String? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) _more();
    });
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 0;
      _lastPage = 1;
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _lastPage) return;
    setState(() => _loading = true);
    final r = await SellerApi.reviews(stars: _stars, replied: _replied, page: _page + 1);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!r.ok) {
        _error = r.message;
        return;
      }
      _items.addAll(asList(r.body['data']));
      _counts = asMap(r.body['counts']);
      final meta = asMap(r.body['meta']);
      _page = asInt(meta['current_page']);
      _lastPage = asInt(meta['last_page']);
    });
  }

  Future<void> _reply(Map<String, dynamic> r) async {
    final ctrl = TextEditingController(text: '${r['seller_reply'] ?? ''}');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(r['seller_reply'] == null ? 'Reply to the review' : 'Edit your reply'),
        content: TextField(controller: ctrl, maxLines: 4, maxLength: 1000, autofocus: true, decoration: const InputDecoration(hintText: 'Your reply')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Post')),
        ],
      ),
    );
    if (text == null || !mounted) return;
    final res = await runAction(context, () => SellerApi.reply(asInt(r['id']), text));
    if (res.ok) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final total = _counts.values.fold<int>(0, (s, v) => s + asInt(v));
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Reviews'),
      body: Column(children: [
        SizedBox(
          height: 50,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
            ChoiceChip(
              label: Text('All ($total)'),
              selected: _stars == null,
              onSelected: (_) {
                _stars = null;
                _refresh();
              },
            ),
            for (var s = 5; s >= 1; s--)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text('$s★ (${_counts['$s'] ?? 0})'),
                  selected: _stars == s,
                  onSelected: (_) {
                    _stars = s;
                    _refresh();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                label: const Text('Not replied'),
                selected: _replied == 'no',
                onSelected: (v) {
                  _replied = v ? 'no' : null;
                  _refresh();
                },
              ),
            ),
          ]),
        ),
        Expanded(
          child: LoadState(
            loading: _loading && _items.isEmpty,
            error: _error,
            onRetry: _refresh,
            child: RefreshIndicator(
              color: kOrange,
              onRefresh: _refresh,
              child: _items.isEmpty
                  ? ListView(children: const [EmptyNote(Icons.reviews_outlined, 'No reviews here.')])
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _card(_items[i]),
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final c = context.bc;
    final photos = (r['photos'] as List? ?? []);
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Stars(asNum(r['rating'])),
          const SizedBox(width: 8),
          Expanded(child: Text('${r['user'] ?? 'Buyer'}', style: TextStyle(color: c.textSecondary, fontSize: 12))),
          Text(formatDate(r['created_at']), style: TextStyle(color: c.muted, fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        Text('${r['product'] ?? ''}${r['variation'] != null ? ' · ${r['variation']}' : ''}', style: TextStyle(fontSize: 12, color: c.muted)),
        if ((r['comment'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${r['comment']}')),
        if (photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, children: [for (final p in photos) ProductThumb(url: p is Map ? p['url'] : '$p', size: 56)]),
          ),
        if (r['seller_reply'] != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(8)),
            child: Text('Your reply: ${r['seller_reply']}', style: TextStyle(color: c.textSecondary)),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _reply(r),
            icon: Icon(r['seller_reply'] == null ? Icons.reply : Icons.edit_outlined, size: 16, color: kOrange),
            label: Text(r['seller_reply'] == null ? 'Reply' : 'Edit reply', style: const TextStyle(color: kOrange)),
          ),
        ),
      ]),
    );
  }
}

// ── Earnings & payouts ─────────────────────────────────────────

class SellerEarningsScreen extends StatefulWidget {
  const SellerEarningsScreen({super.key});
  @override
  State<SellerEarningsScreen> createState() => _SellerEarningsScreenState();
}

class _SellerEarningsScreenState extends State<SellerEarningsScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _error;

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
    final r = await SellerApi.earnings();
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

  Future<void> _request() async {
    final b = asMap(_d!['balances']);
    final ctrl = TextEditingController(text: asNum(b['available']).toStringAsFixed(2));
    final amount = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request a payout'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Available: ${peso(b['available'])} · minimum ${peso(_d!['minimum_payout'])}'),
          TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(prefixText: '₱ ', labelText: 'Amount')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kOrange), onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Request')),
        ],
      ),
    );
    if (amount == null || !mounted) return;
    await runAction(context, () => SellerApi.requestPayout(amount, '${_d!['request_token']}'));
    _load();   // a new request token for the next request
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Earnings & payouts'),
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
    final b = asMap(d['balances']);
    final payouts = asList(d['payouts']);
    final orders = asList(d['data']);
    return ListView(padding: const EdgeInsets.all(12), children: [
      StatGrid([
        StatTile(label: 'Available', value: peso(b['available']), icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF15803D)),
        StatTile(label: 'On the way', value: peso(b['pending']), icon: Icons.hourglass_bottom, color: const Color(0xFFB45309), hint: 'Orders not completed yet'),
        StatTile(label: 'Requested', value: peso(b['pending_payout']), icon: Icons.schedule_send_outlined, color: const Color(0xFF2563EB)),
        StatTile(label: 'Earned (completed)', value: peso(b['completed']), icon: Icons.check_circle_outline),
      ]),
      const SizedBox(height: 12),
      BusyButton('Request payout', busy: false, icon: Icons.payments_outlined, onPressed: asNum(b['available']) >= asNum(d['minimum_payout']) ? _request : null),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Text('Minimum payout ${peso(d['minimum_payout'])}.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted)),
      ),
      SectionCard(
        title: 'Payouts',
        child: payouts.isEmpty
            ? Text('No payout requests yet.', style: TextStyle(color: c.muted))
            : Column(children: [
                for (final p in payouts)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(peso(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Requested ${formatDate(p['created_at'])}${p['paid_at'] != null ? ' · paid ${formatDate(p['paid_at'])}' : ''}'),
                    trailing: Pill('${p['status']}', color: Pill.forState(p['status'])),
                  ),
              ]),
      ),
      SectionCard(
        title: 'Earnings by order',
        child: orders.isEmpty
            ? Text('No orders yet.', style: TextStyle(color: c.muted))
            : Column(children: [
                for (final o in orders)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${o['number']}'),
                    subtitle: Text('${o['status']} · ${formatDate(o['created_at'])}'),
                    trailing: Text(peso(o['earning']), style: TextStyle(fontWeight: FontWeight.w700, color: o['completed'] == true ? const Color(0xFF15803D) : c.muted)),
                  ),
              ]),
      ),
    ]);
  }
}

// ── Store settings ─────────────────────────────────────────────

/// The web's Store Settings: name, description, contact, pickup address (PSGC), logo, banner, vacation mode.
class SellerStoreSettingsScreen extends StatefulWidget {
  const SellerStoreSettingsScreen({super.key});
  @override
  State<SellerStoreSettingsScreen> createState() => _SellerStoreSettingsScreenState();
}

class _SellerStoreSettingsScreenState extends State<SellerStoreSettingsScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _zip = TextEditingController();
  Map<String, dynamic> _store = {};
  bool _vacation = false;
  String? _logo;
  String? _banner;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, String> _errors = {};

  // Pickup address (names as saved; codes from the PSGC lists).
  String _region = '', _province = '', _municipality = '', _barangay = '';
  String _provinceCode = '', _municipalityCode = '';
  bool _editAddress = false;
  List<Map<String, dynamic>> _regions = [], _provinces = [], _cities = [], _barangays = [];
  bool _noProvince = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _phone, _street, _zip]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final r = await SellerApi.storeSettings();
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _loading = false;
        _error = r.message;
      });
      return;
    }
    _fill(asMap(r.body['store']));
    setState(() => _loading = false);
  }

  void _fill(Map<String, dynamic> s) {
    _store = s;
    _name.text = '${s['shop_name'] ?? ''}';
    _description.text = '${s['description'] ?? ''}';
    _phone.text = localPhone(s['phone']);
    _street.text = '${s['street'] ?? ''}';
    _zip.text = '${s['zip_code'] ?? ''}';
    _vacation = s['is_on_vacation'] == true;
    _region = '${s['region'] ?? ''}';
    _province = '${s['province'] ?? ''}';
    _municipality = '${s['municipality'] ?? ''}';
    _barangay = '${s['barangay'] ?? ''}';
    _provinceCode = '${s['province_code'] ?? ''}';
    _municipalityCode = '${s['municipality_code'] ?? ''}';
  }

  Future<void> _startAddress() async {
    setState(() => _editAddress = true);
    _regions = await PsgcService.getRegions();
    if (mounted) setState(() {});
  }

  Future<void> _pickRegion(Map<String, dynamic> r) async {
    setState(() {
      _region = '${r['name']}';
      _province = _municipality = _barangay = _provinceCode = _municipalityCode = '';
      _provinces = _cities = _barangays = [];
    });
    final provinces = await PsgcService.getProvincesByRegion('${r['code']}');
    if (provinces.isEmpty) {
      _noProvince = true;
      _cities = await PsgcService.getMunicipalities('${r['code']}');
    } else {
      _noProvince = false;
      _provinces = provinces;
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickProvince(Map<String, dynamic> p) async {
    setState(() {
      _province = '${p['name']}';
      _provinceCode = '${p['code']}';
      _municipality = _barangay = _municipalityCode = '';
      _cities = _barangays = [];
    });
    _cities = await PsgcService.getMunicipalities('${p['code']}');
    if (mounted) setState(() {});
  }

  Future<void> _pickCity(Map<String, dynamic> c) async {
    setState(() {
      _municipality = '${c['name']}';
      _municipalityCode = '${c['code']}';
      _barangay = '';
      _barangays = [];
    });
    _barangays = await PsgcService.getBarangays('${c['code']}');
    if (mounted) setState(() {});
  }

  Future<String?> _image() async {
    final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png']);
    return f?.files.single.path;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors = {};
    });
    final r = await SellerApi.updateStoreSettings({
      'shop_name': _name.text.trim(),
      'description': _description.text.trim(),
      'phone': _phone.text.trim(),
      'region': _region,
      'province': _noProvince ? '' : _province,
      'province_code': _noProvince ? '' : _provinceCode,
      'municipality': _municipality,
      'municipality_code': _municipalityCode,
      'barangay': _barangay,
      'street': _street.text.trim(),
      'zip_code': _zip.text.trim(),
      'is_on_vacation': _vacation ? '1' : '0',
    }, logo: _logo, banner: _banner);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = r.fieldErrors;
      if (r.ok) {
        _fill(asMap(r.body['store']));
        _logo = _banner = null;
        _editAddress = false;
      }
    });
    showResult(context, r);
  }

  Widget _pick(String label, String value, List<Map<String, dynamic>> items, ValueChanged<Map<String, dynamic>> onPick, String field) {
    final match = items.where((i) => '${i['name']}'.toLowerCase() == value.toLowerCase()).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-${items.length}-$value'),
        isExpanded: true,
        initialValue: match == null ? null : '${match['code']}',
        decoration: InputDecoration(labelText: label, isDense: true, errorText: _errors[field], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        items: [for (final i in items) DropdownMenuItem(value: '${i['code']}', child: Text('${i['name']}', overflow: TextOverflow.ellipsis))],
        onChanged: items.isEmpty ? null : (code) => onPick(items.firstWhere((i) => '${i['code']}' == code)),
      ),
    );
  }

  Widget _imageBox(String label, String? local, dynamic url, VoidCallback onTap, double height) {
    final c = context.bc;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (local != null)
            Image.file(File(local), fit: BoxFit.cover)
          else if (url != null)
            ProductThumb(url: '$url', size: height, radius: 0)
          else
            Icon(Icons.add_photo_alternate_outlined, color: c.muted),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.black54,
              child: Text('$label · tap to change', style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Store settings'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          SectionCard(
            title: 'Store look',
            child: Column(children: [
              _imageBox('Banner', _banner, _store['banner_url'], () async {
                final p = await _image();
                if (p != null) setState(() => _banner = p);
              }, 110),
              if (_errors['banner'] != null) Text(_errors['banner']!, style: const TextStyle(color: Color(0xFFDC2626))),
              Row(children: [
                SizedBox(
                  width: 90,
                  child: _imageBox('Logo', _logo, _store['logo_url'], () async {
                    final p = await _image();
                    if (p != null) setState(() => _logo = p);
                  }, 90),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_errors['logo'] ?? 'JPG or PNG, up to 5 MB.', style: TextStyle(fontSize: 12, color: _errors['logo'] != null ? const Color(0xFFDC2626) : context.bc.muted))),
              ]),
            ]),
          ),
          SectionCard(
            title: 'Store details',
            child: Column(children: [
              FormInput(_name, 'Store name *', maxLength: 30, helper: 'Up to 3 changes per month.', error: _errors['shop_name']),
              FormInput(_description, 'Description', maxLines: 3, maxLength: 500, error: _errors['description']),
              FormInput(_phone, 'Contact number *', keyboard: TextInputType.phone, hint: '09171234567', error: _errors['phone']),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: kOrange,
                value: _vacation,
                title: const Text('Vacation mode'),
                subtitle: const Text('Buyers can browse but can\'t order until you turn it off.'),
                onChanged: (v) => setState(() => _vacation = v),
              ),
            ]),
          ),
          SectionCard(
            title: 'Pickup address',
            trailing: _editAddress ? null : TextButton(onPressed: _startAddress, child: const Text('Change')),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!_editAddress)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text([_barangay, _municipality, _province, _region].where((e) => e.isNotEmpty).join(', ')),
                )
              else ...[
                _pick('Region *', _region, _regions, _pickRegion, 'region'),
                if (!_noProvince) _pick('Province *', _province, _provinces, _pickProvince, 'province'),
                _pick('City / municipality *', _municipality, _cities, _pickCity, 'municipality'),
                _pick('Barangay *', _barangay, _barangays, (b) => setState(() => _barangay = '${b['name']}'), 'barangay'),
              ],
              for (final f in ['region', 'province', 'municipality', 'barangay'])
                if (!_editAddress && _errors[f] != null) Text(_errors[f]!, style: const TextStyle(color: Color(0xFFDC2626))),
              FormInput(_street, 'Street, building, house no. *', error: _errors['street']),
              FormInput(_zip, 'Postal code *', keyboard: TextInputType.number, maxLength: 4, error: _errors['zip_code']),
            ]),
          ),
          BusyButton('Save store settings', busy: _saving, onPressed: _save),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ── Seller account ─────────────────────────────────────────────

/// The web's seller Account page: name, email, phone, address, photo, and the password.
class SellerAccountScreen extends StatefulWidget {
  const SellerAccountScreen({super.key});
  @override
  State<SellerAccountScreen> createState() => _SellerAccountScreenState();
}

class _SellerAccountScreenState extends State<SellerAccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _zip = TextEditingController();
  final _country = TextEditingController();
  String? _photoUrl;
  String? _avatar;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _address, _city, _zip, _country]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> u) {
    _name.text = '${u['name'] ?? ''}';
    _email.text = '${u['email'] ?? ''}';
    _phone.text = localPhone(u['phone']);
    _address.text = '${u['address'] ?? ''}';
    _city.text = '${u['city'] ?? ''}';
    _zip.text = '${u['zip'] ?? ''}';
    _country.text = '${u['country'] ?? 'Philippines'}';
    _photoUrl = u['photo_url'] as String?;
  }

  Future<void> _load() async {
    final r = await SellerApi.account();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _fill(asMap(r.body['user']));
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors = {};
    });
    final r = await SellerApi.updateAccount({
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'city': _city.text.trim(),
      'zip': _zip.text.trim(),
      'country': _country.text.trim(),
    }, avatar: _avatar);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = r.fieldErrors;
    });
    showResult(context, r);
    if (r.ok) {
      final u = asMap(r.body['user']);
      context.read<AuthProvider>().updateUser(u);
      setState(() {
        _fill(u);
        _avatar = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Account'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
                if (x != null) setState(() => _avatar = x.path);
              },
              child: CircleAvatar(
                radius: 44,
                backgroundColor: kOrange,
                backgroundImage: _avatar != null ? FileImage(File(_avatar!)) as ImageProvider : (_photoUrl != null ? NetworkImage(_photoUrl!) : null),
                child: _avatar == null && _photoUrl == null ? const Icon(Icons.camera_alt, color: Colors.white) : null,
              ),
            ),
          ),
          if (_errors['avatar'] != null) Center(child: Text(_errors['avatar']!, style: const TextStyle(color: Color(0xFFDC2626)))),
          const SizedBox(height: 12),
          SectionCard(
            child: Column(children: [
              FormInput(_name, 'Full name *', error: _errors['name']),
              FormInput(_email, 'Email *', keyboard: TextInputType.emailAddress, error: _errors['email']),
              FormInput(_phone, 'Mobile number', keyboard: TextInputType.phone, hint: '09171234567', error: _errors['phone']),
              FormInput(_address, 'Address', error: _errors['address']),
              Row(children: [
                Expanded(child: FormInput(_city, 'City', error: _errors['city'])),
                const SizedBox(width: 8),
                Expanded(child: FormInput(_zip, 'ZIP', error: _errors['zip'])),
              ]),
              FormInput(_country, 'Country', error: _errors['country']),
            ]),
          ),
          BusyButton('Save account', busy: _saving, onPressed: _save),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ── Application status ─────────────────────────────────────────

/// The web's seller status page for an application that isn't approved yet; a rejected one can upload corrected documents.
class SellerStatusScreen extends StatefulWidget {
  const SellerStatusScreen({super.key});
  @override
  State<SellerStatusScreen> createState() => _SellerStatusScreenState();
}

class _SellerStatusScreenState extends State<SellerStatusScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  String? _error;
  final Map<String, String> _files = {};
  bool _sending = false;

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
    final r = await SellerApi.status();
    if (!mounted) return;
    if (r.ok && r.body['status'] == 'approved') {
      // Approved meanwhile: reload the account so the app opens the seller panel.
      await context.read<AuthProvider>().checkAuthStatus();
      return;
    }
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = r.body;
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _resubmit() async {
    setState(() => _sending = true);
    final r = await SellerApi.resubmit(_files);
    if (!mounted) return;
    setState(() => _sending = false);
    showResult(context, r);
    if (r.ok) {
      _files.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Seller application', actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: () => context.read<AuthProvider>().logout(), icon: const Icon(Icons.logout)),
      ]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: _d == null ? const SizedBox() : _body(_d!),
      ),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final c = context.bc;
    final rejected = d['status'] == 'rejected';
    return ListView(padding: const EdgeInsets.all(16), children: [
      Icon(rejected ? Icons.report_gmailerrorred : Icons.hourglass_top, size: 64, color: rejected ? const Color(0xFFDC2626) : kOrange),
      const SizedBox(height: 12),
      Text(rejected ? 'Application not approved' : 'Application under review',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text)),
      const SizedBox(height: 6),
      Text(
        rejected
            ? 'Upload corrected documents below and send them for another review.'
            : 'An ALVY admin is checking your documents. You\'ll get an email once it is reviewed. Meanwhile you can prepare products as drafts on the website.',
        textAlign: TextAlign.center,
        style: TextStyle(color: c.muted),
      ),
      const SizedBox(height: 16),
      SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${d['shop_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
          if (d['submitted_at'] != null) Text('Submitted ${formatDateTime(d['submitted_at'])}', style: TextStyle(color: c.muted, fontSize: 12)),
          if (rejected && (d['rejection_reason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Reason: ${d['rejection_reason']}', style: const TextStyle(color: Color(0xFFDC2626))),
          ],
        ]),
      ),
      SectionCard(
        title: 'Documents',
        child: Column(children: [
          for (final doc in asList(d['documents']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(doc['uploaded'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: doc['uploaded'] == true ? const Color(0xFF15803D) : c.muted),
              title: Text('${doc['label']}'),
              subtitle: _files[doc['field']] != null ? Text(_files[doc['field']]!.split(RegExp(r'[\\/]')).last) : null,
              trailing: rejected
                  ? TextButton(
                      onPressed: () async {
                        final f = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
                        final path = f?.files.single.path;
                        if (path != null) setState(() => _files['${doc['field']}'] = path);
                      },
                      child: const Text('Upload'),
                    )
                  : null,
            ),
        ]),
      ),
      if (rejected) BusyButton('Send for review', busy: _sending, onPressed: _files.isEmpty ? null : _resubmit),
    ]);
  }
}
