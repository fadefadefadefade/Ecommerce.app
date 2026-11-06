import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../buyer/account/notifications_screen.dart';
import 'rider_screens.dart' show RiderDeliveryScreen;
import '../../services/api_client.dart';
import '../../services/rider_api.dart';
import '../../theme/buyer_colors.dart';
import '../../widgets/product_thumb.dart';
import '../seller/seller_kit.dart';

Color _statusColor(String s) => switch (s) {
      'delivered' => const Color(0xFF059669),
      'in_transit' => const Color(0xFFC2410C),
      'picked_up' => const Color(0xFF6B4C3B),
      'accepted' => const Color(0xFF4338CA),
      'failed' => const Color(0xFFDC2626),
      _ => const Color(0xFFB45309),
    };

/// The step a direct courier does next, with the web's button wording.
const _nextStep = {
  'accept': ('accept', 'Accept delivery'),
  'pickup': ('pickup', 'Confirm pickup'),
  'in_transit': ('in-transit', 'Mark Out for Delivery'),
  'complete': ('complete', 'Mark as delivered'),
};

/// The web's courier dashboard: available deliveries (first come, first served), to pick up, to deliver.
class CourierDashboardScreen extends StatefulWidget {
  const CourierDashboardScreen({super.key});
  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false && TickerMode.of(context)) _load();
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await RiderApi.courierDashboard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = r.body;
        _error = null;
      } else if (_d == null) {
        _error = r.message;
      }
    });
  }

  Future<void> _act(int id, String action, [Map<String, dynamic>? body]) async {
    setState(() => _busy = true);
    final r = await RiderApi.courierAction(id, action, body);
    if (!mounted) return;
    setState(() => _busy = false);
    showResult(context, r);
    _load();
  }

  Future<void> _open(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CourierDeliveryScreen(deliveryId: id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Dashboard', actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
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
                  Text('Hi, ${asMap(d['courier'])['name']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
                  Text('${asMap(d['courier'])['hub']}', style: TextStyle(color: c.muted)),
                  const SizedBox(height: 10),
                  StatGrid([
                    StatTile(label: 'Delivered today', value: '${d['today_done']}', icon: Icons.check_circle_outline, color: const Color(0xFF15803D)),
                    StatTile(label: 'Total earnings', value: peso(d['total_earnings']), icon: Icons.account_balance_wallet_outlined),
                    StatTile(label: 'To pick up', value: '${asList(d['for_pickup']).length}', icon: Icons.inventory_2_outlined, color: const Color(0xFF4338CA)),
                    StatTile(label: 'To deliver', value: '${asList(d['for_delivery']).length}', icon: Icons.local_shipping_outlined, color: const Color(0xFFC2410C)),
                  ]),
                  const SizedBox(height: 12),
                  _section('Available deliveries', asList(d['available']), 'No deliveries waiting for a courier right now.'),
                  _section('To pick up from the seller', asList(d['for_pickup']), 'Nothing to pick up.'),
                  _section('To deliver', asList(d['for_delivery']), 'Nothing to deliver.'),
                ]),
              ),
      ),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> rows, String empty) {
    return SectionCard(
      title: '$title (${rows.length})',
      child: rows.isEmpty
          ? Text(empty, style: TextStyle(color: context.bc.muted))
          : Column(children: [for (final x in rows) _card(x)]),
    );
  }

  Widget _card(Map<String, dynamic> x) {
    final c = context.bc;
    final a = asMap(x['actions']);
    final step = _nextStep.entries.where((e) => a[e.key] == true).map((e) => e.value).firstOrNull;
    return InkWell(
      onTap: x['status'] == 'available' ? null : () => _open(asInt(x['id'])),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Order ${x['order_number']}', style: TextStyle(fontWeight: FontWeight.w800, color: c.text))),
            Pill('${x['status_label']}', color: _statusColor('${x['status']}')),
          ]),
          Text('Pick up: ${x['pickup_name']}${x['pickup_address'] != null ? ' — ${x['pickup_address']}' : ''}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          Text('Deliver to: ${x['buyer'] ?? ''} — ${x['address'] ?? ''}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          Text('${x['items_count']} item(s) · fee ${peso(x['fee'])}', style: TextStyle(fontSize: 12, color: c.muted)),
          if (step != null)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kOrange),
                onPressed: _busy
                    ? null
                    : () async {
                        if (step.$1 == 'complete') return _open(asInt(x['id']));   // notes on the delivery page
                        _act(asInt(x['id']), step.$1);
                      },
                child: Text(step.$2),
              ),
            ),
          const Divider(height: 12),
        ]),
      ),
    );
  }
}

/// The web's courier delivery page: status steps, pickup and delivery addresses, items, earnings and the next action.
class CourierDeliveryScreen extends StatefulWidget {
  final int deliveryId;
  const CourierDeliveryScreen({super.key, required this.deliveryId});
  @override
  State<CourierDeliveryScreen> createState() => _CourierDeliveryScreenState();
}

class _CourierDeliveryScreenState extends State<CourierDeliveryScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await RiderApi.courierDelivery(widget.deliveryId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _d = asMap(r.body['delivery']);
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _act(String action) async {
    setState(() => _busy = true);
    final r = await RiderApi.courierAction(widget.deliveryId, action, action == 'complete' ? {'notes': _notes.text.trim()} : null);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.body['delivery'] != null) _d = asMap(r.body['delivery']);
    });
    showResult(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar(d == null ? 'Delivery' : 'Order ${d['order_number']}'),
      body: LoadState(loading: _loading, error: _error, onRetry: _load, child: d == null ? const SizedBox() : _body(d)),
    );
  }

  Widget _body(Map<String, dynamic> d) {
    final c = context.bc;
    final a = asMap(d['actions']);
    const steps = [('accepted', 'Accepted', 'accepted_at'), ('picked_up', 'Picked up', 'picked_up_at'), ('delivered', 'Delivered', 'delivered_at')];
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [
        Pill('${d['status_label']}', color: _statusColor('${d['status']}')),
        const Spacer(),
        Text('Fee ${peso(d['fee'])}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
      ]),
      const SizedBox(height: 10),
      SectionCard(
        child: Column(children: [
          for (final s in steps)
            Row(children: [
              Icon(d[s.$3] != null ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: d[s.$3] != null ? const Color(0xFF15803D) : c.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(s.$2)),
              Text(d[s.$3] != null ? formatDateTime(d[s.$3]) : '—', style: TextStyle(fontSize: 12, color: c.muted)),
            ]),
        ]),
      ),
      SectionCard(
        title: 'Pick up from',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${d['pickup_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (d['pickup_address'] != null) Text('${d['pickup_address']}'),
          if (d['pickup_phone'] != null) Text('${d['pickup_phone']}'),
          if (d['pickup_scheduled_at'] != null) Text('Pickup ${formatDateTime(d['pickup_scheduled_at'])}', style: TextStyle(color: c.muted)),
        ]),
      ),
      SectionCard(
        title: 'Deliver to',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${d['buyer'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${d['buyer_phone'] ?? ''}'),
          Text('${d['address'] ?? ''}'),
          if ((d['notes'] ?? '').toString().isNotEmpty) Text('Notes: ${d['notes']}', style: TextStyle(color: c.muted)),
        ]),
      ),
      SectionCard(
        title: 'Items',
        child: Column(children: [
          for (final i in asList(d['items']))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                ProductThumb(url: i['image_url'], size: 40),
                const SizedBox(width: 8),
                Expanded(child: Text('${i['title']}')),
                Text('${peso(i['price'])} × ${i['quantity']}'),
              ]),
            ),
        ]),
      ),
      if (a['pickup'] == true) BusyButton('Confirm pickup', busy: _busy, icon: Icons.inventory_2_outlined, onPressed: () => _act('pickup')),
      if (a['in_transit'] == true)
        BusyButton('Mark Out for Delivery', busy: _busy, color: const Color(0xFFC2410C), icon: Icons.local_shipping_outlined, onPressed: () => _act('in-transit')),
      if (a['complete'] == true) ...[
        FormInput(_notes, 'Delivery notes (optional)', maxLines: 2, maxLength: 500),
        BusyButton('Mark as delivered', busy: _busy, color: const Color(0xFF15803D), icon: Icons.check_circle_outline, onPressed: () => _act('complete')),
      ],
    ]);
  }
}

/// The web's courier History: filter by status, order number or delivery date.
class CourierHistoryScreen extends StatefulWidget {
  const CourierHistoryScreen({super.key});
  @override
  State<CourierHistoryScreen> createState() => _CourierHistoryScreenState();
}

class _CourierHistoryScreenState extends State<CourierHistoryScreen> {
  final List<Map<String, dynamic>> _rows = [];
  final _order = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _statuses = {};
  String? _status, _date, _error;
  int _page = 0, _last = 1;
  bool _loading = false;

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
    _order.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _rows.clear();
      _page = 0;
      _last = 1;
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _last) return;
    setState(() => _loading = true);
    final r = await RiderApi.courierHistory(status: _status, q: _order.text.trim().isEmpty ? null : _order.text.trim(), date: _date, page: _page + 1);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!r.ok) {
        _error = r.message;
        return;
      }
      _rows.addAll(asList(r.body['data']));
      _summary = asMap(r.body['summary']);
      _statuses = asMap(r.body['statuses']);
      _page = asInt(asMap(r.body['meta'])['current_page']);
      _last = asInt(asMap(r.body['meta'])['last_page']);
    });
  }

  void _open(Map<String, dynamic> x) {
    final id = x['id'] == null ? null : asInt(x['id']);
    if (id == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => x['kind'] == 'rider' ? RiderDeliveryScreen(deliveryId: id) : CourierDeliveryScreen(deliveryId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Delivery History'),
      body: Column(children: [
        if (_summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: StatGrid([
              StatTile(label: 'Delivered', value: '${_summary['delivered'] ?? 0}', icon: Icons.check_circle_outline, color: const Color(0xFF15803D)),
              StatTile(label: 'In progress', value: '${_summary['in_progress'] ?? 0}', icon: Icons.local_shipping_outlined, color: const Color(0xFFB45309)),
              StatTile(label: 'Failed / returned', value: '${_summary['failed'] ?? 0}', icon: Icons.error_outline, color: const Color(0xFFDC2626)),
              StatTile(label: 'Earned from deliveries', value: peso(_summary['earned']), icon: Icons.payments_outlined, color: const Color(0xFF2563EB)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _order,
                onSubmitted: (_) => _refresh(),
                decoration: const InputDecoration(hintText: 'Order # or tracking no.', isDense: true, prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String?>(
              value: _status,
              hint: const Text('All'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final e in _statuses.entries) DropdownMenuItem(value: e.key, child: Text('${e.value}')),
              ],
              onChanged: (v) {
                _status = v;
                _refresh();
              },
            ),
            IconButton(
              tooltip: 'Delivery date',
              icon: Icon(Icons.event, color: _date != null ? kOrange : null),
              onPressed: () async {
                final p = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: DateTime.now());
                _date = p == null ? null : ymd(p);
                _refresh();
              },
            ),
          ]),
        ),
        if (_date != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('On ${formatDate(_date)}', style: TextStyle(color: c.muted))),
        Expanded(
          child: LoadState(
            loading: _loading && _rows.isEmpty,
            error: _error,
            onRetry: _refresh,
            child: RefreshIndicator(
              color: kOrange,
              onRefresh: _refresh,
              child: _rows.isEmpty
                  ? ListView(children: [
                      EmptyNote(
                          Icons.history,
                          _order.text.trim().isNotEmpty || _status != null || _date != null
                              ? 'No deliveries match these filters. Clear the filters to see all your deliveries.'
                              : 'No delivery history yet. Deliveries your sorting center gives you will appear here, with what you earned.'),
                    ])
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _rows.length,
                      itemBuilder: (_, i) {
                        final x = _rows[i];
                        return Card(
                          elevation: 0,
                          color: c.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
                          child: ListTile(
                            onTap: () => _open(x),
                            title: Text('Order ${x['order_number']} · ${x['buyer'] ?? ''}'),
                            subtitle: Text([
                              if (x['tracking'] != null) '${x['tracking']}',
                              if ((x['place'] ?? '').toString().isNotEmpty) '${x['place']}',
                              x['delivered_at'] != null ? 'Delivered ${formatDateTime(x['delivered_at'])}' : formatDateTime(x['created_at']),
                              if (asNum(x['cod']) > 0) 'COD ${peso(x['cod'])}',
                              'Earned ${peso(x['fee'])}',
                              if ((x['note'] ?? '').toString().isNotEmpty) '${x['note']}',
                            ].join(' · ')),
                            isThreeLine: true,
                            trailing: Pill('${x['status_label']}', color: _statusColor(x['status'] == 'in_progress' ? 'accepted' : x['status'] == 'failed' ? 'failed' : '${x['status']}')),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The web's courier Earnings (profit) page.
class CourierProfitScreen extends StatefulWidget {
  const CourierProfitScreen({super.key});
  @override
  State<CourierProfitScreen> createState() => _CourierProfitScreenState();
}

class _CourierProfitScreenState extends State<CourierProfitScreen> {
  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await RiderApi.courierProfit();
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

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('My Earnings'),
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
                  StatGrid([
                    StatTile(label: 'Total earned', value: peso(d['total_earnings']), icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF15803D)),
                    StatTile(label: 'This month', value: peso(d['month']), icon: Icons.calendar_month),
                    StatTile(label: 'This week', value: peso(d['week']), icon: Icons.date_range),
                    StatTile(label: 'Today', value: peso(d['today']), icon: Icons.today),
                    StatTile(label: 'Deliveries completed', value: '${d['total_deliveries']}', icon: Icons.local_shipping_outlined),
                    StatTile(label: 'Pickups completed', value: '${d['total_pickups'] ?? 0}', icon: Icons.inventory_2_outlined),
                    StatTile(label: 'Average per job', value: peso(d['avg_per_delivery']), icon: Icons.calculate_outlined),
                    StatTile(label: 'Pending (jobs in progress)', value: peso(d['pending']), icon: Icons.hourglass_bottom, color: const Color(0xFFB45309)),
                  ]),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Last 6 months · earned per month',
                    child: asList(d['by_month']).isEmpty
                        ? Text('No jobs yet.', style: TextStyle(color: c.muted))
                        : Column(children: [
                            for (final m in asList(d['by_month']))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('${m['month']}'),
                                subtitle: Text('${m['count']} job(s)'),
                                trailing: Text(peso(m['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                          ]),
                  ),
                  SectionCard(
                    title: 'Recent jobs',
                    child: Column(children: [
                      if (asList(d['recent']).isEmpty)
                        Text('No jobs yet. Pickups and deliveries you complete will show here with what you earned.', style: TextStyle(color: c.muted)),
                      for (final x in asList(d['recent']))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Order ${x['order_number']} · ${x['buyer'] ?? ''}'),
                          subtitle: Text('${formatDateTime(x['delivered_at'])}${x['result'] != null ? ' · ${x['result']}' : ''}'),
                          trailing: Text(peso(x['fee']), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
                        ),
                    ]),
                  ),
                ]),
              ),
      ),
    );
  }
}

/// The web's courier Account page: contact number and photo can change; the rest is read-only.
class CourierAccountScreen extends StatefulWidget {
  const CourierAccountScreen({super.key});
  @override
  State<CourierAccountScreen> createState() => _CourierAccountScreenState();
}

class _CourierAccountScreenState extends State<CourierAccountScreen> {
  Map<String, dynamic>? _c;
  String? _photoUrl, _avatar, _error;
  bool _loading = true, _saving = false;
  Map<String, String> _errors = {};
  final _contact = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  void _fill(Map<String, dynamic> body) {
    _c = asMap(body['courier']);
    _photoUrl = asMap(body['user'])['photo_url'] as String?;
    _contact.text = localPhone(_c!['contact_no']);
    _avatar = null;
  }

  Future<void> _load() async {
    final r = await RiderApi.courierAccount();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _fill(r.body);
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
    final r = await RiderApi.updateCourierAccount(_contact.text.trim(), avatar: _avatar);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = r.fieldErrors;
      if (r.ok && r.body['courier'] != null) _fill(r.body);
    });
    showResult(context, r);
    if (r.ok && r.body['user'] != null) context.read<AuthProvider>().updateUser(asMap(r.body['user']));
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final pal = context.bc;
    Widget row(String l, dynamic v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 110, child: Text(l, style: TextStyle(color: pal.muted))),
            Expanded(child: Text('${v ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
    return Scaffold(
      backgroundColor: pal.background,
      appBar: sellerBar('Account'),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: c == null
            ? const SizedBox()
            : ListView(padding: const EdgeInsets.all(12), children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
                      if (x != null) setState(() => _avatar = x.path);
                    },
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: kOrange,
                      backgroundImage: _avatar != null ? FileImage(File(_avatar!)) as ImageProvider : (_photoUrl != null ? NetworkImage(_photoUrl!) : null),
                      child: _avatar == null && _photoUrl == null
                          ? Text('${c['name']}'.isEmpty ? 'C' : '${c['name']}'[0].toUpperCase(), style: const TextStyle(fontSize: 32, color: Colors.white))
                          : null,
                    ),
                  ),
                ),
                if (_errors['avatar'] != null) Center(child: Text(_errors['avatar']!, style: const TextStyle(color: Color(0xFFDC2626)))),
                const SizedBox(height: 8),
                Center(child: Text('${c['name']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: pal.text))),
                Center(child: Text('${c['masked_email']}', style: TextStyle(color: pal.muted))),
                const SizedBox(height: 12),
                SectionCard(
                  child: Column(children: [
                    FormInput(_contact, 'Contact number', keyboard: TextInputType.phone, error: _errors['contact_no']),
                    BusyButton('Save', busy: _saving, onPressed: _save),
                  ]),
                ),
                SectionCard(
                  title: 'Details',
                  child: Column(children: [
                    row('Sex', c['sex']),
                    row('Age', c['age']),
                    row('Birthday', c['birthday'] != null ? formatDate(c['birthday']) : null),
                    row('Address', c['address']),
                    row('Vehicle', c['vehicle_type']),
                    row('Plate no.', c['plate_number']),
                    row('Hub', c['hub']),
                  ]),
                ),
              ]),
      ),
    );
  }
}

/// A courier (rider) account that is waiting for approval — or was turned down. Until approved it can only
/// see its application (Dashboard), its Notifications (the approval or rejection arrives there and by email)
/// and its Profile (with Log out). Approval opens the rider app the next time the Dashboard loads.
class CourierStatusScreen extends StatefulWidget {
  const CourierStatusScreen({super.key});
  @override
  State<CourierStatusScreen> createState() => _CourierStatusScreenState();
}

class _CourierStatusScreenState extends State<CourierStatusScreen> {
  int _tab = 0;
  int _openedNotifications = 0; // a fresh list each time the tab is opened
  Map<String, dynamic>? _a;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ApiResponse r = await RiderApi.courierStatus();
    if (!mounted) return;
    if (r.ok && r.body['application']?['status'] == 'approved') {
      await context.read<AuthProvider>().checkAuthStatus(); // approved: the rider app opens
      return;
    }
    setState(() {
      _loading = false;
      if (r.ok) {
        _a = r.body['application'] == null ? <String, dynamic>{} : asMap(r.body['application']);
        _error = null;
      } else {
        _error = r.message;
      }
    });
  }

  void _go(int tab) {
    if (tab == 0 && _tab != 0) _load();
    setState(() {
      if (tab == 1 && _tab != 1) _openedNotifications++;
      _tab = tab;
    });
  }

  /// Back: from Notifications / Profile to the Dashboard; on the Dashboard, ask (log out or close the app).
  Future<void> _back() async {
    if (_tab != 0) return _go(0);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave ALVY?'),
        content: const Text('Your application stays under review. You can log in again anytime to check it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'logout'), child: const Text('Log out')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kOrange),
              onPressed: () => Navigator.pop(ctx, 'close'),
              child: const Text('Close app')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'logout') await context.read<AuthProvider>().logout();
    if (choice == 'close') await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: IndexedStack(index: _tab, children: [
          _dashboard(context),
          KeyedSubtree(key: ValueKey('notifications-$_openedNotifications'), child: const NotificationsScreen()),
          _profile(context),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _go,
          indicatorColor: const Color(0xFFFFF1EE),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: kOrange), label: 'Dashboard'),
            NavigationDestination(
                icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications, color: kOrange), label: 'Notifications'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: kOrange), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _dashboard(BuildContext context) {
    final a = _a;
    final c = context.bc;
    final rejected = a?['status'] == 'rejected';
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Courier application', actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: LoadState(
        loading: _loading,
        error: _error,
        onRetry: _load,
        child: a == null
            ? const SizedBox()
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Icon(rejected ? Icons.report_gmailerrorred : Icons.two_wheeler, size: 64, color: rejected ? const Color(0xFFDC2626) : kOrange),
                  const SizedBox(height: 10),
                  Text(
                    a.isEmpty ? 'No application found' : (rejected ? 'Application not approved' : 'Application under review'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.isEmpty
                        ? 'Sign up as a courier on the website first.'
                        : rejected
                            ? 'Reason: ${a['rejection_reason'] ?? '—'}'
                            : 'Your application is waiting for approval from ${a['hub']}. We will send you a notification and an email once it has been reviewed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: rejected ? const Color(0xFFDC2626) : c.muted),
                  ),
                  if (!rejected && a.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Card(
                      color: Color(0xFFFFF7ED),
                      child: ListTile(
                        leading: Icon(Icons.lock_clock_outlined, color: Color(0xFF9A3412)),
                        title: Text('Deliveries open after approval', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF9A3412))),
                        subtitle: Text('Until then you can see your application, notifications and profile.', style: TextStyle(color: Color(0xFF9A3412))),
                      ),
                    ),
                  ],
                  if (a.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionCard(title: 'Your application', child: _details(a)),
                  ],
                ]),
              ),
      ),
    );
  }

  Widget _details(Map<String, dynamic> a) {
    final c = context.bc;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final e in [
        ('Status', a['status'] == 'rejected' ? 'Not approved' : 'Under review'),
        ('Hub', a['hub']),
        ('Name', a['name']),
        ('Business name', a['business_name']),
        ('Contact', a['contact_no']),
        ('Email', a['email']),
        ('Vehicle', '${a['vehicle_type'] ?? ''} · ${a['plate_number'] ?? ''}'),
        ('Address', a['address']),
        ('Submitted', formatDate(a['submitted_at'])),
      ])
        if ((e.$2 ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 110, child: Text(e.$1, style: TextStyle(color: c.muted))),
              Expanded(child: Text('${e.$2}', style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
    ]);
  }

  Widget _profile(BuildContext context) {
    final c = context.bc;
    final user = context.watch<AuthProvider>().user;
    final rejected = _a?['status'] == 'rejected';
    final name = user?.name ?? '';
    return Scaffold(
      backgroundColor: c.background,
      appBar: sellerBar('Profile'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFFFFF1EE),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kOrange)),
          ),
        ),
        const SizedBox(height: 10),
        Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
        Text(user?.email ?? '', textAlign: TextAlign.center, style: TextStyle(color: c.muted)),
        const SizedBox(height: 6),
        Center(
          child: Pill(rejected ? 'Courier · not approved' : 'Courier · waiting for approval',
              color: rejected ? const Color(0xFFDC2626) : const Color(0xFFB45309)),
        ),
        const SizedBox(height: 16),
        if (_a != null && _a!.isNotEmpty) SectionCard(title: 'Application', child: _details(_a!)),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626), minimumSize: const Size.fromHeight(48)),
          onPressed: () => context.read<AuthProvider>().logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ]),
    );
  }
}
