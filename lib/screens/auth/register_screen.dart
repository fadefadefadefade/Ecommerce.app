import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/psgc_service.dart';
import '../../widgets/buyer_kit.dart' show phoneFormatters;
import 'otp_screen.dart';

/// The web's sign-up page (/register), step by step: account type, personal details, address,
/// security, then the part for the chosen account (shop, courier or sorting center). The web
/// checks every field with its own rules and messages; a field with an error is shown on its step.
class RegisterScreen extends StatefulWidget {
  final String initialRole;
  const RegisterScreen({super.key, this.initialRole = 'buyer'});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _orange = Color(0xFFfa4e1c);
  static const _ink = Color(0xFF002B4D);
  static const _muted = Color(0xFF6B90AA);
  static const _line = Color(0xFFE6EDF2);

  late String _role = widget.initialRole;
  int _step = 0;
  bool _busy = false;
  Map<String, String> _errors = {};

  // Personal
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _mi = TextEditingController();
  final _contact = TextEditingController();
  String? _sex; // male / female
  DateTime? _birthday;

  // Address
  List<Map<String, dynamic>> _regions = [], _provinces = [], _cities = [], _barangays = [];
  Map<String, dynamic>? _region, _province, _city, _barangay;
  bool _noProvince = false; // NCR
  final _house = TextEditingController();
  final _street = TextEditingController();
  final _zip = TextEditingController();

  // Security
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;
  bool _terms = false;

  // Seller
  final _shop = TextEditingController();
  final _tin = TextEditingController();
  String? _category, _sellerType;

  // Courier
  String _vehicle = 'motorcycle';
  final _plate = TextEditingController();
  int? _hubId;

  // Logistics
  final _business = TextEditingController();

  // Uploads: field name → local path (the same field names as the web form).
  final Map<String, String> _files = {};

  // Lists from the web.
  List<String> _categories = [];
  List<String> _sellerTypes = [];
  List<Map<String, dynamic>> _hubs = [];

  // A rider signs up as role "courier": the chosen hub approves them and they take its jobs.
  // (A logistics company can also add riders and couriers itself; those get an email to set a password.)
  static const _roles = [
    ('buyer', 'Buyer', 'Shop and order', Icons.shopping_bag_outlined),
    ('seller', 'Seller', 'Open a shop', Icons.storefront_outlined),
    ('courier', 'Rider', 'Deliver parcels', Icons.two_wheeler),
    ('logistics', 'Logistics', 'Run a sorting hub', Icons.warehouse_outlined),
  ];

  List<String> get _steps => [
        'Account type',
        'Personal',
        'Address',
        'Security',
        if (_role == 'seller') 'Shop',
        if (_role == 'courier') 'Courier',
        if (_role == 'logistics') 'Sorting Center'
      ];

  /// Which step shows a field (to jump to the first error).
  int _stepOf(String field) {
    const personal = ['first_name', 'last_name', 'middle_initial', 'sex', 'contact_no', 'phone', 'birthday', 'valid_id'];
    const address = ['region', 'province', 'province_code', 'municipality', 'municipality_code', 'barangay', 'house_number', 'street', 'zip_code'];
    const security = ['email', 'password', 'password_confirmation', 'terms'];
    if (field == 'role') return 0;
    if (personal.contains(field)) return 1;
    if (address.contains(field)) return 2;
    if (security.contains(field)) return 3;
    return 4;
  }

  @override
  void initState() {
    super.initState();
    PsgcService.getRegions().then((r) => mounted ? setState(() => _regions = r) : null);
    ApiClient.get('/auth/register/options').then((res) {
      if (!mounted || !res.ok) return;
      setState(() {
        _categories = List<String>.from(res.body['seller_categories'] ?? []);
        _sellerTypes = List<String>.from(res.body['seller_types'] ?? []);
        _hubs = List<Map<String, dynamic>>.from((res.body['hubs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)));
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _mi, _contact, _house, _street, _zip, _email, _password, _confirm, _shop, _tin, _plate, _business]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Address pickers ────────────────────────────────────────

  Future<void> _pickRegion(Map<String, dynamic>? r) async {
    setState(() {
      _region = r;
      _province = _city = _barangay = null;
      _provinces = _cities = _barangays = [];
      _noProvince = false;
    });
    if (r == null) return;
    final provinces = await PsgcService.getProvincesByRegion(r['code']);
    if (!mounted) return;
    if (provinces.isEmpty) {
      // NCR: no province level — cities are listed directly under the region.
      final cities = await PsgcService.getMunicipalities(r['code']);
      if (mounted) {
        setState(() {
          _noProvince = true;
          _cities = cities;
        });
      }
    } else {
      setState(() => _provinces = provinces);
    }
  }

  Future<void> _pickProvince(Map<String, dynamic>? p) async {
    setState(() {
      _province = p;
      _city = _barangay = null;
      _cities = _barangays = [];
    });
    if (p == null) return;
    final cities = await PsgcService.getMunicipalities(p['code']);
    if (mounted) setState(() => _cities = cities);
  }

  Future<void> _pickCity(Map<String, dynamic>? c) async {
    setState(() {
      _city = c;
      _barangay = null;
      _barangays = [];
    });
    if (c == null) return;
    final b = await PsgcService.getBarangays(c['code']);
    if (mounted) setState(() => _barangays = b);
  }

  Future<void> _pickFile(String field) async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
    final path = picked?.files.single.path;
    if (path != null) setState(() => _files[field] = path);
  }

  // ── Submit ─────────────────────────────────────────────────

  Map<String, String> _fields() => {
        'role': _role,
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'middle_initial': _mi.text.trim(),
        'sex': _sex ?? '',
        'contact_no': _contact.text.trim(),
        'birthday': _birthday != null ? DateFormat('yyyy-MM-dd').format(_birthday!) : '',
        'region': _region?['name'] ?? '',
        'province': _noProvince ? '' : (_province?['name'] ?? ''),
        'province_code': _noProvince ? '' : (_province?['code'] ?? ''),
        'municipality': _city?['name'] ?? '',
        'municipality_code': _city?['code'] ?? '',
        'barangay': _barangay?['name'] ?? '',
        'barangay_code': _barangay?['code']?.toString() ?? '',
        'house_number': _house.text.trim(),
        'street': _street.text.trim(),
        'zip_code': _zip.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'password_confirmation': _confirm.text,
        if (_terms) 'terms': '1',
        if (_role == 'seller') ...{
          'shop_name': _shop.text.trim(),
          'line_of_business': _category ?? '',
          'seller_type': _sellerType ?? '',
          'tin': _tin.text.trim(),
        },
        if (_role == 'courier') ...{
          'vehicle_type': _vehicle,
          'plate_number': _plate.text.trim(),
          'logistics_id': _hubId?.toString() ?? '',
        },
        if (_role == 'logistics') 'business_name': _business.text.trim(),
      };

  /// Only the uploads of the chosen account type.
  Map<String, String> _uploads() {
    final keep = switch (_role) {
      'seller' => ['government_id', _sellerType == 'Corporation' ? 'sec_certificate' : 'dti_certificate', 'bir_2303'],
      'courier' => ['or_cr_image', 'vehicle_reg_image'],
      'logistics' => ['government_id', 'business_permit'],
      _ => ['valid_id'],
    };
    return {
      for (final k in keep)
        if (_files[k] != null) k: _files[k]!
    };
  }

  Future<void> _submit() async {
    if (_password.text != _confirm.text) {
      setState(() {
        _errors = {'password': 'The passwords do not match.'};
        _step = 3;
      });
      return;
    }
    setState(() {
      _busy = true;
      _errors = {};
    });
    final result = await context.read<AuthProvider>().register(_fields(), _uploads());
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isError) {
      setState(() {
        _errors = Map.of(result.fieldErrors);
        // The seller sign-up calls the mobile number "phone".
        if (_errors.containsKey('phone')) _errors['contact_no'] ??= _errors['phone']!;
        if (_errors.isNotEmpty) {
          _step = _errors.keys.map(_stepOf).reduce((a, b) => a < b ? a : b).clamp(0, _steps.length - 1);
        }
      });
      // Always say what is wrong, even for a field this step doesn't show.
      _snack(result.message);
      return;
    }
    if (result.needsOtp) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OtpScreen(otpToken: result.otpToken!, message: result.message, maskedEmail: result.maskedEmail, cooldown: result.cooldown),
      ));
      return;
    }
    // Logistics sign-up: waits for the administrator.
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registration submitted'),
        content: Text(result.message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: const Color(0xFFDC2626)));

  // ── UI ─────────────────────────────────────────────────────

  /// Back (the phone's button or the arrow): the previous step; on the first step, leave sign-up.
  void _back() {
    if (_busy) return;
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _steps.length - 1;
    return PopScope(
      canPop: _step == 0 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: _ink,
          leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back', onPressed: _back),
          title: Text('Create account · ${_step + 1}/${_steps.length}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(value: (_step + 1) / _steps.length, color: _orange, backgroundColor: _line),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_steps[_step], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
                      const SizedBox(height: 16),
                      ..._stepBody(),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _line))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (last)
                      CheckboxListTile(
                        value: _terms,
                        onChanged: (v) => setState(() => _terms = v ?? false),
                        activeColor: _orange,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text("I agree to ALVY's Terms and Conditions and Privacy Policy.", style: TextStyle(fontSize: 13)),
                        subtitle: _err('terms'),
                      ),
                    Row(
                      children: [
                        if (_step > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : () => setState(() => _step--),
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                              child: const Text('Back'),
                            ),
                          ),
                        if (_step > 0) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _busy ? null : (last ? _submit : () => setState(() => _step++)),
                            style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                            child: _busy
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(last ? 'Create Account' : 'Next', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Already have an account? Log In')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _stepBody() {
    switch (_steps[_step]) {
      case 'Account type':
        return [
          const Text('What kind of account do you want?', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
          const Text('Pick one to continue — the next steps depend on your choice.', style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              for (final (value, label, sub, icon) in _roles)
                InkWell(
                  onTap: () => setState(() => _role = value),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _role == value ? const Color(0xFFFFF1EE) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _role == value ? _orange : _line, width: _role == value ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: _role == value ? _orange : _muted),
                        const SizedBox(height: 6),
                        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(sub, style: const TextStyle(fontSize: 11, color: _muted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          _err('role') ?? const SizedBox.shrink(),
        ];

      case 'Personal':
        return [
          _text(_first, 'First Name', 'first_name', required: true),
          _text(_last, 'Last Name', 'last_name', required: true),
          _text(_mi, 'Middle Initial', 'middle_initial', maxLength: 3),
          _label('Sex', required: true),
          Wrap(spacing: 10, children: [
            for (final s in ['male', 'female'])
              ChoiceChip(
                label: Text(s == 'male' ? 'Male' : 'Female'),
                selected: _sex == s,
                selectedColor: const Color(0xFFFFF1EE),
                onSelected: (_) => setState(() => _sex = s),
              ),
          ]),
          _err('sex') ?? const SizedBox(height: 8),
          _text(_contact, 'Mobile Number', 'contact_no',
              required: true, hint: '09171234567', keyboard: TextInputType.phone, formatters: phoneFormatters),
          _label('Birthday', required: true),
          OutlinedButton.icon(
            onPressed: () async {
              // At least 18 years old: the picker stops at the latest allowed date (the website checks it too).
              final now = DateTime.now();
              final latest = DateTime(now.year - 18, now.month, now.day);
              final d = await showDatePicker(
                  context: context, initialDate: _birthday ?? (DateTime(2000).isAfter(latest) ? latest : DateTime(2000)), firstDate: DateTime(1900), lastDate: latest,
                  helpText: 'Date of birth (18 or older)');
              if (d != null) setState(() => _birthday = d);
            },
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(_birthday == null ? 'Select date' : '${DateFormat('MMM d, yyyy').format(_birthday!)} · ${_age(_birthday!)} years old'),
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, minimumSize: const Size.fromHeight(48)),
          ),
          _err('birthday') ?? const SizedBox(height: 8),
          if (_role == 'buyer') _upload('valid_id', 'Valid Government ID*', 'A photo or PDF of a valid government-issued ID. JPG, PNG or PDF, max 5 MB.'),
        ];

      case 'Address':
        return [
          _dropdown('Region', _regions, _region, _pickRegion, 'region'),
          if (!_noProvince) _dropdown('Province', _provinces, _province, _region == null ? null : _pickProvince, 'province'),
          if (_noProvince)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Province: not applicable (no province)', style: TextStyle(color: _muted)),
            ),
          _dropdown('City / Municipality', _cities, _city, _cities.isEmpty ? null : _pickCity, 'municipality'),
          _dropdown('Barangay', _barangays, _barangay, _barangays.isEmpty ? null : (b) => setState(() => _barangay = b), 'barangay'),
          _text(_house, 'House / Unit No.', 'house_number', required: true),
          _text(_street, 'Street', 'street', required: true),
          _text(_zip, 'ZIP Code', 'zip_code',
              required: _role == 'seller', keyboard: TextInputType.number, maxLength: 4, formatters: [FilteringTextInputFormatter.digitsOnly]),
        ];

      case 'Security':
        return [
          _text(_email, 'Email Address', 'email', required: true, keyboard: TextInputType.emailAddress, hint: 'juan@gmail.com'),
          _text(_password, 'Password', 'password',
              required: true,
              obscure: _hidePassword,
              hint: 'At least 8 characters',
              // Every account type: the website's password rule.
              help: 'At least 8 characters, including an uppercase letter, a lowercase letter, a number and a symbol (e.g. Mamimili@2026).',
              suffix: IconButton(
                icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              )),
          _text(_confirm, 'Confirm Password', 'password_confirmation', required: true, obscure: _hidePassword),
        ];

      case 'Shop':
        return [
          _text(_shop, 'Shop Name (3–30 characters)', 'shop_name', required: true, maxLength: 30, hint: 'e.g. Maria Clara Handicrafts'),
          _simpleDropdown('Shop Category', _categories, _category, (v) => setState(() => _category = v), 'line_of_business'),
          _simpleDropdown('Seller Type', _sellerTypes, _sellerType, (v) => setState(() => _sellerType = v), 'seller_type'),
          _text(_tin, 'TIN', 'tin',
              required: true,
              hint: '000-000-000-000',
              keyboard: TextInputType.number,
              maxLength: 15,
              formatters: [_TinFormatter()],
              help: '12 digits, including your 3-digit branch code (000 for the main office).'),
          const SizedBox(height: 8),
          const Text('Business Documents', style: TextStyle(fontWeight: FontWeight.w800)),
          const Text('JPG, PNG or PDF · max 5 MB each. Only the admin team can see these.', style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 10),
          _upload('government_id', 'Government-issued ID*', 'Passport, driver\'s license, UMID, PhilID, etc.'),
          if (_sellerType == 'Corporation')
            _upload('sec_certificate', 'SEC Certificate*', 'Required for corporations.')
          else
            _upload('dti_certificate', 'DTI Certificate*', 'Business name registration certificate.'),
          _upload('bir_2303', 'BIR Form 2303*', 'Certificate of Registration from the BIR.'),
        ];

      case 'Courier':
        return [
          _label('Vehicle Type', required: true),
          Wrap(spacing: 8, children: [
            for (final v in ['motorcycle', 'tricycle', 'car', 'truck'])
              ChoiceChip(
                label: Text(v[0].toUpperCase() + v.substring(1)),
                selected: _vehicle == v,
                selectedColor: const Color(0xFFFFF1EE),
                onSelected: (_) => setState(() => _vehicle = v),
              ),
          ]),
          _err('vehicle_type') ?? const SizedBox(height: 8),
          _text(_plate, 'Plate Number', 'plate_number', required: true),
          _upload('or_cr_image', "Driver's License*", 'JPG, PNG or PDF, max 5 MB.'),
          _upload('vehicle_reg_image', 'Vehicle Registration (OR/CR)*', 'JPG, PNG or PDF, max 5 MB.'),
          _label('Sorting Center / Logistics Hub', required: true),
          const Text('Your application goes to the sorting center you choose. It reviews your documents, and you deliver for it once approved.',
              style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 8),
          if (_hubs.isEmpty)
            const Text('No sorting centers are accepting couriers yet. Please check back later.', style: TextStyle(color: _muted))
          else
            RadioGroup<int>(
              groupValue: _hubId,
              onChanged: (v) => setState(() => _hubId = v),
              child: Column(children: [
                for (final h in _hubs)
                  RadioListTile<int>(
                    value: h['id'] as int,
                    activeColor: _orange,
                    contentPadding: EdgeInsets.zero,
                    title: Text(h['name'] ?? ''),
                    subtitle: h['hub_address'] != null ? Text(h['hub_address'], style: const TextStyle(fontSize: 12)) : null,
                  ),
              ]),
            ),
          _err('logistics_id') ?? const SizedBox.shrink(),
        ];

      case 'Sorting Center':
        return [
          _text(_business, 'Business / Center Name', 'business_name', required: true),
          const Text('Documents', style: TextStyle(fontWeight: FontWeight.w800)),
          const Text('JPG, PNG or PDF · max 5 MB each. Only the admin team can see these.', style: TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 10),
          _upload('government_id', 'Government-issued ID*', 'Passport, driver\'s license, UMID, PhilID, etc.'),
          _upload('business_permit', 'Business / DTI Permit*', 'Business permit or DTI business name registration.'),
        ];
    }
    return [];
  }

  int _age(DateTime d) {
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a;
  }

  Widget? _err(String field) {
    final e = _errors[field];
    return e == null
        ? null
        : Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: Text(e, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)));
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('$text${required ? '*' : ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF002B4D))),
      );

  InputDecoration _decoration({String? hint, Widget? suffix, String? error}) => InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        errorText: error,
        errorMaxLines: 3,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _orange, width: 2)),
      );

  Widget _text(TextEditingController c, String label, String field,
      {bool required = false,
      String? hint,
      TextInputType? keyboard,
      int? maxLength,
      bool obscure = false,
      Widget? suffix,
      List<TextInputFormatter>? formatters,
      String? help}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, required: required),
        TextField(
          controller: c,
          keyboardType: keyboard,
          maxLength: maxLength,
          obscureText: obscure,
          inputFormatters: formatters,
          decoration: _decoration(hint: hint, suffix: suffix, error: _errors[field]),
          onChanged: (_) => _errors.containsKey(field) ? setState(() => _errors.remove(field)) : null,
        ),
        if (help != null && _errors[field] == null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(help, style: const TextStyle(color: _muted, fontSize: 12))),
      ]),
    );
  }

  Widget _dropdown(String label, List<Map<String, dynamic>> items, Map<String, dynamic>? value, ValueChanged<Map<String, dynamic>?>? onChanged, String field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, required: true),
        DropdownButtonFormField<String>(
          key: ValueKey('$label-${items.length}-${value?['code']}'),
          initialValue: value?['code']?.toString(),
          isExpanded: true,
          decoration: _decoration(hint: onChanged == null ? 'Choose the one above first' : 'Select ${label.toLowerCase()}', error: _errors[field]),
          items: [
            for (final i in items) DropdownMenuItem(value: i['code'].toString(), child: Text(i['name'] ?? '', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged == null ? null : (code) => onChanged(items.firstWhere((i) => i['code'].toString() == code)),
        ),
      ]),
    );
  }

  Widget _simpleDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged, String field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, required: true),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: _decoration(hint: 'Select ${label.toLowerCase()}', error: _errors[field]),
          items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
          onChanged: onChanged,
        ),
      ]),
    );
  }

  Widget _upload(String field, String label, String hint) {
    final path = _files[field];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF002B4D))),
        Text(hint, style: const TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _pickFile(field),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _errors[field] != null ? const Color(0xFFDC2626) : _line),
            ),
            child: Row(children: [
              Icon(path == null ? Icons.upload_file : Icons.check_circle, color: path == null ? _muted : const Color(0xFF059669)),
              const SizedBox(width: 10),
              Expanded(child: Text(path == null ? 'Click to upload' : path.split(RegExp(r'[\\/]')).last, overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
        _err(field) ?? const SizedBox.shrink(),
      ]),
    );
  }
}

/// 000-000-000-000 as the buyer types the 12 digits.
class _TinFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final parts = <String>[];
    for (var i = 0; i < digits.length && i < 12; i += 3) {
      parts.add(digits.substring(i, (i + 3).clamp(0, digits.length)));
    }
    final text = parts.join('-');
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
