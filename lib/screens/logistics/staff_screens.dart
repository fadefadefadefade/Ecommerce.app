import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../../services/location.dart';
import '../../services/logistics_api.dart';
import '../../theme/buyer_colors.dart';
import 'logistics_kit.dart';
import 'rider_admin_screens.dart' show showDocument;

// The company's Add Rider / Add Courier: people with an app login of their own. They start Pending Activation and
// set their password from the link emailed to them (24 hours). Also the company's hubs (a courier's home hub).

const _maxBytes = 5 * 1024 * 1024; // 5 MB, the website's limit

/// The license form A00-00-000000 while typing: one letter, then digits with the dashes put in.
class LicenseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (raw.isEmpty) return const TextEditingValue();
    final letter = RegExp(r'[A-Z]').hasMatch(raw[0]) ? raw[0] : '';
    final digits = raw.substring(letter.isEmpty ? 0 : 1).replaceAll(RegExp(r'\D'), '');
    final d = digits.length > 10 ? digits.substring(0, 10) : digits;
    final b = StringBuffer(letter);
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 4) b.write('-');
      b.write(d[i]);
    }
    final text = b.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// Asks before leaving a form with typed data (Android Back or the back arrow).
Future<bool> confirmDiscard(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Discard this form?'),
      content: const Text('What you typed will be lost and nothing is saved.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard', style: TextStyle(color: Color(0xFFDC2626)))),
      ],
    ),
  );
  return ok == true;
}

/// A JPG, PNG or PDF picked from the camera, the gallery or Files. Checks the type and the 5 MB limit
/// (camera photos are made smaller before upload).
class DocField extends StatelessWidget {
  final String label;
  final String? path;
  final String? error;
  final ValueChanged<String> onPicked;
  const DocField({super.key, required this.label, required this.path, required this.onPicked, this.error});

  Future<void> _pick(BuildContext context) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take photo'), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Gallery'), onTap: () => Navigator.pop(ctx, 'gallery')),
          ListTile(leading: const Icon(Icons.folder_open), title: const Text('Files (JPG, PNG or PDF)'), onTap: () => Navigator.pop(ctx, 'files')),
        ]),
      ),
    );
    if (source == null || !context.mounted) return;

    String? picked;
    try {
      if (source == 'files') {
        final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
        picked = r?.files.single.path;
      } else {
        // Big camera photos are shrunk (to about 2000 px); the upload also makes them 5 MB or less.
        final x = await ImagePicker().pickImage(source: source == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
        picked = x?.path;
      }
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      final what = source == 'camera' ? 'camera' : 'photos';
      return showError(context,
          e.code.contains('denied') || e.code.contains('access')
              ? 'ALVY needs $what access to attach the document. Allow it in your phone\'s Settings › Apps › ALVY › Permissions, or choose Files.'
              : 'Could not open the $what: ${e.message ?? e.code}. You can choose Files instead.');
    }
    if (picked == null || !context.mounted) return;

    final ext = picked.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'pdf'].contains(ext)) {
      return showError(context, '$label must be a JPG, PNG or PDF file.');
    }
    // Photos are shrunk before upload; a PDF can't be, so it must already be 5 MB or smaller.
    if (ext == 'pdf' && await File(picked).length() > _maxBytes) {
      if (context.mounted) showError(context, '$label must be 5 MB or smaller.');
      return;
    }
    onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final name = path?.split(RegExp(r'[\\/]')).last;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: error,
            errorMaxLines: 3,
            helperText: 'Camera, gallery or Files · JPG, PNG or PDF, max 5 MB',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Row(children: [
            if (path != null && !path!.toLowerCase().endsWith('.pdf'))
              ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.file(File(path!), width: 40, height: 40, fit: BoxFit.cover))
            else
              Icon(path == null ? Icons.upload_file : Icons.picture_as_pdf, color: path == null ? c.muted : kOrange),
            const SizedBox(width: 10),
            Expanded(child: Text(name ?? 'Tap to attach', overflow: TextOverflow.ellipsis, style: TextStyle(color: name == null ? c.muted : c.text))),
            if (path != null) const Icon(Icons.check_circle, color: Color(0xFF059669), size: 18),
          ]),
        ),
      ),
    );
  }
}

/// A text field of the staff forms: the right keyboard, capitals, and the server's message under it.
Widget staffField(TextEditingController c, String label,
    {String? error, TextInputType? keyboard, TextCapitalization caps = TextCapitalization.none, List<TextInputFormatter>? formatters, String? hint, String? helper, ValueChanged<String>? onChanged}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      keyboardType: keyboard,
      textCapitalization: caps,
      inputFormatters: formatters,
      autocorrect: false,
      enableSuggestions: keyboard != TextInputType.emailAddress,
      onChanged: onChanged,
      scrollPadding: const EdgeInsets.only(bottom: 140), // keep the field and its message above the keyboard
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        errorText: error,
        errorMaxLines: 3,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kOrange, width: 2)),
      ),
    ),
  );
}

/// A date field opening the date picker between [first] and [last].
Widget dateField(BuildContext context, String label, DateTime? value, ValueChanged<DateTime> onPicked,
    {required DateTime first, required DateTime last, required DateTime initial, String? error, String? help}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: value ?? initial, firstDate: first, lastDate: last, helpText: help);
        if (d != null) onPicked(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, errorText: error, errorMaxLines: 3, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: const Icon(Icons.event)),
        child: Text(value == null ? 'mm/dd/yyyy' : formatDate(ymd(value), 'MM/dd/yyyy'), style: TextStyle(color: value == null ? context.bc.muted : context.bc.text)),
      ),
    ),
  );
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Shared by Add Rider and Add Courier: the person's details, the license and the save.
abstract class _StaffFormState<T extends StatefulWidget> extends State<T> {
  final first = TextEditingController();
  final last = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final license = TextEditingController();
  final plate = TextEditingController();
  DateTime? birthday;
  DateTime? expiry;
  String? vehicle;
  final docs = <String, String>{};
  Map<String, String> errors = {};
  bool busy = false;

  List<TextEditingController> get _all => [first, last, email, phone, license, plate];

  bool get dirty => _all.any((c) => c.text.trim().isNotEmpty) || birthday != null || expiry != null || vehicle != null || docs.isNotEmpty;

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> personFields() => {
        'first_name': first.text.trim(),
        'last_name': last.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'license_number': license.text.trim(),
        'plate_number': plate.text.trim(),
        if (birthday != null) 'birthday': ymd(birthday!),
        if (expiry != null) 'license_expiry': ymd(expiry!),
        if (vehicle != null) 'vehicle_type': vehicle!,
      };

  Future<ApiResponse> send();

  Future<void> save() async {
    if (busy) return; // a quick double tap sends once
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    final r = await send();
    if (!mounted) return;
    setState(() {
      busy = false;
      errors = r.ok ? {} : r.fieldErrors;
    });
    showResult(context, r);
    if (r.ok) Navigator.pop(context, true);
  }

  List<Widget> personSection(BuildContext context) {
    final latestBirthday = DateTime(_today().year - 18, _today().month, _today().day);
    return [
      staffField(first, 'First name *', error: errors['first_name'], caps: TextCapitalization.words),
      staffField(last, 'Last name *', error: errors['last_name'], caps: TextCapitalization.words),
      dateField(context, 'Date of birth *', birthday, (d) => setState(() => birthday = d),
          first: DateTime(1940), last: latestBirthday, initial: DateTime(1995).isAfter(latestBirthday) ? latestBirthday : DateTime(1995),
          error: errors['birthday'], help: 'Date of birth (18 or older)'),
      staffField(email, 'Email *', error: errors['email'], keyboard: TextInputType.emailAddress, helper: 'The activation link is sent here.'),
      staffField(phone, 'Mobile number *', error: errors['phone'], keyboard: TextInputType.phone, formatters: phoneFormatters, hint: '09XXXXXXXXX'),
      staffField(license, 'Driver\'s license no. *', error: errors['license_number'], caps: TextCapitalization.characters,
          keyboard: TextInputType.visiblePassword, formatters: [LicenseFormatter()], hint: 'A00-00-000000'),
      dateField(context, 'License expiry date *', expiry, (d) => setState(() => expiry = d),
          first: _today(), last: DateTime(_today().year + 15), initial: _today(), error: errors['license_expiry']),
    ];
  }

  Widget plateField() => staffField(plate, 'Plate number *', error: errors['plate_number'], caps: TextCapitalization.characters,
      keyboard: TextInputType.visiblePassword, formatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')), LengthLimitingTextInputFormatter(10)], hint: 'e.g. 123ABC');

  Widget doc(String field, String label) =>
      DocField(label: label, path: docs[field], error: errors[field], onPicked: (p) => setState(() => docs[field] = p));

  Widget form(String title, List<Widget> children, String saveLabel) {
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscard(context) && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: context.bc.background,
        appBar: sellerBar(title),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text('They get an email to set their password (the link lasts 24 hours). Until then they are Pending Activation.',
                  style: TextStyle(color: context.bc.muted, fontSize: 12)),
              const SizedBox(height: 12),
              ...children,
              const SizedBox(height: 8),
              BusyButton(saveLabel, busy: busy, onPressed: save),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add Rider ──────────────────────────────────────────────────

class AddRiderScreen extends StatefulWidget {
  final List<Map<String, dynamic>> barangays;
  final String municipality;
  const AddRiderScreen({super.key, required this.barangays, required this.municipality});
  @override
  State<AddRiderScreen> createState() => _AddRiderScreenState();
}

class _AddRiderScreenState extends _StaffFormState<AddRiderScreen> {
  String? _psgc;

  @override
  bool get dirty => super.dirty || _psgc != null;

  @override
  Future<ApiResponse> send() {
    final b = widget.barangays.where((x) => '${x['psgc']}' == _psgc).firstOrNull;
    return LogisticsApi.addRiderAccount({
      ...personFields(),
      'barangay_psgc': _psgc ?? '',
      if (b?['code'] != null) 'barangay_code': '${b!['code']}',
    }, docs);
  }

  @override
  Widget build(BuildContext context) {
    return form('Add rider', [
      ...personSection(context),
      DropdownButtonFormField<String>(
        initialValue: vehicle,
        decoration: InputDecoration(labelText: 'Vehicle type *', errorText: errors['vehicle_type'], border: const OutlineInputBorder(), isDense: true),
        items: [for (final v in const ['Motorcycle', 'Car', 'Van']) DropdownMenuItem(value: v, child: Text(v))],
        onChanged: (v) => setState(() => vehicle = v),
      ),
      const SizedBox(height: 12),
      plateField(),
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: _psgc,
        decoration: InputDecoration(labelText: 'Barangay of ${widget.municipality} *', errorText: errors['barangay_psgc'], border: const OutlineInputBorder(), isDense: true),
        items: [
          for (final b in widget.barangays)
            DropdownMenuItem(value: '${b['psgc']}', child: Text('${b['name']}${b['covered'] == true ? '' : ' (adds to your coverage)'}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => _psgc = v),
      ),
      const SizedBox(height: 12),
      doc('license_file', 'Driver\'s license *'),
      doc('or_cr_file', 'Vehicle OR/CR *'),
    ], 'Save rider');
  }
}

// ── Add Courier ────────────────────────────────────────────────

class AddCourierScreen extends StatefulWidget {
  final Map<String, dynamic> options; // GET couriers/form: vehicles, dl_codes, license_types, hubs
  const AddCourierScreen({super.key, required this.options});
  @override
  State<AddCourierScreen> createState() => _AddCourierScreenState();
}

class _AddCourierScreenState extends _StaffFormState<AddCourierScreen> {
  final _capacity = TextEditingController();
  String? _licenseType;
  final Set<String> _codes = {};
  int? _hub;

  List<Map<String, dynamic>> get _vehicles => asList(widget.options['vehicles']);
  Map<String, dynamic>? get _vehicle => _vehicles.where((v) => v['name'] == vehicle).firstOrNull;

  @override
  bool get dirty => super.dirty || _capacity.text.isNotEmpty || _licenseType != null || _codes.isNotEmpty || _hub != null;

  @override
  void dispose() {
    _capacity.dispose();
    super.dispose();
  }

  /// The app checks the vehicle's capacity range and DL codes again whenever the vehicle changes (the server checks them too).
  String? get _capacityProblem {
    final v = _vehicle;
    final t = _capacity.text.trim();
    if (v == null || t.isEmpty) return null;
    final kg = int.tryParse(t);
    final range = '${v['name']}: ${asInt(v['min'])} to ${asInt(v['max'])} kg';
    if (kg == null) return 'Whole kg only ($range).';
    if (kg < asInt(v['min']) || kg > asInt(v['max'])) return 'Out of range ($range).';
    return null;
  }

  String? get _codesProblem {
    final v = _vehicle;
    if (v == null || _codes.isEmpty) return null;
    final need = asList(v['codes']).map((e) => '$e').toList();
    return _codes.any(need.contains) ? null : 'A ${v['name']} needs DL code ${need.join(' or ')}.';
  }

  @override
  Future<ApiResponse> send() {
    return LogisticsApi.addCourier({
      ...personFields(),
      if (_licenseType != null) 'license_type': _licenseType!,
      'dl_codes': _codes.join(','),
      'load_capacity_kg': _capacity.text.trim(),
      if (_hub != null) 'home_hub_id': '$_hub',
    }, docs);
  }

  @override
  Widget build(BuildContext context) {
    final hubs = asList(widget.options['hubs']);
    return form('Add courier', [
      ...personSection(context),
      DropdownButtonFormField<String>(
        initialValue: _licenseType,
        decoration: InputDecoration(labelText: 'License type *', errorText: errors['license_type'], border: const OutlineInputBorder(), isDense: true,
            helperText: 'Couriers need a professional license.'),
        items: [for (final t in asList(widget.options['license_types']).map((e) => '$e')) DropdownMenuItem(value: t, child: Text(t))],
        onChanged: (v) => setState(() => _licenseType = v),
      ),
      const SizedBox(height: 12),
      InputDecorator(
        decoration: InputDecoration(labelText: 'DL codes *', errorText: errors['dl_codes'] ?? _codesProblem, errorMaxLines: 2, border: const OutlineInputBorder(), isDense: true),
        child: Wrap(spacing: 6, runSpacing: 4, children: [
          for (final code in asList(widget.options['dl_codes']).map((e) => '$e'))
            FilterChip(
              label: Text(code),
              selected: _codes.contains(code),
              selectedColor: kOrange.withValues(alpha: .18),
              onSelected: (on) => setState(() => on ? _codes.add(code) : _codes.remove(code)),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: vehicle,
        isExpanded: true,
        decoration: InputDecoration(labelText: 'Vehicle type *', errorText: errors['vehicle_type'], border: const OutlineInputBorder(), isDense: true),
        items: [for (final v in _vehicles) DropdownMenuItem(value: '${v['name']}', child: Text('${v['name']}'))],
        onChanged: (v) => setState(() => vehicle = v),
      ),
      const SizedBox(height: 12),
      plateField(),
      staffField(_capacity, 'Load capacity (kg) *',
          error: errors['load_capacity_kg'] ?? _capacityProblem,
          keyboard: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
          helper: _vehicle == null ? 'Choose the vehicle first.' : '${asInt(_vehicle!['min'])} to ${asInt(_vehicle!['max'])} kg for a ${_vehicle!['name']}.',
          onChanged: (_) => setState(() {})),
      DropdownButtonFormField<int>(
        initialValue: _hub,
        isExpanded: true,
        decoration: InputDecoration(labelText: 'Home hub *', errorText: errors['home_hub_id'], border: const OutlineInputBorder(), isDense: true),
        items: [for (final h in hubs) DropdownMenuItem(value: asInt(h['id']), child: Text('${h['label']}', overflow: TextOverflow.ellipsis))],
        onChanged: (v) => setState(() => _hub = v),
      ),
      const SizedBox(height: 12),
      doc('license_file', 'Professional driver\'s license *'),
      doc('or_cr_file', 'Vehicle OR/CR *'),
      doc('nbi_file', 'NBI clearance *'),
    ], 'Save courier');
  }
}

// ── Couriers (made by the company, and applications) ──────────

class CouriersScreen extends StatefulWidget {
  const CouriersScreen({super.key});
  @override
  State<CouriersScreen> createState() => _CouriersScreenState();
}

class _CouriersScreenState extends State<CouriersScreen> {
  final _list = GlobalKey<PagedListState>();

  Future<void> _add() async {
    final r = await LogisticsApi.courierForm();
    if (!mounted) return;
    if (!r.ok) return showResult(context, r);
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AddCourierScreen(options: r.body)));
    if (saved == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PagedList(
      key: _list,
      title: 'Couriers',
      initialTab: 'approved',
      empty: 'No couriers here.',
      fab: FloatingActionButton.extended(
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add courier'),
      ),
      fetch: (page, tab) => LogisticsApi.couriers(status: tab ?? 'approved', page: page),
      itemBuilder: (ctx, c, reload) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: () async {
            await Navigator.push(ctx, MaterialPageRoute(builder: (_) => CourierDetailScreen(courierId: asInt(c['id']))));
            reload();
          },
          leading: const Icon(Icons.local_shipping_outlined),
          title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text([
            '${c['vehicle_type'] ?? ''} ${c['plate_number'] ?? ''}'.trim(),
            if (c['load_capacity_kg'] != null) '${c['load_capacity_kg']} kg',
            if (c['home_hub'] != null) '${c['home_hub']}',
            if (c['duty_label'] != null) '${c['duty_label']}',
            if (c['needs_reverification'] == true) 'Re-verify',
          ].where((e) => e.isNotEmpty).join(' · ')),
          trailing: Pill('${c['status_label'] ?? c['status']}', color: Pill.forState('${c['status']}' == 'pending_activation' ? 'pending' : '${c['status']}')),
        ),
      ),
    );
  }
}

/// A courier's record: made by the company (license, capacity, home hub, Resend activation) or an application to review.
class CourierDetailScreen extends StatefulWidget {
  final int courierId;
  const CourierDetailScreen({super.key, required this.courierId});
  @override
  State<CourierDetailScreen> createState() => _CourierDetailScreenState();
}

class _CourierDetailScreenState extends State<CourierDetailScreen> {
  Map<String, dynamic>? _c;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.courier(widget.courierId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _c = asMap(r.body['courier']);
      } else {
        _error = r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final pal = context.bc;
    Widget row(String l, dynamic v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(l, style: TextStyle(color: pal.muted))),
            Expanded(child: Text('${v ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
    Widget docButton(String which, String label, IconData icon) => OutlinedButton.icon(
          onPressed: () => showDocument(context, LogisticsApi.courierDocument(widget.courierId, which), label),
          icon: Icon(icon),
          label: Text(label),
        );
    return Scaffold(
      backgroundColor: pal.background,
      appBar: sellerBar(c == null ? 'Courier' : '${c['name']}'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: c == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.all(12), children: [
                Align(alignment: Alignment.centerLeft, child: Pill('${c['status_label'] ?? c['status']}', color: Pill.forState('${c['status']}' == 'pending_activation' ? 'pending' : '${c['status']}'))),
                const SizedBox(height: 10),
                SectionCard(
                  child: Column(children: [
                    row('Email', c['email']),
                    row('Mobile', c['contact_no']),
                    row('Birthday', c['birthday'] != null ? formatDate(c['birthday'], 'MM/dd/yyyy') : null),
                    row('Vehicle', '${c['vehicle_type'] ?? '—'} · ${c['plate_number'] ?? '—'}'),
                    if (c['linehaul'] == true) ...[
                      if (c['duty_label'] != null) row('Duty', c['duty_label']),
                      if (c['checklist_at'] != null) row('Checklist', formatDateTime(c['checklist_at'])),
                      if (c['last_seen_at'] != null) row('Last seen', formatDateTime(c['last_seen_at'])),
                      row('Load capacity', '${c['load_capacity_kg']} kg'),
                      row('Home hub', c['home_hub']),
                      row('License', '${c['license_number'] ?? '—'} · ${c['license_type'] ?? ''}'),
                      row('DL codes', c['dl_codes']),
                      row('Expires', c['license_expiry'] != null ? formatDate(c['license_expiry'], 'MM/dd/yyyy') : null),
                    ] else ...[
                      row('Address', c['address']),
                      row('Applied', formatDateTime(c['submitted_at'])),
                    ],
                    if (c['rejection_reason'] != null) row('Reason', c['rejection_reason']),
                  ]),
                ),
                Wrap(spacing: 8, children: [
                  if (c['has_license'] == true) docButton('license', 'License', Icons.badge_outlined),
                  if (c['has_or_cr'] == true) docButton('or-cr', 'OR/CR', Icons.description_outlined),
                  if (c['has_nbi'] == true) docButton('nbi', 'NBI clearance', Icons.verified_user_outlined),
                ]),
                if (c['location'] != null)
                  TextButton.icon(
                    onPressed: () => PhoneLocation.navigate(lat: asNum(asMap(c['location'])['lat']), lng: asNum(asMap(c['location'])['lng'])),
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Show current location on the map'),
                  ),
                if (c['needs_reverification'] == true)
                  Card(
                    color: const Color(0xFFFFF7ED),
                    child: ListTile(
                      title: const Text('Capacity, plate or documents changed: check them', style: TextStyle(color: Color(0xFF9A3412))),
                      trailing: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: kOrange),
                        onPressed: () => act(context, () => LogisticsApi.verifyCourier(widget.courierId), then: _load),
                        child: const Text('Verified'),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (c['linehaul'] == true && c['status'] == 'approved')
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                    onPressed: () async {
                      final reason = await showReasonDialog(context,
                          title: 'Suspend courier', message: 'They go Off Duty; trips not yet departed become Unassigned (10 to 300 characters).', confirmLabel: 'Suspend', maxLength: 300);
                      if (reason != null && context.mounted) await act(context, () => LogisticsApi.suspendCourier(widget.courierId, reason), then: _load);
                    },
                    child: const Text('Suspend'),
                  ),
                if (c['linehaul'] == true && c['status'] == 'suspended')
                  BusyButton('Reactivate', busy: false, color: const Color(0xFF15803D),
                      onPressed: () => act(context, () => LogisticsApi.reactivateCourier(widget.courierId), then: _load)),
                if (c['status'] == 'pending_activation')
                  BusyButton('Resend activation email', busy: false, icon: Icons.forward_to_inbox,
                      onPressed: () => act(context, () => LogisticsApi.resendCourierActivation(widget.courierId))),
                if (c['status'] == 'pending') ...[
                  BusyButton('Approve', busy: false, color: const Color(0xFF15803D), onPressed: () async {
                    final r = await act(context, () => LogisticsApi.approveCourier(widget.courierId));
                    if (r.ok && context.mounted) Navigator.pop(context);
                  }),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final reason = await showReasonDialog(context, title: 'Reject application', message: 'Tell the applicant why.', confirmLabel: 'Reject');
                      if (reason == null || !context.mounted) return;
                      final r = await act(context, () => LogisticsApi.rejectCourier(widget.courierId, reason));
                      if (r.ok && context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Reject'),
                  ),
                ],
              ]),
      ),
    );
  }
}

// ── Hubs ───────────────────────────────────────────────────────

class HubsScreen extends StatefulWidget {
  const HubsScreen({super.key});
  @override
  State<HubsScreen> createState() => _HubsScreenState();
}

class _HubsScreenState extends State<HubsScreen> {
  List<Map<String, dynamic>> _hubs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await LogisticsApi.hubs();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = r.ok ? null : r.message;
      if (r.ok) _hubs = asList(r.body['hubs']);
    });
  }

  Future<void> _add() async {
    final code = TextEditingController(text: 'HUB-');
    final name = TextEditingController();
    final address = TextEditingController();
    var errors = <String, String>{};
    var busy = false;
    PhoneLocation? at;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: StatefulBuilder(builder: (ctx, set) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Add a hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  staffField(code, 'Hub code *', error: errors['code'], caps: TextCapitalization.characters, hint: 'HUB-QC', keyboard: TextInputType.visiblePassword),
                  staffField(name, 'Hub name *', error: errors['name'], caps: TextCapitalization.words, hint: 'QC First-Mile Hub'),
                  staffField(address, 'Address', error: errors['address'], caps: TextCapitalization.words),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.my_location),
                    title: Text(at == null ? 'Map location: not set' : 'Map location: ${at!.lat!.toStringAsFixed(5)}, ${at!.lng!.toStringAsFixed(5)}'),
                    subtitle: const Text('Couriers depart and arrive within 500 m of it. Stand at the hub and tap Use here.'),
                    trailing: TextButton(
                      onPressed: () async {
                        final loc = await PhoneLocation.current();
                        if (!ctx.mounted) return;
                        loc.ok ? set(() => at = loc) : showError(ctx, loc.problem ?? 'No location.');
                      },
                      child: const Text('Use here'),
                    ),
                  ),
                  BusyButton('Save hub', busy: busy, onPressed: () async {
                    set(() => busy = true);
                    final r = await LogisticsApi.addHub({'code': code.text.trim(), 'name': name.text.trim(), 'address': address.text.trim(),
                      if (at != null) 'latitude': at!.lat, if (at != null) 'longitude': at!.lng});
                    if (!ctx.mounted) return;
                    set(() {
                      busy = false;
                      errors = r.fieldErrors;
                    });
                    if (r.ok) {
                      Navigator.pop(ctx, true);
                    } else if (r.fieldErrors.isEmpty) {
                      showResult(ctx, r);
                    }
                  }),
                ]),
              );
          }),
        ),
      ),
    );
    code.dispose();
    name.dispose();
    address.dispose();
    if (saved == true) _load();
  }

  /// Save where the hub is: the phone's location now (stand at the hub).
  Future<void> _setLocation(Map<String, dynamic> h) async {
    final loc = await PhoneLocation.current();
    if (!mounted) return;
    if (!loc.ok) return showError(context, loc.problem ?? 'No location.');
    await act(context, () => LogisticsApi.updateHub(asInt(h['id']), {'latitude': loc.lat, 'longitude': loc.lng}), then: _load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar('Hubs'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Add hub'),
      ),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
          Text('A courier drives from a home hub. Couriers see only your own hubs.', style: TextStyle(color: context.bc.muted, fontSize: 12)),
          const SizedBox(height: 8),
          for (final h in _hubs)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.warehouse_outlined),
                title: Text('${h['code']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([h['name'], h['address'], h['latitude'] == null ? 'No map location yet' : 'Map location set']
                    .where((e) => e != null && '$e'.isNotEmpty).join(' · ')),
                trailing: TextButton(onPressed: () => _setLocation(h), child: const Text('Use here')),
              ),
            ),
        ]),
      ),
    );
  }
}
