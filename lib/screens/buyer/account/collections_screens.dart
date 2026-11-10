import '../../../widgets/responsive.dart';
import 'package:flutter/material.dart';
import '../../../widgets/voucher_ticket.dart';

import '../../../services/buyer_api.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/buyer_colors.dart';
import '../../../widgets/buyer_kit.dart';
import '../../../widgets/buyer_product_card.dart';
import '../../../widgets/net_image.dart';
import '../product_detail_screen.dart';
import '../store_screen.dart';

/// The website's Wishlist (wishlist/index).
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<dynamic> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.wishlist();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (r.ok) items = r.body['items'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    final list = [for (final p in items) Map<String, dynamic>.from(p)];
    final onSale = list.where((p) => (num.tryParse('${p['discount_percent'] ?? 0}') ?? 0) > 0).length;
    final total = list.fold<num>(0, (t, p) => t + (num.tryParse('${p['price'] ?? 0}') ?? 0));
    final soldOut = list.where((p) => p['out_of_stock'] == true).length;
    return Scaffold(
      backgroundColor: c.background,
      // Tablet tab: the web header is already on top (no second bar); opened as a page it keeps its back bar.
      appBar: Responsive.isWide(context) && !Navigator.of(context).canPop() ? null : AppBar(title: const Text('Wishlist')),
      body: LoadState(
        loading: loading,
        error: error,
        onRetry: _load,
        child: RefreshIndicator(
          color: kOrange,
          onRefresh: _load,
          child: list.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
                      child: const Icon(Icons.favorite_border, size: 44, color: Alvy.orange),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(child: Text('Your wishlist is empty', style: Alvy.display(size: 18, color: c.text, weight: FontWeight.w700))),
                  const SizedBox(height: 6),
                  Center(child: Text('Tap the heart on any item to save it here.', style: TextStyle(color: c.muted))),
                ])
              : CustomScrollView(slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverList.list(children: [
                      // The design's board card: the name, a line, and the item / total / on-sale chips.
                      Container(
                        decoration: cardBox(context, radius: 20),
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('All Saved', style: Alvy.display(size: 21, color: c.text, weight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            const Icon(Icons.favorite, color: Alvy.orange, size: 18),
                          ]),
                          const SizedBox(height: 4),
                          Text('Items you love, kept in one place. Prices and stock update live.',
                              style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _chip(Icons.grid_view_rounded, '${list.length} item${list.length == 1 ? '' : 's'}', c.subtle, c.textSecondary),
                            _chip(Icons.payments_outlined, '${peso(total)} total', c.subtle, c.textSecondary),
                            if (onSale > 0) _chip(Icons.local_fire_department_outlined, '$onSale on sale', Alvy.orangeSoft, Alvy.orangeDark),
                          ]),
                        ]),
                      ),
                      if (onSale > 0 || soldOut > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Alvy.orangeSoft, borderRadius: BorderRadius.circular(16)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const CircleAvatar(
                                radius: 18, backgroundColor: Alvy.orange, child: Icon(Icons.notifications_active_outlined, color: Colors.white, size: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(onSale > 0 ? 'On sale now' : 'Heads up', style: TextStyle(fontWeight: FontWeight.w800, color: c.text)),
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (onSale > 0) '$onSale saved item${onSale == 1 ? ' is' : 's are'} discounted right now.',
                                    if (soldOut > 0) '$soldOut ${soldOut == 1 ? 'is' : 'are'} sold out.',
                                  ].join(' '),
                                  style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 14),
                    ]),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid.extent(
                      maxCrossAxisExtent: Responsive.productTileMaxFor(context),
                      childAspectRatio: 0.6,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: [for (final p in list) BuyerProductCard(product: p)],
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ]),
      );
}

/// The website's My Vouchers (vouchers/wallet): claimed vouchers with their state, and ALVY
/// vouchers that can still be claimed.
class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  List<dynamic> claimed = [];
  List<dynamic> claimable = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.vouchers();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (r.ok) {
        claimed = r.body['claimed'];
        claimable = r.body['claimable'];
      }
    });
  }

  Future<void> _claim(Map v) async {
    final r = await BuyerApi.claimVoucher(v['id']);
    if (!mounted) return;
    showResult(context, r);
    if (r.ok) _load();
  }

  Widget _voucher(Map v, {Widget? trailing, bool muted = false}) => VoucherTicket(v, trailing: trailing, muted: muted);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(title: const Text('My Vouchers')),
      body: LoadState(
        loading: loading,
        error: error,
        onRetry: _load,
        child: RefreshIndicator(
          color: kOrange,
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            // The design's wallet card: how many are ready to use, and the way to the Voucher Center.
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Alvy.orange, Alvy.orangeDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: Alvy.buttonShadow,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('READY TO USE', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                Builder(builder: (_) {
                  final n = claimed.where((v) => v['state'] == 'Available').length;
                  return Text('$n voucher${n == 1 ? '' : 's'}', style: Alvy.display(size: 26, color: Colors.white, weight: FontWeight.w800));
                }),
                Text(claimable.isEmpty ? 'Find more in the Voucher Center' : '${claimable.length} more you can claim',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const VoucherCenterScreen()));
                    _load();
                  },
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Alvy.orange, minimumSize: const Size(0, 42)),
                  icon: const Icon(Icons.local_activity_outlined, size: 18),
                  label: const Text('Voucher Center', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            if (claimable.isNotEmpty) ...[
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('ALVY vouchers you can claim', style: Alvy.display(size: 17, color: context.bc.text, weight: FontWeight.w700))),
              for (final v in claimable)
                _voucher(v,
                    trailing: FilledButton(
                        onPressed: () => _claim(v),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14)),
                        child: const Text('Claim'))),
              const SizedBox(height: 12),
            ],
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Claimed', style: Alvy.display(size: 17, color: context.bc.text, weight: FontWeight.w700))),
            if (claimed.isEmpty) Text('No vouchers yet. Claim them from store pages and product pages.', style: TextStyle(color: context.bc.muted)),
            for (final v in claimed)
              _voucher(v,
                  muted: v['state'] != null && v['state'] != 'Available',
                  trailing: Text(v['state'] ?? '',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: v['state'] == 'Available' ? const Color(0xFF15803D) : context.bc.muted))),
          ]),
        ),
      ),
    );
  }
}

/// The website's Voucher Center: every claimable voucher running now, by type (all, free shipping, ALVY discounts, store).
class VoucherCenterScreen extends StatefulWidget {
  const VoucherCenterScreen({super.key});
  @override
  State<VoucherCenterScreen> createState() => _VoucherCenterScreenState();
}

class _VoucherCenterScreenState extends State<VoucherCenterScreen> {
  static const _tabs = [('all', 'All'), ('shipping', 'Free shipping'), ('discount', 'ALVY discounts'), ('store', 'Store vouchers')];
  String tab = 'all';
  Map<String, dynamic> counts = {};
  List<dynamic> vouchers = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.voucherCenter(tab: tab);
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (r.ok) {
        counts = Map<String, dynamic>.from(r.body['counts'] ?? {});
        vouchers = r.body['vouchers'] ?? [];
      }
    });
  }

  Future<void> _claim(Map v) async {
    final r = await BuyerApi.claimVoucher(v['id']);
    if (!mounted) return;
    showResult(context, r);
    if (r.ok) _load();
  }

  bool _claimingAll = false;
  int get _unclaimed => vouchers.where((v) => v['claimed'] != true && v['used_up'] != true).length;

  Future<void> _claimAll() async {
    setState(() => _claimingAll = true);
    final r = await BuyerApi.claimAllVouchers(tab: tab);
    if (!mounted) return;
    setState(() => _claimingAll = false);
    showResult(context, r);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bc;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Voucher Center')),
      body: Column(children: [
        SizedBox(
          height: 58,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), children: [
            for (final (key, label) in _tabs)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterPill('$label  ${counts[key] ?? 0}', selected: tab == key, onTap: () {
                  setState(() {
                    tab = key;
                    loading = true;
                  });
                  _load();
                }),
              ),
          ]),
        ),
        Expanded(
          child: LoadState(
            loading: loading,
            error: error,
            onRetry: _load,
            child: RefreshIndicator(
              color: kOrange,
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                if (vouchers.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No vouchers to claim right now.', textAlign: TextAlign.center, style: TextStyle(color: c.muted))),
                // The website's "Claim all" on each tab: every voucher of this tab not claimed yet.
                if (_unclaimed > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FilledButton.icon(
                      onPressed: _claimingAll ? null : _claimAll,
                      style: FilledButton.styleFrom(backgroundColor: kOrange, minimumSize: const Size.fromHeight(48)),
                      icon: _claimingAll
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.done_all, size: 18),
                      label: Text('Claim all ($_unclaimed)'),
                    ),
                  ),
                for (final v in vouchers)
                  VoucherTicket(
                    v,
                    muted: v['used_up'] == true,
                    trailing: v['used_up'] == true
                        ? Text('Used', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted))
                        : v['claimed'] == true
                            ? const Text('✓ Claimed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)))
                            : FilledButton(
                                onPressed: () => _claim(v),
                                style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14)),
                                child: const Text('Claim')),
                  ),
                if (vouchers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        'One store voucher per store, plus one ALVY discount and one free-shipping voucher per checkout. Each voucher\'s limits are shown on it.',
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The website's Following (stores/following).
class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  List<dynamic> stores = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await BuyerApi.following();
    if (!mounted) return;
    setState(() {
      loading = false;
      error = r.ok ? null : r.message;
      if (r.ok) stores = r.body['stores'];
    });
  }

  Future<void> _openStore(Map s) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => StoreScreen(sellerId: s['id'])));
    _load();
  }

  /// One followed store, like the website: its numbers and a preview of its 4 newest products.
  Widget _store(Map<String, dynamic> s) {
    final c = context.bc;
    final latest = [for (final p in (s['latest'] as List? ?? [])) Map<String, dynamic>.from(p)];
    final name = '${s['name'] ?? ''}';

    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value, maxLines: 1, style: Alvy.display(size: 15, color: Alvy.orange, weight: FontWeight.w800)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ]),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: cardBox(context, radius: 20),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _openStore(s),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Alvy.orange, width: 2)),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: c.subtle,
                    child: s['logo_url'] != null
                        ? ClipOval(child: NetImage(s['logo_url'], width: 44, height: 44, fit: BoxFit.cover))
                        : Text(name.isEmpty ? '?' : name.substring(0, 1), style: Alvy.display(size: 16, color: Alvy.orange, weight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: Alvy.display(size: 16, color: c.text, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if ((s['location'] ?? '') != '') Text('${s['location']}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ]),
                ),
                if (s['on_vacation'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Alvy.warnSoft, borderRadius: BorderRadius.circular(20)),
                    child: const Text('On vacation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                  ),
                const Icon(Icons.chevron_right),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  stat('${s['products'] ?? 0}', 'Products'),
                  stat('${s['followers'] ?? 0}', 'Followers'),
                  stat(s['rating'] != null ? '★ ${s['rating']}' : '—', '${s['reviews'] ?? 0} reviews'),
                  stat('${s['vouchers'] ?? 0}', 'Vouchers'),
                ]),
              ),
              if (latest.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  for (final (i, p) in latest.indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(slug: p['slug'] ?? '${p['id']}'))),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: (p['thumb_url'] ?? p['image_url']) != null
                                ? NetImage(p['thumb_url'] ?? p['image_url'], fit: BoxFit.cover)
                                : Container(color: Alvy.subtle),
                          ),
                        ),
                      ),
                    ),
                  ],
                  for (var i = latest.length; i < 4; i++) ...[const SizedBox(width: 6), const Expanded(child: SizedBox())],
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bc.background,
      appBar: AppBar(title: const Text('Following')),
      body: LoadState(
        loading: loading,
        error: error,
        onRetry: _load,
        child: stores.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(color: Alvy.orangeSoft, shape: BoxShape.circle),
                    child: const Icon(Icons.storefront_outlined, size: 44, color: Alvy.orange),
                  ),
                  const SizedBox(height: 16),
                  Text('No followed stores yet', style: Alvy.display(size: 18, color: context.bc.text, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Follow a store to see its newest items here.', style: TextStyle(color: context.bc.muted)),
                ]),
              )
            : RefreshIndicator(
                color: kOrange,
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [for (final s in stores) _store(Map<String, dynamic>.from(s))]),
              ),
      ),
    );
  }
}
