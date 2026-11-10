import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/buyer_colors.dart';
import '../seller/seller_kit.dart';

export '../seller/seller_kit.dart';
export '../../widgets/reason_dialog.dart';

/// A list page of the logistics portal: optional status tabs with counts, pages, pull to refresh, and a header
/// (e.g. mini stats) — like the web's sc.* list pages.
class PagedList extends StatefulWidget {
  final String title;
  final Future<ApiResponse> Function(int page, String? tab) fetch;
  final Widget Function(BuildContext context, Map<String, dynamic> item, VoidCallback reload) itemBuilder;
  final Widget Function(BuildContext context, Map<String, dynamic> body, VoidCallback reload)? header;
  final String? initialTab;
  final String empty;
  final List<Widget>? actions;
  final Widget? fab;
  final String listKey;

  const PagedList({
    super.key,
    required this.title,
    required this.fetch,
    required this.itemBuilder,
    this.header,
    this.initialTab,
    this.empty = 'Nothing here.',
    this.actions,
    this.fab,
    this.listKey = 'data',
  });

  @override
  State<PagedList> createState() => PagedListState();
}

class PagedListState extends State<PagedList> {
  late String? _tab = widget.initialTab;
  final List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _body = {};
  int _page = 0, _last = 1;
  bool _loading = false;
  String? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) _more();
    });
    reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// The last page's whole answer (riders, stats… that come with the list).
  Map<String, dynamic> get body => _body;

  String? get tab => _tab;

  void setTab(String tab) {
    _tab = tab;
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _items.clear();
      _page = 0;
      _last = 1;
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _last) return;
    setState(() => _loading = true);
    final r = await widget.fetch(_page + 1, _tab);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!r.ok) {
        _error = r.message;
        return;
      }
      _body = r.body;
      _items.addAll(asList(r.body[widget.listKey]));
      final meta = asMap(r.body['meta']);
      _page = meta.isEmpty ? 1 : asInt(meta['current_page']);
      _last = meta.isEmpty ? 1 : asInt(meta['last_page']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = asList(_body['tabs']);
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: sellerBar(widget.title, actions: [...?widget.actions, IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
      floatingActionButton: widget.fab,
      body: Column(children: [
        if (tabs.isNotEmpty)
          SizedBox(
            height: 58,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 10, 16, 8), children: [
              for (final t in tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterPill(
                    '${t['label']} (${t['count']})',
                    selected: (_tab ?? asMap(tabs.first)['key']) == t['key'],
                    onTap: () {
                      _tab = '${t['key']}';
                      reload();
                    },
                  ),
                ),
            ]),
          ),
        Expanded(
          child: LoadState(
            loading: _loading && _items.isEmpty && _body.isEmpty,
            error: _error,
            onRetry: reload,
            child: RefreshIndicator(
              color: kOrange,
              onRefresh: reload,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                itemCount: _items.length + 1 + (widget.header != null ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (widget.header != null) {
                    if (i == 0) return widget.header!(ctx, _body, reload);
                    i--;
                  }
                  if (i == _items.length) {
                    if (_page < _last) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: kOrange)));
                    return _items.isEmpty && !_loading ? EmptyNote(Icons.inbox_outlined, widget.empty) : const SizedBox(height: 8);
                  }
                  return widget.itemBuilder(ctx, _items[i], reload);
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// A parcel row: tracking number, status, route and a few details; [actions] go underneath.
class ParcelCard extends StatelessWidget {
  final Map<String, dynamic> p;
  final List<Widget> actions;
  final List<String> extra;
  final VoidCallback? onTap;
  const ParcelCard(this.p, {super.key, this.actions = const [], this.extra = const [], this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardBox(context),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Pill('${p['status_label']}', color: parcelColor('${p['status']}')),
              const SizedBox(width: 8),
              Expanded(child: Text('#${p['tracking']}', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: Alvy.slate))),
              if (p['cod'] != null) Text(peso(p['cod']), style: Alvy.display(size: 18, color: kOrange, weight: FontWeight.w700)),
            ]),
            if (p['order_number'] != null || p['seller'] != null)
              Text([if (p['order_number'] != null) 'Order ${p['order_number']}', if (p['seller'] != null) '${p['seller']}'].join(' · '),
                  style: TextStyle(fontSize: 12, color: c.muted)),
            const SizedBox(height: 10),
            // The route: an orange dot for the pickup, a slate dot for the drop-off.
            if (p['pickup_address'] != null) _stop(context, kOrange, 'Pickup', '${p['pickup_address']}'),
            _stop(context, Alvy.slate, '${p['receiver'] ?? 'Receiver'}', '${p['dropoff_address'] ?? p['destination'] ?? ''}'),
            const SizedBox(height: 4),
            Text(
              [
                if (asMap(p['area'])['name'] != null) 'Area: ${asMap(p['area'])['name']}',
                if (p['weight_kg'] != null) '${p['weight_kg']} kg',
                p['cod'] != null ? 'Collect on delivery' : 'Paid',
                ...extra,
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: c.muted),
            ),
            if ((p['failure_reason'] ?? '').toString().isNotEmpty)
              Text('${p['failure_reason']}', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: actions),
            ],
          ]),
        ),
      ),
      ),
    );
  }

  Widget _stop(BuildContext context, Color dot, String title, String address) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4, right: 10),
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.bc.text)),
              if (address.isNotEmpty)
                Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: context.bc.textSecondary)),
            ]),
          ),
        ]),
      );
}

Color parcelColor(String s) => switch (s) {
      'delivered' || 'returned' => const Color(0xFF15803D),
      'pending_pickup' || 'pickup_approved' => const Color(0xFFB45309),
      'failed' || 'return_to_sender' || 'lost' || 'damaged' || 'pickup_rejected' || 'cancelled' => const Color(0xFFDC2626),
      _ => Alvy.slate,
    };

/// Choose a rider from [riders] (LogisticsJson::rider rows). Returns the rider id.
Future<int?> pickRider(BuildContext context, List<Map<String, dynamic>> riders, {String title = 'Choose a rider', String? note}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 4), child: Text(title, style: Alvy.display(size: 19, color: ctx.bc.text, weight: FontWeight.w800))),
          if (note != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(note, style: TextStyle(color: ctx.bc.muted))),
          if (riders.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No riders available.')),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final r in riders)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: r['online'] == true ? Alvy.orangeSoft : ctx.bc.subtle,
                    child: Icon(Icons.two_wheeler, size: 20, color: r['online'] == true ? Alvy.orange : ctx.bc.muted),
                  ),
                  title: Text('${r['full_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    if (r['km'] != null) '${r['km']} km away',
                    if (r['area'] != null) '${r['area']}',
                    r['suspended'] == true ? 'Suspended' : (r['online'] == true ? 'Online' : 'Offline'),
                    if (r['active_jobs'] != null) '${r['active_jobs']} active job(s)',
                  ].join(' · ')),
                  onTap: () => Navigator.pop(ctx, asInt(r['id'])),
                ),
            ]),
          ),
        ]),
      ),
    ),
  );
}

/// Runs an action, shows the web's message, and calls [then] when it worked.
Future<ApiResponse> act(BuildContext context, Future<ApiResponse> Function() call, {VoidCallback? then}) async {
  final r = await call();
  if (!context.mounted) return r;
  showResult(context, r);
  // A cut-off answer: the action may have gone through, so show the page as it is now.
  if (r.ok || r.broken) then?.call();
  return r;
}

/// The design's list row for the logistics pages: an icon in a soft square, a title and a muted line, then a trailing widget.
/// [boxed] puts it in a beige box (inside a card); otherwise it is its own white card.
Widget infoRow(BuildContext context,
    {required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap, bool boxed = true, bool navy = false}) {
  final c = context.bc;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: boxed ? c.subtle : c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: boxed ? c.surface : (navy ? Alvy.slateSoft : Alvy.orangeSoft), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 19, color: navy ? Alvy.slate : kOrange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
                if (subtitle != null && subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
              ]),
            ),
            if (trailing != null) trailing,
          ]),
        ),
      ),
    ),
  );
}
